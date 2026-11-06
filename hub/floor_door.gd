extends Area2D

@export_range(1, 3) var target_stage_id: int = 1
@export var custom_title: String = ""

@export_group("Visual Colors")
@export var unlocked_color: Color = Color(0.18, 0.85, 0.78, 0.85)
@export var unlocked_border_color: Color = Color(0.55, 1.0, 0.95, 1.0)
@export var locked_color: Color = Color(0.22, 0.24, 0.28, 0.85)
@export var locked_border_color: Color = Color(0.4, 0.42, 0.46, 1.0)

@onready var inner_glow: ColorRect = get_node_or_null("InnerGlow")
@onready var border_line: Line2D = get_node_or_null("BorderLine")
@onready var title_label: Label = get_node_or_null("TitleLabel")
@onready var status_label: Label = get_node_or_null("StatusLabel")
@onready var prompt_label: Label = get_node_or_null("PromptLabel")

var _player_inside: bool = false
var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if not StageManager.stage_unlocked.is_connected(_on_stage_unlocked):
		StageManager.stage_unlocked.connect(_on_stage_unlocked)

	if prompt_label:
		prompt_label.visible = false
	_update_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or _triggered:
		return

	if event.is_action_pressed("interact") and is_door_unlocked():
		_triggered = true
		StageManager.load_stage(target_stage_id)


func is_door_unlocked() -> bool:
	return StageManager.is_stage_unlocked(target_stage_id)


func _update_visuals() -> void:
	if not is_inside_tree():
		return

	var unlocked := is_door_unlocked()
	if title_label:
		title_label.text = custom_title if custom_title != "" else ("FLOOR %d" % target_stage_id)

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
	if is_door_unlocked():
		prompt_label.text = "[E] Enter"
		prompt_label.modulate = Color(1.0, 1.0, 1.0)
	else:
		prompt_label.text = "Locked (Clear Stage %d)" % (target_stage_id - 1)
		prompt_label.modulate = Color(1.0, 0.45, 0.45)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_update_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_update_prompt()


func _on_stage_unlocked(_new_max_stage: int) -> void:
	_update_visuals()
