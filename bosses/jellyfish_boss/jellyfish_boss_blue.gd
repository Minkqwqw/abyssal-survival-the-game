
class_name JellyfishBossBlue
extends JellyfishBossBase

# ============================================================
# ELECTRIC TELEGRAPH VISUAL
# ============================================================

class ElectricTelegraph extends Node2D:

	var warning_radius: float = 38.0
	var remaining_time: float = 1.5
	var total_time: float = 1.5

	func _ready() -> void:
		z_index = 100
		set_process(true)
		queue_redraw()

	func _process(delta: float) -> void:
		remaining_time = maxf(remaining_time - delta, 0.0)
		queue_redraw()

	func _draw() -> void:
		var pulse: float = 0.85 + sin(Time.get_ticks_msec() * 0.012) * 0.15
		var progress: float = 0.0

		if total_time > 0.0:
			progress = remaining_time / total_time

		# Lingkaran merah transparan.
		draw_circle(
			Vector2.ZERO,
			warning_radius,
			Color(1.0, 0.05, 0.05, 0.18 * pulse)
		)

		# Lingkaran luar.
		draw_arc(
			Vector2.ZERO,
			warning_radius,
			0.0,
			TAU,
			64,
			Color(1.0, 0.12, 0.12, 0.95),
			3.5,
			true
		)

		# Indikator radial countdown.
		if progress > 0.0:
			draw_arc(
				Vector2.ZERO,
				warning_radius + 6.0,
				-PI / 2.0,
				-PI / 2.0 + (TAU * progress),
				64,
				Color(1.0, 0.35, 0.35, 1.0),
				4.0,
				true
			)

		# Lingkaran bagian dalam.
		draw_arc(
			Vector2.ZERO,
			warning_radius * 0.72,
			0.0,
			TAU,
			48,
			Color(1.0, 0.25, 0.25, 0.65),
			1.5,
			true
		)

		# Tanda silang di tengah.
		draw_line(
			Vector2(-warning_radius * 0.3, 0.0),
			Vector2(warning_radius * 0.3, 0.0),
			Color(1.0, 0.3, 0.3, 0.8),
			2.0
		)

		draw_line(
			Vector2(0.0, -warning_radius * 0.3),
			Vector2(0.0, warning_radius * 0.3),
			Color(1.0, 0.3, 0.3, 0.8),
			2.0
		)


# ============================================================
# BLUE JELLYFISH BOSS - ABYSSAL STORM JELLY
# ============================================================

enum State {
	FLOAT_KITE,
	TRIPLE_SHOT,
	SUMMON_ZONES
}


# ============================================================
# BLUE BOSS SETTINGS
# ============================================================

@export_group("Blue Boss Specifics")
@export var preferred_distance: float = 280.0
@export var max_range: float = 550.0


# ============================================================
# TRIPLE SHOT ATTACK
# ============================================================

@export_group("Triple Shot Attack")
@export var projectile_scene: PackedScene = preload("res://enemies/jellyfish/electric_projectile.tscn")
@export var projectile_damage: int = 1
@export var spread_angle_deg: float = 22.0
@export var shoot_cooldown: float = 2.4


# ============================================================
# RANDOM ELECTRIC ZONES SKILL
# ============================================================

@export_group("Random Electric Zones Skill")
@export var hazard_scene: PackedScene = preload("res://bosses/jellyfish_boss/electric_hazard_area.tscn")

@export var zone_count: int = 6
@export var zone_radius: float = 38.0
@export var zone_duration: float = 3.5

@export var zone_telegraph_time: float = 1.5
@export var skill_cooldown: float = 7.0

@export var zone_color: Color = Color(0.25, 0.85, 1.0, 0.8)


# ============================================================
# NODES
# ============================================================

@onready var muzzle: Marker2D = get_node_or_null("Muzzle")


# ============================================================
# VARIABLES
# ============================================================

var current_state: State = State.FLOAT_KITE

var _shoot_cd_timer: float = 1.0
var _skill_cd_timer: float = 4.0

var _is_casting: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	boss_title = "ABYSSAL STORM JELLYFISH"
	max_health = 65
	speed = 85.0
	contact_damage = 1
	currency_reward = 40

	super._ready()

	if muzzle == null:
		muzzle = Marker2D.new()
		muzzle.name = "Muzzle"
		muzzle.position = Vector2(0, 30)
		add_child(muzzle)


# ============================================================
# BOSS PHYSICS
# ============================================================

func _boss_physics_process(delta: float) -> void:
	_shoot_cd_timer = maxf(_shoot_cd_timer - delta, 0.0)
	_skill_cd_timer = maxf(_skill_cd_timer - delta, 0.0)

	match current_state:

		State.FLOAT_KITE:
			_process_kiting(delta)

		State.TRIPLE_SHOT, State.SUMMON_ZONES:
			velocity = velocity.move_toward(
				Vector2.ZERO,
				400.0 * delta
			)


# ============================================================
# FLOAT & KITE
# ============================================================

func _process_kiting(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		velocity = Vector2.ZERO
		return

	var dist: float = global_position.distance_to(player.global_position)
	var dir: Vector2 = global_position.direction_to(player.global_position)

	# Player terlalu dekat: mundur.
	if dist < preferred_distance:
		velocity = -dir * speed

	# Player terlalu jauh: mendekat.
	elif dist > max_range:
		velocity = dir * speed

	# Jarak ideal: bergerak menyamping.
	else:
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		velocity = perp * (speed * 0.7)

	_play_anim(&"walk")

	# Prioritas skill electric zones.
	if _skill_cd_timer <= 0.0:
		_start_summon_electric_zones()
		return

	# Triple shot.
	if _shoot_cd_timer <= 0.0 and dist <= max_range + 50.0:
		_start_triple_shot()
		return


# ============================================================
# TRIPLE ELECTRIC ORB SHOT
# ============================================================

func _start_triple_shot() -> void:
	if _is_casting:
		return

	_is_casting = true
	current_state = State.TRIPLE_SHOT

	_shoot_cd_timer = shoot_cooldown
	velocity = Vector2.ZERO

	_play_anim(&"attack")

	await get_tree().create_timer(0.25).timeout

	if not is_instance_valid(self) or _is_dying:
		return

	_fire_triple_projectiles()

	# Combo burst ketika HP di bawah 50%.
	if float(health) <= float(max_health) * 0.5:
		await get_tree().create_timer(0.3).timeout

		if not is_instance_valid(self) or _is_dying:
			return

		_fire_triple_projectiles()

	await get_tree().create_timer(0.35).timeout

	if not is_instance_valid(self) or _is_dying:
		return

	_is_casting = false
	current_state = State.FLOAT_KITE

	_play_anim(&"idle")


func _fire_triple_projectiles() -> void:
	if projectile_scene == null:
		return

	if player == null or not is_instance_valid(player):
		return

	var spawn_pos: Vector2 = muzzle.global_position if muzzle else global_position

	var base_dir: Vector2 = spawn_pos.direction_to(
		player.global_position
	)

	var angles: Array[float] = [
		0.0,
		deg_to_rad(-spread_angle_deg),
		deg_to_rad(spread_angle_deg)
	]

	var scaled_dmg: int = projectile_damage

	if is_instance_valid(GameState):
		scaled_dmg = GameState.scale_damage(projectile_damage)

	for angle in angles:
		var shoot_dir: Vector2 = base_dir.rotated(angle)

		var proj: Node = projectile_scene.instantiate()

		if not proj is Node2D:
			proj.free()
			continue

		get_tree().current_scene.add_child(proj)

		proj.global_position = spawn_pos

		if proj.has_method("setup"):
			proj.setup(shoot_dir, scaled_dmg)


# ============================================================
# SUMMON ELECTRIC ZONES
# ============================================================

func _start_summon_electric_zones() -> void:
	if _is_casting:
		return

	_is_casting = true
	current_state = State.SUMMON_ZONES

	_skill_cd_timer = skill_cooldown
	velocity = Vector2.ZERO

	# Efek visual ketika boss merapal skill.
	if anim:
		anim.play(&"attack")
		anim.modulate = Color(0.4, 1.2, 1.5, 1.0)

	await get_tree().create_timer(0.5).timeout

	if not is_instance_valid(self) or _is_dying:
		return

	# Panggil zona listrik dengan telegraph.
	await _spawn_random_electric_zones()

	if not is_instance_valid(self) or _is_dying:
		return

	await get_tree().create_timer(0.6).timeout

	if anim:
		anim.modulate = _base_visual_modulate

	if not is_instance_valid(self) or _is_dying:
		return

	_is_casting = false
	current_state = State.FLOAT_KITE

	_play_anim(&"idle")


# ============================================================
# RANDOM ELECTRIC ZONES + RED WARNING TIMER
# ============================================================

func _spawn_random_electric_zones() -> void:
	if hazard_scene == null:
		return

	var positions: Array[Vector2] = []

	# --------------------------------------------------------
	# 1. TENTUKAN LOKASI ZONA
	# --------------------------------------------------------

	for i in range(zone_count):
		var rand_pos: Vector2 = _get_random_arena_point()

		# Zona pertama: dekat player.
		if i == 0 and player != null and is_instance_valid(player):
			rand_pos = player.global_position + Vector2(
				randf_range(-80.0, 80.0),
				randf_range(-80.0, 80.0)
			)

		# Zona kedua: prediksi arah gerak player.
		elif i == 1 and player != null and is_instance_valid(player):
			if "velocity" in player:
				rand_pos = player.global_position + (
					player.velocity.normalized() * 120.0
				)

		# Pastikan lokasi berada dalam arena.
		rand_pos.x = clampf(
			rand_pos.x,
			ARENA_MIN_X + 60.0,
			ARENA_MAX_X - 60.0
		)

		rand_pos.y = clampf(
			rand_pos.y,
			ARENA_MIN_Y + 60.0,
			ARENA_MAX_Y - 60.0
		)

		positions.append(rand_pos)


	# --------------------------------------------------------
	# 2. TAMPILKAN RED WARNING DI SEMUA LOKASI
	# --------------------------------------------------------

	var telegraphs: Array[ElectricTelegraph] = []

	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		return

	for pos in positions:
		var warning := ElectricTelegraph.new()

		warning.warning_radius = zone_radius + 10.0
		warning.remaining_time = zone_telegraph_time
		warning.total_time = zone_telegraph_time

		scene_root.add_child(warning)
		warning.global_position = pos

		telegraphs.append(warning)


	# --------------------------------------------------------
	# 3. TUNGGU COUNTDOWN SELESAI
	# --------------------------------------------------------

	await get_tree().create_timer(zone_telegraph_time).timeout

	# Boss mati ketika sedang merapal skill.
	if not is_instance_valid(self) or _is_dying:
		for warning in telegraphs:
			if is_instance_valid(warning):
				warning.queue_free()

		return


	# --------------------------------------------------------
	# 4. HILANGKAN SEMUA WARNING
	# --------------------------------------------------------

	for warning in telegraphs:
		if is_instance_valid(warning):
			warning.queue_free()


	# --------------------------------------------------------
	# 5. SPAWN AREA LISTRIK PADA LOKASI YANG SAMA
	# --------------------------------------------------------

	var scaled_dmg: int = contact_damage

	if is_instance_valid(GameState):
		scaled_dmg = GameState.scale_damage(contact_damage)

	for pos in positions:
		var hazard: Node = hazard_scene.instantiate()

		if not hazard is Node2D:
			hazard.free()
			continue

		scene_root.add_child(hazard)
		hazard.global_position = pos

		if hazard.has_method("setup"):
			hazard.setup(
				zone_radius,
				scaled_dmg,
				zone_duration,
				zone_color,
				0.0
			)


# ============================================================
# RANDOM ARENA POSITION
# ============================================================

func _get_random_arena_point() -> Vector2:
	return Vector2(
		randf_range(ARENA_MIN_X + 80.0, ARENA_MAX_X - 80.0),
		randf_range(ARENA_MIN_Y + 80.0, ARENA_MAX_Y - 80.0)
	)
