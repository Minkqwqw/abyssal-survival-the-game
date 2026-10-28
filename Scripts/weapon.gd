extends Node2D

@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.15
@export var spread_degrees: float = 0.0   # isi mis. 5.0 untuk peluru agak menyebar

@onready var muzzle: Marker2D = $Muzzle

var can_shoot: bool = true


func shoot() -> void:
	if not can_shoot or bullet_scene == null:
		return

	can_shoot = false

	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.global_rotation = muzzle.global_rotation + deg_to_rad(randf_range(-spread_degrees, spread_degrees))

	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true
