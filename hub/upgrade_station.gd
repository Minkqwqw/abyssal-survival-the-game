extends Area2D

@export var upgrade_menu_scene: PackedScene = preload("res://ui/upgrade_menu/upgrade_menu.tscn")

@onready var prompt_label: Label = get_node_or_null("PromptLabel")

var _player_inside: bool = false
var _active_menu: Node = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt_label:
		prompt_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return

	if event.is_action_pressed("interact"):
		if _active_menu and is_instance_valid(_active_menu):
			_active_menu.queue_free()
			_active_menu = null
		elif upgrade_menu_scene:
			_active_menu = upgrade_menu_scene.instantiate()
			get_tree().current_scene.add_child(_active_menu)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		if prompt_label:
			prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		if prompt_label:
			prompt_label.visible = false
		if _active_menu and is_instance_valid(_active_menu):
			_active_menu.queue_free()
			_active_menu = null
