
extends Area2D

# ============================================================
# ELECTRIC PROJECTILE
# ============================================================

@export_group("Projectile Settings")
@export var speed: float = 350.0
@export var damage: int = 1
@export var lifetime: float = 4.0

var direction: Vector2 = Vector2.ZERO
var _destroyed: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	get_tree().create_timer(lifetime).timeout.connect(
		_on_lifetime_timeout
	)


# ============================================================
# SETUP
# ============================================================

func setup(
	shoot_direction: Vector2,
	projectile_damage: int
) -> void:
	direction = shoot_direction.normalized()
	damage = projectile_damage

	if direction.length() > 0.0:
		global_rotation = direction.angle()


# ============================================================
# MOVEMENT
# ============================================================

func _physics_process(delta: float) -> void:
	if _destroyed:
		return

	if direction == Vector2.ZERO:
		return

	global_position += direction * speed * delta


# ============================================================
# COLLISION
# ============================================================

func _on_body_entered(body: Node2D) -> void:
	if _destroyed:
		return

	# Jangan menyerang sesama enemy.
	if body.is_in_group("enemy"):
		return

	# Player terkena proyektil.
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)

		_destroy()
		return

	# Proyektil mengenai tembok atau objek lain.
	_destroy()


# ============================================================
# LIFETIME
# ============================================================

func _on_lifetime_timeout() -> void:
	_destroy()


# ============================================================
# DESTROY
# ============================================================

func _destroy() -> void:
	if _destroyed:
		return

	_destroyed = true
	queue_free()
