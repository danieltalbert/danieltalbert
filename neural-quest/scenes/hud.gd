class_name Hud
extends CanvasLayer
## HUD: level and title, XP bar, streak indicator, progress counters, and
## the quest compass arrow that points to the lowest uncleared boss (or the
## Golden Glitch after all 20 bosses fall). Also hosts touch controls.

const TEXT := Color("#e8e6f0")
const DIM_TEXT := Color("#9aa0b8")
const GOLD := Color("#ffd45e")
const XP_BLUE := Color("#7ee0ff")
const PANEL_BG := Color(0.078, 0.09, 0.157, 0.75)

var overworld: Overworld

var _level_label: Label
var _xp_bar: ColorRect
var _xp_bar_bg: ColorRect
var _streak_label: Label
var _progress_label: Label
var _compass: Polygon2D
var _minimap: Minimap
var _touch_input := Vector2.ZERO
var _touch_sprint := false


func _ready() -> void:
	layer = 10
	_build_top_bar()
	_build_compass()
	_build_minimap()
	if DisplayServer.is_touchscreen_available():
		_build_touch_controls()
	GameState.xp_gained.connect(func(_a, _t): refresh())
	GameState.streak_changed.connect(func(_s, _m): refresh())
	GameState.progress_changed.connect(refresh)
	refresh()


func _build_minimap() -> void:
	_minimap = Minimap.new()
	_minimap.overworld = overworld
	add_child(_minimap)
	_minimap.position = Vector2(240 - _minimap.size.x - 2, 320 - _minimap.size.y - 4)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		_minimap.visible = not _minimap.visible
		Sfx.play("page")


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_content_margin_all(3)
	bar.add_theme_stylebox_override("panel", style)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(bar)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	bar.add_child(vbox)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 8)
	_level_label.add_theme_color_override("font_color", GOLD)
	row.add_child(_level_label)

	_streak_label = Label.new()
	_streak_label.add_theme_font_size_override("font_size", 8)
	_streak_label.add_theme_color_override("font_color", XP_BLUE)
	row.add_child(_streak_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var map_btn := Button.new()
	map_btn.text = "MAP"
	map_btn.add_theme_font_size_override("font_size", 7)
	map_btn.custom_minimum_size = Vector2(24, 12)
	map_btn.focus_mode = Control.FOCUS_NONE
	map_btn.pressed.connect(func():
		_minimap.visible = not _minimap.visible
		Sfx.play("page"))
	row.add_child(map_btn)

	var mute_btn := Button.new()
	mute_btn.text = "SND"
	mute_btn.add_theme_font_size_override("font_size", 7)
	mute_btn.custom_minimum_size = Vector2(24, 12)
	mute_btn.focus_mode = Control.FOCUS_NONE
	mute_btn.pressed.connect(Sfx.toggle_mute)
	row.add_child(mute_btn)

	_xp_bar_bg = ColorRect.new()
	_xp_bar_bg.color = Color(0, 0, 0, 0.5)
	_xp_bar_bg.custom_minimum_size = Vector2(234, 3)
	vbox.add_child(_xp_bar_bg)
	_xp_bar = ColorRect.new()
	_xp_bar.color = XP_BLUE
	_xp_bar.custom_minimum_size = Vector2(0, 3)
	_xp_bar_bg.add_child(_xp_bar)
	_xp_bar.set_anchors_preset(Control.PRESET_LEFT_WIDE)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 7)
	_progress_label.add_theme_color_override("font_color", DIM_TEXT)
	vbox.add_child(_progress_label)


func _build_compass() -> void:
	_compass = Polygon2D.new()
	_compass.polygon = PackedVector2Array([
		Vector2(6, 0), Vector2(-4, -4), Vector2(-2, 0), Vector2(-4, 4)])
	_compass.color = GOLD
	add_child(_compass)


func refresh() -> void:
	var lv := GameState.level()
	_level_label.text = "LV %d %s" % [lv, GameState.current_title()]
	var per := int(ContentDb.constant("xp_per_level"))
	var into := GameState.xp % per
	_xp_bar.custom_minimum_size.x = 234.0 * into / per
	_xp_bar.size.x = 234.0 * into / per
	if GameState.streak > 0:
		_streak_label.text = "Streak %d (x%.2f)" % [
			GameState.streak, GameState.streak_multiplier()]
	else:
		_streak_label.text = ""
	_progress_label.text = "Bosses %d/20  Minis %d/20  Tutors %d/20  Shards %d/60  XP %d" % [
		GameState.bosses_cleared_count(), GameState.minis.size(),
		GameState.tutors.size(), GameState.shards.size(), GameState.xp]


func _process(_delta: float) -> void:
	_update_compass()


func _compass_target() -> Vector2:
	# Lowest-numbered uncleared boss; after 20/20 the active Glitch.
	if not GameState.all_bosses_cleared():
		for id in range(1, 21):
			if not GameState.boss_cleared(id):
				return overworld.world_position_of_portal(id)
	if overworld.glitch != null:
		return overworld.glitch.position
	return Vector2.INF


func _update_compass() -> void:
	if overworld == null:
		_compass.visible = false
		return
	var target := _compass_target()
	if target == Vector2.INF:
		_compass.visible = false
		return
	var canvas := overworld.get_viewport().get_canvas_transform()
	var screen_pos := canvas * target
	var rect := Rect2(Vector2.ZERO, overworld.get_viewport().get_visible_rect().size)
	if rect.grow(-8).has_point(screen_pos):
		_compass.visible = false
		return
	_compass.visible = true
	var center := rect.size / 2.0
	var dir := (screen_pos - center).normalized()
	var edge := center + dir * (minf(rect.size.x, rect.size.y) / 2.0 - 14.0)
	edge.x = clampf(edge.x, 10.0, rect.size.x - 10.0)
	edge.y = clampf(edge.y, 24.0, rect.size.y - 10.0)
	_compass.position = edge
	_compass.rotation = dir.angle()


# ---- Touch controls ----

func _build_touch_controls() -> void:
	# 26 px buttons at the 2x window scale comfortably exceed 44 px targets.
	var size := 26.0
	var origin := Vector2(10, 320 - 3 * size - 10)
	var dirs := {
		"up": [Vector2(1, 0), Vector2.UP], "left": [Vector2(0, 1), Vector2.LEFT],
		"right": [Vector2(2, 1), Vector2.RIGHT], "down": [Vector2(1, 2), Vector2.DOWN],
	}
	for key in dirs:
		var b := _touch_button(str(key)[0].to_upper(), size)
		b.position = origin + (dirs[key][0] as Vector2) * size
		var v: Vector2 = dirs[key][1]
		b.button_down.connect(func(): _touch_input += v)
		b.button_up.connect(func(): _touch_input -= v)
		add_child(b)

	var run := _touch_button("RUN", size * 1.3)
	run.position = Vector2(240 - size * 1.3 - 10, 320 - size * 1.3 - 14)
	run.button_down.connect(func(): _touch_sprint = true)
	run.button_up.connect(func(): _touch_sprint = false)
	add_child(run)


func _touch_button(text: String, size: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(size, size)
	b.size = Vector2(size, size)
	b.add_theme_font_size_override("font_size", 8)
	b.modulate = Color(1, 1, 1, 0.65)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _physics_process(_delta: float) -> void:
	if overworld != null and overworld.player != null:
		overworld.player.external_input = _touch_input.limit_length(1.0)
		overworld.player.external_sprint = _touch_sprint
