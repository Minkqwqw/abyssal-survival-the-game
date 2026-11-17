extends Node2D

# ============================================================
# ENEMY SPAWNER  –  2-Wave System
# ============================================================
# Setiap stage memiliki 2 wave:
#   Wave 1  → setengah dari total musuh (ceil)
#   Wave 2  → sisa musuh
#
# Wave 2 dimulai HANYA ketika semua musuh wave 1 sudah mati.
# Stage selesai (signal stage_cleared -> pintu terbuka) HANYA ketika semua
# musuh wave 2 sudah mati. Tidak ada timer yang membuka wave atau pintu.
#
# CARA PAKAI (sistem baru – lantai 2+):
#   Set enemy_scene_list  = [CrabScene, JellyBlueScene, ...]
#   Set enemy_count_list  = [4, 4, ...]
#   (Panjang kedua array harus sama)
#
# CARA PAKAI (sistem lama – kompatibel):
#   Set enemy_scene + secondary_enemy_scene + enemy_count
# ============================================================

signal stage_cleared

# --- Sistem BARU: array paralel scene + jumlah ---
@export var enemy_scene_list: Array[PackedScene] = []
@export var enemy_count_list: Array[int] = []

# --- Sistem LAMA (fallback) ---
@export var enemy_scene: PackedScene
@export var secondary_enemy_scene: PackedScene
@export_range(0.0, 1.0) var secondary_spawn_chance: float = 0.0
@export var enemy_count: int = 0
@export var max_enemies: int = 0:
	set(value):
		max_enemies = value
		if value > 0:
			enemy_count = value

# --- Spawn area ---
@export var edge_margin: float = 40.0
@export var min_distance_from_player: float = 240.0
@export var min_distance_between_enemies: float = 56.0
@export var default_area_rect: Rect2 = Rect2(-520.0, -300.0, 1040.0, 600.0)
@export var use_default_area_rect: bool = true

# --- Wave settings ---
## Jeda (detik) sebelum musuh wave 2 bisa menyerang setelah spawn
@export var wave2_grace_period: float = 1.5

@onready var spawn_area: ReferenceRect = get_node_or_null("SpawnArea")

# Internal state
var _wave_1_plan: Array = []   # [{scene, count}]
var _wave_2_plan: Array = []

var _current_wave: int = 0
var _alive_wave: int = 0
var _stage_done: bool = false
var _combat_started: bool = false
var _shutting_down: bool = false   # true saat stage dibongkar (pindah scene / player mati)


# ============================================================
# READY / EXIT
# ============================================================

func _ready() -> void:
	_build_wave_plans()

	# Hubungkan ke sinyal arena_entered dari stage induk
	var stage := get_tree().current_scene
	if stage and stage.has_signal("arena_entered"):
		if not stage.arena_entered.is_connected(_on_arena_entered):
			stage.arena_entered.connect(_on_arena_entered)
	else:
		# Fallback: jika tidak ada trigger line, langsung mulai
		call_deferred("_start_wave_1")


func _exit_tree() -> void:
	# Dari titik ini jangan mulai wave baru atau memancarkan stage_cleared
	_shutting_down = true


func _on_arena_entered() -> void:
	if _combat_started:
		return
	_combat_started = true
	_start_wave_1()


# ============================================================
# BUILD PLANS
# ============================================================


func _build_wave_plans() -> void:
	_wave_1_plan.clear()
	_wave_2_plan.clear()

	var entries: Array[Dictionary] = []

	# Prioritas: enemy_scene_list (sistem baru)
	if not enemy_scene_list.is_empty():
		for i: int in range(enemy_scene_list.size()):
			var sc: PackedScene = enemy_scene_list[i]
			var cnt: int = 0

			if i < enemy_count_list.size():
				cnt = enemy_count_list[i]

			if sc != null and cnt > 0:
				entries.append({
					"scene": sc,
					"count": cnt
				})

	else:
		# Fallback sistem lama
		var total: int = maxi(enemy_count, max_enemies)

		if total > 0 and enemy_scene != null:
			if secondary_enemy_scene != null and secondary_spawn_chance > 0.0:

				var sec: int = roundi(
					float(total) * secondary_spawn_chance
				)

				var pri: int = total - sec

				if pri > 0:
					entries.append({
						"scene": enemy_scene,
						"count": pri
					})

				if sec > 0:
					entries.append({
						"scene": secondary_enemy_scene,
						"count": sec
					})

			else:
				entries.append({
					"scene": enemy_scene,
					"count": total
				})

	# Split tiap tipe musuh ke wave 1 dan wave 2
	for entry: Dictionary in entries:
		var sc: PackedScene = entry["scene"] as PackedScene
		var cnt: int = int(entry["count"])

		var w1: int = ceili(float(cnt) / 2.0)
		var w2: int = cnt - w1

		if w1 > 0:
			_wave_1_plan.append({
				"scene": sc,
				"count": w1
			})

		if w2 > 0:
			_wave_2_plan.append({
				"scene": sc,
				"count": w2
			})




# ============================================================
# WAVE 1
# ============================================================

func _start_wave_1() -> void:
	if _stage_done or _shutting_down or not is_inside_tree():
		return

	var total := _plan_total(_wave_1_plan)
	if total == 0:
		if _plan_total(_wave_2_plan) == 0:
			_finish_stage()
			return
		_start_wave_2()
		return

	_current_wave = 1
	_alive_wave = 0

	var spawned := _spawn_plan(_wave_1_plan)
	if spawned == 0:
		_start_wave_2()
		return


# ============================================================
# WAVE 2
# ============================================================

func _start_wave_2() -> void:
	if _stage_done or _shutting_down or not is_inside_tree() or _current_wave >= 2:
		return

	_current_wave = 2
	_alive_wave = 0

	var total := _plan_total(_wave_2_plan)
	if total == 0:
		_finish_stage()
		return

	var spawned := _spawn_plan(_wave_2_plan, wave2_grace_period)

	if spawned == 0:
		_finish_stage()


# ============================================================
# SPAWN HELPERS
# ============================================================

func _spawn_plan(plan: Array, grace: float = 0.0) -> int:
	if not is_inside_tree():
		return 0

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var taken: Array[Vector2] = []
	var spawned_total := 0

	for entry in plan:
		var sc: PackedScene = entry["scene"]
		var cnt: int = entry["count"]
		if sc == null or cnt <= 0:
			continue

		var positions := _find_positions(cnt, taken, player)
		for pos in positions:
			taken.append(pos)
			_spawn_one(sc, pos, grace)
			spawned_total += 1

	return spawned_total


func _find_positions(count: int, taken: Array[Vector2], player: Node2D) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var max_attempts := count * 60
	var attempts := 0

	while result.size() < count and attempts < max_attempts:
		attempts += 1
		var pos := _random_point_in_area()
		var combined: Array[Vector2] = []
		combined.append_array(taken)
		combined.append_array(result)
		if _is_valid_position(pos, combined, player):
			result.append(pos)

	if result.size() < count:
		push_warning("[EnemySpawner] Hanya %d dari %d posisi valid." % [result.size(), count])

	return result


func _spawn_one(sc: PackedScene, pos: Vector2, grace: float = 0.0) -> void:
	var enemy := sc.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = pos

	# Terapkan grace period: enemy tidak bisa menyerang selama grace detik
	if grace > 0.0 and enemy.has_method("apply_grace_period"):
		enemy.apply_grace_period(grace)

	_alive_wave += 1
	# enemy ikut dikirim supaya bisa dibedakan: mati (dihitung) vs ikut terhapus saat stage dibongkar (diabaikan)
	enemy.tree_exited.connect(_on_enemy_removed.bind(enemy))


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


func _plan_total(plan: Array) -> int:
	var total := 0
	for e in plan:
		total += int(e.get("count", 0))
	return total


# ============================================================
# ENEMY REMOVED
# ============================================================

func _on_enemy_removed(enemy: Node) -> void:
	# Stage sedang dibongkar (pindah scene, player mati, dll.): semua musuh ikut keluar
	# dari tree. Itu BUKAN musuh yang dikalahkan, jadi jangan mulai wave / selesai stage.
	if _shutting_down or _stage_done or not is_inside_tree():
		return

	# Musuh yang benar-benar mati dihapus lewat queue_free(). Kalau tidak, dia hanya terlepas.
	if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
		return

	_alive_wave -= 1

	if _alive_wave <= 0:
		match _current_wave:
			1:
				_start_wave_2()
			2:
				_finish_stage()


# ============================================================
# FINISH
# ============================================================

func _finish_stage() -> void:
	if _stage_done or _shutting_down:
		return
	_stage_done = true
	stage_cleared.emit()
