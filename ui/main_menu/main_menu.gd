extends Control

@export var options_menu_scene: PackedScene = preload("res://ui/options_menu/options_menu.tscn")

@onready var bg_primary: TextureRect = $BgPrimary
@onready var bg_secondary: TextureRect = $BgSecondary
@onready var status_label: Label = $TopStatusBar/StatusLabel
@onready var theme_prev_btn: TextureButton = $ThemeSwitcherBar/ThemePrevBtn
@onready var theme_label: Label = $ThemeSwitcherBar/ThemeNameLabel
@onready var theme_next_btn: TextureButton = $ThemeSwitcherBar/ThemeNextBtn

@onready var start_btn: TextureButton = $LeftMenuColumn/StartButton
@onready var options_btn: TextureButton = $LeftMenuColumn/OptionsButton
@onready var credits_btn: TextureButton = $LeftMenuColumn/CreditsButton
@onready var quit_btn: TextureButton = $LeftMenuColumn/QuitButton

@onready var credits_modal: Control = $CreditsModal
@onready var credits_close_btn: TextureButton = $CreditsModal/CenterPanel/CloseCreditsBtn
@onready var fade_rect: ColorRect = $FadeRect

var _active_options_menu: Node = null
var _transitioning: bool = false


func _ready() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	options_btn.pressed.connect(_on_options_pressed)
	credits_btn.pressed.connect(_on_credits_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	if credits_close_btn:
		credits_close_btn.pressed.connect(func(): credits_modal.visible = false)

	if theme_prev_btn:
		theme_prev_btn.pressed.connect(func(): _cycle_bg_theme(-1))
	if theme_next_btn:
		theme_next_btn.pressed.connect(func(): _cycle_bg_theme(1))

	if is_instance_valid(SaveManager):
		if not SaveManager.settings_changed.is_connected(_on_settings_changed):
			SaveManager.settings_changed.connect(_on_settings_changed)
	if is_instance_valid(GameState):
		if not GameState.currency_changed.is_connected(func(_c): _refresh_status()):
			GameState.currency_changed.connect(func(_c): _refresh_status())
		if not GameState.difficulty_changed.is_connected(func(_d): _refresh_status()):
			GameState.difficulty_changed.connect(func(_d): _refresh_status())

	_apply_bg_theme(false)
	_refresh_status()

	if fade_rect:
		fade_rect.color.a = 1.0
		var tween := create_tween()
		tween.tween_property(fade_rect, "color:a", 0.0, 0.45)


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event.is_action_pressed("ui_cancel"):
		if credits_modal and credits_modal.visible:
			credits_modal.visible = false
			get_viewport().set_input_as_handled()


func _refresh_status() -> void:
	if not status_label:
		return
	var pearls := GameState.currency if is_instance_valid(GameState) else 0
	var max_lvl := StageManager.max_unlocked_level if is_instance_valid(StageManager) else 1
	var total_lvl := StageManager.TOTAL_LEVELS if is_instance_valid(StageManager) else 5
	var diff_name := GameState.get_difficulty_name() if is_instance_valid(GameState) else "NORMAL"
	status_label.text = "Pearls: %d   |   Floor: %d / %d   |   %s" % [pearls, max_lvl, total_lvl, diff_name]


func _cycle_bg_theme(step: int) -> void:
	if not is_instance_valid(SaveManager):
		return
	var next_idx := posmod(SaveManager.menu_bg_theme + step, 2)
	SaveManager.set_menu_bg_theme(next_idx)


func _on_settings_changed() -> void:
	_apply_bg_theme(true)
	_refresh_status()


func _apply_bg_theme(animate: bool) -> void:
	var idx := SaveManager.menu_bg_theme if is_instance_valid(SaveManager) else 0
	if theme_label:
		theme_label.text = "BG 1: Kraken Abyss" if idx == 0 else "BG 2: Trench Canyon"
	if not bg_secondary:
		return
	var target_alpha := 1.0 if idx == 1 else 0.0
	if animate:
		var tween := create_tween()
		tween.tween_property(bg_secondary, "modulate:a", target_alpha, 0.35)
	else:
		bg_secondary.modulate.a = target_alpha


func _on_start_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	if fade_rect:
		var tween := create_tween()
		tween.tween_property(fade_rect, "color:a", 1.0, 0.3)
		await tween.finished
	if is_instance_valid(StageManager):
		StageManager.return_to_lobby()
	else:
		get_tree().change_scene_to_file("res://hub/hub.tscn")


func _on_options_pressed() -> void:
	if _active_options_menu and is_instance_valid(_active_options_menu):
		return
	if credits_modal:
		credits_modal.visible = false
	if options_menu_scene:
		_active_options_menu = options_menu_scene.instantiate()
		add_child(_active_options_menu)


func _on_credits_pressed() -> void:
	if credits_modal:
		credits_modal.visible = not credits_modal.visible


func _on_quit_pressed() -> void:
	if is_instance_valid(SaveManager):
		SaveManager.save_game()
	get_tree().quit()
