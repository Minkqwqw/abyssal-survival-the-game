extends Node

signal stage_unlocked(new_max_stage: int)

const TOTAL_STAGES: int = 3
const SAVE_PATH: String = "user://save_data.cfg"
const LOBBY_SCENE_PATH: String = "res://Scenes/Lobby.tscn"

const STAGE_PATHS: Dictionary = {
	1: "res://Scenes/Stage1_Toxic.tscn",
	2: "res://Scenes/Stage2_Reef.tscn",
	3: "res://Scenes/Stage3_Abyss.tscn",
}

const STAGE_NAMES: Dictionary = {
	1: "Stage 1: Toxic Shallows",
	2: "Stage 2: Crimson Reef",
	3: "Stage 3: The Deep Abyss",
}

var max_unlocked_stage: int = 1
var current_stage_id: int = 0


func _ready() -> void:
	load_progress()


func is_stage_unlocked(stage_id: int) -> bool:
	return stage_id >= 1 and stage_id <= max_unlocked_stage and STAGE_PATHS.has(stage_id)


func unlock_stage(stage_id: int) -> void:
	var clamped_id := clampi(stage_id, 1, TOTAL_STAGES)
	if clamped_id > max_unlocked_stage:
		max_unlocked_stage = clamped_id
		save_progress()
		stage_unlocked.emit(max_unlocked_stage)


func complete_stage(stage_id: int) -> void:
	var next_stage := stage_id + 1
	if next_stage <= TOTAL_STAGES:
		unlock_stage(next_stage)
		load_stage(next_stage)
	else:
		# Seluruh 3 stage selesai, kembali ke Lobby
		return_to_lobby()


func load_stage(stage_id: int) -> void:
	if not is_stage_unlocked(stage_id):
		push_warning("Stage %d masih terkunci!" % stage_id)
		return

	current_stage_id = stage_id
	get_tree().call_deferred("change_scene_to_file", STAGE_PATHS[stage_id])


func return_to_lobby() -> void:
	current_stage_id = 0
	get_tree().call_deferred("change_scene_to_file", LOBBY_SCENE_PATH)


func get_stage_title(stage_id: int) -> String:
	return STAGE_NAMES.get(stage_id, "Stage %d" % stage_id)


func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progression", "max_unlocked_stage", max_unlocked_stage)
	config.save(SAVE_PATH)


func load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		max_unlocked_stage = clampi(
			int(config.get_value("progression", "max_unlocked_stage", 1)),
			1,
			TOTAL_STAGES
		)
	else:
		max_unlocked_stage = 1


func reset_progress() -> void:
	max_unlocked_stage = 1
	save_progress()
	stage_unlocked.emit(max_unlocked_stage)
