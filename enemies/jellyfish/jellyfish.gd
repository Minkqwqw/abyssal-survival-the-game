extends BaseEnemy

@export var pulse_frequency: float = 3.5
@export var drift_amplitude: float = 0.45

@export_group("Attack")
@export var attack_range: float = 60.0              # jarak ke player untuk mulai menyengat (piksel)
@export var attack_cooldown: float = 1.5            # jeda antar serangan
@export_range(0.0, 1.0, 0.05) var attack_speed_multiplier: float = 0.0   # 0 = berhenti total saat menyengat

const ANIM_IDLE := "idle"
const ANIM_WALK := "walk"
const ANIM_ATTACK := "attack"
const ANIM_HIT := "hit"
const ANIM_DEAD := "dead"

var jelly_sprite: AnimatedSprite2D
var _pulse_time: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _base_speed: float = 0.0
var _attack_cd: float = 0.0
var _is_attacking: bool = false
var _is_dying: bool = false
var _hit_lock: bool = false
var _hit_token: int = 0


func _ready() -> void:
	speed = 135.0
	max_health = 4
	currency_reward = 3
	super._ready()

	_base_speed = speed
	_pulse_time = randf() * TAU

	jelly_sprite = _find_animated_sprite()
	if jelly_sprite == null:
		push_warning("Jellyfish: node AnimatedSprite2D tidak ditemukan")
		return

	_base_scale = jelly_sprite.scale

	# Animasi sekali jalan tidak boleh looping
	var frames := jelly_sprite.sprite_frames
	if frames:
		for anim_name in [ANIM_ATTACK, ANIM_HIT, ANIM_DEAD]:
			if frames.has_animation(anim_name):
				frames.set_animation_loop(anim_name, false)

	_play(ANIM_IDLE)


func _physics_process(delta: float) -> void:
	if _is_dying:
		return

	super._physics_process(delta)

	if jelly_sprite == null:
		return

	_attack_cd = maxf(_attack_cd - delta, 0.0)

	if _can_attack():
		_start_attack()

	_update_animation()


# ---------- Gerakan ----------

func _move_behavior(delta: float) -> void:
	_pulse_time += delta * pulse_frequency
	var to_player := global_position.direction_to(player.global_position)
	var perpendicular := to_player.orthogonal() * sin(_pulse_time) * drift_amplitude
	var pulse_speed := speed * (0.65 + 0.55 * absf(sin(_pulse_time * 0.5)))
	velocity = (to_player + perpendicular).normalized() * pulse_speed + knockback

	# Efek mengembang-mengempis, relatif terhadap Scale sprite di scene
	if jelly_sprite:
		var scale_pulse := 1.0 + 0.08 * sin(_pulse_time)
		jelly_sprite.scale = _base_scale * Vector2(scale_pulse, 2.0 - scale_pulse)


# ---------- Animasi ----------

func _update_animation() -> void:
	# Prioritas: mati > hit > menyerang > gerak
	if _is_dying or _hit_lock or _is_attacking:
		return

	_play(ANIM_WALK if velocity.length() > 10.0 else ANIM_IDLE)


# ---------- Serangan ----------

func _can_attack() -> bool:
	if _is_attacking or _hit_lock or _attack_cd > 0.0:
		return false
	if player == null or not is_instance_valid(player):
		return false
	return global_position.distance_to(player.global_position) <= attack_range


func _start_attack() -> void:
	_attack_cd = attack_cooldown

	if not _has_anim(ANIM_ATTACK):
		return

	_is_attacking = true
	speed = _base_speed * attack_speed_multiplier
	jelly_sprite.play(ANIM_ATTACK)

	await get_tree().create_timer(_anim_length(ANIM_ATTACK)).timeout

	if not is_instance_valid(self) or _is_dying:
		return

	_is_attacking = false
	speed = _base_speed


# ---------- Terkena peluru ----------

func take_damage(amount: int) -> void:
	if _is_dying:
		return

	super.take_damage(amount)

	# Kalau damage tadi membunuhnya, die() sudah menandai _is_dying
	if _is_dying or jelly_sprite == null:
		return

	_play_hit()


func _play_hit() -> void:
	# Saat menyengat, jellyfish tidak terganggu animasi hit
	if _is_attacking or not _has_anim(ANIM_HIT):
		return

	_hit_token += 1
	var token := _hit_token
	_hit_lock = true
	jelly_sprite.play(ANIM_HIT)

	await get_tree().create_timer(_anim_length(ANIM_HIT)).timeout

	if not is_instance_valid(self) or _is_dying:
		return

	if token == _hit_token:   # abaikan kalau sudah ada hit yang lebih baru
		_hit_lock = false


# ---------- Mati ----------

func die() -> void:
	if _is_dying:
		return

	_is_dying = true
	_is_attacking = false
	_hit_lock = false
	velocity = Vector2.ZERO
	knockback = Vector2.ZERO
	speed = 0.0
	_disable_collisions()

	if jelly_sprite and _has_anim(ANIM_DEAD):
		jelly_sprite.scale = _base_scale
		jelly_sprite.play(ANIM_DEAD)
		await get_tree().create_timer(_anim_length(ANIM_DEAD)).timeout

	super.die()   # koin, signal, dan queue_free dari BaseEnemy


func _disable_collisions() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)

	var hit_area := get_node_or_null("HitArea")
	if hit_area is Area2D:
		hit_area.set_deferred("monitoring", false)


# ---------- Helper ----------

func _has_anim(anim_name: String) -> bool:
	return jelly_sprite != null and jelly_sprite.sprite_frames != null \
			and jelly_sprite.sprite_frames.has_animation(anim_name)


func _play(anim_name: String) -> void:
	if not _has_anim(anim_name):
		return

	if jelly_sprite.animation != anim_name or not jelly_sprite.is_playing():
		jelly_sprite.play(anim_name)


func _anim_length(anim_name: String) -> float:
	var frames := jelly_sprite.sprite_frames
	var fps := frames.get_animation_speed(anim_name)
	if fps <= 0.0:
		return 0.5

	var total := 0.0
	for i in frames.get_frame_count(anim_name):
		total += frames.get_frame_duration(anim_name, i)
	return total / fps


func _find_animated_sprite() -> AnimatedSprite2D:
	for child in get_children():
		if child is AnimatedSprite2D:
			return child
	return null
