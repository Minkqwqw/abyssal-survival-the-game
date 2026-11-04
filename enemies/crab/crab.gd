extends CharacterBody2D

@export var speed: float = 120.0
@export var max_health: int = 3
@export var contact_damage: int = 1
@export var damage_cooldown: float = 0.8
@export var knockback_strength: float = 200.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_area: Area2D = $HitArea

var health: int
var player: Node2D = null
var knockback: Vector2 = Vector2.ZERO
var can_damage: bool = true


func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	var direction := global_position.direction_to(player.global_position)
	velocity = direction * speed + knockback

	# Knockback memudar perlahan
	knockback = knockback.move_toward(Vector2.ZERO, 800.0 * delta)

	look_at(player.global_position)
	move_and_slide()

	_check_contact_damage()


func _check_contact_damage() -> void:
	if not can_damage:
		return

	for body in hit_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(contact_damage)
			can_damage = false
			await get_tree().create_timer(damage_cooldown).timeout
			can_damage = true
			break


func take_damage(amount: int) -> void:
	health -= amount

	# Knockback menjauhi player
	if player:
		knockback = player.global_position.direction_to(global_position) * knockback_strength

	_flash()

	if health <= 0:
		die()


func _flash() -> void:
	sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(self):
		sprite.modulate = Color.WHITE


func die() -> void:
	# Tempat menambah efek partikel, suara, atau drop item
	queue_free()
