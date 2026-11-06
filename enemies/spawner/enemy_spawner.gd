extends Node2D

signal stage_cleared

@export var enemy_scene: PackedScene
@export var secondary_enemy_scene: PackedScene
@export_range(0.0, 1.0) var secondary_spawn_chance: float = 0.0
@export var enemy_count: int = 10
@export var max_enemies: int = 0:
	set(value):
		max_enemies = value
		if value > 0:
			enemy_count = value
@export var spawn_interval: float = 1.5
@export var spawn_radius: float = 520.0
@export var edge_margin: float = 40.0
@export var min_distance_from_player: float = 240.0
@export var min_distance_between_enemies: float = 56.0
@export var default_area_rect: Rect2 = Rect2(-520.0, -300.0, 1040.0, 600.0)
@export var use_default_area_rect: bool = true

@onready var spawn_area: ReferenceRect = get_node_or_null("SpawnArea")

var alive_enemies: int = 0


func _ready() -> void:
	call_deferred("_spawn_all")


func _spawn_all() -> void:
	if enemy_scene == null:
		push_warning("Enemy Scene di EnemySpawner belum diisi")
		stage_cleared.emit()
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var positions: Array[Vector2] = []
	var attempts := 0

	while positions.size() < enemy_count and attempts < enemy_count * 60:
		attempts += 1
		var pos := _random_point_in_area()

		if _is_valid_position(pos, positions, player):
			positions.append(pos)

	if positions.size() < enemy_count:
		push_warning("Hanya %d dari %d musuh yang muat di area." % [positions.size(), enemy_count])

	if positions.is_empty():
		stage_cleared.emit()
		return

	for pos in positions:
		_spawn_enemy(pos)


func _random_point_in_area() -> Vector2:
	var origin: Vector2
	var size: Vector2
	if spawn_area and not use_default_area_rect:
		origin = spawn_area.global_position
		size = spawn_area.size
	else:
		origin = global_position + default_area_rect.position
		size = default_area_rect.size

	return Vector2(
		randf_range(origin.x + edge_margin, origin.x + size.x - edge_margin),
		randf_range(origin.y + edge_margin, origin.y + size.y - edge_margin)
	)


func _is_valid_position(pos: Vector2, taken: Array[Vector2], player: Node2D) -> bool:
	if player and is_instance_valid(player) and pos.distance_to(player.global_position) < min_distance_from_player:
		return false

	for other in taken:
		if pos.distance_to(other) < min_distance_between_enemies:
			return false

	return true


func _spawn_enemy(pos: Vector2) -> void:
	var chosen_scene := enemy_scene
	if secondary_enemy_scene != null and randf() < secondary_spawn_chance:
		chosen_scene = secondary_enemy_scene

	var enemy := chosen_scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = pos

	alive_enemies += 1
	enemy.tree_exited.connect(_on_enemy_removed)


func _on_enemy_removed() -> void:
	alive_enemies -= 1

	if alive_enemies <= 0:
		stage_cleared.emit()
