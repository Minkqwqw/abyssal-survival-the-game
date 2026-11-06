extends Area2D

@export var current_direction: Vector2 = Vector2.RIGHT
@export var current_strength: float = 160.0

var _bodies_inside: Array[Node2D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if _bodies_inside.is_empty():
		return

	var push_vec := current_direction.normalized() * current_strength * delta
	for body in _bodies_inside.duplicate():
		if is_instance_valid(body):
			body.global_position += push_vec
		else:
			_bodies_inside.erase(body)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not _bodies_inside.has(body):
		_bodies_inside.append(body)


func _on_body_exited(body: Node2D) -> void:
	_bodies_inside.erase(body)
