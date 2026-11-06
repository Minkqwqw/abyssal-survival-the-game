extends CharacterBody2D

signal boss_died
signal health_changed(current: int, maximum: int)

enum State { IDLE, SCUTTLE, WINDUP, CHARGE, SHOOT, STUNNED }

@export var max_health: int = 40
@export var scuttle_speed: float = 90.0
@export var charge_speed: float = 600.0
@export var contact_damage: int = 1
@export var damage_cooldown: float = 0.8
@export var bubble_scene: PackedScene       # bisa pakai Bullet.tscn versi musuh (lihat catatan)
@export_group("Bubble Barrage")
@export var barrage_duration: float = 3.5          # lama fase menembak (detik)
@export var fire_interval_min: float = 0.06        # jeda antar gelembung (detik)
@export var fire_interval_max: float = 0.18
@export var aim_jitter_deg: float = 35.0           # penyimpangan dari arah player
@export var random_shot_chance: float = 0.3        # peluang gelembung ke arah acak total
@export var bubble_speed_min: float = 220.0
@export var bubble_speed_max: float = 420.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_area: Area2D = $HitArea
@onready var mouth: Marker2D = $Mouth
@onready var health_bar: ProgressBar = $CanvasLayer/HealthBar

var health: int
var player: Node2D = null
var state: State = State.IDLE
var phase: int = 1
var can_damage: bool = true
var charge_dir: Vector2 = Vector2.ZERO
var scuttle_side: float = 1.0


func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	add_to_group("boss")
	player = get_tree().get_first_node_in_group("player")

	health_bar.max_value = max_health
	health_bar.value = health

	_choose_next_action()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		velocity = Vector2.ZERO
		return

	match state:
		State.SCUTTLE:
			_do_scuttle()
		State.CHARGE:
			velocity = charge_dir * charge_speed
		_:
			velocity = velocity.move_toward(Vector2.ZERO, 1500.0 * delta)

	move_and_slide()

	# Kalau menabrak dinding saat charge, langsung pusing sebentar
	if state == State.CHARGE and get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			if not (col.get_collider() is CharacterBody2D):
				_stun(0.8)
				break

	_check_contact_damage()


# ---------- Pengambilan keputusan ----------

func _choose_next_action() -> void:
	if state == State.STUNNED and health <= 0:
		return

	state = State.SCUTTLE
	scuttle_side = [-1.0, 1.0].pick_random()

	var wait := 1.6 if phase == 1 else 0.9
	await get_tree().create_timer(wait).timeout
	if not is_instance_valid(self) or health <= 0:
		return

	var roll := randf()
	if roll < 0.5:
		_attack_charge()
	else:
		_attack_bubbles()


# ---------- Gerakan menyamping ----------

func _do_scuttle() -> void:
	var to_player := global_position.direction_to(player.global_position)
	# Kepiting jalan menyamping: tegak lurus terhadap arah ke player + sedikit mendekat
	var side := to_player.orthogonal() * scuttle_side
	var speed := scuttle_speed * (1.5 if phase == 2 else 1.0)
	velocity = (side * 0.8 + to_player * 0.4).normalized() * speed


# ---------- Serangan 1: Charge ----------

func _attack_charge() -> void:
	state = State.WINDUP
	velocity = Vector2.ZERO

	# Peringatan: sprite berkedip kuning sebelum menyerbu
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0.9, 0.2), 0.25)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	await tween.finished
	if not is_instance_valid(self) or health <= 0:
		return

	charge_dir = global_position.direction_to(player.global_position)
	state = State.CHARGE

	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self) or health <= 0:
		return

	if state == State.CHARGE:
		_stun(0.6)


func _stun(duration: float) -> void:
	state = State.STUNNED
	velocity = Vector2.ZERO
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self) and health > 0:
		_choose_next_action()

# ---------- Serangan 2: Hujan Gelembung ----------

func _attack_bubbles() -> void:
	state = State.SHOOT
	velocity = Vector2.ZERO

	if bubble_scene == null:
		push_warning("Bubble Scene di CrabBoss belum diisi")
		_choose_next_action()
		return

	# Peringatan singkat: boss membesar sebelum menembak
	var base_scale := sprite.scale
	var tween := create_tween()
	tween.tween_property(sprite, "scale", base_scale * 1.1, 0.2)
	tween.tween_property(sprite, "scale", base_scale, 0.2)
	await tween.finished
	if not is_instance_valid(self) or health <= 0:
		return

	# Fase 2: lebih lama dan lebih rapat
	var duration := barrage_duration * (1.4 if phase == 2 else 1.0)
	var interval_scale := 0.6 if phase == 2 else 1.0
	var elapsed := 0.0

	while elapsed < duration:
		if not is_instance_valid(self) or health <= 0:
			return
		if player == null or not is_instance_valid(player):
			break

		_fire_random_bubble()

		var wait := randf_range(fire_interval_min, fire_interval_max) * interval_scale
		await get_tree().create_timer(wait).timeout
		elapsed += wait

	# Jeda setelah menembak: celah untuk player menyerang balik
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(self) and health > 0:
		_choose_next_action()


func _fire_random_bubble() -> void:
	var angle: float

	if randf() < random_shot_chance:
		# Tembakan liar ke segala arah
		angle = randf() * TAU
	else:
		# Mengarah ke player dengan penyimpangan acak
		var to_player := (player.global_position - mouth.global_position).angle()
		angle = to_player + deg_to_rad(randf_range(-aim_jitter_deg, aim_jitter_deg))

	var bubble := bubble_scene.instantiate()
	bubble.speed = randf_range(bubble_speed_min, bubble_speed_max)
	get_tree().current_scene.add_child(bubble)
	bubble.global_position = mouth.global_position
	bubble.global_rotation = angle

# ---------- Damage ----------

func _check_contact_damage() -> void:
	if not can_damage:
		return

	for body in hit_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(contact_damage)
			can_damage = false
			await get_tree().create_timer(damage_cooldown).timeout
			can_damage = true
			break


func take_damage(amount: int) -> void:
	if health <= 0:
		return

	health -= amount
	health_bar.value = health
	health_changed.emit(health, max_health)
	_flash()

	if phase == 1 and health <= max_health / 2.0:
		_enter_phase_two()

	if health <= 0:
		die()


func _enter_phase_two() -> void:
	phase = 2
	var tween := create_tween()
	tween.tween_property(sprite, "scale", sprite.scale * 1.15, 0.2)
	sprite.self_modulate = Color(1, 0.6, 0.6)   # kepiting memerah


func _flash() -> void:
	sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(self) and state != State.WINDUP:
		sprite.modulate = Color.WHITE


func die() -> void:
	state = State.STUNNED
	velocity = Vector2.ZERO
	boss_died.emit()
	health_bar.get_parent().queue_free()   # hapus CanvasLayer + bar
	queue_free()
