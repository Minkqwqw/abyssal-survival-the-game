extends Area2D

@export var damage_per_tick: int = 1
@export var tick_interval: float = 1.2

var _targets_inside: Array[Node2D] = []
var _tick_timer: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if _targets_inside.is_empty():
		_tick_timer = 0.0
		return

	_tick_timer += delta
	if _tick_timer >= tick_interval:
		_tick_timer = 0.0
		for body in _targets_inside.duplicate():
			if is_instance_valid(body) and body.has_method("take_damage"):
				body.take_damage(damage_per_tick)
			else:
				_targets_inside.erase(body)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _targets_inside.has(body):
		_targets_inside.append(body)


func _on_body_exited(body: Node2D) -> void:
	_targets_inside.erase(body)
