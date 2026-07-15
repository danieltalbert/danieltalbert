class_name Minimap
extends Control
## Minimap: a vertical strip of the whole descent, toggled with Tab or the
## MAP button. Terrain is baked once into a tiny texture; live markers
## (player, portals, shards, tutors, minis, glitch) draw on top each frame.

const BG := Color(0.043, 0.047, 0.078, 0.85)
const BORDER := Color("#3a3f5c")
const GOLD := Color("#ffd45e")
const RED := Color("#ff5c72")
const CYAN := Color("#7ee0ff")
const GREEN := Color("#58e07a")
const ORANGE := Color("#e0a040")
const WHITE := Color("#e8e6f0")

var overworld: Overworld

var _terrain: ImageTexture
var _map_w := 0
var _map_h := 0
var _scale_x := 1.5
var _scale_y := 0.73
var _origin := Vector2(6, 5)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_w = int(ContentDb.map["width"])
	_map_h = int(ContentDb.map["height"])
	_scale_y = 300.0 / _map_h
	_scale_x = 1.5
	size = Vector2(_map_w * _scale_x + 12, _map_h * _scale_y + 10)
	_bake_terrain()


func _bake_terrain() -> void:
	var img := Image.create(_map_w, _map_h, false, Image.FORMAT_RGBA8)
	for y in _map_h:
		var act := 1
		if overworld != null and y < overworld.act_of_row.size():
			act = overworld.act_of_row[y]
		var ground := ContentDb.palette_color(act, "ground_dark").darkened(0.35)
		var path := ContentDb.palette_color(act, "path")
		var solid := ContentDb.palette_color(act, "ground_dark").darkened(0.65)
		for x in _map_w:
			match ContentDb.tile_at(x, y):
				"P":
					img.set_pixel(x, y, path)
				"#":
					img.set_pixel(x, y, solid)
				_:
					img.set_pixel(x, y, ground)
	_terrain = ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _spot(x: float, y: float) -> Vector2:
	return _origin + Vector2(x * _scale_x, y * _scale_y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER, false, 1.0)
	draw_texture_rect(_terrain, Rect2(_origin,
		Vector2(_map_w * _scale_x, _map_h * _scale_y)), false)

	var blink := sin(Time.get_ticks_msec() / 150.0) > 0.0

	for s_i in ContentDb.map["shards"].size():
		if not GameState.shard_collected(s_i):
			var c: Array = ContentDb.map["shards"][s_i]
			draw_rect(Rect2(_spot(float(c[0]), float(c[1])), Vector2(1, 1)), CYAN)

	if overworld != null:
		for t in overworld.get_children():
			if t is Tutor and not GameState.tutor_read(t.world_id):
				var p := _spot(t.position.x / 16.0, t.position.y / 16.0)
				draw_rect(Rect2(p, Vector2(2, 2)), GREEN)
			elif t is Monster and not GameState.mini_beaten(t.world_id):
				var p := _spot(t.position.x / 16.0, t.position.y / 16.0)
				draw_rect(Rect2(p, Vector2(2, 2)), ORANGE)

	for portal in ContentDb.map["portals"]:
		var color := GOLD if GameState.boss_cleared(int(portal["id"])) else RED
		draw_rect(Rect2(_spot(float(portal["x"]) - 0.5, float(portal["y"]) - 0.5),
			Vector2(3, 3)), color)

	if overworld != null and overworld.glitch != null and blink:
		var gp := overworld.glitch.position / 16.0
		draw_rect(Rect2(_spot(gp.x, gp.y) - Vector2(1, 1), Vector2(3, 3)), GOLD)

	if overworld != null and overworld.player != null:
		var pp := overworld.player.position / 16.0
		if blink:
			draw_rect(Rect2(_spot(pp.x, pp.y) - Vector2(1, 1), Vector2(3, 3)), WHITE)
		# Camera view box: full map width, about 20 rows tall.
		var view_rows := 320.0 / 16.0
		var top := clampf(pp.y - view_rows / 2.0, 0.0, _map_h - view_rows)
		draw_rect(Rect2(_spot(0, top),
			Vector2(_map_w * _scale_x, view_rows * _scale_y)),
			Color(1, 1, 1, 0.35), false, 1.0)
