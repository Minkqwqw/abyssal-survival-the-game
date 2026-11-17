class_name JellyfishBossBlue
extends JellyfishBossBase

# ============================================================
# BLUE JELLYFISH BOSS - "ABYSSAL STORM JELLY"
# ============================================================
# Karakteristik & Mekanisme:
#  1. Pergerakan Lebih Lambat: Melayang anggun dan menjaga jarak
#     taktis dari player (tipe ranged caster).
#  2. Skill Electric Zones Acak: Memanggil beberapa area listrik
#     kecil di seluruh map secara acak dengan telegraph peringatan.
#  3. Serangan Triple Electric Orb: Meniru tembakan keroco biru,
#     tetapi menembakkan 3 bola listrik sekaligus (spread shot).
# ============================================================

enum State { FLOAT_KITE, TRIPLE_SHOT, SUMMON_ZONES }

@export_group("Blue Boss Specifics")
@export var preferred_distance: float = 280.0
@export var max_range: float = 550.0

@export_group("Triple Shot Attack")
@export var projectile_scene: PackedScene = preload("res://enemies/jellyfish/electric_projectile.tscn")
@export var projectile_damage: int = 1
@export var spread_angle_deg: float = 22.0 # Sudut sebaran peluru kiri dan kanan
@export var shoot_cooldown: float = 2.4

@export_group("Random Electric Zones Skill")
@export var hazard_scene: PackedScene = preload("res://bosses/jellyfish_boss/electric_hazard_area.tscn")
@export var zone_count: int = 6 # Jumlah zona listrik kecil yang dipanggil
@export var zone_radius: float = 38.0
@export var zone_duration: float = 3.5
@export var zone_telegraph_time: float = 0.7 # Durasi lingkaran peringatan sebelum aktif
@export var skill_cooldown: float = 7.0
@export var zone_color: Color = Color(0.25, 0.85, 1.0, 0.8) # Biru cyan elektrik

@onready var muzzle: Marker2D = get_node_or_null("Muzzle")

var current_state: State = State.FLOAT_KITE
var _shoot_cd_timer: float = 1.0
var _skill_cd_timer: float = 4.0
var _is_casting: bool = false


func _ready() -> void:
	boss_title = "ABYSSAL STORM JELLYFISH"
	max_health = 65
	speed = 85.0 # Gerak lebih lambat sesuai permintaan
	contact_damage = 1
	currency_reward = 40

	super._ready()

	if muzzle == null:
		muzzle = Marker2D.new()
		muzzle.name = "Muzzle"
		muzzle.position = Vector2(0, 30)
		add_child(muzzle)


func _boss_physics_process(delta: float) -> void:
	_shoot_cd_timer = maxf(_shoot_cd_timer - delta, 0.0)
	_skill_cd_timer = maxf(_skill_cd_timer - delta, 0.0)

	match current_state:
		State.FLOAT_KITE:
			_process_kiting(delta)
		State.TRIPLE_SHOT, State.SUMMON_ZONES:
			velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)


# ============================================================
# STATE: FLOAT & KITE (Melayang Lambat & Menjaga Jarak)
# ============================================================

func _process_kiting(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		velocity = Vector2.ZERO
		return

	var dist := global_position.distance_to(player.global_position)
	var dir := global_position.direction_to(player.global_position)

	# Jika player terlalu dekat -> mundur perlahan
	if dist < preferred_distance:
		velocity = -dir * speed
	# Jika player terlalu jauh -> mendekat perlahan
	elif dist > max_range:
		velocity = dir * speed
	# Jarak ideal -> melayang menyamping (strafing) perlahan
	else:
		var perp := Vector2(-dir.y, dir.x)
		velocity = perp * (speed * 0.7)

	_play_anim(&"walk")

	# Prioritas Skill: Memanggil petir acak di map
	if _skill_cd_timer <= 0.0:
		_start_summon_electric_zones()
		return

	# Attack reguler: Triple Spread Shot
	if _shoot_cd_timer <= 0.0 and dist <= max_range + 50.0:
		_start_triple_shot()
		return


# ============================================================
# ATTACK: TRIPLE ELECTRIC ORB SHOT (3 Bola Listrik Sekaligus)
# ============================================================

func _start_triple_shot() -> void:
	if _is_casting:
		return

	_is_casting = true
	current_state = State.TRIPLE_SHOT
	_shoot_cd_timer = shoot_cooldown
	velocity = Vector2.ZERO

	_play_anim(&"attack")

	# Jeda sejenak menyesuaikan ayunan tentakel / frame animasi tembak
	await get_tree().create_timer(0.25).timeout

	if _is_dying or not is_instance_valid(self):
		return

	_fire_triple_projectiles()

	# Jika darah di bawah 50%, tembakkan gelombang kedua (combo burst)
	if float(health) <= float(max_health) * 0.5:
		await get_tree().create_timer(0.3).timeout
		if not _is_dying and is_instance_valid(self):
			_fire_triple_projectiles()

	await get_tree().create_timer(0.35).timeout

	if _is_dying or not is_instance_valid(self):
		return

	_is_casting = false
	current_state = State.FLOAT_KITE
	_play_anim(&"idle")


func _fire_triple_projectiles() -> void:
	if projectile_scene == null or player == null or not is_instance_valid(player):
		return

	var spawn_pos: Vector2 = muzzle.global_position if muzzle else global_position
	var base_dir: Vector2 = spawn_pos.direction_to(player.global_position)

	# Sudut: Tengah (0°), Kiri (-spread), Kanan (+spread)
	var angles: Array[float] = [
		0.0,
		deg_to_rad(-spread_angle_deg),
		deg_to_rad(spread_angle_deg)
	]

	var scaled_dmg: int = GameState.scale_damage(projectile_damage) if is_instance_valid(GameState) else projectile_damage

	for angle in angles:
		var shoot_dir := base_dir.rotated(angle)
		var proj := projectile_scene.instantiate()
		if not proj is Node2D:
			proj.free()
			continue

		get_tree().current_scene.add_child(proj)
		proj.global_position = spawn_pos

		if proj.has_method("setup"):
			proj.setup(shoot_dir, scaled_dmg)


# ============================================================
# SKILL: RANDOM ELECTRIC ZONES ACROSS MAP
# ============================================================

func _start_summon_electric_zones() -> void:
	if _is_casting:
		return

	_is_casting = true
	current_state = State.SUMMON_ZONES
	_skill_cd_timer = skill_cooldown
	velocity = Vector2.ZERO

	# Efek visual glow saat merapal mantra badai
	if anim:
		anim.play(&"attack")
		anim.modulate = Color(0.4, 1.2, 1.5, 1.0)

	await get_tree().create_timer(0.5).timeout

	if _is_dying or not is_instance_valid(self):
		return

	_spawn_random_electric_zones()

	await get_tree().create_timer(0.6).timeout

	if anim:
		anim.modulate = _base_visual_modulate

	if _is_dying or not is_instance_valid(self):
		return

	_is_casting = false
	current_state = State.FLOAT_KITE
	_play_anim(&"idle")


func _spawn_random_electric_zones() -> void:
	if hazard_scene == null:
		return

	var scaled_dmg: int = GameState.scale_damage(contact_damage) if is_instance_valid(GameState) else contact_damage

	# 1. Spawn beberapa zona acak di seluruh map
	for i in range(zone_count):
		var rand_pos := _get_random_arena_point()

		# Khusus zona pertama & kedua: tempatkan di dekat posisi player untuk memberi tekanan
		if i == 0 and player and is_instance_valid(player):
			rand_pos = player.global_position + Vector2(randf_range(-80.0, 80.0), randf_range(-80.0, 80.0))
		elif i == 1 and player and is_instance_valid(player):
			# Prediksi arah gerak player
			if "velocity" in player:
				rand_pos = player.global_position + (player.velocity.normalized() * 120.0)

		# Clamp agar selalu berada di dalam batas arena
		rand_pos.x = clampf(rand_pos.x, ARENA_MIN_X + 60.0, ARENA_MAX_X - 60.0)
		rand_pos.y = clampf(rand_pos.y, ARENA_MIN_Y + 60.0, ARENA_MAX_Y - 60.0)

		var hazard := hazard_scene.instantiate()
		if not hazard is Node2D:
			hazard.free()
			continue

		get_tree().current_scene.add_child(hazard)
		hazard.global_position = rand_pos

		if hazard.has_method("setup"):
			hazard.setup(
				zone_radius,
				scaled_dmg,
				zone_duration,
				zone_color,
				zone_telegraph_time # Peringatan muncul terlebih dahulu
			)


func _get_random_arena_point() -> Vector2:
	return Vector2(
		randf_range(ARENA_MIN_X + 80.0, ARENA_MAX_X - 80.0),
		randf_range(ARENA_MIN_Y + 80.0, ARENA_MAX_Y - 80.0)
	)
