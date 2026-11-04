extends CharacterBody2D

signal health_changed(new_health: int)
signal died

@export var speed: float = 250.0
@export var acceleration: float = 1800.0
@export var friction: float = 1400.0
@export var max_health: int = 5

@export_group("Dash")
@export var dash_speed: float = 700.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.6

@export_group("Weapon")
@export var weapon_scene: PackedScene
@export var weapon_offset: Vector2 = Vector2(24, 0)

@export_group("Aim")
@export var aim_half_angle_deg: float = 60.0   # 60 berarti total sudut bidik 120°
@export var block_shot_outside_arc: bool = false

@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown_timer: Timer = $DashCooldown
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var health: int
var weapon: Node2D = null
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var facing_dir: Vector2 = Vector2.DOWN
var mouse_in_arc: bool = true


func _ready() -> void:
	health = max_health
	add_to_group("player")

	dash_timer.wait_time = dash_duration
	dash_timer.one_shot = true
	dash_timer.timeout.connect(_on_dash_finished)

	dash_cooldown_timer.wait_time = dash_cooldown
	dash_cooldown_timer.one_shot = true

	_equip_weapon(weapon_scene)


func _physics_process(delta: float) -> void:
	if is_dashing:
		velocity = dash_direction * dash_speed
	else:
		_handle_movement(delta)

		if Input.is_action_just_pressed("dash"):
			_start_dash()

	move_and_slide()

	_update_facing()
	_aim_weapon()
	_update_animation()

	if Input.is_action_pressed("shoot") and weapon and not is_dashing:
		if mouse_in_arc or not block_shot_outside_arc:
			weapon.shoot()


# ---------- Senjata ----------

func _equip_weapon(scene: PackedScene) -> void:
	# Hapus senjata lama kalau ada (berguna kalau nanti mau ganti senjata)
	if weapon:
		weapon.queue_free()
		weapon = null

	if scene == null:
		return

	weapon = scene.instantiate()
	weapon.position = weapon_offset
	weapon_pivot.add_child(weapon)


func _aim_weapon() -> void:
	var mouse_angle := (get_global_mouse_position() - global_position).angle()
	var facing_angle := facing_dir.angle()
	var half := deg_to_rad(aim_half_angle_deg)

	# Selisih sudut mouse terhadap arah hadap, dalam rentang -PI..PI
	var diff := angle_difference(facing_angle, mouse_angle)
	mouse_in_arc = absf(diff) <= half

	# Batasi sudut bidik ke dalam busur di depan player
	var aim_angle := facing_angle + clampf(diff, -half, half)
	weapon_pivot.rotation = aim_angle

	# Flip supaya senjata tidak terbalik saat mengarah ke kiri
	weapon_pivot.scale.y = -1.0 if absf(wrapf(aim_angle, -PI, PI)) > PI / 2.0 else 1.0


# ---------- Gerakan ----------

func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func _update_facing() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir == Vector2.ZERO:
		return   # diam: pertahankan arah hadap terakhir

	if absf(input_dir.x) >= absf(input_dir.y):
		facing_dir = Vector2.RIGHT if input_dir.x > 0.0 else Vector2.LEFT
	else:
		facing_dir = Vector2.DOWN if input_dir.y > 0.0 else Vector2.UP


# ---------- Dash ----------

func _start_dash() -> void:
	if not dash_cooldown_timer.is_stopped():
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir == Vector2.ZERO:
		dash_direction = facing_dir
	else:
		dash_direction = input_dir.normalized()

	is_dashing = true
	dash_timer.start()
	dash_cooldown_timer.start()


func _on_dash_finished() -> void:
	is_dashing = false


# ---------- Animasi ----------

func _update_animation() -> void:
	# Diam: pakai animasi idle
	if velocity.length() < 10.0:
		_play_idle()
		return

	# Bergerak: pilih animasi sesuai arah gerak yang dominan
	var anim_name: String
	if absf(velocity.x) > absf(velocity.y):
		anim_name = "right" if velocity.x > 0.0 else "left"
	else:
		anim_name = "down" if velocity.y > 0.0 else "up"

	_play_anim(anim_name)


func _play_idle() -> void:
	var dir_name: String
	match facing_dir:
		Vector2.UP:
			dir_name = "up"
		Vector2.DOWN:
			dir_name = "down"
		Vector2.LEFT:
			dir_name = "left"
		_:
			dir_name = "right"

	# Pakai idle per arah kalau ada, kalau tidak pakai "idle" biasa
	var directional := "idle_" + dir_name
	if anim.sprite_frames and anim.sprite_frames.has_animation(directional):
		_play_anim(directional)
	else:
		_play_anim("idle")


func _play_anim(anim_name: String) -> void:
	# Cek dulu supaya animasi tidak diulang dari frame pertama tiap frame
	if anim.animation != anim_name or not anim.is_playing():
		anim.play(anim_name)


# ---------- Damage ----------

func take_damage(amount: int) -> void:
	if is_dashing:
		return

	health -= amount
	health_changed.emit(health)

	if health <= 0:
		died.emit()
		StageManager.return_to_lobby()
		queue_free()
