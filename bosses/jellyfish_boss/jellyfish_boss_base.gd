class_name JellyfishBossBase
extends CharacterBody2D

# ============================================================
# JELLYFISH BOSS - BASE CLASS
# ============================================================
# Kelas dasar untuk Jellyfish Boss (Merah & Biru).
# Menangani UI bar HP, sistem damage, batas arena, integrasi GameState,
# animasi dasar, dan alur kematian boss.
# ============================================================

signal boss_died
signal health_changed(current: int, maximum: int)

# Batas arena agar boss tidak pernah keluar dari viewbox pertempuran
const ARENA_MIN_X: float = -820.0
const ARENA_MAX_X: float = 820.0
const ARENA_MIN_Y: float = -395.0
const ARENA_MAX_Y: float = 435.0

@export_group("Base Boss Settings")
@export var boss_title: String = "JELLYFISH EMPEROR"
@export var max_health: int = 60
@export var speed: float = 120.0
@export var contact_damage: int = 1
@export var damage_cooldown: float = 0.8
@export var currency_reward: int = 35

@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var hit_area: Area2D = get_node_or_null("HitArea")
@onready var health_bar: ProgressBar = get_node_or_null("CanvasLayer/HealthBar")
@onready var boss_title_label: Label = get_node_or_null("CanvasLayer/BossTitleLabel")

var health: int
var player: Node2D = null
var _is_dying: bool = false
var _damage_lock_timer: float = 0.0
var _base_visual_modulate: Color = Color.WHITE


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 3

	if is_instance_valid(GameState):
		max_health = GameState.scale_enemy_hp(max_health)
		contact_damage = GameState.scale_damage(contact_damage)
		speed = GameState.scale_enemy_speed(speed)
		currency_reward = GameState.scale_currency(currency_reward)

	health = max_health

	add_to_group("enemy")
	add_to_group("boss")

	player = get_tree().get_first_node_in_group("player")

	if hit_area:
		hit_area.collision_layer = 0
		hit_area.collision_mask = 1
		if not hit_area.body_entered.is_connected(_on_hit_area_body_entered):
			hit_area.body_entered.connect(_on_hit_area_body_entered)

	if anim:
		_base_visual_modulate = anim.modulate
		_setup_animations()
		_play_anim(&"idle")

	_init_boss_hud()


func _init_boss_hud() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	if boss_title_label:
		boss_title_label.text = boss_title


func _setup_animations() -> void:
	if anim == null or anim.sprite_frames == null:
		return
	var frames := anim.sprite_frames
	for one_shot in [&"attack", &"hit", &"death"]:
		if frames.has_animation(one_shot):
			frames.set_animation_loop(one_shot, false)
	for looping in [&"idle", &"walk"]:
		if frames.has_animation(looping):
			frames.set_animation_loop(looping, true)


func _physics_process(delta: float) -> void:
	if _is_dying:
		velocity = Vector2.ZERO
		return

	if _damage_lock_timer > 0.0:
		_damage_lock_timer = maxf(_damage_lock_timer - delta, 0.0)

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	_boss_physics_process(delta)

	move_and_slide()
	_clamp_to_arena()
	_check_contact_damage()


## Virtual method untuk di-override oleh child class (Red / Blue)
func _boss_physics_process(_delta: float) -> void:
	pass


func _clamp_to_arena() -> void:
	global_position.x = clampf(global_position.x, ARENA_MIN_X, ARENA_MAX_X)
	global_position.y = clampf(global_position.y, ARENA_MIN_Y, ARENA_MAX_Y)


func _check_contact_damage() -> void:
	if _damage_lock_timer > 0.0 or _is_dying:
		return

	if hit_area != null:
		for body in hit_area.get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(contact_damage)
				_damage_lock_timer = damage_cooldown
				break


func _on_hit_area_body_entered(body: Node2D) -> void:
	if _damage_lock_timer > 0.0 or _is_dying:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(contact_damage)
		_damage_lock_timer = damage_cooldown


# ============================================================
# DAMAGE & DEATH
# ============================================================

func take_damage(amount: int) -> void:
	if _is_dying or health <= 0 or amount <= 0:
		return

	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)

	if health_bar:
		health_bar.value = health

	_flash_hit()

	if health <= 0:
		die()
	else:
		_on_health_damaged()


func _on_health_damaged() -> void:
	pass


func _flash_hit() -> void:
	if anim == null:
		return
	anim.modulate = Color(1.0, 0.35, 0.35, 1.0)
	var tween := create_tween()
	tween.tween_property(anim, "modulate", _base_visual_modulate, 0.12)


func die() -> void:
	if _is_dying:
		return
	_is_dying = true
	velocity = Vector2.ZERO

	# Matikan tabrakan
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)

	if hit_area:
		hit_area.set_deferred("monitoring", false)

	# Berikan reward koin/pearls
	if is_instance_valid(GameState) and currency_reward > 0:
		GameState.add_currency(currency_reward)

	# Sembunyikan HUD boss
	var canvas := get_node_or_null("CanvasLayer")
	if canvas:
		canvas.visible = false

	# Animasi kematian
	if _has_anim(&"death"):
		anim.play(&"death")
		await anim.animation_finished
	else:
		var fade_tween := create_tween()
		fade_tween.tween_property(self, "modulate:a", 0.0, 0.6)
		await fade_tween.finished

	boss_died.emit()
	queue_free()


# ============================================================
# ANIMATION HELPERS
# ============================================================

func _play_anim(anim_name: StringName) -> void:
	if anim == null or not _has_anim(anim_name):
		return
	if anim.animation != anim_name:
		anim.play(anim_name)


func _has_anim(anim_name: StringName) -> bool:
	return (
		anim != null
		and anim.sprite_frames != null
		and anim.sprite_frames.has_animation(anim_name)
	)


func _get_animation_duration(anim_name: StringName, fallback: float = 0.5) -> float:
	if not _has_anim(anim_name):
		return fallback
	var frames: int = anim.sprite_frames.get_frame_count(anim_name)
	var fps: float = anim.sprite_frames.get_animation_speed(anim_name)
	if fps <= 0.0:
		return fallback
	var playback_speed := absf(anim.speed_scale)
	if playback_speed <= 0.0:
		return fallback
	return maxf(float(frames) / (fps * playback_speed), 0.1)
