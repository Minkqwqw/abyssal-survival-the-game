extends Control

const LEVEL_INFO: Array[Dictionary] = [
	{
		"level": 1,
		"name": "level 1",
		"subtitle": "Toxic Shallows",
		"depth": "Depth: -200m",
		"accent": Color(0.25, 0.78, 0.48, 1.0),
		"desc": "Ruined lab outskirts contaminated by toxic chemical leaks."
	},
	{
		"level": 2,
		"name": "level 2",
		"subtitle": "Crimson Reef",
		"depth": "Depth: -450m",
		"accent": Color(0.95, 0.45, 0.45, 1.0),
		"desc": "Strong underwater currents sweeping through overgrown red coral."
	},
	{
		"level": 3,
		"name": "level 3",
		"subtitle": "The Deep Abyss",
		"depth": "Depth: -800m",
		"accent": Color(0.65, 0.35, 0.95, 1.0),
		"desc": "Pitch-black abyssal trench patrolled by mutated deep-sea predators."
	},
	{
		"level": 4,
		"name": "level 4",
		"subtitle": "Hydrothermal Vents",
		"depth": "Depth: -1,250m",
		"accent": Color(0.95, 0.55, 0.2, 1.0),
		"desc": "Superheated volcanic fissures surrounding the lower reactor foundations."
	},
	{
		"level": 5,
		"name": "level 5",
		"subtitle": "Hadal Trench",
		"depth": "Depth: -2,000m",
		"accent": Color(0.3, 0.85, 1.0, 1.0),
		"desc": "The deepest crushed laboratory core at the bottom of the ocean."
	}
]

@onready var subtitle_info_label: Label = $MainFrame/HeaderSubLabel
@onready var preview_title_label: Label = $MainFrame/PreviewBox/PreviewTitleLabel
@onready var preview_desc_label: Label = $MainFrame/PreviewBox/PreviewDescLabel
@onready var back_button: Button = $MainFrame/BackToLobbyButton
@onready var cards_container: HBoxContainer = $MainFrame/CardsContainer
@onready var difficulty_buttons: Dictionary = {
	GameState.Difficulty.NORMAL: $MainFrame/DifficultyRow/NormalButton,
	GameState.Difficulty.HARD: $MainFrame/DifficultyRow/HardButton,
	GameState.Difficulty.NIGHTMARE: $MainFrame/DifficultyRow/NightmareButton,
}

var _card_buttons: Dictionary = {}


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_setup_level_cards()
	_setup_difficulty_buttons()
	_update_header()
	_update_preview(StageManager.max_unlocked_level if is_instance_valid(StageManager) else 1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _update_header() -> void:
	var pearls := GameState.currency if is_instance_valid(GameState) else 0
	var max_lvl := StageManager.max_unlocked_level if is_instance_valid(StageManager) else 1
	var diff_name: String = GameState.get_difficulty_name() if is_instance_valid(GameState) else "NORMAL"
	subtitle_info_label.text = "Select Destination Floor (Level 1 - 5)   |   Unlocked: %d / 5   |   Abyssal Pearls: %d   |   Difficulty: %s" % [max_lvl, pearls, diff_name]


func _setup_level_cards() -> void:
	for info in LEVEL_INFO:
		var lvl: int = info["level"]
		var card: Panel = cards_container.get_node_or_null("LevelCard%d" % lvl)
		if not card:
			continue

		var unlocked: bool = StageManager.is_level_unlocked(lvl) if is_instance_valid(StageManager) else (lvl == 1)
		var accent: Color = info["accent"]

		var border: Line2D = card.get_node_or_null("CardBorder")
		var top_bar: ColorRect = card.get_node_or_null("AccentBar")
		var depth_lbl: Label = card.get_node_or_null("DepthLabel")
		var level_lbl: Label = card.get_node_or_null("LevelLabel")
		var zone_lbl: Label = card.get_node_or_null("ZoneLabel")
		var status_lbl: Label = card.get_node_or_null("StatusLabel")
		var select_btn: Button = card.get_node_or_null("SelectButton")

		if depth_lbl:
			depth_lbl.text = info["depth"]
		if level_lbl:
			level_lbl.text = info["name"]
		if zone_lbl:
			zone_lbl.text = info["subtitle"]

		if unlocked:
			if top_bar:
				top_bar.color = accent
			if border:
				border.default_color = accent
			if level_lbl:
				level_lbl.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if status_lbl:
				status_lbl.text = "UNLOCKED"
				status_lbl.modulate = Color(0.55, 1.0, 0.85, 1.0)
			if select_btn:
				select_btn.disabled = false
				select_btn.text = "DEPLOY"
		else:
			if top_bar:
				top_bar.color = Color(0.28, 0.3, 0.35, 0.8)
			if border:
				border.default_color = Color(0.35, 0.38, 0.44, 0.9)
			if level_lbl:
				level_lbl.modulate = Color(0.55, 0.58, 0.65, 1.0)
			if status_lbl:
				status_lbl.text = "LOCKED (Clear Lv.%d)" % (lvl - 1)
				status_lbl.modulate = Color(0.95, 0.45, 0.45, 0.9)
			if select_btn:
				select_btn.disabled = true
				select_btn.text = "LOCKED"

		if select_btn:
			select_btn.mouse_entered.connect(func(): _update_preview(lvl))
			select_btn.focus_entered.connect(func(): _update_preview(lvl))
			select_btn.pressed.connect(func(): _on_level_selected(lvl))
			_card_buttons[lvl] = select_btn


func _update_preview(lvl: int) -> void:
	var idx := clampi(lvl - 1, 0, LEVEL_INFO.size() - 1)
	var info: Dictionary = LEVEL_INFO[idx]
	var unlocked: bool = StageManager.is_level_unlocked(lvl) if is_instance_valid(StageManager) else (lvl == 1)
	var status_tag := "READY FOR DEPLOYMENT" if unlocked else "SECTOR LOCKED"
	if preview_title_label:
		preview_title_label.text = "%s — %s  [%s]" % [info["name"].to_upper(), info["subtitle"], status_tag]
		preview_title_label.modulate = info["accent"] if unlocked else Color(0.7, 0.72, 0.78, 1.0)
	if preview_desc_label:
		preview_desc_label.text = "%s   |   %s" % [info["depth"], info["desc"]]


func _on_level_selected(lvl: int) -> void:
	if is_instance_valid(StageManager) and StageManager.is_level_unlocked(lvl):
		StageManager.start_level(lvl)


func _setup_difficulty_buttons() -> void:
	for diff in difficulty_buttons:
		var btn: Button = difficulty_buttons[diff]
		if btn:
			btn.pressed.connect(_on_difficulty_selected.bind(diff))
	if is_instance_valid(GameState) and not GameState.difficulty_changed.is_connected(_on_difficulty_changed):
		GameState.difficulty_changed.connect(_on_difficulty_changed)
	_refresh_difficulty_buttons()


func _refresh_difficulty_buttons() -> void:
	if not is_instance_valid(GameState):
		return
	for diff in difficulty_buttons:
		var btn: Button = difficulty_buttons[diff]
		if btn == null:
			continue
		btn.modulate = Color(0.55, 1.0, 0.85, 1.0) if GameState.difficulty == diff else Color.WHITE


func _on_difficulty_selected(diff: int) -> void:
	if is_instance_valid(GameState):
		GameState.set_difficulty(diff, false)


func _on_difficulty_changed(_new_difficulty: int) -> void:
	_refresh_difficulty_buttons()
	_update_header()


func _on_back_pressed() -> void:
	if is_instance_valid(StageManager):
		StageManager.return_to_lobby()
	else:
		get_tree().change_scene_to_file("res://hub/hub.tscn")
