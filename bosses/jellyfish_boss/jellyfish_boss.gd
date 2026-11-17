class_name JellyfishBossDuo
extends Node2D

# ============================================================
# JELLYFISH BOSS (DUO / ENCOUNTER MANAGER)
# ============================================================
# Mengelola pertemuan bos ubur-ubur di Level 2 Stage 3.
# Mendukung mode:
#   1. DUO (Default): Bos Merah (Crimson Volt) & Bos Biru (Abyssal Storm)
#      muncul bersamaan sebagai Twin Boss.
#   2. RED_ONLY: Hanya Bos Merah yang bertarung.
#   3. BLUE_ONLY: Hanya Bos Biru yang bertarung.
# ============================================================

signal boss_died

enum BossMode { DUO, RED_ONLY, BLUE_ONLY }

@export var boss_mode: BossMode = BossMode.DUO
@export var red_boss_scene: PackedScene = preload("res://bosses/jellyfish_boss/jellyfish_boss_red.tscn")
@export var blue_boss_scene: PackedScene = preload("res://bosses/jellyfish_boss/jellyfish_boss_blue.tscn")

@export_group("Duo Balancing")
@export var duo_health_scale: float = 0.85 # Pengurangan HP saat berdua agar pertempuran seimbang

var _active_bosses: Array[Node2D] = []
var _total_bosses: int = 0
var _defeated_bosses: int = 0


func _ready() -> void:
	# Panggil di frame berikutnya agar posisi boss_spawn_point sudah ditetapkan oleh BaseStage
	call_deferred("_spawn_encounter")


func _spawn_encounter() -> void:
	match boss_mode:
		BossMode.DUO:
			_spawn_duo()
		BossMode.RED_ONLY:
			_spawn_single(red_boss_scene, Vector2.ZERO, false)
		BossMode.BLUE_ONLY:
			_spawn_single(blue_boss_scene, Vector2.ZERO, false)


func _spawn_duo() -> void:
	_total_bosses = 2
	_defeated_bosses = 0

	# Bos Merah di sisi kiri
	var red_boss := red_boss_scene.instantiate() as JellyfishBossBase
	# Bos Biru di sisi kanan
	var blue_boss := blue_boss_scene.instantiate() as JellyfishBossBase

	if red_boss == null or blue_boss == null:
		push_error("Gagal instantiate Jellyfish Boss scenes!")
		return

	# Terapkan balancing HP untuk Duo
	red_boss.max_health = roundi(red_boss.max_health * duo_health_scale)
	red_boss.health = red_boss.max_health
	blue_boss.max_health = roundi(blue_boss.max_health * duo_health_scale)
	blue_boss.health = blue_boss.max_health

	# Sesuaikan posisi bar darah agar bertingkat rapi dan tidak tumpang tindih
	_adjust_duo_hud(red_boss, blue_boss)

	# Tambahkan ke scene
	add_child(red_boss)
	add_child(blue_boss)

	# Beri offset posisi relatif dari spawn point
	red_boss.position = Vector2(-160.0, 0.0)
	blue_boss.position = Vector2(160.0, 0.0)

	_active_bosses.append(red_boss)
	_active_bosses.append(blue_boss)

	red_boss.boss_died.connect(_on_boss_child_died)
	blue_boss.boss_died.connect(_on_boss_child_died)


func _spawn_single(scene: PackedScene, offset: Vector2, _is_secondary: bool) -> void:
	_total_bosses = 1
	_defeated_bosses = 0

	var boss := scene.instantiate() as JellyfishBossBase
	if boss == null:
		return

	add_child(boss)
	boss.position = offset
	_active_bosses.append(boss)

	boss.boss_died.connect(_on_boss_child_died)


func _adjust_duo_hud(red: JellyfishBossBase, blue: JellyfishBossBase) -> void:
	# Atur bar Bos Merah di bagian atas (Y: 16 - 60)
	var red_title := red.get_node_or_null("CanvasLayer/BossTitleLabel") as Label
	var red_bar := red.get_node_or_null("CanvasLayer/HealthBar") as ProgressBar

	if red_title:
		red_title.offset_top = 16.0
		red_title.offset_bottom = 38.0
	if red_bar:
		red_bar.offset_top = 40.0
		red_bar.offset_bottom = 60.0

	# Atur bar Bos Biru di bawah bar Merah (Y: 66 - 110)
	var blue_title := blue.get_node_or_null("CanvasLayer/BossTitleLabel") as Label
	var blue_bar := blue.get_node_or_null("CanvasLayer/HealthBar") as ProgressBar

	if blue_title:
		blue_title.offset_top = 66.0
		blue_title.offset_bottom = 88.0
	if blue_bar:
		blue_bar.offset_top = 90.0
		blue_bar.offset_bottom = 110.0


func _on_boss_child_died() -> void:
	_defeated_bosses += 1

	# Cari apakah masih ada bos yang hidup di encounter
	for boss in _active_bosses:
		if is_instance_valid(boss) and not boss._is_dying:
			# Mode Enraged untuk bos yang masih bertahan hidup
			boss.speed *= 1.2
			if boss.anim:
				boss.anim.modulate = Color(1.3, 0.8, 0.8, 1.0)

	# Jika semua bos sudah dikalahkan -> selesaikan encounter
	if _defeated_bosses >= _total_bosses:
		boss_died.emit()
		queue_free()
