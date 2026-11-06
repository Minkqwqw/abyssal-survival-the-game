# Global Game State
extends Node

signal currency_changed(new_currency: int)
signal upgrade_purchased(upgrade_id: String, new_level: int)
signal floor_unlocked(new_max_floor: int)
signal difficulty_changed(new_difficulty: int)

enum Difficulty { NORMAL, HARD, NIGHTMARE }

const DIFFICULTY_META: Dictionary = {
	Difficulty.NORMAL:    {"name": "NORMAL",    "hp": 1.0, "damage": 1.0, "speed": 1.0,  "count": 1.0,  "currency": 1.0},
	Difficulty.HARD:      {"name": "HARD",      "hp": 1.5, "damage": 1.5, "speed": 1.15, "count": 1.25, "currency": 0.5},
	Difficulty.NIGHTMARE: {"name": "NIGHTMARE", "hp": 2.0, "damage": 2.0, "speed": 1.3,  "count": 1.5,  "currency": 0.25},
}

var current_floor: int = 1
var unlocked_floors: int = 1
var currency: int = 0
var difficulty: int = Difficulty.NORMAL
var default_difficulty: int = Difficulty.NORMAL

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


func set_difficulty(diff: int, persist: bool) -> void:
	difficulty = clampi(diff, Difficulty.NORMAL, Difficulty.NIGHTMARE)
	if persist:
		default_difficulty = difficulty
		if is_instance_valid(SaveManager):
			SaveManager.save_game()
	difficulty_changed.emit(difficulty)


func get_difficulty_name() -> String:
	return DIFFICULTY_META[difficulty]["name"]


func _mult(key: String) -> float:
	return float(DIFFICULTY_META[difficulty].get(key, 1.0))


func scale_enemy_hp(base: int) -> int:
	return maxi(1, roundi(base * _mult("hp")))


func scale_damage(base: int) -> int:
	return maxi(1, roundi(base * _mult("damage")))


func scale_enemy_speed(base: float) -> float:
	return base * _mult("speed")


func scale_enemy_count(base: int) -> int:
	return maxi(1, roundi(base * _mult("count")))


func scale_currency(base: int) -> int:
	if base <= 0:
		return 0
	return maxi(1, roundi(base * _mult("currency")))


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
