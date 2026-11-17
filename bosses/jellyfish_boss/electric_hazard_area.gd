extends Area2D

# ============================================================
# ELECTRIC HAZARD AREA
# ============================================================
# Area berbahaya bermuatan listrik yang dihasilkan oleh Jellyfish Boss.
# Digunakan untuk:
#  1. Jejak listrik Jellyfish Merah (trail saat bergerak/rush).
#  2. Zona listrik acak Jellyfish Biru (electric strike / storm).
# ============================================================

@export_group("Hazard Settings")
@export var damage: int = 1
@export var duration: float = 3.5
@export var radius: float = 45.0
@export var tick_interval: float = 0.6
@export var telegraph_time: float = 0.0 # Delay sebelum aktif (muncul indikator bahaya)
@export var hazard_color: Color = Color(0.2, 0.8, 1.0, 0.75) # Warna default (biru/listrik)

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

var is_active: bool = false
var _elapsed_time: float = 0.0
var _tick_timer: float = 0.0
var _anim_time: float = 0.0
var _circle_shape: CircleShape2D
var _targets_inside: Array[Node2D] = []
var _is_fading: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Hanya mendeteksi Player (layer 1)
	monitoring = true

	# Pastikan ada CollisionShape2D dengan CircleShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)

	_circle_shape = CircleShape2D.new()
	_circle_shape.radius = radius
	collision_shape.shape = _circle_shape

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if telegraph_time > 0.0:
		is_active = false
		monitoring = false
	else:
		is_active = true
		monitoring = true


func setup(
	p_radius: float,
	p_damage: int,
	p_duration: float,
	p_color: Color,
	p_telegraph: float = 0.0
) -> void:
	radius = p_radius
	damage = p_damage
	duration = p_duration
	hazard_color = p_color
	telegraph_time = p_telegraph

	if _circle_shape:
		_circle_shape.radius = radius


func _process(delta: float) -> void:
	_anim_time += delta
	queue_redraw()

	if telegraph_time > 0.0:
		telegraph_time -= delta
		if telegraph_time <= 0.0:
			_activate_hazard()
		return

	if not is_active or _is_fading:
		return

	_elapsed_time += delta

	# Ticking damage ke target di dalam area
	_tick_timer += delta
	if _tick_timer >= tick_interval:
		_tick_timer = 0.0
		_deal_tick_damage()

	# Cek habis durasi
	if _elapsed_time >= duration:
		_fade_out_and_free()


func _activate_hazard() -> void:
	is_active = true
	monitoring = true
	# Cek apakah ada player yang sudah berada di dalam area
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and not _targets_inside.has(body):
			_targets_inside.append(body)
	_deal_tick_damage()


func _deal_tick_damage() -> void:
	for body in _targets_inside.duplicate():
		if is_instance_valid(body) and body.has_method("take_damage"):
			body.take_damage(damage)
		else:
			_targets_inside.erase(body)


func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	if body.is_in_group("player") and not _targets_inside.has(body):
		_targets_inside.append(body)
		if body.has_method("take_damage"):
			body.take_damage(damage)


func _on_body_exited(body: Node2D) -> void:
	_targets_inside.erase(body)


func _fade_out_and_free() -> void:
	if _is_fading:
		return
	_is_fading = true
	monitoring = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


func _draw() -> void:
	# Jika masih tahap telegraph (peringatan)
	if telegraph_time > 0.0:
		var pulse: float = 0.4 + 0.35 * sin(_anim_time * 14.0)
		var warn_color := Color(hazard_color.r, hazard_color.g, hazard_color.b, pulse * 0.5)
		draw_circle(Vector2.ZERO, radius, warn_color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(hazard_color.r, hazard_color.g, hazard_color.b, 0.9), 2.5)
		return

	# Area aktif (medan listrik dan sambaran percikan petir)
	var pulse_active: float = 0.25 + 0.12 * sin(_anim_time * 9.0)
	var fill_color := Color(hazard_color.r, hazard_color.g, hazard_color.b, pulse_active)
	draw_circle(Vector2.ZERO, radius, fill_color)

	# Lingkaran batas luar
	var border_color := Color(hazard_color.r, hazard_color.g, hazard_color.b, 0.8)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, border_color, 2.0)

	# Efek percikan busur listrik di dalam radius
	var spark_count := 4
	for i in range(spark_count):
		var angle_seed := (i * (TAU / spark_count)) + (_anim_time * 4.0)
		var r_dist := radius * (0.3 + 0.6 * absf(sin(_anim_time * 6.0 + i)))
		var spark_pt := Vector2(cos(angle_seed), sin(angle_seed)) * r_dist
		var spark_end := spark_pt + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		draw_line(spark_pt, spark_end, Color(1.0, 1.0, 1.0, 0.85), 1.5)
