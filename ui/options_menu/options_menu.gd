extends CanvasLayer

signal menu_closed

const THEME_NAMES: Array[String] = [
	"Theme 1: Kraken Abyss",
	"Theme 2: Trench Canyon"
]

const DIFFICULTY_ORDER: Array[int] = [
	GameState.Difficulty.NORMAL,
	GameState.Difficulty.HARD,
	GameState.Difficulty.NIGHTMARE,
]

@onready var tex_unchecked: Texture2D = preload("res://ui/main_menu/assets/checkbox_unchecked.png")
@onready var tex_checked: Texture2D = preload("res://ui/main_menu/assets/checkbox_checked.png")

@onready var close_btn: TextureButton = $CenterRoot/PanelFrame/CloseButton
@onready var master_slider: HSlider = $CenterRoot/PanelFrame/MasterRow/MasterSlider
@onready var master_val_label: Label = $CenterRoot/PanelFrame/MasterRow/MasterValueLabel
@onready var music_slider: HSlider = $CenterRoot/PanelFrame/MusicRow/MusicSlider
@onready var music_val_label: Label = $CenterRoot/PanelFrame/MusicRow/MusicValueLabel
@onready var sfx_slider: HSlider = $CenterRoot/PanelFrame/SfxRow/SfxSlider
@onready var sfx_val_label: Label = $CenterRoot/PanelFrame/SfxRow/SfxValueLabel

@onready var fullscreen_check: TextureButton = $CenterRoot/PanelFrame/ToggleRow/FullscreenCheck
@onready var vsync_check: TextureButton = $CenterRoot/PanelFrame/ToggleRow/VsyncCheck

@onready var theme_prev_btn: TextureButton = $CenterRoot/PanelFrame/ThemeRow/ThemePrevButton
@onready var theme_value_label: Label = $CenterRoot/PanelFrame/ThemeRow/ThemeValueLabel
@onready var theme_next_btn: TextureButton = $CenterRoot/PanelFrame/ThemeRow/ThemeNextButton

@onready var diff_prev_btn: TextureButton = $CenterRoot/PanelFrame/DifficultyRow/DiffPrevButton
@onready var diff_value_label: Label = $CenterRoot/PanelFrame/DifficultyRow/DiffValueLabel
@onready var diff_next_btn: TextureButton = $CenterRoot/PanelFrame/DifficultyRow/DiffNextButton

@onready var reset_save_btn: TextureButton = $CenterRoot/PanelFrame/BottomRow/ResetSaveButton
@onready var reset_btn_label: Label = $CenterRoot/PanelFrame/BottomRow/ResetSaveButton/BtnLabel

var _confirming_reset: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(_close)

	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)

	fullscreen_check.pressed.connect(_on_fullscreen_toggled)
	vsync_check.pressed.connect(_on_vsync_toggled)

	theme_prev_btn.pressed.connect(func(): _cycle_theme(-1))
	theme_next_btn.pressed.connect(func(): _cycle_theme(1))

	diff_prev_btn.pressed.connect(func(): _cycle_difficulty(-1))
	diff_next_btn.pressed.connect(func(): _cycle_difficulty(1))

	reset_save_btn.pressed.connect(_on_reset_save_pressed)

	if is_instance_valid(GameState) and not GameState.difficulty_changed.is_connected(_on_difficulty_changed):
		GameState.difficulty_changed.connect(_on_difficulty_changed)

	_sync_from_managers()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _sync_from_managers() -> void:
	var master_v := SaveManager.master_volume if is_instance_valid(SaveManager) else 0.85
	var music_v := SaveManager.music_volume if is_instance_valid(SaveManager) else 0.80
	var sfx_v := SaveManager.sfx_volume if is_instance_valid(SaveManager) else 0.90

	master_slider.set_value_no_signal(master_v * 100.0)
	music_slider.set_value_no_signal(music_v * 100.0)
	sfx_slider.set_value_no_signal(sfx_v * 100.0)

	master_val_label.text = "%d%%" % roundi(master_v * 100.0)
	music_val_label.text = "%d%%" % roundi(music_v * 100.0)
	sfx_val_label.text = "%d%%" % roundi(sfx_v * 100.0)

	var fs_on := SaveManager.fullscreen_enabled if is_instance_valid(SaveManager) else true
	var vs_on := SaveManager.vsync_enabled if is_instance_valid(SaveManager) else true
	_update_checkbox_visual(fullscreen_check, fs_on)
	_update_checkbox_visual(vsync_check, vs_on)

	var theme_idx := SaveManager.menu_bg_theme if is_instance_valid(SaveManager) else 0
	theme_value_label.text = THEME_NAMES[clampi(theme_idx, 0, THEME_NAMES.size() - 1)]

	_refresh_difficulty_controls()


func _is_in_gameplay() -> bool:
	if is_instance_valid(StageManager) and StageManager.has_method("is_in_gameplay"):
		return StageManager.is_in_gameplay()
	var scene := get_tree().current_scene if get_tree() else null
	return scene != null and scene is BaseStage


func _refresh_difficulty_controls() -> void:
	var diff_name := GameState.get_difficulty_name() if is_instance_valid(GameState) else "NORMAL"
	var in_gameplay := _is_in_gameplay()

	diff_value_label.text = diff_name
	diff_value_label.modulate = Color(0.6, 0.68, 0.72, 0.65) if in_gameplay else Color.WHITE

	if diff_prev_btn:
		diff_prev_btn.disabled = in_gameplay
		diff_prev_btn.modulate = Color(0.4, 0.45, 0.5, 0.35) if in_gameplay else Color.WHITE
	if diff_next_btn:
		diff_next_btn.disabled = in_gameplay
		diff_next_btn.modulate = Color(0.4, 0.45, 0.5, 0.35) if in_gameplay else Color.WHITE


func _on_difficulty_changed(_new_diff: int) -> void:
	_refresh_difficulty_controls()


func _update_checkbox_visual(btn: TextureButton, is_checked: bool) -> void:
	if not btn:
		return
	var tex := tex_checked if is_checked else tex_unchecked
	btn.texture_normal = tex
	btn.texture_hover = tex
	btn.texture_pressed = tex


func _on_master_changed(val: float) -> void:
	var norm := clampf(val / 100.0, 0.0, 1.0)
	master_val_label.text = "%d%%" % roundi(val)
	if is_instance_valid(SaveManager):
		SaveManager.set_master_volume(norm)


func _on_music_changed(val: float) -> void:
	var norm := clampf(val / 100.0, 0.0, 1.0)
	music_val_label.text = "%d%%" % roundi(val)
	if is_instance_valid(SaveManager):
		SaveManager.set_music_volume(norm)


func _on_sfx_changed(val: float) -> void:
	var norm := clampf(val / 100.0, 0.0, 1.0)
	sfx_val_label.text = "%d%%" % roundi(val)
	if is_instance_valid(SaveManager):
		SaveManager.set_sfx_volume(norm)


func _on_fullscreen_toggled() -> void:
	if not is_instance_valid(SaveManager):
		return
	var next_state := not SaveManager.fullscreen_enabled
	SaveManager.set_fullscreen(next_state)
	_update_checkbox_visual(fullscreen_check, next_state)


func _on_vsync_toggled() -> void:
	if not is_instance_valid(SaveManager):
		return
	var next_state := not SaveManager.vsync_enabled
	SaveManager.set_vsync(next_state)
	_update_checkbox_visual(vsync_check, next_state)


func _cycle_theme(step: int) -> void:
	if not is_instance_valid(SaveManager):
		return
	var count := THEME_NAMES.size()
	var next_idx := posmod(SaveManager.menu_bg_theme + step, count)
	SaveManager.set_menu_bg_theme(next_idx)
	theme_value_label.text = THEME_NAMES[next_idx]


func _cycle_difficulty(step: int) -> void:
	if not is_instance_valid(GameState) or _is_in_gameplay():
		return
	var cur := DIFFICULTY_ORDER.find(GameState.difficulty)
	if cur == -1:
		cur = 0

	var next_idx := posmod(cur + step, DIFFICULTY_ORDER.size())
	var next_diff: int = DIFFICULTY_ORDER[next_idx]
	GameState.set_difficulty(next_diff, true)
	_refresh_difficulty_controls()


func _on_reset_save_pressed() -> void:
	if not _confirming_reset:
		_confirming_reset = true
		if reset_btn_label:
			reset_btn_label.text = "CONFIRM RESET?"
			reset_btn_label.modulate = Color(1.0, 0.55, 0.55, 1.0)
		return

	_confirming_reset = false
	if is_instance_valid(StageManager):
		StageManager.reset_progress()
	if reset_btn_label:
		reset_btn_label.text = "PROGRESS RESET!"
		reset_btn_label.modulate = Color(0.55, 1.0, 0.85, 1.0)
	_sync_from_managers()


func _close() -> void:
	menu_closed.emit()
	queue_free()
