# Global Game State
extends Node

signal currency_changed(new_currency: int)
signal upgrade_purchased(upgrade_id: String, new_level: int)
signal floor_unlocked(new_max_floor: int)

var current_floor: int = 1
var unlocked_floors: int = 1
var currency: int = 0

var upgrade_levels: Dictionary = {
	"max_health": 0,
	"dash_cooldown": 0,
}


func add_currency(amount: int) -> void:
	if amount <= 0:
		return
	currency += amount
	currency_changed.emit(currency)
	if is_instance_valid(SaveManager):
		SaveManager.save_game()


func spend_currency(amount: int) -> bool:
	if amount < 0 or currency < amount:
		return false
	currency -= amount
	currency_changed.emit(currency)
	return true


func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrade_levels.get(upgrade_id, 0))


func purchase_upgrade(upgrade_id: String, cost: int, max_level: int = 5) -> bool:
	var current_lvl := get_upgrade_level(upgrade_id)
	if current_lvl >= max_level:
		return false
	if not spend_currency(cost):
		return false

	upgrade_levels[upgrade_id] = current_lvl + 1
	upgrade_purchased.emit(upgrade_id, current_lvl + 1)
	if is_instance_valid(SaveManager):
		SaveManager.save_game()
	return true


func get_max_health_bonus() -> int:
	return get_upgrade_level("max_health") * 1


func get_dash_cooldown_multiplier() -> float:
	var lvl := get_upgrade_level("dash_cooldown")
	return maxf(0.4, 1.0 - (lvl * 0.12))


func unlock_floor(floor_num: int) -> void:
	if floor_num > unlocked_floors:
		unlocked_floors = floor_num
		floor_unlocked.emit(unlocked_floors)
		if is_instance_valid(SaveManager):
			SaveManager.save_game()


func reset_state() -> void:
	current_floor = 1
	unlocked_floors = 1
	currency = 0
	upgrade_levels = {
		"max_health": 0,
		"dash_cooldown": 0,
	}
	currency_changed.emit(currency)
	floor_unlocked.emit(unlocked_floors)
	if is_instance_valid(SaveManager):
		SaveManager.save_game()
