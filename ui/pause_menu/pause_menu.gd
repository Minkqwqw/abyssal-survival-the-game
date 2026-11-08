extends CanvasLayer

signal menu_closed

@export var options_menu_scene: PackedScene = preload("res://ui/options_menu/options_menu.tscn")

@onready var close_btn: TextureButton = $CenterRoot/PanelFrame/CloseButton
@onready var status_label: Label = $CenterRoot/PanelFrame/StatusLabel
@onready var resume_btn: TextureButton = $CenterRoot/PanelFrame/ButtonColumn/ResumeButton
@onready var settings_btn: TextureButton = $CenterRoot/PanelFrame/ButtonColumn/SettingsButton
@onready var lobby_btn: TextureButton = $CenterRoot/PanelFrame/ButtonColumn/LobbyButton
@onready var main_menu_btn: TextureButton = $CenterRoot/PanelFrame/ButtonColumn/MainMenuButton
@onready var exit_btn: TextureButton = $CenterRoot/PanelFrame/ButtonColumn/ExitGameButton

var _active_options_menu: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	if close_btn:
		close_btn.pressed.connect(_on_resume_pressed)
	if resume_btn:
		resume_btn.pressed.connect(_on_resume_pressed)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	if lobby_btn:
		lobby_btn.pressed.connect(_on_lobby_pressed)
	if main_menu_btn:
		main_menu_btn.pressed.connect(_on_main_menu_pressed)
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_pressed)

	if is_instance_valid(GameState):
		if not GameState.difficulty_changed.is_connected(_on_state_updated):
			GameState.difficulty_changed.connect(_on_state_updated)
		if not GameState.currency_changed.is_connected(_on_state_updated):
			GameState.currency_changed.connect(_on_state_updated)

	_refresh_status()


func _unhandled_input(event: InputEvent) -> void:
	if _active_options_menu and is_instance_valid(_active_options_menu):
		return
	if visible and event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()


func _on_state_updated(_val: int) -> void:
	_refresh_status()


func _refresh_status() -> void:
	if not status_label:
		return
	var lvl := StageManager.current_level_id if is_instance_valid(StageManager) else 1
	var stg := maxi(1, StageManager.current_stage_id) if is_instance_valid(StageManager) else 1
	var total_stg := StageManager.TOTAL_STAGES if is_instance_valid(StageManager) else 3
	var diff_name := GameState.get_difficulty_name() if is_instance_valid(GameState) else "NORMAL"
	var pearls := GameState.currency if is_instance_valid(GameState) else 0
	status_label.text = "Level %d  |  Stage %d / %d  |  %s  |  Pearls: %d" % [lvl, stg, total_stg, diff_name, pearls]


func _on_resume_pressed() -> void:
	get_tree().paused = false
	menu_closed.emit()
	queue_free()


func _on_settings_pressed() -> void:
	if _active_options_menu and is_instance_valid(_active_options_menu):
		return
	if options_menu_scene:
		_active_options_menu = options_menu_scene.instantiate()
		add_child(_active_options_menu)


func _on_lobby_pressed() -> void:
	get_tree().paused = false
	if is_instance_valid(StageManager):
		StageManager.return_to_lobby()
	else:
		get_tree().change_scene_to_file("res://hub/hub.tscn")


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	if is_instance_valid(StageManager):
		StageManager.open_main_menu()
	else:
		get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")


func _on_exit_pressed() -> void:
	get_tree().paused = false
	if is_instance_valid(SaveManager):
		SaveManager.save_game()
	get_tree().quit()
