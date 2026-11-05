extends Node2D

@export_range(1, 5) var stage_id: int = 1
@export var stage_title: String = "Stage 1: Toxic Shallows"
@export var background_color: Color = Color(0.04, 0.09, 0.07, 1.0)
@export var arena_floor_color: Color = Color(0.08, 0.17, 0.14, 1.0)
@export var border_color: Color = Color(0.25, 0.75, 0.5, 1.0)
@export var boss_scene: PackedScene
@export var boss_spawn_point: Marker2D

@onready var background: ColorRect = get_node_or_null("Background")
@onready var arena_floor: ColorRect = get_node_or_null("ArenaFloor")
@onready var bounds_outline: Line2D = get_node_or_null("MapBounds/BoundsOutline")
@onready var spawn_point: Marker2D = get_node_or_null("SpawnPoint")
@onready var exit_portal: Area2D = get_node_or_null("ExitPortal")
@onready var player: CharacterBody2D = get_node_or_null("Player")
@onready var stage_label: Label = get_node_or_null("StageHUD/StageTitleLabel")
@onready var health_label: Label = get_node_or_null("StageHUD/HealthLabel")
@onready var objective_label: Label = get_node_or_null("StageHUD/ObjectiveLabel")

const STAGE_CLEAR_UI_PATH: String = "res://ui/stage_clear/stage_clear.tscn"
const BOSS_4_PATH: String = "res://bosses/boss_4/boss_4.tscn"
const BOSS_5_PATH: String = "res://bosses/boss_5/boss_5.tscn"

var boss_spawned: bool = false
var player_dead: bool = false


func _ready() -> void:
	StageManager.current_stage_id = stage_id
	var active_level: int = StageManager.current_level_id if is_instance_valid(StageManager) else 1

	var floor_res: Resource = StageManager.get_floor_data(active_level) if is_instance_valid(StageManager) else null
	if floor_res and active_level >= 4:
		background_color = floor_res.get("background_color")
		arena_floor_color = floor_res.get("arena_floor_color")
		border_color = floor_res.get("border_color")
		if stage_id == StageManager.TOTAL_STAGES:
			if active_level == 4 and ResourceLoader.exists(BOSS_4_PATH):
				boss_scene = load(BOSS_4_PATH)
			elif active_level == 5 and ResourceLoader.exists(BOSS_5_PATH):
				boss_scene = load(BOSS_5_PATH)

	if background:
		background.color = background_color
	if arena_floor:
		arena_floor.color = arena_floor_color
	if bounds_outline:
		bounds_outline.default_color = border_color

	if exit_portal:
		exit_portal.portal_mode = exit_portal.PortalMode.STAGE_EXIT
		exit_portal.target_stage_id = stage_id
		if exit_portal.has_method("set_exit_unlocked"):
			exit_portal.set_exit_unlocked(false)
		else:
			exit_portal._update_visuals()

	if objective_label:
		objective_label.text = "Defeat all enemies in the area!"

	if player:
		if spawn_point:
			player.global_position = spawn_point.global_position
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)
		_on_player_health_changed(player.health)

	if stage_label:
		var lvl_title := StageManager.get_level_title(active_level) if is_instance_valid(StageManager) else ("Level %d" % active_level)
		stage_label.text = "%s  —  Stage %d / %d" % [lvl_title, stage_id, StageManager.TOTAL_STAGES]

	var spawner := get_node_or_null("EnemySpawner")
	if spawner:
		if active_level > 1 and "enemy_count" in spawner:
			spawner.enemy_count += (active_level - 1) * 3
		if active_level > 1 and "max_enemies" in spawner:
			spawner.max_enemies += (active_level - 1) * 3
		spawner.stage_cleared.connect(_on_waves_cleared)
	else:
		_on_waves_cleared()


func _on_waves_cleared() -> void:
	if player_dead or not is_inside_tree():
		return

	if boss_scene != null:
		_spawn_boss()
	else:
		_unlock_exit_portal()


func _spawn_boss() -> void:
	if boss_spawned or player_dead or not is_inside_tree():
		return

	if boss_scene == null:
		_unlock_exit_portal()
		return

	boss_spawned = true

	if objective_label:
		objective_label.text = "WARNING: Defeat the Boss!"
		objective_label.modulate = Color(1.0, 0.55, 0.45)

	var boss := boss_scene.instantiate()
	add_child(boss)

	if boss_spawn_point:
		boss.global_position = boss_spawn_point.global_position
	elif spawn_point:
		boss.global_position = spawn_point.global_position + Vector2(0, -400)
	else:
		boss.global_position = Vector2(0, -200)

	if boss.has_signal("boss_died"):
		boss.boss_died.connect(_on_boss_died)


func _on_boss_died() -> void:
	if is_instance_valid(GameState):
		var lvl_mult: int = maxi(1, StageManager.current_level_id if is_instance_valid(StageManager) else 1)
		GameState.add_currency(15 * stage_id * lvl_mult)
	_unlock_exit_portal()


func _unlock_exit_portal() -> void:
	if exit_portal and exit_portal.has_method("set_exit_unlocked"):
		exit_portal.set_exit_unlocked(true)

	if objective_label:
		if stage_id < StageManager.TOTAL_STAGES:
			objective_label.text = "Stage Cleared! Enter north EXIT PORTAL [E] to Stage %d" % (stage_id + 1)
		else:
			objective_label.text = "Level Complete! Enter north EXIT PORTAL [E] to Return to Lobby"
		objective_label.modulate = Color(0.55, 1.0, 0.8)

	if ResourceLoader.exists(STAGE_CLEAR_UI_PATH):
		var clear_scene := load(STAGE_CLEAR_UI_PATH) as PackedScene
		if clear_scene:
			var clear_ui := clear_scene.instantiate()
			add_child(clear_ui)


func _on_player_health_changed(new_health: int) -> void:
	if health_label and player:
		var coins := GameState.currency if is_instance_valid(GameState) else 0
		health_label.text = "HP: %d / %d   |   Pearls: %d" % [maxi(new_health, 0), player.max_health, coins]


func _on_player_died() -> void:
	if player_dead:
		return
	player_dead = true
	StageManager.return_to_lobby()
