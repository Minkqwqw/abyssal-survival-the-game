# Stage Manager
extends Node

func change_stage(stage_path: String) -> void:
	get_tree().change_scene_to_file(stage_path)
