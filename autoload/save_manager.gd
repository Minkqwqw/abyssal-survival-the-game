# Save Manager
extends Node

const SAVE_PATH: String = "user://save_data.cfg"


func _ready() -> void:
	load_game()


func save_game() -> void:
	var config := ConfigFile.new()
	if is_instance_valid(StageManager):
		config.set_value("progression", "max_unlocked_stage", StageManager.max_unlocked_stage)
	if is_instance_valid(GameState):
		config.set_value("progression", "current_floor", GameState.current_floor)
		config.set_value("progression", "unlocked_floors", GameState.unlocked_floors)
		config.set_value("economy", "currency", GameState.currency)
		config.set_value("upgrades", "levels", GameState.upgrade_levels)
	config.save(SAVE_PATH)


func load_game() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	if is_instance_valid(GameState):
		GameState.current_floor = int(config.get_value("progression", "current_floor", 1))
		GameState.unlocked_floors = int(config.get_value("progression", "unlocked_floors", 1))
		GameState.currency = int(config.get_value("economy", "currency", 0))
		var saved_upgrades = config.get_value("upgrades", "levels", {})
		if saved_upgrades is Dictionary:
			for key in saved_upgrades.keys():
				GameState.upgrade_levels[key] = int(saved_upgrades[key])
