extends Node2D

# View-Box (Camera2D) limits matching the 2201.6 x 1228.8 scaled Lobby Map (1376x768 * 1.6)
const VIEWBOX_LEFT: int = -1100
const VIEWBOX_RIGHT: int = 1100
const VIEWBOX_TOP: int = -614
const VIEWBOX_BOTTOM: int = 614

@export var difficulty_menu_scene: PackedScene = preload("res://ui/difficulty_menu/difficulty_menu.tscn")
@export var options_menu_scene: PackedScene = preload("res://ui/options_menu/options_menu.tscn")

@onready var spawn_point: Marker2D = get_node_or_null("SpawnPoint")
@onready var player: CharacterBody2D = get_node_or_null("Player")
@onready var checkpoint_label: Label = get_node_or_null("HUD/CheckpointLabel")
@onready var help_label: Label = get_node_or_null("HUD/HelpLabel")
@onready var main_menu_btn: TextureButton = get_node_or_null("HUD/MainMenuButton")
@onready var options_btn: TextureButton = get_node_or_null("HUD/OptionsButton")
@onready var lab_door_area: Area2D = get_node_or_null("LabElevatorDoor")
@onready var lab_door_prompt: Label = get_node_or_null("LabElevatorDoor/PromptLabel")
@onready var reactor_area: Area2D = get_node_or_null("ReactorZone")
@onready var reactor_prompt: Label = get_node_or_null("ReactorZone/PromptLabel")
@onready var reactor_glow: Polygon2D = get_node_or_null("ReactorZone/ReactorPulseGlow")

var _player_at_lab_door: bool = false
var _player_at_reactor: bool = false
var _entering_elevator: bool = false
var _pulse_time: float = 0.0
var _active_difficulty_menu: Node = null
var _active_options_menu: Node = null


func _ready() -> void:
	if player:
		if spawn_point:
			player.global_position = spawn_point.global_position
		_configure_player_viewbox()

	if main_menu_btn:
		main_menu_btn.pressed.connect(_on_main_menu_pressed)
	if options_btn:
		options_btn.pressed.connect(_on_options_pressed)

	if lab_door_area:
		lab_door_area.body_entered.connect(_on_lab_door_body_entered)
		lab_door_area.body_exited.connect(_on_lab_door_body_exited)
	if lab_door_prompt:
		lab_door_prompt.visible = false

	if reactor_area:
		reactor_area.body_entered.connect(_on_reactor_body_entered)
		reactor_area.body_exited.connect(_on_reactor_body_exited)
	if reactor_prompt:
		reactor_prompt.visible = false

	if is_instance_valid(StageManager):
		if not StageManager.stage_unlocked.is_connected(_on_progress_updated):
			StageManager.stage_unlocked.connect(_on_progress_updated)
		if StageManager.has_signal("level_unlocked") and not StageManager.level_unlocked.is_connected(_on_progress_updated):
			StageManager.level_unlocked.connect(_on_progress_updated)

	if is_instance_valid(GameState) and not GameState.currency_changed.is_connected(_on_currency_changed):
		GameState.currency_changed.connect(_on_currency_changed)
	if is_instance_valid(GameState) and not GameState.difficulty_changed.is_connected(_on_difficulty_changed):
		GameState.difficulty_changed.connect(_on_difficulty_changed)

	_update_hud()


func _process(delta: float) -> void:
	_pulse_time += delta
	if reactor_glow:
		reactor_glow.color.a = 0.14 + 0.08 * sin(_pulse_time * 2.6)


func _configure_player_viewbox() -> void:
	if not player:
		return
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam:
		cam.limit_left = VIEWBOX_LEFT
		cam.limit_right = VIEWBOX_RIGHT
		cam.limit_top = VIEWBOX_TOP
		cam.limit_bottom = VIEWBOX_BOTTOM
		cam.limit_smoothed = true
		cam.position_smoothing_enabled = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_checkpoint"):
		StageManager.reset_progress()
		_update_hud()
		return

	if event.is_action_pressed("interact"):
		if _player_at_lab_door and not _entering_elevator:
			_entering_elevator = true
			StageManager.open_elevator_loading()
		elif _player_at_reactor:
			_toggle_difficulty_menu()


func _on_main_menu_pressed() -> void:
	if is_instance_valid(StageManager):
		StageManager.open_main_menu()
	else:
		get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")


func _on_options_pressed() -> void:
	if _active_options_menu and is_instance_valid(_active_options_menu):
		_active_options_menu.queue_free()
		_active_options_menu = null
	elif options_menu_scene:
		_active_options_menu = options_menu_scene.instantiate()
		add_child(_active_options_menu)


func _on_lab_door_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_at_lab_door = true
		if lab_door_prompt:
			lab_door_prompt.visible = true


func _on_lab_door_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_at_lab_door = false
		if lab_door_prompt:
			lab_door_prompt.visible = false


func _on_reactor_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_at_reactor = true
		if reactor_prompt:
			reactor_prompt.modulate = Color(0.65, 1.0, 0.9, 1.0)
			reactor_prompt.visible = true
		_update_reactor_prompt()


func _on_reactor_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_at_reactor = false
		_close_difficulty_menu()
		if reactor_prompt:
			reactor_prompt.visible = false


func _update_reactor_prompt() -> void:
	if reactor_prompt == null:
		return
	var diff_name: String = GameState.get_difficulty_name() if is_instance_valid(GameState) else "NORMAL"
	reactor_prompt.text = "[E] Reactor Core — Difficulty: %s" % diff_name


func _toggle_difficulty_menu() -> void:
	if _active_difficulty_menu and is_instance_valid(_active_difficulty_menu):
		_close_difficulty_menu()
	elif difficulty_menu_scene:
		_active_difficulty_menu = difficulty_menu_scene.instantiate()
		get_tree().current_scene.add_child(_active_difficulty_menu)


func _close_difficulty_menu() -> void:
	if _active_difficulty_menu and is_instance_valid(_active_difficulty_menu):
		_active_difficulty_menu.queue_free()
	_active_difficulty_menu = null


func _on_difficulty_changed(_new_difficulty: int) -> void:
	if _player_at_reactor:
		_update_reactor_prompt()


func _on_progress_updated(_val: int) -> void:
	_update_hud()


func _on_currency_changed(_new_currency: int) -> void:
	_update_hud()


func _update_hud() -> void:
	if checkpoint_label:
		var coins := GameState.currency if is_instance_valid(GameState) else 0
		var max_lvl := StageManager.max_unlocked_level if "max_unlocked_level" in StageManager else StageManager.max_unlocked_stage
		var total_lvl := StageManager.TOTAL_LEVELS if "TOTAL_LEVELS" in StageManager else StageManager.TOTAL_STAGES
		checkpoint_label.text = "Progress: Level %d / %d Unlocked   |   Pearls: %d" % [
			max_lvl,
			total_lvl,
			coins
		]
