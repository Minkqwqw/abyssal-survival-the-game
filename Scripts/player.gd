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

@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown_timer: Timer = $DashCooldown

var health: int
var weapon: Node2D = null
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO


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
	
	_aim_weapon()
	
	if Input.is_action_pressed("shoot") and weapon and not is_dashing:
		weapon.shoot()


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
	var mouse_pos := get_global_mouse_position()
	weapon_pivot.rotation = (mouse_pos - global_position).angle()

	# Flip senjata supaya tidak terbalik saat membidik ke kiri
	weapon_pivot.scale.y = -1.0 if mouse_pos.x < global_position.x else 1.0


func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func _start_dash() -> void:
	if not dash_cooldown_timer.is_stopped():
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir == Vector2.ZERO:
		dash_direction = (get_global_mouse_position() - global_position).normalized()
	else:
		dash_direction = input_dir.normalized()

	is_dashing = true
	dash_timer.start()
	dash_cooldown_timer.start()


func _on_dash_finished() -> void:
	is_dashing = false


func take_damage(amount: int) -> void:
	if is_dashing:
		return

	health -= amount
	health_changed.emit(health)

	if health <= 0:
		died.emit()
		StageManager.return_to_lobby()
		queue_free()
