class_name BaseStage
extends Node2D

signal arena_entered

const VIEWBOX_LEFT: int = -1101
const VIEWBOX_RIGHT: int = 1101
const VIEWBOX_TOP: int = -614
const VIEWBOX_BOTTOM: int = 614

@export_range(1, 5) var level_id_override: int = 0
@export_range(1, 3) var stage_id: int = 1
@export var stage_title: String = "Stage 1: Toxic Shallows"
@export var background_color: Color = Color(0.03, 0.07, 0.06, 1.0)
@export var arena_floor_color: Color = Color(0.07, 0.15, 0.13, 1.0)
@export var border_color: Color = Color(0.25, 0.78, 0.48, 1.0)
@export var map_texture: Texture2D
@export var map_shader_material: Material
@export var boss_scene: PackedScene
@export var boss_spawn_point: Marker2D

@export_group("Trigger Line")
@export var trigger_line_y: float = 0.0
@export var show_trigger_line_visual: bool = true

@export_group("Background Music")
@export var floor_1_bgm: AudioStream

@onready var stage_bgm: AudioStreamPlayer = get_node_or_null("StageBGM") as AudioStreamPlayer
@onready var background: ColorRect = get_node_or_null("Background")
@onready var arena_floor: ColorRect = get_node_or_null("ArenaFloor")
@onready var map_sprite: Sprite2D = get_node_or_null("MapEnvironment/MapSprite")
@onready var shader_overlay: ColorRect = get_node_or_null("MapEnvironment/FloorShaderOverlay")
@onready var custom_props: Node2D = get_node_or_null("MapEnvironment/CustomAssetsContainer")
@onready var bounds_outline: Line2D = get_node_or_null("MapBounds/BoundsOutline")
@onready var spawn_point: Marker2D = get_node_or_null("SpawnPoint")
@onready var exit_portal: Area2D = get_node_or_null("ExitPortal")
@onready var player: CharacterBody2D = get_node_or_null("Player")
@onready var stage_label: Label = get_node_or_null("StageHUD/StageTitleLabel")
@onready var health_label: Label = get_node_or_null("StageHUD/HealthLabel")
@onready var objective_label: Label = get_node_or_null("StageHUD/ObjectiveLabel")

const STAGE_CLEAR_UI_PATH: String = "res://ui/stage_clear/stage_clear.tscn"
const BOSS_1_PATH: String = "res://bosses/crab_boss/crab_boss.tscn"
const BOSS_3_PATH: String = "res://bosses/boss_3/boss_3.tscn"
const BOSS_4_PATH: String = "res://bosses/boss_4/boss_4.tscn"
const BOSS_5_PATH: String = "res://bosses/boss_5/boss_5.tscn"

var boss_spawned: bool = false
var player_dead: bool = false
var combat_active: bool = false
var _trigger_neck_x: float = 96.0
var _trigger_line_node: Line2D = null


func _ready() -> void:
	if is_instance_valid(StageManager):
		StageManager.current_stage_id = stage_id
		if level_id_override >= 1 and level_id_override <= StageManager.TOTAL_LEVELS:
			StageManager.current_level_id = level_id_override

	var active_level: int = level_id_override if level_id_override > 0 else (StageManager.current_level_id if is_instance_valid(StageManager) else 1)

	# Atur BGM berdasarkan level
	_setup_stage_bgm(active_level)

	var floor_res: Resource = StageManager.get_floor_data(active_level) if is_instance_valid(StageManager) else null
	if floor_res:
		background_color = floor_res.get("background_color")
		arena_floor_color = floor_res.get("arena_floor_color")
		border_color = floor_res.get("border_color")

	# Load map texture sesuai (Level, Stage) jika belum di-assign secara eksplisit
	if map_texture == null:
		var auto_tex_path := "res://Assets/environments/maps/level_%d_stage_%d.png" % [active_level, stage_id]
		if ResourceLoader.exists(auto_tex_path):
			map_texture = load(auto_tex_path)

	if map_sprite and map_texture:
		map_sprite.texture = map_texture
		map_sprite.visible = true
		if arena_floor:
			arena_floor.visible = false
	if map_sprite and map_shader_material:
		map_sprite.material = map_shader_material
	if shader_overlay and map_shader_material:
		shader_overlay.material = map_shader_material

	# ATURAN KETAT: BOS HANYA MUNCUL PADA STAGE 3 (Stage 1 & Stage 2 bebas bos)
	if stage_id == StageManager.TOTAL_STAGES:
		if boss_scene == null:
			if active_level in [1, 2] and ResourceLoader.exists(BOSS_1_PATH):
				boss_scene = load(BOSS_1_PATH)
			elif active_level == 3 and ResourceLoader.exists(BOSS_3_PATH):
				boss_scene = load(BOSS_3_PATH)
			elif active_level == 4 and ResourceLoader.exists(BOSS_4_PATH):
				boss_scene = load(BOSS_4_PATH)
			elif active_level == 5 and ResourceLoader.exists(BOSS_5_PATH):
				boss_scene = load(BOSS_5_PATH)
	else:
		boss_scene = null

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
		_configure_player_camera()
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)
		_on_player_health_changed(player.health)

	if stage_label:
		var lvl_title := StageManager.get_level_title(active_level) if is_instance_valid(StageManager) else ("Level %d" % active_level)
		var diff_name: String = GameState.get_difficulty_name() if is_instance_valid(GameState) else "NORMAL"
		stage_label.text = "%s  —  Stage %d / %d  [%s]" % [lvl_title, stage_id, StageManager.TOTAL_STAGES, diff_name]

	var spawner := get_node_or_null("EnemySpawner")
	if spawner:
		if active_level > 1 and "enemy_count" in spawner:
			spawner.enemy_count += (active_level - 1) * 3
		if active_level > 1 and "max_enemies" in spawner:
			spawner.max_enemies += (active_level - 1) * 3
		if is_instance_valid(GameState) and "enemy_count" in spawner:
			spawner.enemy_count = GameState.scale_enemy_count(spawner.enemy_count)
		spawner.stage_cleared.connect(_on_waves_cleared)
	else:
		_on_waves_cleared()

	_setup_trigger_line()


func _physics_process(_delta: float) -> void:
	if not combat_active and player and is_instance_valid(player):
		if player.global_position.y <= trigger_line_y:
			start_combat()


func is_player_in_safe_zone() -> bool:
	if combat_active or player == null or not is_instance_valid(player):
		return false
	return player.global_position.y > trigger_line_y


func start_combat() -> void:
	if combat_active:
		return
	combat_active = true
	arena_entered.emit()

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and enemy.has_method("aggro"):
			enemy.aggro()

	if _trigger_line_node and is_instance_valid(_trigger_line_node):
		var tween := create_tween()
		tween.tween_property(_trigger_line_node, "modulate:a", 0.0, 0.4)
		tween.tween_callback(_trigger_line_node.queue_free)


func _setup_trigger_line() -> void:
	if spawn_point == null:
		combat_active = true
		return

	if is_zero_approx(trigger_line_y):
		var found_opening := false
		var collider := get_node_or_null("MapBounds/WallColliderRight") as CollisionPolygon2D
		if collider and collider.polygon.size() > 0:
			var min_y := 9999.0
			var found_x := 96.0
			for pt in collider.polygon:
				if pt.x >= 40.0 and pt.x <= 180.0 and pt.y > 250.0 and pt.y < spawn_point.position.y:
					if pt.y < min_y:
						min_y = pt.y
						found_x = pt.x
			if min_y < 9000.0:
				trigger_line_y = min_y
				_trigger_neck_x = found_x
				found_opening = true

		if not found_opening:
			trigger_line_y = spawn_point.position.y - 60.0
			_trigger_neck_x = 96.0

	if show_trigger_line_visual:
		_create_trigger_line_visual()


func _create_trigger_line_visual() -> void:
	if _trigger_line_node != null or combat_active:
		return
	_trigger_line_node = Line2D.new()
	_trigger_line_node.name = "TriggerLineVisual"
	_trigger_line_node.width = 4.0
	_trigger_line_node.default_color = Color(1.0, 0.82, 0.25, 0.85)
	var half_w := _trigger_neck_x + 10.0
	_trigger_line_node.points = PackedVector2Array([
		Vector2(-half_w, trigger_line_y),
		Vector2(half_w, trigger_line_y)
	])
	_trigger_line_node.z_index = 10
	add_child(_trigger_line_node)


func _configure_player_camera() -> void:
	if not player:
		return
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam:
		cam.limit_left = VIEWBOX_LEFT
		cam.limit_right = VIEWBOX_RIGHT
		cam.limit_top = VIEWBOX_TOP
		cam.limit_bottom = VIEWBOX_BOTTOM
		cam.limit_smoothed = true
		cam.position_smoothing_enabled = true


func _on_waves_cleared() -> void:
	if player_dead or not is_inside_tree():
		return

	# Bos HANYA muncul di Stage 3
	if stage_id == StageManager.TOTAL_STAGES and boss_scene != null:
		_spawn_boss()
	else:
		_unlock_exit_portal()


func _spawn_boss() -> void:
	if boss_spawned or player_dead or not is_inside_tree():
		return

	if stage_id != StageManager.TOTAL_STAGES or boss_scene == null:
		_unlock_exit_portal()
		return

	boss_spawned = true

	if objective_label:
		objective_label.text = "WARNING: Stage 3 Boss Approaching! Defeat the Boss!"
		objective_label.modulate = Color(1.0, 0.55, 0.45)

	var boss := boss_scene.instantiate()
	add_child(boss)

	if boss_spawn_point:
		boss.global_position = boss_spawn_point.global_position
	else:
		boss.global_position = Vector2(0, -120)

	if boss.has_signal("boss_died"):
		boss.boss_died.connect(_on_boss_died)


func _on_boss_died() -> void:
	if is_instance_valid(GameState):
		var lvl_mult: int = maxi(1, StageManager.current_level_id if is_instance_valid(StageManager) else 1)
		GameState.add_currency(GameState.scale_currency(15 * stage_id * lvl_mult))
	_unlock_exit_portal()


func _unlock_exit_portal() -> void:
	if exit_portal and exit_portal.has_method("set_exit_unlocked"):
		exit_portal.set_exit_unlocked(true)

	if objective_label:
		if stage_id < StageManager.TOTAL_STAGES:
			objective_label.text = "Stage Cleared! Approach North Exit Door (2-5m) & Press [E] to Stage %d" % (stage_id + 1)
		else:
			objective_label.text = "Level Complete! Approach North Exit Door (2-5m) & Press [E] to Return to Lobby"
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


# ---------- BACKGROUND MUSIC ----------

func _setup_stage_bgm(active_level: int) -> void:
	if stage_bgm == null:
		push_warning("Node StageBGM tidak ditemukan!")
		return

	# Hentikan musik sebelumnya
	stage_bgm.stop()

	# BGM khusus Level 1
	if active_level == 1:
		if floor_1_bgm == null:
			push_warning("BGM Level 1 belum di-assign!")
			return

		stage_bgm.stream = floor_1_bgm
		stage_bgm.volume_db = -15.0
		stage_bgm.play()
