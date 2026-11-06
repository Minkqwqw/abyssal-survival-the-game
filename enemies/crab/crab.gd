extends BaseEnemy

@export var attack_range: float = 70.0      # jarak ke player untuk mulai menyerang (piksel)
@export var attack_cooldown: float = 1.2    # jeda antar serangan
@export var face_deadzone: float = 6.0      # toleransi supaya tidak bolak-balik saat player tepat di atas/bawah

const ANIM_IDLE := "idle"
const ANIM_LEFT := "left"
const ANIM_RIGHT := "right"
const ANIM_DEAD := "dead"

var crab_sprite: AnimatedSprite2D
var _target: Node2D
var _face_left: bool = true
var _is_attacking: bool = false
var _is_dying: bool = false
var _attack_cd: float = 0.0
var _normal_speed: Variant = null


func _ready() -> void:
	super._ready()

	# Kepiting memakai animasi kiri/kanan, jadi sprite tidak boleh diputar
	set("rotate_sprite_to_player", false)

	_target = get_tree().get_first_node_in_group("player")
	crab_sprite = _find_animated_sprite()
	
	if crab_sprite == null:
		push_warning("Crab: node AnimatedSprite2D tidak ditemukan")
		return

	crab_sprite.flip_h = false

	# Animasi sekali jalan tidak boleh looping
	var frames := crab_sprite.sprite_frames
	if frames:
		for anim_name in ["attack_left", "attack_right", "attak_right", ANIM_DEAD]:
			if frames.has_animation(anim_name):
				frames.set_animation_loop(anim_name, false)

	_play(ANIM_IDLE)


func _physics_process(delta: float) -> void:
	if _is_dying:
		return

	super._physics_process(delta)
	
	# Pengaman: batalkan rotasi apa pun yang diterapkan BaseEnemy
	rotation = 0.0
	if crab_sprite:
		crab_sprite.rotation = 0.0

	if crab_sprite == null:
		return

	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_update_facing()

	if _is_attacking:
		return

	if _can_attack():
		_start_attack()
		return

	_update_move_animation()


# ---------- Arah hadap ----------

func _update_facing() -> void:
	var dx := velocity.x
	if _target != null and is_instance_valid(_target):
		dx = _target.global_position.x - global_position.x

	if absf(dx) > face_deadzone:
		_face_left = dx < 0.0


# ---------- Animasi jalan / idle ----------

func _update_move_animation() -> void:
	if velocity.length() > 10.0:
		_play(ANIM_LEFT if _face_left else ANIM_RIGHT)
	else:
		_play(ANIM_IDLE)


# ---------- Serangan ----------

func _can_attack() -> bool:
	if _attack_cd > 0.0:
		return false
	if _target == null or not is_instance_valid(_target):
		return false
	return global_position.distance_to(_target.global_position) <= attack_range


func _get_attack_anim() -> String:
	var frames := crab_sprite.sprite_frames
	if frames == null:
		return ""

	if _face_left:
		return "attack_left" if frames.has_animation("attack_left") else ""

	if frames.has_animation("attack_right"):
		return "attack_right"
	if frames.has_animation("attak_right"):   # nama dengan typo di SpriteFrames
		return "attak_right"
	return ""


func _start_attack() -> void:
	_attack_cd = attack_cooldown

	var anim_name := _get_attack_anim()
	if anim_name == "":
		return

	_is_attacking = true
	_freeze_movement(true)
	crab_sprite.play(anim_name)

	await get_tree().create_timer(_anim_length(anim_name)).timeout

	if not is_instance_valid(self) or _is_dying:
		return

	_is_attacking = false
	_freeze_movement(false)


## Berhenti sebentar saat menyerang (kalau BaseEnemy punya variabel speed)
func _freeze_movement(freeze: bool) -> void:
	if freeze:
		_normal_speed = get("speed")
		if _normal_speed != null:
			set("speed", 0.0)
	elif _normal_speed != null:
		set("speed", _normal_speed)


# ---------- Mati ----------

func die() -> void:
	if _is_dying:
		return

	_is_dying = true
	_is_attacking = false
	velocity = Vector2.ZERO
	_disable_collisions()

	var frames := crab_sprite.sprite_frames if crab_sprite else null
	if frames and frames.has_animation(ANIM_DEAD):
		crab_sprite.play(ANIM_DEAD)
		await get_tree().create_timer(_anim_length(ANIM_DEAD)).timeout

	super.die()   # koin, signal, dan queue_free dari BaseEnemy


func _disable_collisions() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)

	var hit := get_node_or_null("HitArea")
	if hit is Area2D:
		hit.set_deferred("monitoring", false)


# ---------- Helper ----------

func _play(anim_name: String) -> void:
	var frames := crab_sprite.sprite_frames
	if frames == null or not frames.has_animation(anim_name):
		return

	if crab_sprite.animation != anim_name or not crab_sprite.is_playing():
		crab_sprite.play(anim_name)


func _anim_length(anim_name: String) -> float:
	var frames := crab_sprite.sprite_frames
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
