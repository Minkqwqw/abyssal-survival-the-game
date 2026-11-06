
extends BaseEnemy

@export_group("Crab Attack")
@export var attack_range: float = 70.0
@export var attack_cooldown: float = 1.2
@export var face_deadzone: float = 6.0

# Nama animasi
const ANIM_IDLE := "idle"
const ANIM_LEFT := "left"
const ANIM_RIGHT := "right"
const ANIM_ATTACK_LEFT := "attack_left"
const ANIM_ATTACK_RIGHT := "attack_right"
const ANIM_HIT := "hit"
const ANIM_DEAD := "dead"

var crab_sprite: AnimatedSprite2D

var _face_left: bool = false
var _is_attacking: bool = false
var _is_dying: bool = false
var _hit_lock: bool = false

var _attack_cd: float = 0.0

# Token untuk mencegah timer animasi lama mengganggu animasi baru.
var _hit_token: int = 0
var _attack_token: int = 0


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	super._ready()

	crab_sprite = _find_animated_sprite()

	if crab_sprite == null:
		push_warning("Crab: AnimatedSprite2D tidak ditemukan!")
		return

	# Animasi sekali jalan tidak boleh looping.
	var frames := crab_sprite.sprite_frames

	if frames:
		for anim_name in [
			ANIM_ATTACK_LEFT,
			ANIM_ATTACK_RIGHT,
			ANIM_HIT,
			ANIM_DEAD
		]:
			if frames.has_animation(anim_name):
				frames.set_animation_loop(anim_name, false)

	crab_sprite.flip_h = false
	_play(ANIM_IDLE)


# =========================================================
# PHYSICS PROCESS
# =========================================================

func _physics_process(delta: float) -> void:
	if _is_dying:
		return

	# Movement, knockback, dan contact damage dari BaseEnemy.
	super._physics_process(delta)

	if crab_sprite == null:
		return

	_attack_cd = maxf(_attack_cd - delta, 0.0)

	_update_facing()

	# Prioritas animasi: mati > hit > attack > movement.
	if _hit_lock or _is_attacking:
		return

	if _can_attack():
		_start_attack()
		return

	_update_animation()


# =========================================================
# MOVEMENT
# =========================================================

func _move_behavior(_delta: float) -> void:
	# Berhenti saat menyerang, terkena hit, atau mati.
	if _is_dying or _hit_lock or _is_attacking:
		velocity = Vector2.ZERO
		return

	if player == null or not is_instance_valid(player):
		velocity = Vector2.ZERO
		return

	# Bergerak menuju player tanpa memutar node Crab.
	var direction := global_position.direction_to(
		player.global_position
	)

	velocity = direction * speed + knockback


# =========================================================
# FACING
# =========================================================

func _update_facing() -> void:
	if player == null or not is_instance_valid(player):
		return

	var difference := player.global_position.x - global_position.x

	if absf(difference) <= face_deadzone:
		return

	_face_left = difference < 0.0


# =========================================================
# MOVEMENT ANIMATION
# =========================================================

func _update_animation() -> void:
	if _is_dying or _hit_lock or _is_attacking:
		return

	if velocity.length() < 10.0:
		_play(ANIM_IDLE)
	elif _face_left:
		_play(ANIM_LEFT)
	else:
		_play(ANIM_RIGHT)


# =========================================================
# ATTACK
# =========================================================

func _can_attack() -> bool:
	if _is_dying or _is_attacking or _hit_lock:
		return false

	if _attack_cd > 0.0:
		return false

	if player == null or not is_instance_valid(player):
		return false

	return global_position.distance_to(player.global_position) <= attack_range


func _start_attack() -> void:
	if _is_dying or _is_attacking or _hit_lock:
		return

	_attack_cd = attack_cooldown
	_is_attacking = true

	velocity = Vector2.ZERO

	var selected_animation: String

	if _face_left:
		selected_animation = ANIM_ATTACK_LEFT
	else:
		selected_animation = ANIM_ATTACK_RIGHT

	if not _has_anim(selected_animation):
		push_warning("Crab: Animasi tidak ditemukan: " + selected_animation)
		_is_attacking = false
		return

	_attack_token += 1
	var token := _attack_token

	crab_sprite.play(selected_animation)

	await get_tree().create_timer(
		_anim_length(selected_animation)
	).timeout

	if not is_instance_valid(self) or _is_dying:
		return

	# Abaikan jika attack sudah diinterupsi oleh hit.
	if token != _attack_token:
		return

	_is_attacking = false
	_update_animation()


# =========================================================
# TAKE DAMAGE
# =========================================================

func take_damage(amount: int) -> void:
	if _is_dying:
		return

	# Jalankan sistem damage dari BaseEnemy.
	super.take_damage(amount)

	# Jika damage membunuh Crab, jangan memainkan animasi hit.
	if _is_dying or crab_sprite == null:
		return

	_play_hit()


# =========================================================
# HIT ANIMATION
# =========================================================

func _play_hit() -> void:
	if _is_dying:
		return

	if not _has_anim(ANIM_HIT):
		push_warning("Crab: Animasi hit tidak ditemukan!")
		return

	# Interupsi attack jika Crab terkena serangan.
	_attack_token += 1
	_is_attacking = false

	# Token baru membatalkan timer hit sebelumnya.
	_hit_token += 1
	var token := _hit_token

	_hit_lock = true
	velocity = Vector2.ZERO

	crab_sprite.play(ANIM_HIT)

	await get_tree().create_timer(
		_anim_length(ANIM_HIT)
	).timeout

	if not is_instance_valid(self) or _is_dying:
		return

	# Abaikan timer hit lama.
	if token == _hit_token:
		_hit_lock = false
		_update_animation()


# =========================================================
# DEATH
# =========================================================

func die() -> void:
	if _is_dying:
		return

	_is_dying = true
	_is_attacking = false
	_hit_lock = false

	_attack_token += 1
	_hit_token += 1

	velocity = Vector2.ZERO
	knockback = Vector2.ZERO
	speed = 0.0

	_disable_collisions()

	if crab_sprite != null and _has_anim(ANIM_DEAD):
		crab_sprite.play(ANIM_DEAD)

		await get_tree().create_timer(
			_anim_length(ANIM_DEAD)
		).timeout

		if not is_instance_valid(self):
			return

	# Berikan reward dan hapus enemy melalui BaseEnemy.
	super.die()


func _disable_collisions() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)

	if hit_area is Area2D:
		hit_area.set_deferred("monitoring", false)

		for child in hit_area.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)


# =========================================================
# HELPER
# =========================================================

func _has_anim(anim_name: String) -> bool:
	return (
		crab_sprite != null
		and crab_sprite.sprite_frames != null
		and crab_sprite.sprite_frames.has_animation(anim_name)
	)


func _play(anim_name: String) -> void:
	if not _has_anim(anim_name):
		return

	if (
		crab_sprite.animation != anim_name
		or not crab_sprite.is_playing()
	):
		crab_sprite.play(anim_name)


func _anim_length(anim_name: String) -> float:
	if not _has_anim(anim_name):
		return 0.5

	var frames := crab_sprite.sprite_frames
	var fps := frames.get_animation_speed(anim_name)

	if fps <= 0.0:
		return 0.5

	var total := 0.0

	for i in range(frames.get_frame_count(anim_name)):
		total += frames.get_frame_duration(anim_name, i)

	return total / fps


func _find_animated_sprite() -> AnimatedSprite2D:
	for child in get_children():
		if child is AnimatedSprite2D:
			return child

	return null
