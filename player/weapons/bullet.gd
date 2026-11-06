
extends Area2D

@export_group("Bullet Settings")
@export var speed: float = 800.0
@export var lifetime: float = 2.0
@export var damage: int = 1

@export_group("Animation")
@export var fly_animation: StringName = &"ink"
@export var hit_animation: StringName = &"hit"

var bullet_sprite: AnimatedSprite2D

var _is_hit: bool = false
var _is_destroyed: bool = false


func _ready() -> void:
	# Cari AnimatedSprite2D.
	bullet_sprite = _find_animated_sprite()

	if bullet_sprite == null:
		push_warning("Bullet: AnimatedSprite2D tidak ditemukan!")
		return

	# Animasi hit tidak boleh looping.
	var frames := bullet_sprite.sprite_frames

	if frames and frames.has_animation(hit_animation):
		frames.set_animation_loop(hit_animation, false)

	# Jalankan animasi peluru.
	_play(fly_animation)

	# Hubungkan signal tabrakan.
	body_entered.connect(_on_body_entered)

	# Hapus peluru jika melewati lifetime.
	get_tree().create_timer(lifetime).timeout.connect(_on_lifetime_timeout)


func _physics_process(delta: float) -> void:
	if _is_hit or _is_destroyed:
		return

	# Gerakkan peluru berdasarkan arah rotasinya.
	global_position += Vector2.RIGHT.rotated(global_rotation) * speed * delta


# =========================================================
# COLLISION
# =========================================================

func _on_body_entered(body: Node2D) -> void:
	if _is_hit or _is_destroyed:
		return

	# Jangan mengenai player sendiri.
	if body.is_in_group("player"):
		return

	# Hanya proses tabrakan dengan enemy.
	if body.is_in_group("enemy"):
		_is_hit = true

		# Berikan damage kepada musuh.
		if body.has_method("take_damage"):
			body.take_damage(damage)

		_play_hit()
		return

	# Jika mengenai objek lain, hapus peluru.
	_destroy()


# =========================================================
# HIT ANIMATION
# =========================================================

func _play_hit() -> void:
	if not _has_anim(hit_animation):
		_destroy()
		return

	# Hentikan collision agar tidak mengenai objek lain.
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	# Jalankan animasi hit.
	bullet_sprite.play(hit_animation)

	# Tunggu animasi selesai.
	await bullet_sprite.animation_finished

	if not is_instance_valid(self):
		return

	_destroy()


# =========================================================
# LIFETIME
# =========================================================

func _on_lifetime_timeout() -> void:
	if not is_instance_valid(self) or _is_destroyed:
		return

	# Jika sedang memainkan animasi hit, jangan ganggu.
	if _is_hit:
		return

	_destroy()


# =========================================================
# DESTROY
# =========================================================

func _destroy() -> void:
	if _is_destroyed:
		return

	_is_destroyed = true
	queue_free()


# =========================================================
# ANIMATION HELPERS
# =========================================================

func _play(anim_name: StringName) -> void:
	if not _has_anim(anim_name):
		push_warning("Bullet: Animasi tidak ditemukan: " + str(anim_name))
		return

	bullet_sprite.play(anim_name)


func _has_anim(anim_name: StringName) -> bool:
	return (
		bullet_sprite != null
		and bullet_sprite.sprite_frames != null
		and bullet_sprite.sprite_frames.has_animation(anim_name)
	)


func _find_animated_sprite() -> AnimatedSprite2D:
	for child in get_children():
		if child is AnimatedSprite2D:
			return child

	return null
