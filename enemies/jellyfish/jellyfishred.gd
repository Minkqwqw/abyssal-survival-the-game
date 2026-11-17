
extends BaseEnemy

# ============================================================
# JELLYFISH RED - MELEE ATTACKER
# ============================================================

@export_group("Red Jellyfish Settings")
@export var attack_range: float = 85.0
@export var attack_cooldown: float = 1.5

@export_group("Electric Attack Settings")
@export var electric_damage: int = 2


# ============================================================
# ANIMATION NAMES
# ============================================================

const ANIM_WALK: StringName = &"walk"
const ANIM_ATTACK: StringName = &"attack"
const ANIM_HIT: StringName = &"hit"
const ANIM_DEATH: StringName = &"death"


# ============================================================
# NODES
# ============================================================

@onready var jelly_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var attack_area: Area2D = get_node_or_null("AttackArea")


# ============================================================
# STATES
# ============================================================

var _is_attacking: bool = false
var _is_dying: bool = false
var _hit_lock: bool = false
var _attack_active: bool = false

var _attack_cooldown_timer: float = 0.0

# Mencegah satu target terkena damage berkali-kali.
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
		if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
			attack_area.body_entered.connect(_on_attack_area_body_entered)

		attack_area.monitoring = false

	# Hubungkan sinyal animasi selesai.
	if not jelly_sprite.animation_finished.is_connected(_on_animation_finished):
		jelly_sprite.animation_finished.connect(_on_animation_finished)

	_setup_animations()
	_play(ANIM_WALK)


func _setup_animations() -> void:
	if jelly_sprite == null or jelly_sprite.sprite_frames == null:
		return

	if _has_anim(ANIM_WALK):
		jelly_sprite.sprite_frames.set_animation_loop(ANIM_WALK, true)

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

	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)

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

	var direction: Vector2 = global_position.direction_to(player.global_position)

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

	var distance: float = global_position.distance_to(player.global_position)

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

	_damaged_targets.clear()
	velocity = Vector2.ZERO

	# Aktifkan area serangan.
	attack_area.set_deferred("monitoring", true)

	# Mulai attack dari frame pertama.
	jelly_sprite.stop()
	jelly_sprite.play(ANIM_ATTACK)
	jelly_sprite.frame = 0


# ============================================================
# ANIMATION FINISHED
# ============================================================

func _on_animation_finished() -> void:
	if jelly_sprite == null:
		return

	match jelly_sprite.animation:

		# ----------------------------------------------------
		# ATTACK FINISHED
		# ----------------------------------------------------
		ANIM_ATTACK:
			if _is_dying or not _is_attacking:
				return

			_attack_active = false
			_is_attacking = false

			if attack_area != null:
				attack_area.set_deferred("monitoring", false)

			# Kembali ke walk.
			jelly_sprite.stop()
			jelly_sprite.play(ANIM_WALK)
			jelly_sprite.frame = 0


		# ----------------------------------------------------
		# HIT FINISHED
		# ----------------------------------------------------
		ANIM_HIT:
			if _is_dying or not _hit_lock:
				return

			_hit_lock = false

			# Kembali ke walk.
			jelly_sprite.stop()
			jelly_sprite.play(ANIM_WALK)
			jelly_sprite.frame = 0


		# ----------------------------------------------------
		# DEATH FINISHED
		# ----------------------------------------------------
		ANIM_DEATH:
			if not _is_dying:
				return

			# Animasi death selesai.
			# Hapus enemy melalui BaseEnemy.
			super.die()


# ============================================================
# ELECTRIC DAMAGE
# ============================================================

func _on_attack_area_body_entered(body: Node2D) -> void:
	if not _attack_active or _is_dying:
		return

	if not body.is_in_group("player"):
		return

	var target_id: int = body.get_instance_id()

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

	_play(ANIM_WALK)


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


# ============================================================
# HIT
# ============================================================

func take_damage(amount: int) -> void:
	if _is_dying:
		return

	# Proses damage melalui BaseEnemy.
	super.take_damage(amount)

	# Jika damage menyebabkan kematian,
	# jangan memainkan animasi hit.
	if _is_dying or jelly_sprite == null:
		return

	_play_hit()


func _play_hit() -> void:
	if _is_dying or not _has_anim(ANIM_HIT):
		return

	# Batalkan attack yang sedang berlangsung.
	_is_attacking = false
	_attack_active = false

	if attack_area != null:
		attack_area.set_deferred("monitoring", false)

	_hit_lock = true
	velocity = Vector2.ZERO

	# Mulai hit dari frame pertama.
	jelly_sprite.stop()
	jelly_sprite.play(ANIM_HIT)
	jelly_sprite.frame = 0


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

	velocity = Vector2.ZERO
	knockback = Vector2.ZERO
	speed = 0.0

	# Matikan semua collision.
	_disable_collisions()

	# Mainkan animasi death.
	if _has_anim(ANIM_DEATH):
		jelly_sprite.stop()
		jelly_sprite.play(ANIM_DEATH)
		jelly_sprite.frame = 0
	else:
		# Jika animasi death tidak tersedia,
		# langsung hapus enemy.
		super.die()


# ============================================================
# COLLISION
# ============================================================

func _disable_collisions() -> void:

	# CollisionShape2D utama.
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)

	# HitArea dari BaseEnemy.
	if hit_area != null and hit_area is Area2D:
		hit_area.set_deferred("monitoring", false)

		for child in hit_area.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)

	# AttackArea.
	if attack_area != null:
		attack_area.set_deferred("monitoring", false)

		for child in attack_area.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
