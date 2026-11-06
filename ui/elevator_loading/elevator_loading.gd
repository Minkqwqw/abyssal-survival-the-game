extends Control

@export var loading_duration: float = 3.4
@export var shaft_scroll_speed: float = 440.0

@onready var shaft_bg_a: TextureRect = $ShaftViewport/ShaftBgA
@onready var shaft_bg_b: TextureRect = $ShaftViewport/ShaftBgB
@onready var passing_beam_1: ColorRect = $ShaftViewport/PassingBeam1
@onready var passing_beam_2: ColorRect = $ShaftViewport/PassingBeam2
@onready var cabin_root: Node2D = $CabinLayer/CabinRoot
@onready var player_sprite: AnimatedSprite2D = $CabinLayer/CabinRoot/PlayerStandSprite
@onready var depth_label: Label = $OverlayUI/TopBar/DepthLabel
@onready var status_label: Label = $OverlayUI/BottomBar/StatusLabel
@onready var progress_bar: ProgressBar = $OverlayUI/BottomBar/DescentProgressBar
@onready var fade_rect: ColorRect = $OverlayUI/FadeRect

var _elapsed: float = 0.0
var _transitioning: bool = false
var _shaft_height: float = 1080.0
var _base_cabin_pos: Vector2 = Vector2(960.0, 520.0)


func _ready() -> void:
	_base_cabin_pos = cabin_root.position
	if player_sprite:
		player_sprite.play("idle")

	if fade_rect:
		fade_rect.color.a = 1.0
		var tween := create_tween()
		tween.tween_property(fade_rect, "color:a", 0.0, 0.35)


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("dash") or event.is_action_pressed("ui_accept"):
		_finish_descent()


func _process(delta: float) -> void:
	if _transitioning:
		return

	_elapsed += delta
	var progress := clampf(_elapsed / loading_duration, 0.0, 1.0)

	if shaft_bg_a and shaft_bg_b:
		shaft_bg_a.position.y -= shaft_scroll_speed * delta
		shaft_bg_b.position.y -= shaft_scroll_speed * delta
		if shaft_bg_a.position.y <= -_shaft_height:
			shaft_bg_a.position.y = shaft_bg_b.position.y + _shaft_height
		if shaft_bg_b.position.y <= -_shaft_height:
			shaft_bg_b.position.y = shaft_bg_a.position.y + _shaft_height

	for beam in [passing_beam_1, passing_beam_2]:
		if beam:
			beam.position.y -= (shaft_scroll_speed * 1.45) * delta
			if beam.position.y < -80.0:
				beam.position.y += 1160.0

	if cabin_root:
		var bob_y := sin(_elapsed * 16.0) * 2.5
		var sway_x := cos(_elapsed * 9.0) * 1.2
		cabin_root.position = _base_cabin_pos + Vector2(sway_x, bob_y)

	if progress_bar:
		progress_bar.value = progress * 100.0
	if depth_label:
		var depth_meters := int(lerpf(120.0, 860.0, progress))
		depth_label.text = "ABYSSAL LAB LIFT  |  DEPTH: -%d m" % depth_meters
	if status_label:
		var dots := ".".repeat(1 + (int(_elapsed * 3.0) % 3))
		status_label.text = "DESCENDING TO SECTOR SELECTOR%s   ([SPACE / E] Skip)" % dots

	if _elapsed >= loading_duration:
		_finish_descent()


func _finish_descent() -> void:
	if _transitioning:
		return
	_transitioning = true

	if fade_rect:
		var tween := create_tween()
		tween.tween_property(fade_rect, "color:a", 1.0, 0.3)
		await tween.finished

	StageManager.open_stage_selector()
