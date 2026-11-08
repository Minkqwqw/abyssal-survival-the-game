extends CharacterBody2D

signal boss_died
signal health_changed(current: int, maximum: int)

enum State { IDLE, SCUTTLE, MELEE_SLASH, WINDUP, CHARGE, SHOOT, RADIAL_SKILL, STUNNED, DEAD }

const FACING_HYSTERESIS: float = 0.15

# Batas aman arena (mengikuti poligon heksagonal/oktagonal MapBounds di Stage 3 agar boss tidak pernah keluar map)
const ARENA_MIN_X: float = -820.0
const ARENA_MAX_X: float = 820.0
const ARENA_MIN_Y: float = -395.0
const ARENA_MAX_Y: float = 435.0

@export var max_health: int = 40
@export var scuttle_speed: float = 95.0
@export var charge_speed: float = 600.0
@export var contact_damage: int = 1
@export var melee_damage: int = 1
@export var damage_cooldown: float = 0.8
@export var knockback_resistance: float = 0.35
@export var currency_reward: int = 25
@export var bubble_scene: PackedScene

@export_group("Dash Charge")
@export var charge_damage: int = 2                 # damage ke player saat tertabrak dash
@export var charge_hit_radius: float = 95.0        # jarak (piksel) dari pusat boss yang dihitung kena dash
@export var charge_recoil: float = 320.0           # boss terpental ke belakang setelah menabrak player

@export_group("Kontak Badan")
@export var contact_radius: float = 80.0           # cadangan kalau HitArea kecil/tidak mengenai player
@export var keep_distance: float = 90.0            # saat scuttle, boss tidak menempel lebih dekat dari ini

@export_group("Melee Claw Slash")
@export var melee_trigger_range: float = 195.0
@export var melee_slash_offset: float = 72.0       # titik pusat sabetan di depan boss (menghadap player)
@export var melee_slash_reach: float = 150.0       # radius sabetan dari titik pusat
@export var melee_cooldown: float = 1.6

@export_group("Bubble Barrage")
@export var barrage_duration: float = 3.5          # lama fase menembak (detik)
@export var fire_interval_min: float = 0.06        # jeda antar gelembung (detik)
@export var fire_interval_max: float = 0.18
@export var aim_jitter_deg: float = 35.0           # penyimpangan dari arah player
@export var random_shot_chance: float = 0.3        # peluang gelembung ke arah acak total
@export var bubble_speed_min: float = 220.0
@export var bubble_speed_max: float = 420.0

@export_group("Ocean Sovereign Radial Skill")
@export var radial_blade_count: int = 8            # jumlah sabit energi (8 arah sesuai referensi)
@export var radial_waves_phase_1: int = 1
@export var radial_waves_phase_2: int = 2
@export var radial_blade_speed: float = 310.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var body_collider: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var hit_area: Area2D = get_node_or_null("HitArea")
@onready var slash_area: Area2D = get_node_or_null("SlashArea")
@onready var slash_shape: CollisionShape2D = get_node_or_null("SlashArea/CollisionShape2D")
@onready var mouth: Marker2D = get_node_or_null("Mouth")
@onready var health_bar: ProgressBar = get_node_or_null("CanvasLayer/HealthBar")
@onready var boss_title_label: Label = get_node_or_null("CanvasLayer/BossTitleLabel")

var health: int
var player: Node2D = null
var state: State = State.IDLE
var phase: int = 1
var charge_dir: Vector2 = Vector2.ZERO
var scuttle_side: float = 1.0
var facing_dir: Vector2 = Vector2.DOWN
var face_left: bool = false
var knockback: Vector2 = Vector2.ZERO

var _base_visual_scale: Vector2 = Vector2(1.35, 1.35)
var _base_self_modulate: Color = Color.WHITE
var _phase_tint: Color = Color.WHITE
var _action_token: int = 0
var _hit_anim_token: int = 0
var _hit_anim_playing: bool = false
var _melee_cd: float = 0.0
var _damage_lock: float = 0.0        # jeda antar damage ke player (menggantikan can_damage)
var _charge_hit_done: bool = false   # dash hanya melukai sekali per serbuan
var _is_dying: bool = false


func _ready() -> void:
	# PENTING untuk game top-down: mode Grounded membuat boss "naik" ke player dan ikut
	# terbawa/menempel (dianggap lantai bergerak). Floating menghilangkan itu.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	if is_instance_valid(GameState):
		max_health = GameState.scale_enemy_hp(max_health)
		contact_damage = GameState.scale_damage(contact_damage)
		melee_damage = GameState.scale_damage(melee_damage)
		charge_damage = GameState.scale_damage(charge_damage)
		scuttle_speed = GameState.scale_enemy_speed(scuttle_speed)
		charge_speed = GameState.scale_enemy_speed(charge_speed)
		bubble_speed_min = GameState.scale_enemy_speed(bubble_speed_min)
		bubble_speed_max = GameState.scale_enemy_speed(bubble_speed_max)
		radial_blade_speed = GameState.scale_enemy_speed(radial_blade_speed)
		currency_reward = GameState.scale_currency(currency_reward)
	health = max_health
	add_to_group("enemy")
	add_to_group("boss")
	player = get_tree().get_first_node_in_group("player")

	# Pastikan collision mask HitArea dan SlashArea aktif terhadap Player (layer 1)
	if hit_area:
		hit_area.collision_mask = 1
		if not hit_area.body_entered.is_connected(_on_hit_area_body_entered):
			hit_area.body_entered.connect(_on_hit_area_body_entered)

	if slash_area:
		slash_area.collision_mask = 1
		slash_area.monitoring = false

	# Sinkronisasi skala & warna dari node Sprite2D (kompatibel penuh dengan Boss3, Boss4, Boss5)
	if anim:
		if sprite:
			_base_self_modulate = sprite.self_modulate
			# Jika scene turunan (Boss3/4/5) mengubah scale Sprite2D dari default (3.0), proporsikan ke AnimatedSprite2D
			var scale_ratio := sprite.scale / 3.0
			_base_visual_scale = Vector2(1.35, 1.35) * scale_ratio
			sprite.visible = false
		anim.scale = _base_visual_scale
		anim.self_modulate = _base_self_modulate
		_configure_animation_loops()
		_play_anim("idle")
	elif sprite:
		_base_visual_scale = sprite.scale
		_base_self_modulate = sprite.self_modulate

	_phase_tint = _base_self_modulate

	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	if boss_title_label:
		boss_title_label.text = "CRAB PRINCESS  -  OCEAN SOVEREIGN"

	_choose_next_action()


func _configure_animation_loops() -> void:
	if anim == null or anim.sprite_frames == null:
		return
	var frames := anim.sprite_frames
	for one_shot_anim in ["attack_left", "attack_right", "skill", "hit", "dead"]:
		if frames.has_animation(one_shot_anim):
			frames.set_animation_loop(one_shot_anim, false)
	for loop_anim in ["idle", "move", "down", "left", "right", "up", "charge_left", "charge_right"]:
		if frames.has_animation(loop_anim):
			frames.set_animation_loop(loop_anim, true)


func _physics_process(delta: float) -> void:
	if _is_dying or state == State.DEAD:
		velocity = Vector2.ZERO
		return

	_melee_cd = maxf(_melee_cd - delta, 0.0)
	_damage_lock = maxf(_damage_lock - delta, 0.0)
	knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null or not is_instance_valid(player):
			velocity = Vector2.ZERO
			_update_directional_animation()
			return

	_update_facing_to_player()

	match state:
		State.SCUTTLE:
			_do_scuttle()
			# Bila player masuk jarak dekat saat scuttle dan melee siap, langsung sabet dengan capit!
			if _melee_cd <= 0.0 and global_position.distance_to(player.global_position) <= melee_trigger_range:
				_attack_melee_slash()
				return
		State.CHARGE:
			velocity = charge_dir * charge_speed
		_:
			# Diam total (pusing, windup, menembak). Tidak boleh akumulasi dengan knockback di bawah.
			velocity = Vector2.ZERO

	velocity += knockback
	move_and_slide()
	_clamp_within_arena_bounds()

	# Dash: cek apakah menabrak player (damage, lalu boss terpental dan pusing sebentar)
	if state == State.CHARGE:
		_check_charge_hit()

	# Kalau menabrak dinding arena saat charge, langsung pusing sebentar
	if state == State.CHARGE and get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			if col and not (col.get_collider() is CharacterBody2D):
				_stun(0.75)
				break

	_update_directional_animation()
	_check_contact_damage()


# ---------- Orientasi 4 Arah & Kiri/Kanan ----------

func _update_facing_to_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	var to_player := player.global_position - global_position
	if to_player.length() <= 1.0:
		return

	if absf(to_player.x) > 6.0:
		face_left = to_player.x < 0.0

	var dir := to_player.normalized()
	var want_horizontal: bool
	if facing_dir.x != 0.0:
		want_horizontal = not (absf(dir.y) > absf(dir.x) + FACING_HYSTERESIS)
	else:
		want_horizontal = absf(dir.x) > absf(dir.y) + FACING_HYSTERESIS

	if want_horizontal:
		facing_dir = Vector2.RIGHT if dir.x >= 0.0 else Vector2.LEFT
	else:
		facing_dir = Vector2.DOWN if dir.y >= 0.0 else Vector2.UP

	# Arahkan titik Mouth sedikit ke arah player agar gelembung/sabit keluar dari posisi depan boss
	if mouth:
		mouth.position = dir * 42.0


func _update_directional_animation() -> void:
	if _is_dying or state == State.DEAD:
		return
	if state in [State.MELEE_SLASH, State.WINDUP, State.CHARGE, State.SHOOT, State.RADIAL_SKILL]:
		return
	if _hit_anim_playing:
		return

	if state == State.STUNNED:
		_play_anim("hit" if _has_anim("hit") else "idle")
		return

	if velocity.length() < 12.0:
		_play_anim("idle")
		return

	# Saat bergerak (SCUTTLE), gunakan animasi 4 arah (down, left, right, up) atau move menyamping
	match facing_dir:
		Vector2.UP:
			_play_anim("up" if _has_anim("up") else "move")
		Vector2.LEFT:
			_play_anim("left" if _has_anim("left") else "move")
		Vector2.RIGHT:
			_play_anim("right" if _has_anim("right") else "move")
		_:
			# Saat menghadap ke bawah namun berjalan menyamping cepat, variasikan dengan animasi scuttle "move"
			if absf(velocity.x) > absf(velocity.y) * 1.15 and _has_anim("move"):
				_play_anim("move")
			else:
				_play_anim("down" if _has_anim("down") else "idle")


func _clamp_within_arena_bounds() -> void:
	var clamped_x := clampf(global_position.x, ARENA_MIN_X, ARENA_MAX_X)
	var clamped_y := clampf(global_position.y, ARENA_MIN_Y, ARENA_MAX_Y)
	if clamped_x != global_position.x or clamped_y != global_position.y:
		global_position = Vector2(clamped_x, clamped_y)
		if state == State.CHARGE:
			_stun(0.75)


# ---------- Pengambilan Keputusan AI Boss ----------

func _choose_next_action() -> void:
	if _is_dying or health <= 0 or not is_inside_tree():
		return

	_action_token += 1
	var token := _action_token

	state = State.SCUTTLE
	scuttle_side = [-1.0, 1.0].pick_random()

	var wait := 1.45 if phase == 1 else 0.85
	await get_tree().create_timer(wait).timeout
	if not _is_token_valid(token):
		return

	if player and is_instance_valid(player) and global_position.distance_to(player.global_position) <= melee_trigger_range and _melee_cd <= 0.0:
		_attack_melee_slash()
		return

	var roll := randf()
	if roll < 0.36:
		_attack_charge()
	elif roll < 0.70:
		_attack_bubbles()
	else:
		_attack_radial_skill()


func _is_token_valid(token: int) -> bool:
	return is_instance_valid(self) and is_inside_tree() and not _is_dying and health > 0 and token == _action_token


# ---------- Gerakan Menyamping (Scuttle) ----------

func _do_scuttle() -> void:
	var to_player := global_position.direction_to(player.global_position)
	var dist := global_position.distance_to(player.global_position)
	var side := to_player.orthogonal() * scuttle_side
	var speed := scuttle_speed * (1.45 if phase == 2 else 1.0)

	# Jangan terus mendorong badan ke player: kalau sudah terlalu dekat, mundur sedikit sambil berputar
	var approach := 0.45 if dist > keep_distance else -0.35
	velocity = (side * 0.78 + to_player * approach).normalized() * speed


# ---------- Serangan 1: Melee Claw Slash (Sabetan Capit Sabit) ----------

func _attack_melee_slash() -> void:
	if _is_dying or health <= 0:
		return

	_action_token += 1
	var token := _action_token
	_melee_cd = melee_cooldown * (0.75 if phase == 2 else 1.0)

	state = State.MELEE_SLASH
	velocity = Vector2.ZERO
	_update_facing_to_player()

	var slash_anim := "attack_left" if face_left else "attack_right"
	_play_anim(slash_anim, true)

	# Frame windup singkat sebelum capit mengayun (0.28 detik)
	await get_tree().create_timer(0.28).timeout
	if not _is_token_valid(token):
		return

	# Aktifkan hitbox sabetan sabit di depan boss (ke arah player)
	_trigger_slash_hitbox()
	# Tembakkan juga 1 gelombang sabit energi ke arah player saat capit mengayun!
	if player and is_instance_valid(player):
		_spawn_projectile((player.global_position - global_position).angle(), 380.0, "crescent")

	await get_tree().create_timer(0.38).timeout
	if not _is_token_valid(token):
		return

	_choose_next_action()


func _trigger_slash_hitbox() -> void:
	if player == null or not is_instance_valid(player):
		return

	# Titik pusat sabetan mengikuti arah ke player saat capit jatuh, bukan hanya kiri/kanan
	var dir := global_position.direction_to(player.global_position)
	var hit_center := global_position + dir * melee_slash_offset

	if slash_area:
		slash_area.global_position = hit_center
		slash_area.monitoring = true

	if player.global_position.distance_to(hit_center) <= melee_slash_reach:
		_damage_player(melee_damage, 0.5)

	if slash_area:
		get_tree().create_timer(0.18).timeout.connect(func():
			if is_instance_valid(slash_area):
				slash_area.monitoring = false
		)


# ---------- Serangan 2: High-Speed Charge Dash ----------

func _attack_charge() -> void:
	if _is_dying or health <= 0:
		return

	_action_token += 1
	var token := _action_token
	state = State.WINDUP
	velocity = Vector2.ZERO
	_update_facing_to_player()

	var prep_anim: String = "attack_left" if face_left else "attack_right"
	_play_anim(prep_anim, true)

	# Peringatan: berkedip kuning keemasan sebelum menyerbu
	var target_node: Node2D = _get_visual_node()

	if target_node != null:
		var tween := create_tween()
		tween.tween_property(
			target_node,
			"modulate",
			Color(1.0, 0.92, 0.25),
			0.22
		)
		tween.tween_property(
			target_node,
			"modulate",
			Color.WHITE,
			0.22
		)
		await tween.finished
	else:
		await get_tree().create_timer(0.44).timeout

	if not _is_token_valid(token):
		return

	if player and is_instance_valid(player):
		charge_dir = global_position.direction_to(player.global_position)
		face_left = charge_dir.x < 0.0
	else:
		charge_dir = Vector2.DOWN

	_charge_hit_done = false
	state = State.CHARGE
	_play_anim("charge_left" if face_left else "charge_right", true)

	var dash_time := 0.62 if phase == 1 else 0.72
	await get_tree().create_timer(dash_time).timeout
	if not _is_token_valid(token):
		return

	if state == State.CHARGE:
		_stun(0.55)


## Dipanggil tiap frame saat CHARGE. Melukai player sekali per serbuan, lalu boss terpental.
func _check_charge_hit() -> void:
	if _charge_hit_done or player == null or not is_instance_valid(player):
		return

	var touched := false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col and col.get_collider() == player:
			touched = true
			break

	# Cadangan: kalau HitArea/collider tidak sempat bersentuhan, pakai jarak
	if not touched and global_position.distance_to(player.global_position) <= charge_hit_radius:
		touched = true

	if not touched:
		return

	_charge_hit_done = true
	_damage_player(charge_damage, 0.6)

	# Terpental ke belakang supaya tidak menempel pada player
	knockback = -charge_dir * charge_recoil
	_stun(0.55)


func _stun(duration: float) -> void:
	if _is_dying or health <= 0:
		return

	_action_token += 1
	var token := _action_token

	state = State.STUNNED
	velocity = Vector2.ZERO
	_play_anim("hit" if _has_anim("hit") else "idle", true)

	await get_tree().create_timer(duration).timeout
	if _is_token_valid(token):
		_choose_next_action()


# ---------- Serangan 3: Bubble Barrage (Hujan Gelembung Abyssal) ----------

func _attack_bubbles() -> void:
	if _is_dying or health <= 0:
		return

	_action_token += 1
	var token := _action_token

	state = State.SHOOT
	velocity = Vector2.ZERO

	if bubble_scene == null:
		push_warning("Bubble Scene di CrabBoss belum diisi")
		_choose_next_action()
		return

	_play_anim("skill", true)

	var target_node: Node2D = _get_visual_node()
	if target_node:
		var tween := create_tween()
		tween.tween_property(target_node, "scale", _get_phase_scale() * 1.08, 0.18)
		tween.tween_property(target_node, "scale", _get_phase_scale(), 0.18)
		await tween.finished
	else:
		await get_tree().create_timer(0.36).timeout

	if not _is_token_valid(token):
		return

	var duration := barrage_duration * (1.35 if phase == 2 else 1.0)
	var interval_scale := 0.62 if phase == 2 else 1.0
	var elapsed := 0.0

	while elapsed < duration:
		if not _is_token_valid(token):
			return
		if player == null or not is_instance_valid(player):
			break

		_fire_random_bubble()

		var wait := randf_range(fire_interval_min, fire_interval_max) * interval_scale
		await get_tree().create_timer(wait).timeout
		elapsed += wait

	if not _is_token_valid(token):
		return

	await get_tree().create_timer(0.65).timeout
	if _is_token_valid(token):
		_choose_next_action()


func _fire_random_bubble() -> void:
	var origin := mouth.global_position if mouth else global_position
	var angle: float

	if randf() < random_shot_chance:
		angle = randf() * TAU
	else:
		var to_player := (player.global_position - origin).angle()
		angle = to_player + deg_to_rad(randf_range(-aim_jitter_deg, aim_jitter_deg))

	var spd := randf_range(bubble_speed_min, bubble_speed_max)
	# Di Fase 2, selingi gelembung dengan sabit energi merah muda
	var mode := "crescent" if (phase == 2 and randf() < 0.35) else "bubble"
	_spawn_projectile(angle, spd, mode)


# ---------- Serangan 4: Ocean Sovereign Radial Skill (8-Way Crescent Ring) ----------

func _attack_radial_skill() -> void:
	if _is_dying or health <= 0:
		return

	_action_token += 1
	var token := _action_token

	state = State.RADIAL_SKILL
	velocity = Vector2.ZERO

	if bubble_scene == null:
		_choose_next_action()
		return

	_play_anim("skill", true)

	# Efek aura merah muda menyala saat memanggil lingkaran sihir (sesuai referensi 169978.png)
	var target_node: Node2D = _get_visual_node()
	if target_node:
		var tween := create_tween()
		tween.tween_property(target_node, "modulate", Color(1.0, 0.55, 0.75), 0.28)
		tween.tween_property(target_node, "modulate", Color.WHITE, 0.22)
		await tween.finished
	else:
		await get_tree().create_timer(0.5).timeout

	if not _is_token_valid(token):
		return

	var waves := radial_waves_phase_2 if phase == 2 else radial_waves_phase_1
	var base_angle := 0.0
	if player and is_instance_valid(player):
		base_angle = (player.global_position - global_position).angle()

	for w in waves:
		if not _is_token_valid(token):
			return
		var offset_angle := base_angle + (w * (PI / float(radial_blade_count)))
		for i in radial_blade_count:
			var ang := offset_angle + (TAU * float(i) / float(radial_blade_count))
			_spawn_projectile(ang, radial_blade_speed * (1.15 if phase == 2 else 1.0), "crescent")
		await get_tree().create_timer(0.42).timeout

	if not _is_token_valid(token):
		return

	await get_tree().create_timer(0.55).timeout
	if _is_token_valid(token):
		_choose_next_action()


func _spawn_projectile(angle: float, proj_speed: float, mode: String = "bubble") -> void:
	if bubble_scene == null or not is_inside_tree():
		return

	var proj := bubble_scene.instantiate()
	proj.speed = proj_speed
	if "damage" in proj and is_instance_valid(GameState):
		proj.damage = GameState.scale_damage(proj.damage)
	if proj.has_method("set_visual_mode"):
		proj.set_visual_mode(mode)
	elif "visual_mode" in proj:
		proj.visual_mode = mode

	var scene_root := get_tree().current_scene if get_tree().current_scene else get_parent()
	scene_root.add_child(proj)
	proj.global_position = mouth.global_position if mouth else global_position
	proj.global_rotation = angle


# ---------- Damage ke Player ----------

## Satu pintu untuk semua damage boss ke player (kontak, dash, sabetan).
## lock_time = jeda sebelum boss boleh melukai lagi (supaya tidak kena beruntun dalam 1 frame).
func _damage_player(amount: int, lock_time: float) -> bool:
	if player == null or not is_instance_valid(player) or not player.has_method("take_damage"):
		return false
	if _damage_lock > 0.0:
		return false
	# Player yang sedang dash kebal: jangan buang jeda damage
	if player.get("is_dashing") == true:
		return false

	player.take_damage(amount)
	_damage_lock = lock_time
	return true


func _on_hit_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_check_contact_damage()


func _check_contact_damage() -> void:
	if _is_dying or health <= 0 or _damage_lock > 0.0:
		return
	# Dash punya damage sendiri (_check_charge_hit)
	if state == State.CHARGE:
		return

	var touching := false
	if hit_area:
		for body in hit_area.get_overlapping_bodies():
			if body.is_in_group("player"):
				touching = true
				break

	# Cadangan: HitArea yang lebih kecil dari collider boss tidak akan pernah menyentuh player
	if not touching and player and is_instance_valid(player):
		touching = global_position.distance_to(player.global_position) <= contact_radius

	if touching:
		_damage_player(contact_damage, damage_cooldown)


# ---------- Menerima Damage ----------

func take_damage(amount: int) -> void:
	if _is_dying or health <= 0:
		return

	health = maxi(health - amount, 0)
	if health_bar:
		health_bar.value = health
	health_changed.emit(health, max_health)

	if player and is_instance_valid(player) and state == State.SCUTTLE:
		knockback = player.global_position.direction_to(global_position) * (140.0 * knockback_resistance)

	_flash()
	_play_hit_reaction()

	if phase == 1 and health > 0 and health <= int(max_health / 2.0):
		_enter_phase_two()

	if health <= 0:
		die()


func _play_hit_reaction() -> void:
	# Jangan memutus animasi serangan/skill utama, hanya mainkan animasi hurt saat sedang scuttle/idle
	if _is_dying or state not in [State.IDLE, State.SCUTTLE] or not _has_anim("hit"):
		return

	_hit_anim_token += 1
	var token := _hit_anim_token
	_hit_anim_playing = true
	_play_anim("hit", true)

	await get_tree().create_timer(0.28).timeout
	if is_instance_valid(self) and not _is_dying and token == _hit_anim_token:
		_hit_anim_playing = false


func _enter_phase_two() -> void:
	phase = 2
	_phase_tint = Color(
		clampf(_base_self_modulate.r * 1.08, 0.0, 1.0),
		clampf(_base_self_modulate.g * 0.72, 0.0, 1.0),
		clampf(_base_self_modulate.b * 0.78, 0.0, 1.0),
		1.0
	)
	var target_node: Node2D = _get_visual_node()
	if target_node:
		target_node.self_modulate = _phase_tint
		var tween := create_tween()
		tween.tween_property(target_node, "scale", _get_phase_scale(), 0.25)
	if boss_title_label:
		boss_title_label.text = "CRAB PRINCESS  -  OCEAN SOVEREIGN (PHASE 2)"
		boss_title_label.modulate = Color(1.0, 0.55, 0.68)


func _get_phase_scale() -> Vector2:
	return _base_visual_scale * (1.12 if phase == 2 else 1.0)


func _flash() -> void:
	var target_node: Node2D = _get_visual_node()
	if target_node == null:
		return
	target_node.modulate = Color(1.0, 0.35, 0.45)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(self) and target_node and state != State.WINDUP:
		target_node.modulate = Color.WHITE


# ---------- Kematian Boss (Defeat Animation) ----------

func die() -> void:
	if _is_dying:
		return

	_is_dying = true
	_action_token += 1   # Batalkan seluruh coroutine serangan yang sedang menunggu timer
	state = State.DEAD
	velocity = Vector2.ZERO
	knockback = Vector2.ZERO
	_damage_lock = 9999.0   # boss yang sedang kalah tidak boleh melukai player

	# Matikan seluruh collider agar tidak melukai player saat animasi kalah diputar
	if body_collider:
		body_collider.set_deferred("disabled", true)
	if hit_area:
		hit_area.set_deferred("monitoring", false)
	if slash_area:
		slash_area.set_deferred("monitoring", false)

	var target_node: Node2D = _get_visual_node()
	if target_node:
		target_node.modulate = Color.WHITE
		target_node.self_modulate = _base_self_modulate

	if anim and _has_anim("dead"):
		_play_anim("dead", true)
		await get_tree().create_timer(_anim_length("dead") + 0.35).timeout

	if not is_instance_valid(self):
		return

	if is_instance_valid(GameState) and currency_reward > 0:
		GameState.add_currency(currency_reward)

	boss_died.emit()
	if health_bar and health_bar.get_parent():
		health_bar.get_parent().queue_free()
	queue_free()


# Mengambil node visual aktif dengan tipe bersama yang jelas.
# AnimatedSprite2D dan Sprite2D sama-sama turunan Node2D.
func _get_visual_node() -> Node2D:
	if anim != null:
		return anim
	if sprite != null:
		return sprite
	return null


# ---------- Helper Animasi ----------

func _has_anim(anim_name: String) -> bool:
	return anim != null and anim.sprite_frames != null and anim.sprite_frames.has_animation(anim_name)


func _play_anim(anim_name: String, force_restart: bool = false) -> void:
	if not _has_anim(anim_name):
		return
	if force_restart or anim.animation != anim_name or not anim.is_playing():
		anim.play(anim_name)

func _anim_length(anim_name: String) -> float:
	if not _has_anim(anim_name):
		return 0.6
	var frames := anim.sprite_frames
	var fps := frames.get_animation_speed(anim_name)
	if fps <= 0.0:
		return 0.6
	var total := 0.0
	for i in frames.get_frame_count(anim_name):
		total += frames.get_frame_duration(anim_name, i)
	return total / fps
