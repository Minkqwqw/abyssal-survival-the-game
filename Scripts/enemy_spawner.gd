extends Node2D

signal stage_cleared

@export var enemy_scene: PackedScene
@export var enemy_count: int = 10
@export var edge_margin: float = 40.0                 # jarak aman dari tepi area
@export var min_distance_from_player: float = 250.0   # supaya tidak muncul menempel player
@export var min_distance_between_enemies: float = 60.0

@onready var spawn_area: ReferenceRect = $SpawnArea

var alive_enemies: int = 0


func _ready() -> void:
	# Ditunda satu frame supaya Player sudah selesai _ready() dan masuk group "player"
	call_deferred("_spawn_all")


func _spawn_all() -> void:
	if enemy_scene == null:
		push_warning("Enemy Scene di EnemySpawner belum diisi")
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var positions: Array[Vector2] = []
	var attempts := 0

	# Cari posisi acak yang valid sampai jumlahnya cukup
	while positions.size() < enemy_count and attempts < enemy_count * 50:
		attempts += 1
		var pos := _random_point_in_area()

		if _is_valid_position(pos, positions, player):
			positions.append(pos)

	if positions.size() < enemy_count:
		push_warning("Hanya %d dari %d musuh yang muat di area. Perbesar SpawnArea atau kecilkan jarak minimum." % [positions.size(), enemy_count])

	for pos in positions:
		_spawn_enemy(pos)


func _random_point_in_area() -> Vector2:
	var origin := spawn_area.global_position
	var size := spawn_area.size
	return Vector2(
		randf_range(origin.x + edge_margin, origin.x + size.x - edge_margin),
		randf_range(origin.y + edge_margin, origin.y + size.y - edge_margin)
	)


func _is_valid_position(pos: Vector2, taken: Array[Vector2], player: Node2D) -> bool:
	if player and pos.distance_to(player.global_position) < min_distance_from_player:
		return false

	for other in taken:
		if pos.distance_to(other) < min_distance_between_enemies:
			return false

	return true


func _spawn_enemy(pos: Vector2) -> void:
	var enemy := enemy_scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = pos

	alive_enemies += 1
	enemy.tree_exited.connect(_on_enemy_removed)


func _on_enemy_removed() -> void:
	alive_enemies -= 1

	if alive_enemies <= 0:
		stage_cleared.emit()
		print("Stage 1 selesai!")
