extends CharacterBody2D

signal health_changed(new_health: int)
signal died


@export var max_health: int = 5

@export var speed: float = 250.0
@export var acceleration: float = 1800.0
@export var friction: float = 1400.0

@export_group("Dash")
@export var dash_speed: float = 700.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.6

@export_group("Shooting")
@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.15

@onready var muzzle: Marker2D = $Muzzle
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown_timer: Timer = $DashCooldown

var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var can_shoot: bool = true
var health: int = max_health


func _ready() -> void:
	dash_timer.wait_time = dash_duration
	dash_timer.one_shot = true
	dash_timer.timeout.connect(_on_dash_finished)

	dash_cooldown_timer.wait_time = dash_cooldown
	dash_cooldown_timer.one_shot = true


func _physics_process(delta: float) -> void:
	_aim_at_mouse()

	if is_dashing:
		velocity = dash_direction * dash_speed
	else:
		_handle_movement(delta)

		if Input.is_action_just_pressed("dash"):
			_start_dash()

	if Input.is_action_pressed("shoot") and can_shoot:
		_shoot()

	move_and_slide()


func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func _aim_at_mouse() -> void:
	look_at(get_global_mouse_position())


func _start_dash() -> void:
	if not dash_cooldown_timer.is_stopped():
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Kalau tidak sedang menekan arah, dash ke arah mouse
	if input_dir == Vector2.ZERO:
		dash_direction = Vector2.RIGHT.rotated(rotation)
	else:
		dash_direction = input_dir.normalized()

	is_dashing = true
	dash_timer.start()
	dash_cooldown_timer.start()


func _on_dash_finished() -> void:
	is_dashing = false


func _shoot() -> void:
	if bullet_scene == null:
		return

	can_shoot = false

	var bullet = bullet_scene.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.rotation = rotation
	get_tree().current_scene.add_child(bullet)

	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true


func take_damage(amount: int) -> void:
	# I-frame saat dash: tidak menerima damage
	if is_dashing:
		return

	health -= amount
	health_changed.emit(health)

	if health <= 0:
		died.emit()
		queue_free()
