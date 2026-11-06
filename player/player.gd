extends CharacterBody2D

signal health_changed(new_health: int)
signal died

const FACING_HYSTERESIS := 0.15   # toleransi supaya arah hadap tidak berganti-ganti di sudut diagonal

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

@export_group("Backpedal")
@export_range(0.1, 1.0, 0.05) var backpedal_speed_multiplier: float = 0.55   # kecepatan saat jalan lurus ke belakang
@export var slow_only_while_shooting: bool = false                            # true = melambat hanya saat menembak
@export var reverse_walk_anim_when_backpedal: bool = true                     # animasi jalan diputar terbalik saat mundur

@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown_timer: Timer = $DashCooldown
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var health: int
var base_max_health: int
var base_dash_cooldown: float
var weapon: Node2D = null
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var aim_dir: Vector2 = Vector2.DOWN      # arah dari player ke mouse
var facing_dir: Vector2 = Vector2.DOWN   # arah hadap sprite (4 arah), mengikuti bidikan
var _anim_backwards: bool = false


func _ready() -> void:
	base_max_health = max_health
	base_dash_cooldown = dash_cooldown
	_apply_upgrades(true)
	add_to_group("player")

	if is_instance_valid(GameState) and not GameState.upgrade_purchased.is_connected(_on_upgrade_purchased):
		GameState.upgrade_purchased.connect(_on_upgrade_purchased)

	dash_timer.wait_time = dash_duration
	dash_timer.one_shot = true
	dash_timer.timeout.connect(_on_dash_finished)

	dash_cooldown_timer.wait_time = dash_cooldown
	dash_cooldown_timer.one_shot = true

	_equip_weapon(weapon_scene)


func _apply_upgrades(reset_hp: bool = false) -> void:
	if is_instance_valid(GameState):
		max_health = base_max_health + GameState.get_max_health_bonus()
		dash_cooldown = base_dash_cooldown * GameState.get_dash_cooldown_multiplier()
	if reset_hp:
		health = max_health
	else:
		health = mini(health + 1, max_health)
	if dash_cooldown_timer:
		dash_cooldown_timer.wait_time = dash_cooldown
	health_changed.emit(health)


func _on_upgrade_purchased(_upgrade_id: String, _new_level: int) -> void:
	_apply_upgrades(true)


func _physics_process(delta: float) -> void:
	_update_aim()

	if is_dashing:
		velocity = dash_direction * dash_speed
	else:
		_handle_movement(delta)

		if Input.is_action_just_pressed("dash"):
			_start_dash()

	move_and_slide()

	_aim_weapon()
	_update_animation()

	if Input.is_action_pressed("shoot") and weapon and not is_dashing:
		weapon.shoot()


# ---------- Bidikan ----------

func _update_aim() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		aim_dir = to_mouse.normalized()

	# Arah hadap 4 arah mengikuti bidikan, dengan hysteresis di sudut diagonal
	var want_horizontal: bool
	if facing_dir.x != 0.0:
		want_horizontal = not (absf(aim_dir.y) > absf(aim_dir.x) + FACING_HYSTERESIS)
	else:
		want_horizontal = absf(aim_dir.x) > absf(aim_dir.y) + FACING_HYSTERESIS

	if want_horizontal:
		facing_dir = Vector2.RIGHT if aim_dir.x >= 0.0 else Vector2.LEFT
	else:
		facing_dir = Vector2.DOWN if aim_dir.y >= 0.0 else Vector2.UP


func _aim_weapon() -> void:
	# Dihitung ulang setelah move_and_slide() supaya laras tepat di posisi player terbaru
	var angle := (get_global_mouse_position() - global_position).angle()
	weapon_pivot.rotation = angle

	# Flip supaya senjata tidak terbalik saat mengarah ke kiri
	weapon_pivot.scale.y = -1.0 if absf(angle) > PI / 2.0 else 1.0


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


# ---------- Gerakan ----------

func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir != Vector2.ZERO:
		var target_speed := speed * _get_backpedal_factor(input_dir)
		velocity = velocity.move_toward(input_dir * target_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


## 1.0 = kecepatan normal, mengecil sampai backpedal_speed_multiplier saat bergerak
## lurus berlawanan dengan arah bidik. Gerak menyamping tetap kecepatan normal.
func _get_backpedal_factor(input_dir: Vector2) -> float:
	if slow_only_while_shooting and not Input.is_action_pressed("shoot"):
		return 1.0

	var dot := input_dir.normalized().dot(aim_dir)   # 1 = searah bidikan, -1 = berlawanan
	var backward_amount := clampf(-dot, 0.0, 1.0)
	return lerpf(1.0, backpedal_speed_multiplier, backward_amount)


# ---------- Dash ----------

func _start_dash() -> void:
	if not dash_cooldown_timer.is_stopped():
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir == Vector2.ZERO:
		dash_direction = aim_dir
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

	# Bergerak: animasi mengikuti arah hadap (arah bidik), bukan arah jalan
	var backwards := false
	if reverse_walk_anim_when_backpedal and not is_dashing:
		backwards = velocity.normalized().dot(aim_dir) < -0.5

	_play_anim(_dir_name(facing_dir), backwards)


func _play_idle() -> void:
	var dir_name := _dir_name(facing_dir)

	# Pakai idle per arah kalau ada, kalau tidak pakai "idle" biasa
	var directional := "idle_" + dir_name
	if anim.sprite_frames and anim.sprite_frames.has_animation(directional):
		_play_anim(directional)
	else:
		_play_anim("idle")


func _dir_name(dir: Vector2) -> String:
	if dir == Vector2.UP:
		return "up"
	if dir == Vector2.DOWN:
		return "down"
	if dir == Vector2.LEFT:
		return "left"
	return "right"


func _play_anim(anim_name: String, backwards: bool = false) -> void:
	# Jangan mulai ulang animasi yang sedang berjalan dengan arah putar yang sama
	if anim.animation == anim_name and anim.is_playing() and _anim_backwards == backwards:
		return

	_anim_backwards = backwards
	if backwards:
		anim.play_backwards(anim_name)
	else:
		anim.play(anim_name)


# ---------- Damage ----------

func take_damage(amount: int) -> void:
	if is_dashing or health <= 0:
		return

	health -= amount
	health_changed.emit(health)

	if health <= 0:
		var has_stage_listener := died.get_connections().size() > 0
		died.emit()
		if not has_stage_listener:
			StageManager.return_to_lobby()
		queue_free()
