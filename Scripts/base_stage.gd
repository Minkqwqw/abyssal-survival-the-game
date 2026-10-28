extends Node2D

@export_range(1, 3) var stage_id: int = 1
@export var stage_title: String = "Stage 1: Toxic Shallows"
@export var background_color: Color = Color(0.04, 0.09, 0.07, 1.0)
@export var arena_floor_color: Color = Color(0.08, 0.17, 0.14, 1.0)
@export var border_color: Color = Color(0.25, 0.75, 0.5, 1.0)

@onready var background: ColorRect = $Background
@onready var arena_floor: ColorRect = $ArenaFloor
@onready var bounds_outline: Line2D = $MapBounds/BoundsOutline
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var exit_portal: Area2D = $ExitPortal
@onready var player: CharacterBody2D = $Player
@onready var stage_label: Label = $StageHUD/StageTitleLabel
@onready var health_label: Label = $StageHUD/HealthLabel


func _ready() -> void:
	StageManager.current_stage_id = stage_id

	if background:
		background.color = background_color
	if arena_floor:
		arena_floor.color = arena_floor_color
	if bounds_outline:
		bounds_outline.default_color = border_color

	if exit_portal:
		exit_portal.portal_mode = exit_portal.PortalMode.STAGE_EXIT
		exit_portal.target_stage_id = stage_id
		exit_portal._update_visuals()

	if player:
		if spawn_point:
			player.global_position = spawn_point.global_position
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)
		_on_player_health_changed(player.health)

	if stage_label:
		stage_label.text = stage_title if stage_title != "" else StageManager.get_stage_title(stage_id)


func _on_player_health_changed(new_health: int) -> void:
	if health_label and player:
		health_label.text = "HP: %d / %d" % [maxi(new_health, 0), player.max_health]


func _on_player_died() -> void:
	StageManager.return_to_lobby()
