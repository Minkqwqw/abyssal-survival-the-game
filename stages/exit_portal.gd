extends Area2D

signal door_proximity_changed(is_near: bool)

enum PortalMode {
	STAGE_SELECT,
	STAGE_EXIT,
}

@export var portal_mode: PortalMode = PortalMode.STAGE_EXIT
@export_range(1, 3) var target_stage_id: int = 1
@export var auto_trigger: bool = false
@export var custom_title: String = ""
@export var exit_unlocked: bool = false

@export_group("Proximity Door Animation (2-5m)")
@export var meters_to_pixels: float = 80.0
@export_range(2.0, 5.0, 0.1) var proximity_open_meters: float = 3.5
@export_range(2.5, 6.0, 0.1) var proximity_close_meters: float = 4.5
@export var door_open_duration: float = 0.42

@export_group("Visual Colors")
@export var unlocked_color: Color = Color(0.18, 0.85, 0.78, 0.85)
@export var unlocked_border_color: Color = Color(0.55, 1.0, 0.95, 1.0)
@export var exit_color: Color = Color(0.22, 0.95, 0.82, 0.88)
@export var exit_border_color: Color = Color(0.65, 1.0, 0.95, 1.0)
@export var locked_color: Color = Color(0.22, 0.24, 0.28, 0.85)
@export var locked_border_color: Color = Color(0.4, 0.42, 0.46, 1.0)

@onready var outer_frame: ColorRect = get_node_or_null("OuterFrame")
@onready var inner_glow: ColorRect = get_node_or_null("InnerGlow")
@onready var border_line: Line2D = get_node_or_null("BorderLine")
@onready var door_sprite: AnimatedSprite2D = get_node_or_null("DoorAnimatedSprite")
@onready var left_leaf: ColorRect = get_node_or_null("DoorPanels/LeftLeaf")
@onready var right_leaf: ColorRect = get_node_or_null("DoorPanels/RightLeaf")
@onready var lock_indicator: ColorRect = get_node_or_null("DoorPanels/LockIndicator")
@onready var title_label: Label = get_node_or_null("TitleLabel")
@onready var status_label: Label = get_node_or_null("StatusLabel")
@onready var prompt_label: Label = get_node_or_null("PromptLabel")

var _player_inside: bool = false
var _player_near_door: bool = false
var _door_anim_open: bool = false
var _triggered: bool = false
var _door_tween: Tween = null
var _pulse_time: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if is_instance_valid(StageManager) and not StageManager.stage_unlocked.is_connected(_on_stage_unlocked):
		StageManager.stage_unlocked.connect(_on_stage_unlocked)

	if prompt_label:
		prompt_label.visible = false

	_set_door_panels_immediate(0.0)
	_update_visuals()


func _physics_process(delta: float) -> void:
	_pulse_time += delta
	var unlocked := is_portal_active()

	if not unlocked:
		if _door_anim_open or _player_near_door:
			_player_near_door = false
			_animate_door(false)
		return

	# Cek jarak player terhadap pintu (2 - 5 meter sesuai konsep stage game)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and is_instance_valid(player):
		var dist_px := global_position.distance_to(player.global_position)
		var open_px := proximity_open_meters * meters_to_pixels
		var close_px := maxi(int(open_px + 32.0), int(proximity_close_meters * meters_to_pixels))

		if not _player_near_door and dist_px <= open_px:
			_player_near_door = true
			_animate_door(true)
			door_proximity_changed.emit(true)
			_update_visuals()
		elif _player_near_door and dist_px > close_px:
			_player_near_door = false
			_animate_door(false)
			door_proximity_changed.emit(false)
			_update_visuals()

	if inner_glow and _door_anim_open:
		inner_glow.modulate.a = 0.82 + 0.18 * sin(_pulse_time * 4.5)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or _triggered:
		return

	if event.is_action_pressed("interact"):
		_try_activate_portal()


func set_exit_unlocked(unlocked: bool) -> void:
	var changed := (exit_unlocked != unlocked)
	exit_unlocked = unlocked
	if not unlocked:
		_player_near_door = false
		_animate_door(false)
	elif changed:
		# Status berubah menjadi UNLOCKED; cek apakah player sudah dekat (2-5m)
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player and is_instance_valid(player):
			var dist_px := global_position.distance_to(player.global_position)
			if dist_px <= proximity_open_meters * meters_to_pixels:
				_player_near_door = true
				_animate_door(true)
			else:
				_animate_door(false)
	_update_visuals()


func is_portal_active() -> bool:
	if portal_mode == PortalMode.STAGE_EXIT:
		return exit_unlocked
	return StageManager.is_stage_unlocked(target_stage_id)


func _animate_door(open_state: bool) -> void:
	_door_anim_open = open_state

	if door_sprite and door_sprite.sprite_frames:
		if not is_portal_active():
			door_sprite.play("locked")
		elif open_state:
			door_sprite.play("opening")
		else:
			if door_sprite.animation == "opening" or door_sprite.animation == "open":
				door_sprite.play_backwards("opening")
			else:
				door_sprite.play("unlocked_closed")

	if _door_tween and _door_tween.is_running():
		_door_tween.kill()

	_door_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var target_open := 1.0 if (is_portal_active() and open_state) else 0.0

	if left_leaf:
		_door_tween.tween_property(left_leaf, "position:x", lerpf(-52.0, -98.0, target_open), door_open_duration)
		_door_tween.tween_property(left_leaf, "size:x", lerpf(51.0, 12.0, target_open), door_open_duration)
	if right_leaf:
		_door_tween.tween_property(right_leaf, "position:x", lerpf(1.0, 86.0, target_open), door_open_duration)
		_door_tween.tween_property(right_leaf, "size:x", lerpf(51.0, 12.0, target_open), door_open_duration)
	if lock_indicator:
		_door_tween.tween_property(lock_indicator, "modulate:a", 0.0 if target_open > 0.5 else 1.0, door_open_duration * 0.6)


func _set_door_panels_immediate(open_ratio: float) -> void:
	if left_leaf:
		left_leaf.position.x = lerpf(-52.0, -98.0, open_ratio)
		left_leaf.size.x = lerpf(51.0, 12.0, open_ratio)
	if right_leaf:
		right_leaf.position.x = lerpf(1.0, 86.0, open_ratio)
		right_leaf.size.x = lerpf(51.0, 12.0, open_ratio)


func _update_visuals() -> void:
	if not is_inside_tree():
		return

	var unlocked := is_portal_active()

	if door_sprite and door_sprite.sprite_frames and not _door_anim_open:
		door_sprite.play("unlocked_closed" if unlocked else "locked")

	if lock_indicator:
		lock_indicator.color = Color(0.25, 0.98, 0.85, 0.95) if unlocked else Color(0.95, 0.28, 0.28, 0.95)

	if portal_mode == PortalMode.STAGE_EXIT:
		if title_label:
			title_label.text = custom_title if custom_title != "" else "EXIT PORTAL"
		if unlocked:
			if inner_glow:
				inner_glow.color = exit_color if _door_anim_open else Color(0.12, 0.48, 0.45, 0.65)
			if border_line:
				border_line.default_color = exit_border_color
			if status_label:
				if _door_anim_open:
					status_label.text = "OPEN — NEXT STAGE" if target_stage_id < StageManager.TOTAL_STAGES else "OPEN — LOBBY"
					status_label.modulate = Color(0.55, 1.0, 0.92)
				else:
					status_label.text = "UNLOCKED (APPROACH)"
					status_label.modulate = Color(1.0, 0.92, 0.5)
		else:
			if inner_glow:
				inner_glow.color = locked_color
			if border_line:
				border_line.default_color = locked_border_color
			if status_label:
				status_label.text = "LOCKED"
				status_label.modulate = Color(0.65, 0.65, 0.7)
	else:
		if title_label:
			title_label.text = custom_title if custom_title != "" else ("STAGE %d" % target_stage_id)
		if unlocked:
			if inner_glow:
				inner_glow.color = unlocked_color
			if border_line:
				border_line.default_color = unlocked_border_color
			if status_label:
				status_label.text = "UNLOCKED"
				status_label.modulate = Color(0.55, 1.0, 0.9)
		else:
			if inner_glow:
				inner_glow.color = locked_color
			if border_line:
				border_line.default_color = locked_border_color
			if status_label:
				status_label.text = "LOCKED"
				status_label.modulate = Color(0.65, 0.65, 0.7)

	_update_prompt()


func _update_prompt() -> void:
	if not prompt_label:
		return
	if not _player_inside:
		prompt_label.visible = false
		return

	prompt_label.visible = true
	if is_portal_active():
		prompt_label.text = "[E] Enter Next Stage" if target_stage_id < StageManager.TOTAL_STAGES else "[E] Return to Lobby"
		prompt_label.modulate = Color(1.0, 1.0, 1.0)
	elif portal_mode == PortalMode.STAGE_EXIT:
		prompt_label.text = "Locked (Clear Stage First)"
		prompt_label.modulate = Color(1.0, 0.45, 0.45)
	else:
		prompt_label.text = "Locked (Clear Stage %d)" % (target_stage_id - 1)
		prompt_label.modulate = Color(1.0, 0.45, 0.45)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	_player_inside = true
	if is_portal_active() and not _door_anim_open:
		_player_near_door = true
		_animate_door(true)
	_update_visuals()

	if auto_trigger and is_portal_active():
		_try_activate_portal()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	_player_inside = false
	_update_prompt()


func _on_stage_unlocked(_new_max_stage: int) -> void:
	_update_visuals()


func _try_activate_portal() -> void:
	if _triggered or not is_portal_active():
		return

	_triggered = true
	if portal_mode == PortalMode.STAGE_EXIT:
		StageManager.complete_stage(target_stage_id)
	else:
		StageManager.load_stage(target_stage_id)
