class_name LabStation
extends Node2D
## Lab station: a stationary terminal that opens this zone's interactive
## ML lab. Shows a "*" indicator until the lab is completed once.

signal triggered

const TRIGGER_RADIUS := 10.0
const REARM_RADIUS := 22.0

var world_id := 1

var _armed := true
var _sprite: Sprite2D
var _indicator: Label
var _pulse := 0.0


func _ready() -> void:
	var act: Dictionary = ContentDb.act_for_world(world_id)
	var accent := Color(str(act.get("palette", {}).get("accent", "#ffffff")))
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.lab_texture(accent)
	add_child(_sprite)

	_indicator = Label.new()
	_indicator.text = "*"
	_indicator.add_theme_font_size_override("font_size", 10)
	_indicator.add_theme_color_override("font_color", Color("#7ee0ff"))
	_indicator.add_theme_color_override("font_outline_color", Color("#101020"))
	_indicator.add_theme_constant_override("outline_size", 2)
	_indicator.position = Vector2(-3, -18)
	add_child(_indicator)
	_refresh()
	GameState.progress_changed.connect(_refresh)


func _refresh() -> void:
	_indicator.visible = not GameState.lab_done(world_id)


func _process(delta: float) -> void:
	_pulse += delta * 4.0
	_sprite.modulate = Color(1, 1, 1, 0.88 + 0.12 * sin(_pulse))
	_indicator.position.y = -18 + sin(_pulse * 0.7) * 1.5


func check_player(player_pos: Vector2) -> void:
	var dist := position.distance_to(player_pos)
	if _armed and dist < TRIGGER_RADIUS:
		_armed = false
		triggered.emit()
	elif not _armed and dist > REARM_RADIUS:
		_armed = true
