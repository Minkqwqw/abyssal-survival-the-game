extends Node2D

@onready var spawn_point: Marker2D = $SpawnPoint
@onready var player: CharacterBody2D = $Player
@onready var checkpoint_label: Label = $HUD/CheckpointLabel


func _ready() -> void:
	if player and spawn_point:
		player.global_position = spawn_point.global_position

	if not StageManager.stage_unlocked.is_connected(_on_stage_unlocked):
		StageManager.stage_unlocked.connect(_on_stage_unlocked)

	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_checkpoint"):
		StageManager.reset_progress()
		_update_hud()


func _on_stage_unlocked(_new_max_stage: int) -> void:
	_update_hud()


func _update_hud() -> void:
	if checkpoint_label:
		checkpoint_label.text = "Checkpoint Progress: Stage %d / %d Unlocked" % [
			StageManager.max_unlocked_stage,
			StageManager.TOTAL_STAGES
		]
