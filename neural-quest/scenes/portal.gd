class_name Portal
extends Node2D
## Boss portal: a numbered ring on the path. Emits `triggered` when the
## player walks onto it, then re-arms only after the player steps away so
## closing the quiz panel does not instantly reopen it.

signal triggered

const TRIGGER_RADIUS := 10.0
const REARM_RADIUS := 20.0

var world_id := 1

var _armed := true
var _sprite: Sprite2D
var _label: Label
var _pulse := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.portal_texture()
	add_child(_sprite)

	_label = Label.new()
	_label.text = str(world_id)
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color("#e8e6f0"))
	_label.add_theme_color_override("font_outline_color", Color("#101020"))
	_label.add_theme_constant_override("outline_size", 2)
	_label.position = Vector2(-8, -6)
	_label.size = Vector2(16, 12)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	_refresh_tint()
	GameState.progress_changed.connect(_refresh_tint)


func _refresh_tint() -> void:
	if GameState.boss_cleared(world_id):
		_sprite.modulate = Color("#ffd45e")
	else:
		var act: Dictionary = ContentDb.act_for_world(world_id)
		_sprite.modulate = Color(str(act.get("palette", {}).get("accent", "#ffffff")))


func _process(delta: float) -> void:
	_pulse += delta * 3.0
	var s := 1.0 + 0.06 * sin(_pulse)
	_sprite.scale = Vector2(s, s)


func check_player(player_pos: Vector2) -> void:
	var dist := position.distance_to(player_pos)
	if _armed and dist < TRIGGER_RADIUS:
		_armed = false
		triggered.emit()
	elif not _armed and dist > REARM_RADIUS:
		_armed = true
