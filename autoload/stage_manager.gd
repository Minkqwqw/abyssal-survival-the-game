
extends Node

signal stage_unlocked(new_max_stage: int)
signal level_unlocked(new_max_level: int)

const TOTAL_LEVELS: int = 5
const TOTAL_STAGES: int = 3

const SAVE_PATH: String = "user://save_data.cfg"

const MAIN_MENU_SCENE_PATH: String = "res://ui/main_menu/main_menu.tscn"
const LOBBY_SCENE_PATH: String = "res://hub/hub.tscn"
const ELEVATOR_SCENE_PATH: String = "res://ui/elevator_loading/elevator_loading.tscn"
const STAGE_SELECTOR_SCENE_PATH: String = "res://ui/stage_selector/stage_selector.tscn"


# ============================================================
# DEDICATED STAGE SCENES (5 LEVEL x 3 STAGE)
# ============================================================

const LEVEL_STAGE_PATHS: Dictionary = {
	1: {
		1: "res://stages/floors/floor_1/level_1_stage_1.tscn",
		2: "res://stages/floors/floor_1/level_1_stage_2.tscn",
		3: "res://stages/floors/floor_1/level_1_stage_3.tscn",
	},
	2: {
		1: "res://stages/floors/floor_2/level_2_stage_1.tscn",
		2: "res://stages/floors/floor_2/level_2_stage_2.tscn",
		3: "res://stages/floors/floor_2/level_2_stage_3.tscn",
	},
	3: {
		1: "res://stages/floors/floor_3/level_3_stage_1.tscn",
		2: "res://stages/floors/floor_3/level_3_stage_2.tscn",
		3: "res://stages/floors/floor_3/level_3_stage_3.tscn",
	},
	4: {
		1: "res://stages/floors/floor_4/level_4_stage_1.tscn",
		2: "res://stages/floors/floor_4/level_4_stage_2.tscn",
		3: "res://stages/floors/floor_4/level_4_stage_3.tscn",
	},
	5: {
		1: "res://stages/floors/floor_5/level_5_stage_1.tscn",
		2: "res://stages/floors/floor_5/level_5_stage_2.tscn",
		3: "res://stages/floors/floor_5/level_5_stage_3.tscn",
	},
}


# ============================================================
# STAGE & LEVEL INFORMATION
# ============================================================

const STAGE_NAMES: Dictionary = {
	1: "Stage 1: Sector Entry",
	2: "Stage 2: Inner Conduit",
	3: "Stage 3: Core Sanctum (Boss)",
}

const LEVEL_DATA_PATHS: Dictionary = {
	1: "res://data/floors/floor_1.tres",
	2: "res://data/floors/floor_2.tres",
	3: "res://data/floors/floor_3.tres",
	4: "res://data/floors/floor_4.tres",
	5: "res://data/floors/floor_5.tres",
}

const LEVEL_NAMES: Dictionary = {
	1: "Level 1: Toxic Shallows",
	2: "Level 2: Crimson Reef",
	3: "Level 3: The Deep Abyss",
	4: "Level 4: Hydrothermal Vents",
	5: "Level 5: Hadal Trench",
}


# ============================================================
# PROGRESSION VARIABLES
# ============================================================

var max_unlocked_level: int = 1
var current_level_id: int = 1

var max_unlocked_stage: int = 1
var current_stage_id: int = 0


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	load_progress()


# ============================================================
# UNLOCK CHECKS
# ============================================================

func is_level_unlocked(level_id: int) -> bool:
	return (
		level_id >= 1
		and level_id <= max_unlocked_level
		and level_id <= TOTAL_LEVELS
	)


func is_stage_unlocked(stage_id: int) -> bool:
	return (
		stage_id >= 1
		and stage_id <= TOTAL_STAGES
		and stage_id <= max_unlocked_stage
	)


# ============================================================
# GET STAGE SCENE PATH
# ============================================================

func get_stage_scene_path(level_id: int, stage_id: int) -> String:
	if level_id < 1 or level_id > TOTAL_LEVELS:
		push_error("Level %d tidak valid!" % level_id)
		return ""

	if stage_id < 1 or stage_id > TOTAL_STAGES:
		push_error("Stage %d tidak valid!" % stage_id)
		return ""

	var level_stages: Dictionary = LEVEL_STAGE_PATHS.get(level_id, {})
	var scene_path: String = level_stages.get(stage_id, "")

	if scene_path.is_empty():
		push_error(
			"Path Level %d Stage %d belum terdaftar!"
			% [level_id, stage_id]
		)
		return ""

	if not ResourceLoader.exists(scene_path):
		push_error("Scene tidak ditemukan: %s" % scene_path)
		return ""

	return scene_path


# ============================================================
# UNLOCK LEVEL
# ============================================================

func unlock_level(level_id: int) -> void:
	var clamped_lvl := clampi(level_id, 1, TOTAL_LEVELS)

	if clamped_lvl <= max_unlocked_level:
		return

	max_unlocked_level = clamped_lvl

	if is_instance_valid(GameState):
		GameState.unlock_floor(max_unlocked_level)

	save_progress()

	level_unlocked.emit(max_unlocked_level)


# ============================================================
# UNLOCK STAGE
# ============================================================

func unlock_stage(stage_id: int) -> void:
	var clamped_id := clampi(stage_id, 1, TOTAL_STAGES)

	if clamped_id <= max_unlocked_stage:
		return

	max_unlocked_stage = clamped_id

	save_progress()

	stage_unlocked.emit(max_unlocked_stage)


# ============================================================
# GAMEPLAY CHECK
# ============================================================

func is_in_gameplay() -> bool:
	if current_stage_id > 0:
		return true

	var scene := get_tree().current_scene if get_tree() else null

	return scene != null and scene is BaseStage


# ============================================================
# SCENE TRANSITIONS
# ============================================================

func open_main_menu() -> void:
	current_stage_id = 0

	if is_instance_valid(GameState):
		GameState.player_current_health = -1

	get_tree().paused = false
	get_tree().call_deferred(
		"change_scene_to_file",
		MAIN_MENU_SCENE_PATH
	)


func open_elevator_loading() -> void:
	current_stage_id = 0

	get_tree().paused = false
	get_tree().call_deferred(
		"change_scene_to_file",
		ELEVATOR_SCENE_PATH
	)


func open_stage_selector() -> void:
	current_stage_id = 0

	get_tree().paused = false
	get_tree().call_deferred(
		"change_scene_to_file",
		STAGE_SELECTOR_SCENE_PATH
	)


# ============================================================
# START LEVEL
# ============================================================

func start_level(level_id: int) -> void:
	if not is_level_unlocked(level_id):
		push_warning("Level %d masih terkunci!" % level_id)
		return

	var clamped_lvl := clampi(level_id, 1, TOTAL_LEVELS)
	var target_scene := get_stage_scene_path(clamped_lvl, 1)

	if target_scene.is_empty():
		return

	current_level_id = clamped_lvl
	current_stage_id = 1

	# Stage pertama menjadi titik awal level baru.
	max_unlocked_stage = 1

	if is_instance_valid(GameState):
		GameState.current_floor = current_level_id

	save_progress()

	get_tree().call_deferred(
		"change_scene_to_file",
		target_scene
	)


# ============================================================
# COMPLETE STAGE
# ============================================================

func complete_stage(stage_id: int) -> void:
	if stage_id < 1 or stage_id > TOTAL_STAGES:
		push_warning("Stage %d tidak valid!" % stage_id)
		return

	var next_stage := stage_id + 1

	if next_stage <= TOTAL_STAGES:
		unlock_stage(next_stage)
		load_stage(next_stage)
	else:
		# Seluruh 3 stage dalam level telah selesai.
		if current_level_id < TOTAL_LEVELS:
			unlock_level(current_level_id + 1)

		return_to_lobby()


# ============================================================
# LOAD STAGE
# ============================================================

func load_stage(stage_id: int) -> void:
	if stage_id < 1 or stage_id > TOTAL_STAGES:
		push_warning("Stage %d tidak valid!" % stage_id)
		return

	if stage_id > max_unlocked_stage:
		unlock_stage(stage_id)

	var target_scene := get_stage_scene_path(
		current_level_id,
		stage_id
	)

	if target_scene.is_empty():
		return

	current_stage_id = stage_id

	get_tree().call_deferred(
		"change_scene_to_file",
		target_scene
	)


# ============================================================
# CHANGE STAGE DIRECTLY
# ============================================================

func change_stage(stage_path: String) -> void:
	if stage_path.is_empty():
		push_warning("Stage path kosong!")
		return

	if not ResourceLoader.exists(stage_path):
		push_error("Scene tidak ditemukan: %s" % stage_path)
		return

	get_tree().call_deferred(
		"change_scene_to_file",
		stage_path
	)


# ============================================================
# RETURN TO LOBBY
# ============================================================

func return_to_lobby() -> void:
	current_stage_id = 0

	if is_instance_valid(GameState):
		GameState.player_current_health = -1

	get_tree().paused = false

	get_tree().call_deferred(
		"change_scene_to_file",
		LOBBY_SCENE_PATH
	)


# ============================================================
# GET TITLES
# ============================================================

func get_stage_title(stage_id: int) -> String:
	return STAGE_NAMES.get(
		stage_id,
		"Stage %d" % stage_id
	)


func get_level_title(level_id: int) -> String:
	return LEVEL_NAMES.get(
		level_id,
		"Level %d" % level_id
	)


# ============================================================
# GET FLOOR DATA
# ============================================================

func get_floor_data(level_id: int) -> Resource:
	var path: String = LEVEL_DATA_PATHS.get(level_id, "")

	if path != "" and ResourceLoader.exists(path):
		return load(path)

	return null


# ============================================================
# SAVE PROGRESS
# ============================================================

func save_progress() -> void:
	if is_instance_valid(SaveManager):
		SaveManager.save_game()
		return

	var config := ConfigFile.new()

	config.set_value(
		"progression",
		"max_unlocked_stage",
		max_unlocked_stage
	)

	config.set_value(
		"progression",
		"max_unlocked_level",
		max_unlocked_level
	)

	config.set_value(
		"progression",
		"current_level_id",
		current_level_id
	)

	var error := config.save(SAVE_PATH)

	if error != OK:
		push_error("Gagal menyimpan progress! Error: %s" % error_string(error))


# ============================================================
# LOAD PROGRESS
# ============================================================

func load_progress() -> void:
	var config := ConfigFile.new()

	if config.load(SAVE_PATH) == OK:
		max_unlocked_stage = clampi(
			int(
				config.get_value(
					"progression",
					"max_unlocked_stage",
					1
				)
			),
			1,
			TOTAL_STAGES
		)

		# Kompatibilitas dengan data save versi sebelumnya.
		var saved_floors := int(
			config.get_value(
				"progression",
				"unlocked_floors",
				1
			)
		)

		var saved_levels := int(
			config.get_value(
				"progression",
				"max_unlocked_level",
				saved_floors
			)
		)

		max_unlocked_level = clampi(
			maxi(saved_floors, saved_levels),
			1,
			TOTAL_LEVELS
		)

		current_level_id = clampi(
			int(
				config.get_value(
					"progression",
					"current_level_id",
					config.get_value(
						"progression",
						"current_floor",
						1
					)
				)
			),
			1,
			TOTAL_LEVELS
		)

	else:
		max_unlocked_stage = 1
		max_unlocked_level = 1
		current_level_id = 1

	if is_instance_valid(GameState):
		GameState.unlocked_floors = max_unlocked_level
		GameState.current_floor = current_level_id


# ============================================================
# RESET PROGRESS
# ============================================================

func reset_progress() -> void:
	max_unlocked_stage = 1
	max_unlocked_level = 1
	current_level_id = 1
	current_stage_id = 0

	if is_instance_valid(GameState):
		GameState.reset_state()

	save_progress()

	level_unlocked.emit(max_unlocked_level)
	stage_unlocked.emit(max_unlocked_stage)
