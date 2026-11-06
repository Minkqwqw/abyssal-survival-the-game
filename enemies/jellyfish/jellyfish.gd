extends BaseEnemy

@export var pulse_frequency: float = 3.5
@export var drift_amplitude: float = 0.45

var _pulse_time: float = 0.0


func _ready() -> void:
	speed = 135.0
	max_health = 4
	currency_reward = 3
	super._ready()
	_pulse_time = randf() * TAU
	if sprite:
		sprite.self_modulate = Color(0.65, 0.85, 1.0, 0.9)


func _move_behavior(delta: float) -> void:
	_pulse_time += delta * pulse_frequency
	var to_player := global_position.direction_to(player.global_position)
	var perpendicular := to_player.orthogonal() * sin(_pulse_time) * drift_amplitude
	var pulse_speed := speed * (0.65 + 0.55 * absf(sin(_pulse_time * 0.5)))
	velocity = (to_player + perpendicular).normalized() * pulse_speed + knockback

	if sprite:
		var scale_pulse := 1.0 + 0.08 * sin(_pulse_time)
		sprite.scale = Vector2(scale_pulse, 2.0 - scale_pulse) * 0.85
