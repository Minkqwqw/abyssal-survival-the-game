class_name JellyfishBossRed
extends JellyfishBossBase

# ============================================================
# RED JELLYFISH BOSS - "CRIMSON VOLT JELLY"
# ============================================================
# Karakteristik & Mekanisme:
#  1. Pergerakan Cepat: Lincah dan agresif mengejar player.
#  2. Skill Electric Trail: Meninggalkan jejak area listrik di lantai
#     saat bergerak, terutama saat fase Overcharge Rush.
#  3. Serangan Area Luas (Mega Electric Burst): Meniru serangan
#     melee keroco merah, tetapi melepaskan ledakan listrik radial
#     dengan jangkauan area yang jauh lebih besar.
# ============================================================

enum State { CHASE, RUSH_SKILL, BURST_ATTACK, STUNNED }

@export_group("Red Boss Specifics")
@export var rush_speed: float = 380.0
@export var rush_duration: float = 1.3
@export var rush_cooldown: float = 6.0
@export var trail_spawn_interval: float = 0.16 # Detik antar pembuatan jejak listrik
@export var trail_hazard_duration: float = 4.0
@export var trail_hazard_radius: float = 40.0
@export var trail_color: Color = Color(1.0, 0.28, 0.18, 0.85) # Merah neon membara

@export_group("Mega Burst Attack")
@export var burst_damage: int = 2
@export var burst_radius: float = 240.0 # Area sangat luas dibanding keroco (58px)
@export var burst_trigger_range: float = 170.0
@export var burst_cooldown: float = 3.5
@export var burst_windup_time: float = 0.55

@export_group("Hazard Prefab")
@export var hazard_scene: PackedScene = preload("res://bosses/jellyfish_boss/electric_hazard_area.tscn")

@onready var burst_area: Area2D = get_node_or_null("BurstArea")
@onready var burst_shape: CollisionShape2D = get_node_or_null("BurstArea/CollisionShape2D")

var current_state: State = State.CHASE
var _state_timer: float = 0.0
var _trail_timer: float = 0.0
var _rush_cd_timer: float = 3.0
var _burst_cd_timer: float = 1.5

var _rush_target_dir: Vector2 = Vector2.ZERO
var _is_performing_burst: bool = false
var _burst_telegraph_active: bool = false
var _burst_telegraph_timer: float = 0.0


func _ready() -> void:
	boss_title = "CRIMSON VOLT JELLYFISH"
	max_health = 75
	speed = 195.0 # Gerak dasar cepat
	contact_damage = 1
	currency_reward = 40

	super._ready()

	_init_burst_area()


func _init_burst_area() -> void:
	if burst_area == null:
		burst_area = Area2D.new()
		burst_area.name = "BurstArea"
		burst_area.collision_layer = 0
		burst_area.collision_mask = 1
		burst_area.monitoring = false
		add_child(burst_area)

	if burst_shape == null:
		burst_shape = CollisionShape2D.new()
		burst_shape.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = burst_radius
		burst_shape.shape = circle
		burst_area.add_child(burst_shape)
	elif burst_shape.shape is CircleShape2D:
		(burst_shape.shape as CircleShape2D).radius = burst_radius


func _boss_physics_process(delta: float) -> void:
	_trail_timer += delta
	_rush_cd_timer = maxf(_rush_cd_timer - delta, 0.0)
	_burst_cd_timer = maxf(_burst_cd_timer - delta, 0.0)

	match current_state:
		State.CHASE:
			_process_chase(delta)
		State.RUSH_SKILL:
			_process_rush(delta)
		State.BURST_ATTACK:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		State.STUNNED:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)


# ============================================================
# STATE: CHASE (Pengejaran Cepat & Peletakan Jejak Listrik)
# ============================================================

func _process_chase(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		velocity = Vector2.ZERO
		return

	var distance := global_position.distance_to(player.global_position)
	var dir := global_position.direction_to(player.global_position)

	# Bergerak cepat mengejar player
	velocity = dir * speed

	_play_anim(&"walk")

	# Tinggalkan jejak listrik saat bergerak di fase chase
	if _trail_timer >= trail_spawn_interval * 1.8:
		_trail_timer = 0.0
		_spawn_electric_trail()

	# Cek apakah dapat melancarkan Mega Burst Attack (Jarak dekat)
	if distance <= burst_trigger_range and _burst_cd_timer <= 0.0:
		_start_burst_attack()
		return

	# Cek apakah dapat melancarkan Rush Skill (Serbuan cepat berlistrik)
	if distance > 260.0 and _rush_cd_timer <= 0.0:
		_start_rush_skill()
		return


# ============================================================
# STATE: RUSH SKILL (Serbuan Cepat Meninggalkan Jejak Listrik Padat)
# ============================================================

func _start_rush_skill() -> void:
	current_state = State.RUSH_SKILL
	_rush_cd_timer = rush_cooldown
	_state_timer = rush_duration

	if player and is_instance_valid(player):
		_rush_target_dir = global_position.direction_to(player.global_position)
	else:
		_rush_target_dir = Vector2.RIGHT.rotated(randf() * TAU)

	# Efek kilatan saat mulai menerjang
	if anim:
		anim.modulate = Color(1.3, 0.5, 0.3, 1.0)

	_play_anim(&"walk")


func _process_rush(delta: float) -> void:
	_state_timer -= delta
	velocity = _rush_target_dir * rush_speed

	# Spawn jejak listrik secara rapat saat melesat cepat
	if _trail_timer >= trail_spawn_interval:
		_trail_timer = 0.0
		_spawn_electric_trail()

	if _state_timer <= 0.0:
		_end_rush_skill()


func _end_rush_skill() -> void:
	if anim:
		anim.modulate = _base_visual_modulate
	current_state = State.CHASE


# ============================================================
# SKILL: SPAWN ELECTRIC TRAIL
# ============================================================

func _spawn_electric_trail() -> void:
	if hazard_scene == null:
		return

	var hazard := hazard_scene.instantiate()
	if not hazard is Node2D:
		hazard.free()
		return

	get_tree().current_scene.add_child(hazard)
	hazard.global_position = global_position

	if hazard.has_method("setup"):
		hazard.setup(
			trail_hazard_radius,
			GameState.scale_damage(contact_damage) if is_instance_valid(GameState) else contact_damage,
			trail_hazard_duration,
			trail_color,
			0.0
		)


# ============================================================
# ATTACK: MEGA ELECTRIC BURST (Serangan Area Luas)
# ============================================================

func _start_burst_attack() -> void:
	if _is_performing_burst:
		return

	current_state = State.BURST_ATTACK
	_is_performing_burst = true
	_burst_cd_timer = burst_cooldown
	velocity = Vector2.ZERO

	# Animasi & Telegraph peringatan ledakan area
	_burst_telegraph_active = true
	_burst_telegraph_timer = burst_windup_time

	if anim:
		anim.play(&"attack")

	# Tunggu jeda windup telegraph
	await get_tree().create_timer(burst_windup_time).timeout

	if _is_dying or not is_instance_valid(self):
		return

	# Ledakkan area burst
	_burst_telegraph_active = false
	_execute_burst_explosion()

	# Tinggalkan medan listrik besar di pusat ledakan
	_spawn_large_burst_hazard()

	# Jeda pemulihan setelah ledakan
	await get_tree().create_timer(0.4).timeout

	if _is_dying or not is_instance_valid(self):
		return

	_is_performing_burst = false
	current_state = State.CHASE
	_play_anim(&"idle")


func _execute_burst_explosion() -> void:
	if burst_area == null:
		return

	burst_area.monitoring = true
	# Berikan damage ke semua player di dalam area jangkauan luas
	for body in burst_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			var dmg := GameState.scale_damage(burst_damage) if is_instance_valid(GameState) else burst_damage
			body.take_damage(dmg)

	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(burst_area):
		burst_area.monitoring = false


func _spawn_large_burst_hazard() -> void:
	if hazard_scene == null:
		return

	var hazard := hazard_scene.instantiate()
	if hazard is Node2D:
		get_tree().current_scene.add_child(hazard)
		hazard.global_position = global_position
		if hazard.has_method("setup"):
			hazard.setup(
				burst_radius * 0.75,
				GameState.scale_damage(contact_damage) if is_instance_valid(GameState) else contact_damage,
				trail_hazard_duration * 0.8,
				Color(1.0, 0.2, 0.1, 0.9),
				0.0
			)


# ============================================================
# VISUAL DRAW (Warning Indicator untuk Serangan Area Luas)
# ============================================================

func _process(delta: float) -> void:
	if _burst_telegraph_active:
		_burst_telegraph_timer = maxf(_burst_telegraph_timer - delta, 0.0)
		queue_redraw()
	else:
		queue_redraw()


func _draw() -> void:
	if _burst_telegraph_active:
		var progress: float = 1.0 - (_burst_telegraph_timer / burst_windup_time)
		var curr_rad: float = lerpf(30.0, burst_radius, progress)
		# Lingkaran peringatan bahaya mengembang
		draw_circle(Vector2.ZERO, curr_rad, Color(1.0, 0.25, 0.15, 0.22))
		draw_arc(Vector2.ZERO, burst_radius, 0.0, TAU, 36, Color(1.0, 0.4, 0.2, 0.85), 3.0)
