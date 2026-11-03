extends Node2D

@export_range(1, 3) var stage_id: int = 1
@export var stage_title: String = "Stage 1: Toxic Shallows"
@export var background_color: Color = Color(0.04, 0.09, 0.07, 1.0)
@export var arena_floor_color: Color = Color(0.08, 0.17, 0.14, 1.0)
@export var border_color: Color = Color(0.25, 0.75, 0.5, 1.0)
@export var boss_scene: PackedScene
@export var boss_spawn_point: Marker2D

@onready var background: ColorRect = $Background
@onready var arena_floor: ColorRect = $ArenaFloor
@onready var bounds_outline: Line2D = $MapBounds/BoundsOutline
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var exit_portal: Area2D = $ExitPortal
@onready var player: CharacterBody2D = $Player
@onready var stage_label: Label = $StageHUD/StageTitleLabel
@onready var health_label: Label = $StageHUD/HealthLabel

var boss_spawned: bool = false
var player_dead: bool = false


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

	var spawner := get_node_or_null("EnemySpawner")
	if spawner:
		spawner.stage_cleared.connect(_spawn_boss)


func _spawn_boss() -> void:
	# Pengaman: jangan spawn dua kali, jangan spawn saat scene sedang dihapus
	# atau saat player sudah mati
	if boss_spawned or player_dead or not is_inside_tree():
		return

	if boss_scene == null:
		push_warning("Boss Scene di base_stage belum diisi")
		return

	boss_spawned = true

	var boss := boss_scene.instantiate()
	add_child(boss)

	if boss_spawn_point:
		boss.global_position = boss_spawn_point.global_position
	else:
		# Fallback kalau Marker2D belum diisi: muncul di seberang titik spawn player
		boss.global_position = spawn_point.global_position + Vector2(0, -400)
		push_warning("Boss Spawn Point belum diisi, memakai posisi cadangan")

	boss.boss_died.connect(_on_boss_died)


func _on_boss_died() -> void:
	print("Boss kalah! %s selesai" % stage_title)
	# Di sini nanti bisa mengaktifkan ExitPortal, memunculkan UI "Stage Clear", dll.


func _on_player_health_changed(new_health: int) -> void:
	if health_label and player:
		health_label.text = "HP: %d / %d" % [maxi(new_health, 0), player.max_health]


func _on_player_died() -> void:
	player_dead = true
	StageManager.return_to_lobby()
