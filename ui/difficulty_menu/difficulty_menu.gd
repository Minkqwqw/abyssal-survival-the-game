extends CanvasLayer

signal menu_closed

const ACTIVE_MARKER: String = "   [ACTIVE]"

@onready var normal_btn: Button = $Panel/NormalButton
@onready var hard_btn: Button = $Panel/HardButton
@onready var nightmare_btn: Button = $Panel/NightmareButton
@onready var close_btn: Button = $Panel/CloseButton

var _tier_buttons: Dictionary = {}


func _ready() -> void:
	_tier_buttons = {
		GameState.Difficulty.NORMAL: normal_btn,
		GameState.Difficulty.HARD: hard_btn,
		GameState.Difficulty.NIGHTMARE: nightmare_btn,
	}
	for diff in _tier_buttons:
		var btn: Button = _tier_buttons[diff]
		if btn:
			btn.pressed.connect(_on_difficulty_selected.bind(diff))
	if close_btn:
		close_btn.pressed.connect(_close)
	if is_instance_valid(GameState) and not GameState.difficulty_changed.is_connected(_on_difficulty_changed):
		GameState.difficulty_changed.connect(_on_difficulty_changed)
	_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _refresh_ui() -> void:
	if not is_instance_valid(GameState):
		return

	for diff in _tier_buttons:
		var btn: Button = _tier_buttons[diff]
		if btn == null:
			continue
		var meta: Dictionary = GameState.DIFFICULTY_META[diff]
		var active: bool = GameState.difficulty == diff
		btn.text = "%s — Enemy HP x%s, DMG x%s, Speed x%s, Count x%s, Pearls x%s%s" % [
			meta["name"],
			str(meta["hp"]), str(meta["damage"]), str(meta["speed"]),
			str(meta["count"]), str(meta["currency"]),
			ACTIVE_MARKER if active else ""
		]
		btn.modulate = Color(0.55, 1.0, 0.85, 1.0) if active else Color.WHITE


func _on_difficulty_selected(diff: int) -> void:
	if is_instance_valid(GameState):
		GameState.set_difficulty(diff, true)
	_refresh_ui()


func _on_difficulty_changed(_new_difficulty: int) -> void:
	_refresh_ui()


func _close() -> void:
	menu_closed.emit()
	queue_free()
