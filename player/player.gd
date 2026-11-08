extends CharacterBody2D

signal health_changed(new_health: int)
signal died

const FACING_HYSTERESIS := 0.15   # toleransi supaya arah hadap tidak berganti-ganti di sudut diagonal

@export var speed: float = 250.0
@export var acceleration: float = 1800.0
@export var friction: float = 1400.0
@export var max_health: int = 5

@export_group("Dash")
@export var dash_speed: float = 700.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.6

@export_group("Weapon")
@export var weapon_scene: PackedScene
@export var weapon_offset: Vector2 = Vector2(24, 0)

@export_group("Backpedal")
@export_range(0.1, 1.0, 0.05) var backpedal_speed_multiplier: float = 0.55   # kecepatan saat jalan lurus ke belakang
@export var slow_only_while_shooting: bool = false                            # true = melambat hanya saat menembak
@export var reverse_walk_anim_when_backpedal: bool = true                     # animasi jalan diputar terbalik saat mundur

@export_group("Animation")
@export var death_pause: float = 0.6   # lama player tergeletak di lantai sebelum died dipancarkan (detik)

@export_group("Damage")
@export_range(0.0, 5.0, 0.05) var hit_immunity_duration: float = 1.0 # kebal damage setelah terkena hit (detik)

@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown_timer: Timer = $DashCooldown
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# SFX (buat node AudioStreamPlayer di dalam SFX)
@onready var walk_sfx: AudioStreamPlayer = get_node_or_null("SFX/Walk") as AudioStreamPlayer
@onready var dash_sfx: AudioStreamPlayer = get_node_or_null("SFX/Dash") as AudioStreamPlayer
@onready var hit_sfx: AudioStreamPlayer = get_node_or_null("SFX/Hit") as AudioStreamPlayer

var health: int
var base_max_health: int
var base_dash_cooldown: float
var weapon: Node2D = null
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var aim_dir: Vector2 = Vector2.DOWN      # arah dari player ke mouse
var facing_dir: Vector2 = Vector2.DOWN   # arah hadap sprite (4 arah), mengikuti bidikan

var _anim_backwards: bool = false
var _hit_lock: bool = false              # animasi hit sedang diputar
var _hit_token: int = 0
var _damage_immune: bool = false         # true selama player mendapat invulnerability frame
var _immunity_token: int = 0
var _is_dead: bool = false


func _ready() -> void:
	base_max_health = max_health
	base_dash_cooldown = dash_cooldown
	_apply_upgrades(true)
	add_to_group("player")

	if is_instance_valid(GameState) and not GameState.upgrade_purchased.is_connected(_on_upgrade_purchased):
		GameState.upgrade_purchased.connect(_on_upgrade_purchased)

	dash_timer.wait_time = dash_duration
	dash_timer.one_shot = true
	dash_timer.timeout.connect(_on_dash_finished)

	dash_cooldown_timer.wait_time = dash_cooldown
	dash_cooldown_timer.one_shot = true

	_configure_animation_loops()
	if not _has_anim("immune"):
		push_warning("Animasi 'immune' tidak ditemukan di AnimatedSprite2D > SpriteFrames.")
	_equip_weapon(weapon_scene)


func _apply_upgrades(reset_hp: bool = false) -> void:
	if is_instance_valid(GameState):
		max_health = base_max_health + GameState.get_max_health_bonus()
		dash_cooldown = base_dash_cooldown * GameState.get_dash_cooldown_multiplier()
	if reset_hp:
		health = max_health
	else:
		health = mini(health + 1, max_health)
	if dash_cooldown_timer:
		dash_cooldown_timer.wait_time = dash_cooldown
	health_changed.emit(health)


func _on_upgrade_purchased(_upgrade_id: String, _new_level: int) -> void:
	_apply_upgrades(true)


## Animasi sekali jalan (dash, hit, dead) tidak boleh looping; yang lain looping.
func _configure_animation_loops() -> void:
	if anim == null or anim.sprite_frames == null:
		return

	var frames := anim.sprite_frames
	for anim_name in frames.get_animation_names():
		var n := String(anim_name)
		var one_shot := n.begins_with("hit") or n.begins_with("dash") or n == "dead"
		# Animasi immune harus looping selama durasi kebal.
		if n == "immune":
			one_shot = false
		frames.set_animation_loop(anim_name, not one_shot)


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	_update_aim()

	if is_dashing:
		velocity = dash_direction * dash_speed
	else:
		_handle_movement(delta)

		if Input.is_action_just_pressed("dash"):
			_start_dash()

	move_and_slide()
	_update_walk_sfx()

	_aim_weapon()
	_update_animation()

	if Input.is_action_pressed("shoot") and weapon and not is_dashing:
		weapon.shoot()


# ---------- Bidikan ----------

func _update_aim() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		aim_dir = to_mouse.normalized()

	# Arah hadap 4 arah mengikuti bidikan, dengan hysteresis di sudut diagonal
	var want_horizontal: bool
	if facing_dir.x != 0.0:
		want_horizontal = not (absf(aim_dir.y) > absf(aim_dir.x) + FACING_HYSTERESIS)
	else:
		want_horizontal = absf(aim_dir.x) > absf(aim_dir.y) + FACING_HYSTERESIS

	if want_horizontal:
		facing_dir = Vector2.RIGHT if aim_dir.x >= 0.0 else Vector2.LEFT
	else:
		facing_dir = Vector2.DOWN if aim_dir.y >= 0.0 else Vector2.UP


func _aim_weapon() -> void:
	# Dihitung ulang setelah move_and_slide() supaya laras tepat di posisi player terbaru
	var angle := (get_global_mouse_position() - global_position).angle()
	weapon_pivot.rotation = angle

	# Flip supaya senjata tidak terbalik saat mengarah ke kiri
	weapon_pivot.scale.y = -1.0 if absf(angle) > PI / 2.0 else 1.0


# ---------- Senjata ----------

func _equip_weapon(scene: PackedScene) -> void:
	# Hapus senjata lama kalau ada (berguna kalau nanti mau ganti senjata)
	if weapon:
		weapon.queue_free()
		weapon = null

	if scene == null:
		return

	weapon = scene.instantiate()
	weapon.position = weapon_offset
	weapon_pivot.add_child(weapon)


# ---------- Gerakan ----------

func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir != Vector2.ZERO:
		var target_speed := speed * _get_backpedal_factor(input_dir)
		velocity = velocity.move_toward(input_dir * target_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


## 1.0 = kecepatan normal, mengecil sampai backpedal_speed_multiplier saat bergerak
## lurus berlawanan dengan arah bidik. Gerak menyamping tetap kecepatan normal.
func _get_backpedal_factor(input_dir: Vector2) -> float:
	if slow_only_while_shooting and not Input.is_action_pressed("shoot"):
		return 1.0

	var dot := input_dir.normalized().dot(aim_dir)   # 1 = searah bidikan, -1 = berlawanan
	var backward_amount := clampf(-dot, 0.0, 1.0)
	return lerpf(1.0, backpedal_speed_multiplier, backward_amount)


func _update_walk_sfx() -> void:
	if walk_sfx == null:
		return

	var should_play := velocity.length() >= 10.0 and not is_dashing and not _hit_lock and not _is_dead
	if should_play:
		if not walk_sfx.playing:
			walk_sfx.play()
	else:
		_stop_walk_sfx()


func _stop_walk_sfx() -> void:
	if walk_sfx != null and walk_sfx.playing:
		walk_sfx.stop()


# ---------- Dash ----------

func _start_dash() -> void:
	if not dash_cooldown_timer.is_stopped():
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir == Vector2.ZERO:
		dash_direction = aim_dir
	else:
		dash_direction = input_dir.normalized()

	is_dashing = true
	_stop_walk_sfx()
	if dash_sfx != null:
		dash_sfx.play()
	dash_timer.start()
	dash_cooldown_timer.start()

	# Dash membatalkan animasi hit yang sedang berjalan
	_hit_token += 1
	_hit_lock = false
	_play_dash_anim()


func _on_dash_finished() -> void:
	is_dashing = false


func _play_dash_anim() -> void:
	# Animasi dash mengikuti arah GERAK, bukan arah bidik
	var dash_anim := _dir_anim("dash", _to_cardinal(dash_direction))
	if dash_anim == "":
		return

	# Percepat/perlambat animasi supaya semua frame muat dalam durasi dash
	var scale_factor := 1.0
	if dash_duration > 0.0:
		scale_factor = _anim_length(dash_anim) / dash_duration
	_play_anim(dash_anim, false, scale_factor, true)


# ---------- Animasi ----------

func _update_animation() -> void:
	# Dash, hit, dan mati memiliki prioritas animasi sendiri.
	if _is_dead or is_dashing or _hit_lock:
		return

	# Setelah animasi hit selesai, tampilkan animasi immune selama I-frame aktif.
	# Animasi "immune" sebaiknya diatur Loop agar efeknya terus berjalan
	# sampai durasi immunity berakhir.
	if _damage_immune and _has_anim("immune"):
		_play_anim("immune")
		return

	# Diam: pakai animasi idle
	if velocity.length() < 10.0:
		_play_idle()
		return

	# Bergerak: animasi mengikuti arah hadap (arah bidik), bukan arah jalan
	var backwards := false
	if reverse_walk_anim_when_backpedal:
		backwards = velocity.normalized().dot(aim_dir) < -0.5

	var walk_anim := _walk_anim_name(_dir_name(facing_dir))
	if walk_anim != "":
		_play_anim(walk_anim, backwards)


func _play_idle() -> void:
	var directional := "idle_" + _dir_name(facing_dir)

	# Pakai idle per arah kalau ada, kalau tidak pakai "idle" biasa
	if _has_anim(directional):
		_play_anim(directional)
	elif _has_anim("idle"):
		_play_anim("idle")


## Nama animasi jalan: "walk_down" (sheet baru) atau "down" (nama lama)
func _walk_anim_name(dir_name: String) -> String:
	if _has_anim("walk_" + dir_name):
		return "walk_" + dir_name
	if _has_anim(dir_name):
		return dir_name
	return ""


## Cari animasi "<prefix>_<arah>", cadangan "<prefix>" saja. Kosong kalau tidak ada.
func _dir_anim(prefix: String, dir: Vector2) -> String:
	var directional := prefix + "_" + _dir_name(dir)
	if _has_anim(directional):
		return directional
	if _has_anim(prefix):
		return prefix
	return ""


func _dir_name(dir: Vector2) -> String:
	if dir == Vector2.UP:
		return "up"
	if dir == Vector2.DOWN:
		return "down"
	if dir == Vector2.LEFT:
		return "left"
	return "right"


## Ubah vektor bebas menjadi 4 arah mata angin
func _to_cardinal(dir: Vector2) -> Vector2:
	if absf(dir.x) >= absf(dir.y):
		return Vector2.RIGHT if dir.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if dir.y >= 0.0 else Vector2.UP


func _has_anim(anim_name: String) -> bool:
	return anim != null and anim.sprite_frames != null and anim.sprite_frames.has_animation(anim_name)


func _anim_length(anim_name: String) -> float:
	if not _has_anim(anim_name):
		return 0.4
	var frames := anim.sprite_frames
	var fps := frames.get_animation_speed(anim_name)
	if fps <= 0.0:
		return 0.4
	var total := 0.0
	for i in frames.get_frame_count(anim_name):
		total += frames.get_frame_duration(anim_name, i)
	return total / fps


func _play_anim(anim_name: String, backwards: bool = false, speed_factor: float = 1.0, force_restart: bool = false) -> void:
	if not _has_anim(anim_name):
		return

	# Jangan mulai ulang animasi yang sedang berjalan dengan arah putar yang sama
	if not force_restart and anim.animation == anim_name and anim.is_playing() and _anim_backwards == backwards:
		return

	_anim_backwards = backwards
	anim.speed_scale = speed_factor
	if backwards:
		anim.play_backwards(anim_name)
	else:
		anim.play(anim_name)


# ---------- Damage ----------

func take_damage(amount: int) -> void:
	# Abaikan damage jika sedang dash, kebal, mati, atau nilai damage tidak valid.
	if amount <= 0 or is_dashing or _damage_immune or health <= 0 or _is_dead:
		return

	# Aktifkan invulnerability frame segera setelah menerima satu hit.
	_damage_immune = true
	_immunity_token += 1
	_start_damage_immunity(_immunity_token)

	health -= amount
	if hit_sfx != null:
		hit_sfx.play()
	health_changed.emit(health)

	if health <= 0:
		_die()
	else:
		_play_hit_anim()


func _start_damage_immunity(token: int) -> void:
	await get_tree().create_timer(hit_immunity_duration).timeout

	# Pastikan node masih ada dan timer ini masih merupakan timer yang berlaku.
	if not is_instance_valid(self):
		return

	if token == _immunity_token and not _is_dead:
		_damage_immune = false


func _play_hit_anim() -> void:
	var hit_anim := _dir_anim("hit", facing_dir)
	if hit_anim == "":
		return

	_hit_token += 1
	var token := _hit_token
	_hit_lock = true
	_play_anim(hit_anim, false, 1.0, true)

	await get_tree().create_timer(_anim_length(hit_anim)).timeout

	# Abaikan kalau sudah ada hit baru, dash, atau player sudah mati
	if is_instance_valid(self) and not _is_dead and token == _hit_token:
		_hit_lock = false


func _die() -> void:
	_is_dead = true
	_stop_walk_sfx()
	is_dashing = false
	_hit_lock = false
	velocity = Vector2.ZERO
	dash_timer.stop()

	# Senjata disembunyikan dan tubuh tidak lagi menghalangi / terkena apa pun
	if weapon_pivot:
		weapon_pivot.visible = false
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)

	if _has_anim("dead"):
		_play_anim("dead", false, 1.0, true)
		await get_tree().create_timer(_anim_length("dead") + death_pause).timeout
	else:
		await get_tree().create_timer(death_pause).timeout

	if not is_instance_valid(self):
		return

	var has_stage_listener := died.get_connections().size() > 0
	died.emit()
	if not has_stage_listener:
		StageManager.return_to_lobby()
	queue_free()
