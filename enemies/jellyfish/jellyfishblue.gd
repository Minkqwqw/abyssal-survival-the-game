
extends BaseEnemy

# ============================================================
# JELLYFISH BLUE - RANGED ATTACKER
# ============================================================

@export_group("Blue Jellyfish Settings")
@export var attack_range: float = 300.0
@export var preferred_distance: float = 180.0
@export var attack_cooldown: float = 2.0
@export var projectile_scene: PackedScene

@export_group("Projectile Settings")
@export var projectile_damage: int = 1

@export_group("Animation Settings")
@export var animation_fallback_duration: float = 0.5


# Animation Names
const ANIM_MOVE: StringName = &"move"
const ANIM_ATTACK: StringName = &"attack"
const ANIM_HIT: StringName = &"hit"
const ANIM_DEATH: StringName = &"death"


# Nodes
@onready var jelly_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var muzzle: Marker2D = get_node_or_null("Muzzle")


# States
var _is_attacking: bool = false
var _is_dying: bool = false
var _hit_lock: bool = false

var _attack_cooldown_timer: float = 0.0

var _attack_token: int = 0
var _hit_token: int = 0


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	super._ready()

	if jelly_sprite == null:
		push_warning("JellyfishBlue: AnimatedSprite2D tidak ditemukan!")
		return

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

	var distance := global_position.distance_to(player.global_position)
	var direction := global_position.direction_to(player.global_position)

	# Menjaga jarak dari player.
	if distance < preferred_distance:
		velocity = -direction * speed + knockback
	elif distance > attack_range:
		velocity = direction * speed + knockback
	else:
		velocity = knockback


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

	var distance := global_position.distance_to(player.global_position)

	return distance <= attack_range


func _start_attack() -> void:
	if not _has_anim(ANIM_ATTACK):
		return

	_is_attacking = true
	_attack_cooldown_timer = attack_cooldown

	_attack_token += 1
	var token := _attack_token

	velocity = Vector2.ZERO

	jelly_sprite.play(ANIM_ATTACK)

	# Menembakkan proyektil.
	_shoot_projectile()

	await get_tree().create_timer(
		_get_animation_duration(ANIM_ATTACK)
	).timeout

	if not is_instance_valid(self) or _is_dying:
		return

	if token != _attack_token:
		return

	_is_attacking = false
	_update_animation()


func _shoot_projectile() -> void:
	if projectile_scene == null:
		push_warning("JellyfishBlue: Projectile Scene belum diatur!")
		return

	if player == null or not is_instance_valid(player):
		return

	var projectile := projectile_scene.instantiate()

	if not projectile is Node2D:
		projectile.queue_free()
		return

	get_tree().current_scene.add_child(projectile)

	var spawn_position := global_position

	if muzzle != null:
		spawn_position = muzzle.global_position

	var direction := spawn_position.direction_to(
		player.global_position
	)

	projectile.global_position = spawn_position

	if projectile.has_method("setup"):
		projectile.setup(direction, projectile_damage)


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

	# Membatalkan attack sebelumnya.
	_attack_token += 1
	_is_attacking = false

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
