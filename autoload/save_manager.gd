# Save Manager
extends Node

signal settings_changed

const SAVE_PATH: String = "user://save_data.cfg"

var master_volume: float = 0.85
var music_volume: float = 0.80
var sfx_volume: float = 0.90
var fullscreen_enabled: bool = true
var vsync_enabled: bool = true
var menu_bg_theme: int = 0


func _ready() -> void:
	_ensure_audio_buses()
	load_game()
	apply_settings()


func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		var music_idx := AudioServer.bus_count
		AudioServer.add_bus(music_idx)
		AudioServer.set_bus_name(music_idx, "Music")
		AudioServer.set_bus_send(music_idx, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		var sfx_idx := AudioServer.bus_count
		AudioServer.add_bus(sfx_idx)
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")


func apply_settings() -> void:
	_ensure_audio_buses()
	_set_bus_linear("Master", master_volume)
	_set_bus_linear("Music", music_volume)
	_set_bus_linear("SFX", sfx_volume)

	var current_mode := DisplayServer.window_get_mode()
	if fullscreen_enabled:
		if current_mode != DisplayServer.WINDOW_MODE_FULLSCREEN and current_mode != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if current_mode != DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

	var target_vsync := DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	if DisplayServer.window_get_vsync_mode() != target_vsync:
		DisplayServer.window_set_vsync_mode(target_vsync)

	settings_changed.emit()


func _set_bus_linear(bus_name: String, linear_val: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var clamped := clampf(linear_val, 0.0, 1.0)
	if clamped <= 0.005:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(clamped))


func set_master_volume(val: float) -> void:
	master_volume = clampf(val, 0.0, 1.0)
	_set_bus_linear("Master", master_volume)
	save_game()
	settings_changed.emit()


func set_music_volume(val: float) -> void:
	music_volume = clampf(val, 0.0, 1.0)
	_set_bus_linear("Music", music_volume)
	save_game()
	settings_changed.emit()


func set_sfx_volume(val: float) -> void:
	sfx_volume = clampf(val, 0.0, 1.0)
	_set_bus_linear("SFX", sfx_volume)
	save_game()
	settings_changed.emit()


func set_fullscreen(enabled: bool) -> void:
	fullscreen_enabled = enabled
	apply_settings()
	save_game()


func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	apply_settings()
	save_game()


func set_menu_bg_theme(theme_idx: int) -> void:
	menu_bg_theme = clampi(theme_idx, 0, 1)
	save_game()
	settings_changed.emit()


func save_game() -> void:
	var config := ConfigFile.new()
	if is_instance_valid(StageManager):
		config.set_value("progression", "max_unlocked_stage", StageManager.max_unlocked_stage)
		config.set_value("progression", "max_unlocked_level", StageManager.max_unlocked_level)
		config.set_value("progression", "current_level_id", StageManager.current_level_id)
	if is_instance_valid(GameState):
		config.set_value("progression", "current_floor", GameState.current_floor)
		config.set_value("progression", "unlocked_floors", GameState.unlocked_floors)
		config.set_value("progression", "difficulty", GameState.default_difficulty)
		config.set_value("economy", "currency", GameState.currency)
		config.set_value("upgrades", "levels", GameState.upgrade_levels)

	config.set_value("settings", "master_volume", master_volume)
	config.set_value("settings", "music_volume", music_volume)
	config.set_value("settings", "sfx_volume", sfx_volume)
	config.set_value("settings", "fullscreen", fullscreen_enabled)
	config.set_value("settings", "vsync", vsync_enabled)
	config.set_value("settings", "menu_bg_theme", menu_bg_theme)
	config.save(SAVE_PATH)


func load_game() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	if is_instance_valid(GameState):
		GameState.current_floor = int(config.get_value("progression", "current_floor", 1))
		var unlocked_f := int(config.get_value("progression", "unlocked_floors", 1))
		var unlocked_l := int(config.get_value("progression", "max_unlocked_level", unlocked_f))
		GameState.unlocked_floors = maxi(unlocked_f, unlocked_l)
		GameState.currency = int(config.get_value("economy", "currency", 0))
		var saved_difficulty := int(config.get_value("progression", "difficulty", GameState.Difficulty.NORMAL))
		GameState.default_difficulty = clampi(saved_difficulty, GameState.Difficulty.NORMAL, GameState.Difficulty.NIGHTMARE)
		GameState.difficulty = GameState.default_difficulty
		var saved_upgrades = config.get_value("upgrades", "levels", {})
		if saved_upgrades is Dictionary:
			for key in saved_upgrades.keys():
				GameState.upgrade_levels[key] = int(saved_upgrades[key])

	master_volume = clampf(float(config.get_value("settings", "master_volume", 0.85)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value("settings", "music_volume", 0.80)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("settings", "sfx_volume", 0.90)), 0.0, 1.0)
	fullscreen_enabled = bool(config.get_value("settings", "fullscreen", true))
	vsync_enabled = bool(config.get_value("settings", "vsync", true))
	menu_bg_theme = clampi(int(config.get_value("settings", "menu_bg_theme", 0)), 0, 1)
