extends Area2D

enum PortalMode {
	STAGE_SELECT,
	STAGE_EXIT,
}

@export var portal_mode: PortalMode = PortalMode.STAGE_SELECT
@export_range(1, 3) var target_stage_id: int = 1
@export var auto_trigger: bool = false
@export var custom_title: String = ""

@export_group("Visual Colors")
@export var unlocked_color: Color = Color(0.18, 0.85, 0.78, 0.85)
@export var unlocked_border_color: Color = Color(0.55, 1.0, 0.95, 1.0)
@export var exit_color: Color = Color(0.95, 0.75, 0.2, 0.85)
@export var exit_border_color: Color = Color(1.0, 0.92, 0.5, 1.0)
@export var locked_color: Color = Color(0.22, 0.24, 0.28, 0.85)
@export var locked_border_color: Color = Color(0.4, 0.42, 0.46, 1.0)

@onready var inner_glow: ColorRect = $InnerGlow
@onready var border_line: Line2D = $BorderLine
@onready var title_label: Label = $TitleLabel
@onready var status_label: Label = $StatusLabel
@onready var prompt_label: Label = $PromptLabel

var _player_inside: bool = false
var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if not StageManager.stage_unlocked.is_connected(_on_stage_unlocked):
		StageManager.stage_unlocked.connect(_on_stage_unlocked)

	prompt_label.visible = false
	_update_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or _triggered:
		return

	if event.is_action_pressed("interact"):
		_try_activate_portal()


func is_portal_active() -> bool:
	if portal_mode == PortalMode.STAGE_EXIT:
		return true
	return StageManager.is_stage_unlocked(target_stage_id)


func _update_visuals() -> void:
	var unlocked := is_portal_active()

	if portal_mode == PortalMode.STAGE_EXIT:
		inner_glow.color = exit_color
		border_line.default_color = exit_border_color
		title_label.text = custom_title if custom_title != "" else "EXIT PORTAL"
		status_label.text = "NEXT STAGE" if target_stage_id < StageManager.TOTAL_STAGES else "RETURN LOBBY"
		status_label.modulate = Color(1.0, 0.92, 0.5)
	else:
		title_label.text = custom_title if custom_title != "" else ("STAGE %d" % target_stage_id)
		if unlocked:
			inner_glow.color = unlocked_color
			border_line.default_color = unlocked_border_color
			status_label.text = "UNLOCKED"
			status_label.modulate = Color(0.55, 1.0, 0.9)
		else:
			inner_glow.color = locked_color
			border_line.default_color = locked_border_color
			status_label.text = "LOCKED"
			status_label.modulate = Color(0.65, 0.65, 0.7)

	_update_prompt()


func _update_prompt() -> void:
	if not _player_inside:
		prompt_label.visible = false
		return

	prompt_label.visible = true
	if is_portal_active():
		prompt_label.text = "[E] Enter"
		prompt_label.modulate = Color(1.0, 1.0, 1.0)
	else:
		prompt_label.text = "Locked (Clear Stage %d)" % (target_stage_id - 1)
		prompt_label.modulate = Color(1.0, 0.45, 0.45)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	_player_inside = true
	_update_prompt()

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
