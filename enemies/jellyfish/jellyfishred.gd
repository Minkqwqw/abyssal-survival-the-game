
extends BaseEnemy

# ============================================================
# JELLYFISH RED - MELEE ATTACKER
# ============================================================

@export_group("Red Jellyfish Settings")
@export var attack_range: float = 85.0
@export var attack_cooldown: float = 1.5

@export_group("Electric Attack Settings")
@export var electric_damage: int = 2

@export_group("Animation Settings")
@export var animation_fallback_duration: float = 0.5


# Animation Names
const ANIM_MOVE: StringName = &"move"
const ANIM_ATTACK: StringName = &"attack"
const ANIM_HIT: StringName = &"hit"
const ANIM_DEATH: StringName = &"death"


# Nodes
@onready var jelly_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var attack_area: Area2D = get_node_or_null("AttackArea")


# States
var _is_attacking: bool = false
var _is_dying: bool = false
var _hit_lock: bool = false
var _attack_active: bool = false

var _attack_cooldown_timer: float = 0.0

var _attack_token: int = 0
var _hit_token: int = 0

# Mencegah satu target terkena damage berkali-kali
# dalam satu serangan.
var _damaged_targets: Dictionary = {}


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	super._ready()

	if jelly_sprite == null:
		push_warning("JellyfishRed: AnimatedSprite2D tidak ditemukan!")
		return

	if attack_area == null:
		push_warning("JellyfishRed: AttackArea tidak ditemukan!")
	else:
		attack_area.body_entered.connect(
			_on_attack_area_body_entered
		)
		attack_area.monitoring = false

	_setup_animations()
	_play(ANIM_MOVE)


func _setup_animations() -> void:
	if jelly_sprite.sprite_frames == null:
		return

	for anim_name in [ANIM_ATTACK, ANIM_HIT, ANIM_DEATH]:
		if _has_anim(anim_name):
			jelly_sprite.sprite_frames.set_animation_loop(anim_name, false)


# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:
	if _is_dying:
		return

	super._physics_process(delta)

	if jelly_sprite == null:
		return

	_attack_cooldown_timer = maxf(
		_attack_cooldown_timer - delta,
		0.0
	)

	if _hit_lock or _is_attacking:
		return

	if _can_attack():
		_start_attack()
		return

	_update_animation()


# ============================================================
# MOVEMENT
# ============================================================

func _move_behavior(_delta: float) -> void:
	if _is_dying or _hit_lock or _is_attacking:
		velocity = Vector2.ZERO
		return

	if player == null or not is_instance_valid(player):
		velocity = Vector2.ZERO
		return

	var direction := global_position.direction_to(
		player.global_position
	)

	# Jellyfish merah mengejar player secara langsung.
	velocity = direction * speed + knockback


# ============================================================
# ATTACK
# ============================================================

func _can_attack() -> bool:
	if _is_dying or _is_attacking or _hit_lock:
		return false

	if _attack_cooldown_timer > 0.0:
		return false

	if player == null or not is_instance_valid(player):
		return false

	var distance := global_position.distance_to(
		player.global_position
	)

	return distance <= attack_range


func _start_attack() -> void:
	if not _has_anim(ANIM_ATTACK):
		return

	if attack_area == null:
		push_warning("JellyfishRed: AttackArea belum tersedia!")
		return

	_is_attacking = true
	_attack_active = true
	_attack_cooldown_timer = attack_cooldown

	_attack_token += 1
	var token := _attack_token

	_damaged_targets.clear()
	velocity = Vector2.ZERO

	jelly_sprite.play(ANIM_ATTACK)

	# Aktifkan area serangan listrik.
	attack_area.set_deferred("monitoring", true)

	await get_tree().create_timer(
		_get_animation_duration(ANIM_ATTACK)
	).timeout

	if not is_instance_valid(self) or _is_dying:
		return

	if token != _attack_token:
		return

	_attack_active = false
	_is_attacking = false

	attack_area.set_deferred("monitoring", false)

	_update_animation()


# ============================================================
# ELECTRIC DAMAGE
# ============================================================

func _on_attack_area_body_entered(body: Node2D) -> void:
	if not _attack_active or _is_dying:
		return

	if not body.is_in_group("player"):
		return

	var target_id := body.get_instance_id()

	if _damaged_targets.has(target_id):
		return

	_damaged_targets[target_id] = true

	if body.has_method("take_damage"):
		body.take_damage(electric_damage)


# ============================================================
# ANIMATION
# ============================================================

func _update_animation() -> void:
	if _is_dying or _hit_lock or _is_attacking:
		return

	_play(ANIM_MOVE)


func _play(anim_name: StringName) -> void:
	if jelly_sprite == null:
		return

	if not _has_anim(anim_name):
		return

	if jelly_sprite.animation != anim_name:
		jelly_sprite.play(anim_name)


func _has_anim(anim_name: StringName) -> bool:
	return (
		jelly_sprite != null
		and jelly_sprite.sprite_frames != null
		and jelly_sprite.sprite_frames.has_animation(anim_name)
	)


func _get_animation_duration(anim_name: StringName) -> float:
	if not _has_anim(anim_name):
		return animation_fallback_duration

	var frames := jelly_sprite.sprite_frames.get_frame_count(anim_name)
	var fps := jelly_sprite.sprite_frames.get_animation_speed(anim_name)

	if fps <= 0.0:
		return animation_fallback_duration

	return maxf(float(frames) / fps, 0.1)


# ============================================================
# HIT
# ============================================================

func take_damage(amount: int) -> void:
	if _is_dying:
		return

	super.take_damage(amount)

	if _is_dying or jelly_sprite == null:
		return

	_play_hit()


func _play_hit() -> void:
	if _is_dying or not _has_anim(ANIM_HIT):
		return

	_attack_token += 1
	_is_attacking = false
	_attack_active = false

	if attack_area != null:
		attack_area.set_deferred("monitoring", false)

	_hit_token += 1
	var token := _hit_token

	_hit_lock = true
	velocity = Vector2.ZERO

	jelly_sprite.play(ANIM_HIT)

	await get_tree().create_timer(
		_get_animation_duration(ANIM_HIT)
	).timeout

	if not is_instance_valid(self) or _is_dying:
		return

	if token == _hit_token:
		_hit_lock = false
		_update_animation()


# ============================================================
# DEATH
# ============================================================

func die() -> void:
	if _is_dying:
		return

	_is_dying = true
	_is_attacking = false
	_attack_active = false
	_hit_lock = false

	_attack_token += 1
	_hit_token += 1

	velocity = Vector2.ZERO
	knockback = Vector2.ZERO
	speed = 0.0

	_disable_collisions()

	if _has_anim(ANIM_DEATH):
		jelly_sprite.play(ANIM_DEATH)

		await get_tree().create_timer(
			_get_animation_duration(ANIM_DEATH)
		).timeout

		if not is_instance_valid(self):
			return

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

	if attack_area != null:
		attack_area.set_deferred("monitoring", false)

		for child in attack_area.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
