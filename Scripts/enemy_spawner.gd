extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var spawn_radius: float = 600.0
@export var max_enemies: int = 15

var player: Node2D


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

	var timer := Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = true
	timer.timeout.connect(_spawn_enemy)
	add_child(timer)


func _spawn_enemy() -> void:
	if enemy_scene == null or player == null or not is_instance_valid(player):
		return

	if get_tree().get_nodes_in_group("enemy").size() >= max_enemies:
		return

	var angle := randf() * TAU
	var enemy := enemy_scene.instantiate()
	enemy.global_position = player.global_position + Vector2.RIGHT.rotated(angle) * spawn_radius
	get_tree().current_scene.add_child(enemy)
