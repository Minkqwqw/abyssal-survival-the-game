class_name BaseEnemy
extends CharacterBody2D

@export var speed: float = 110.0
@export var max_health: int = 3
@export var contact_damage: int = 1
@export var damage_cooldown: float = 0.8
@export var knockback_strength: float = 200.0
@export var currency_reward: int = 2

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var hit_area: Area2D = get_node_or_null("HitArea")

var current_health: int
var health: int:
	get:
		return current_health
	set(value):
		current_health = value

var player: Node2D = null
var knockback: Vector2 = Vector2.ZERO
var can_damage: bool = true


func _ready() -> void:
	current_health = max_health
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null or not is_instance_valid(player):
			return

	_move_behavior(delta)
	knockback = knockback.move_toward(Vector2.ZERO, 800.0 * delta)
	move_and_slide()
	_check_contact_damage()


func _move_behavior(_delta: float) -> void:
	var direction := global_position.direction_to(player.global_position)
	velocity = direction * speed + knockback
	look_at(player.global_position)


func _check_contact_damage() -> void:
	if not can_damage or hit_area == null:
		return

	for body in hit_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(contact_damage)
			can_damage = false
			await get_tree().create_timer(damage_cooldown).timeout
			if is_instance_valid(self):
				can_damage = true
			break


func take_damage(amount: int) -> void:
	if current_health <= 0:
		return

	current_health -= amount

	if player and is_instance_valid(player):
		knockback = player.global_position.direction_to(global_position) * knockback_strength

	_flash()

	if current_health <= 0:
		die()


func _flash() -> void:
	if sprite == null:
		return
	sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(self) and sprite:
		sprite.modulate = Color.WHITE


func die() -> void:
	if is_instance_valid(GameState) and currency_reward > 0:
		GameState.add_currency(currency_reward)
	queue_free()
