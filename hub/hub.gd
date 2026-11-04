extends Node2D

@onready var spawn_point: Marker2D = get_node_or_null("SpawnPoint")
@onready var player: CharacterBody2D = get_node_or_null("Player")
@onready var checkpoint_label: Label = get_node_or_null("HUD/CheckpointLabel")


func _ready() -> void:
	if player and spawn_point:
		player.global_position = spawn_point.global_position

	if not StageManager.stage_unlocked.is_connected(_on_stage_unlocked):
		StageManager.stage_unlocked.connect(_on_stage_unlocked)

	if is_instance_valid(GameState) and not GameState.currency_changed.is_connected(_on_currency_changed):
		GameState.currency_changed.connect(_on_currency_changed)

	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_checkpoint"):
		StageManager.reset_progress()
		_update_hud()


func _on_stage_unlocked(_new_max_stage: int) -> void:
	_update_hud()


func _on_currency_changed(_new_currency: int) -> void:
	_update_hud()


func _update_hud() -> void:
	if checkpoint_label:
		var coins := GameState.currency if is_instance_valid(GameState) else 0
		checkpoint_label.text = "Checkpoint: Stage %d / %d Unlocked   |   Pearls: %d" % [
			StageManager.max_unlocked_stage,
			StageManager.TOTAL_STAGES,
			coins
		]
