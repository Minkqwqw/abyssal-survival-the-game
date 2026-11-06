extends Area2D

@export var speed: float = 300.0
@export var lifetime: float = 4.0
@export var damage: int = 1
@export var visual_mode: String = "bubble"   # "bubble" atau "crescent"

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")


func _ready() -> void:
	# Pastikan peluru boss dapat mendeteksi Player (layer 1) dan dinding (layer 1)
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

	if anim_sprite and anim_sprite.sprite_frames:
		var anim_name := visual_mode if anim_sprite.sprite_frames.has_animation(visual_mode) else "bubble"
		anim_sprite.play(anim_name)
		if sprite:
			sprite.visible = false


func set_visual_mode(mode: String) -> void:
	visual_mode = mode
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(mode):
		anim_sprite.play(mode)


func _physics_process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("boss"):
		return

	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
		return

	# Hancur saat menabrak dinding arena (StaticBody2D)
	if body is StaticBody2D:
		queue_free()
