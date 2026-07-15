class_name PixelArt
## Programmatic pixel art. Every texture in the game is generated here from
## string pixel maps or small drawing routines, so the repo ships zero
## external image assets. Palette hex values are documented in CLAUDE.md.

const TILE := 16

const PLAYER_COLORS := {
	"h": Color("#503020"), "s": Color("#f2d5a0"), "e": Color("#1a1626"),
	"t": Color("#4de3d1"), "d": Color("#2fb3a3"), "b": Color("#705038"),
	"c": Color("#ffd45e"),
}

# 16x16 player maps. '.' is transparent.
const PLAYER_MAPS := {
	"down_0": [
		"................",
		"................",
		".....hhhhhh.....",
		"....hhhhhhhh....",
		"....hsssssss....",
		"....hsesse.s....",
		"....ssssssss....",
		".....ssssss.....",
		"....tttttttt....",
		"...sttddddtts...",
		"...stttttttts...",
		"....tttttttt....",
		".....tt..tt.....",
		".....bb..bb.....",
		"....bbb..bbb....",
		"................"],
	"down_1": [
		"................",
		"................",
		".....hhhhhh.....",
		"....hhhhhhhh....",
		"....hsssssss....",
		"....hsesse.s....",
		"....ssssssss....",
		".....ssssss.....",
		"....tttttttt....",
		"...sttddddtts...",
		"...stttttttts...",
		"....tttttttt....",
		"....tt....tt....",
		"....bb....bb....",
		"...bbb....bbb...",
		"................"],
	"up_0": [
		"................",
		"................",
		".....hhhhhh.....",
		"....hhhhhhhh....",
		"....hhhhhhhh....",
		"....hhhhhhhh....",
		"....shhhhhhs....",
		".....ssssss.....",
		"....tttttttt....",
		"...sttddddtts...",
		"...stttttttts...",
		"....tttttttt....",
		".....tt..tt.....",
		".....bb..bb.....",
		"....bbb..bbb....",
		"................"],
	"up_1": [
		"................",
		"................",
		".....hhhhhh.....",
		"....hhhhhhhh....",
		"....hhhhhhhh....",
		"....hhhhhhhh....",
		"....shhhhhhs....",
		".....ssssss.....",
		"....tttttttt....",
		"...sttddddtts...",
		"...stttttttts...",
		"....tttttttt....",
		"....tt....tt....",
		"....bb....bb....",
		"...bbb....bbb...",
		"................"],
	"side_0": [
		"................",
		"................",
		".....hhhhhh.....",
		"....hhhhhhhh....",
		"....hhssssss....",
		"....hhse.sse....",
		"....hsssssss....",
		".....ssssss.....",
		"....tttttttt....",
		"....ttdddtts....",
		"....ttttttts....",
		"....tttttttt....",
		".....tttt.......",
		".....bb.bb......",
		"....bbb.bbb.....",
		"................"],
	"side_1": [
		"................",
		"................",
		".....hhhhhh.....",
		"....hhhhhhhh....",
		"....hhssssss....",
		"....hhse.sse....",
		"....hsssssss....",
		".....ssssss.....",
		"....tttttttt....",
		"....ttdddtts....",
		"....ttttttts....",
		"....tttttttt....",
		"....tt..tt......",
		"....bb...bb.....",
		"...bbb...bbb....",
		"................"],
}

# Gold crown overlay pixels, drawn over the top of the head when earned.
const CROWN_ROWS := [
	".....c.c.c......",
	".....cccccc.....",
]

const TUTOR_MAP := [
	"................",
	"................",
	".....rrrrrr.....",
	"....rrrrrrrr....",
	"....rsssssss....",
	"....rsesse.s....",
	"....rsssssss....",
	"....rrrrrrrr....",
	"...rrrrrrrrrr...",
	"...rrgggggrrr...",
	"...rrgggggrrr...",
	"...rrrrrrrrrr...",
	"....rrrrrrrr....",
	"....rrrrrrrr....",
	"...rrrrrrrrrr...",
	"................"]

const MONSTER_MAP_0 := [
	"................",
	"................",
	"................",
	"................",
	"....mm....mm....",
	"....mmm..mmm....",
	"...mmmmmmmmmm...",
	"..mmwwmmmmwwmm..",
	"..mmwemmmmewmm..",
	"..mmmmmmmmmmmm..",
	"..mmmmkkkkmmmm..",
	"..mmmmmmmmmmmm..",
	"...mmmmmmmmmm...",
	"...mm.mmmm.mm...",
	"................",
	"................"]

const MONSTER_MAP_1 := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"....mm....mm....",
	"...mmmm..mmmm...",
	"..mmmmmmmmmmmm..",
	"..mmwwmmmmwwmm..",
	"..mmwemmmmewmm..",
	"..mmmmkkkkmmmm..",
	"..mmmmmmmmmmmm..",
	".mmmmmmmmmmmmmm.",
	".mm.mm.mm.mm.mm.",
	"................",
	"................"]

const SPIKE_MAP_0 := [
	"................",
	"................",
	"....m...m..m....",
	"...mmm.mmm.mmm..",
	"..mmmmmmmmmmmm..",
	".mmwwmmmmmmwwmm.",
	".mmwemmmmmmewmm.",
	".mmmmmmmmmmmmmm.",
	"m.mmmkkkkkkmmm.m",
	".mmmmmmmmmmmmmm.",
	"..mmmmmmmmmmmm..",
	"...mmm.mm.mmm...",
	"....m..mm..m....",
	"................",
	"................",
	"................"]

const SPIKE_MAP_1 := [
	"................",
	"................",
	"................",
	"...m...mm...m...",
	"..mmm.mmmm.mmm..",
	".mmmmmmmmmmmmmm.",
	"mmmwwmmmmmmwwmmm",
	"mmmwemmmmmmewmmm",
	".mmmmkkkkkkmmmm.",
	".mmmmmmmmmmmmmm.",
	"..mmmmmmmmmmmm..",
	"..mmm.mmmm.mmm..",
	"...m...mm...m...",
	"................",
	"................",
	"................"]

const WISP_MAP_0 := [
	"................",
	".......mm.......",
	"......mmmm......",
	".....mmmmmm.....",
	"....mmmmmmmm....",
	"...mmwwmmwwmm...",
	"...mmwemmewmm...",
	"...mmmmmmmmmm...",
	"...mmkkkkkkmm...",
	"....mmmmmmmm....",
	".....mmmmmm.....",
	"....mm.mm.mm....",
	"...m..m..m..m...",
	"................",
	"................",
	"................"]

const WISP_MAP_1 := [
	"................",
	".......mm.......",
	"......mmmm......",
	".....mmmmmm.....",
	"....mmmmmmmm....",
	"...mmwwmmwwmm...",
	"...mmwemmewmm...",
	"...mmmmmmmmmm...",
	"...mmkkkkkkmm...",
	"....mmmmmmmm....",
	"....mmmmmm......",
	"...mm.mm.mm.....",
	"..m..m..m..m....",
	"................",
	"................",
	"................"]

const GLITCH_MAP_0 := [
	"................",
	".......g........",
	"......ggg.......",
	".....ggggg......",
	"....ggwwwgg.....",
	"...ggwwwwwgg....",
	"..ggwwwgwwwgg...",
	".gggwwgggwwggg..",
	"..ggwwwgwwwgg...",
	"...ggwwwwwgg....",
	"....ggwwwgg.....",
	".....ggggg......",
	"......ggg.......",
	".......g........",
	"................",
	"................"]

const GLITCH_MAP_1 := [
	"........g.......",
	".......ggg......",
	"......ggggg.....",
	".....ggwwwgg....",
	"....ggwwwwwgg...",
	"...ggwwgggwwgg..",
	"....ggwwwwwgg...",
	".....ggwwwgg....",
	"......ggggg.....",
	".......ggg......",
	"........g.......",
	"....w.......w...",
	"................",
	"................",
	"................",
	"................"]

const SHARD_MAP := [
	"...x....",
	"..xxx...",
	".xxwxx..",
	"xxwwwxx.",
	".xxwxx..",
	"..xxx...",
	"...x....",
	"........"]

const PORTAL_MAP := [
	"....pppppppp....",
	"..pppppppppppp..",
	".pppkkkkkkkkppp.",
	".ppkkkkkkkkkkpp.",
	"pppkkkkkkkkkkppp",
	"ppkkkkkkkkkkkkpp",
	"ppkkkkkkkkkkkkpp",
	"ppkkkkkkkkkkkkpp",
	"ppkkkkkkkkkkkkpp",
	"ppkkkkkkkkkkkkpp",
	"ppkkkkkkkkkkkkpp",
	"pppkkkkkkkkkkppp",
	".ppkkkkkkkkkkpp.",
	".pppkkkkkkkkppp.",
	"..pppppppppppp..",
	"....pppppppp...."]


static func tex_from_map(rows: Array, colors: Dictionary) -> ImageTexture:
	var h := rows.size()
	var w := (rows[0] as String).length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var row: String = rows[y]
		for x in mini(w, row.length()):
			var ch := row[x]
			if colors.has(ch):
				img.set_pixel(x, y, colors[ch])
	return ImageTexture.create_from_image(img)


static func player_frames(crowned: bool) -> Dictionary:
	var frames := {}
	for key in PLAYER_MAPS:
		var rows: Array = (PLAYER_MAPS[key] as Array).duplicate()
		if crowned:
			rows[0] = CROWN_ROWS[0]
			rows[1] = CROWN_ROWS[1]
		frames[key] = tex_from_map(rows, PLAYER_COLORS)
	return frames


static func tutor_texture(accent: Color) -> ImageTexture:
	var colors := {
		"r": accent.darkened(0.25), "g": Color("#e8e6f0"),
		"s": Color("#f2d5a0"), "e": Color("#1a1626"),
	}
	return tex_from_map(TUTOR_MAP, colors)


static func monster_textures(body: Color, variant: int = 0) -> Array:
	var colors := {
		"m": body, "w": Color("#e8e6f0"), "e": Color("#1a1626"),
		"k": body.darkened(0.35),
	}
	var maps := [
		[MONSTER_MAP_0, MONSTER_MAP_1],
		[SPIKE_MAP_0, SPIKE_MAP_1],
		[WISP_MAP_0, WISP_MAP_1],
	]
	var pair: Array = maps[clampi(variant, 0, maps.size() - 1)]
	return [tex_from_map(pair[0], colors), tex_from_map(pair[1], colors)]


static func glitch_textures() -> Array:
	var colors := {"g": Color("#ffd45e"), "w": Color("#fff6d8")}
	return [tex_from_map(GLITCH_MAP_0, colors), tex_from_map(GLITCH_MAP_1, colors)]


static func shard_texture() -> ImageTexture:
	return tex_from_map(SHARD_MAP, {"x": Color("#7ee0ff"), "w": Color("#eafcff")})


static func portal_texture() -> ImageTexture:
	# Ring is white so nodes can tint it with the act accent via modulate.
	return tex_from_map(PORTAL_MAP, {"p": Color.WHITE, "k": Color("#101020", 0.85)})


static func dot_texture(color: Color = Color.WHITE, size: int = 2) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


## Terrain atlas: one 16 px row of tiles per act.
## Columns: 0 ground, 1 ground variant, 2 path, 3 obstacle.
static func build_terrain_atlas(acts: Array) -> ImageTexture:
	var img := Image.create(4 * TILE, acts.size() * TILE, false, Image.FORMAT_RGBA8)
	for i in acts.size():
		var pal: Dictionary = acts[i]["palette"]
		var ground := Color(str(pal["ground"]))
		var ground_dark := Color(str(pal["ground_dark"]))
		var path := Color(str(pal["path"]))
		var path_dark := Color(str(pal["path_dark"]))
		var ob_a := Color(str(pal["obstacle_a"]))
		var ob_b := Color(str(pal["obstacle_b"]))
		var accent := Color(str(pal["accent"]))
		var oy := i * TILE
		_draw_ground(img, 0, oy, ground, ground_dark, false, accent)
		_draw_ground(img, TILE, oy, ground, ground_dark, true, accent)
		_draw_path(img, 2 * TILE, oy, path, path_dark)
		_draw_ground(img, 3 * TILE, oy, ground, ground_dark, false, accent)
		match int(acts[i]["id"]):
			1: _draw_tree(img, 3 * TILE, oy, ob_a, ob_b)
			2: _draw_pillar(img, 3 * TILE, oy, ob_a, ob_b)
			3: _draw_crystal(img, 3 * TILE, oy, ob_a, ob_b, accent)
			4: _draw_coral(img, 3 * TILE, oy, ob_a, ob_b, accent)
	return ImageTexture.create_from_image(img)


# Fixed speckle offsets keep tiles deterministic without an RNG.
const SPECKLES := [[2, 3], [6, 1], [11, 4], [4, 9], [13, 11], [8, 13], [1, 12], [10, 8]]
const SPECKLES_ALT := [[3, 6], [9, 2], [12, 9], [5, 13], [14, 5], [7, 7], [2, 14]]


static func _draw_ground(img: Image, ox: int, oy: int, base: Color, dark: Color,
		variant: bool, accent: Color) -> void:
	for y in TILE:
		for x in TILE:
			img.set_pixel(ox + x, oy + y, base)
	for s in SPECKLES:
		img.set_pixel(ox + s[0], oy + s[1], dark)
	if variant:
		for s in SPECKLES_ALT:
			img.set_pixel(ox + s[0], oy + s[1], dark)
		img.set_pixel(ox + 7, oy + 5, accent)
		img.set_pixel(ox + 8, oy + 5, accent)
		img.set_pixel(ox + 7, oy + 4, accent)


static func _draw_path(img: Image, ox: int, oy: int, base: Color, dark: Color) -> void:
	for y in TILE:
		for x in TILE:
			img.set_pixel(ox + x, oy + y, base)
	for s in SPECKLES_ALT:
		img.set_pixel(ox + s[0], oy + s[1], dark)
	for x in TILE:
		if x % 3 != 0:
			img.set_pixel(ox + x, oy, dark)
			img.set_pixel(ox + x, oy + TILE - 1, dark)


static func _draw_tree(img: Image, ox: int, oy: int, trunk: Color, leaves: Color) -> void:
	for y in range(9, 15):
		for x in range(6, 10):
			img.set_pixel(ox + x, oy + y, trunk)
	var dark := leaves.darkened(0.25)
	for y in range(1, 10):
		for x in range(2, 14):
			var dx := absf(x - 7.5)
			var dy := absf(y - 5.0)
			if dx * dx / 36.0 + dy * dy / 20.0 <= 1.0:
				img.set_pixel(ox + x, oy + y, dark if (x + y) % 5 == 0 else leaves)


static func _draw_pillar(img: Image, ox: int, oy: int, stone: Color, leaf: Color) -> void:
	var dark := stone.darkened(0.3)
	for x in range(3, 13):
		img.set_pixel(ox + x, oy + 1, dark)
		img.set_pixel(ox + x, oy + 2, stone)
	for y in range(3, 13):
		for x in range(5, 11):
			img.set_pixel(ox + x, oy + y, dark if x == 5 else stone)
	for x in range(3, 13):
		img.set_pixel(ox + x, oy + 13, dark)
		img.set_pixel(ox + x, oy + 14, stone)
	for p in [[2, 14], [13, 12], [1, 11], [14, 15]]:
		img.set_pixel(ox + p[0], oy + p[1], leaf)


static func _draw_crystal(img: Image, ox: int, oy: int, edge: Color, core: Color,
		glow: Color) -> void:
	for y in range(1, 15):
		var half := 7 - absi(y - 8)
		for x in range(8 - half, 8 + half):
			var c := core
			if x == 8 - half or x == 8 + half - 1 or y == 1:
				c = edge
			img.set_pixel(ox + x, oy + y, c)
	img.set_pixel(ox + 7, oy + 4, glow)
	img.set_pixel(ox + 8, oy + 5, glow)
	img.set_pixel(ox + 6, oy + 9, glow)


static func _draw_coral(img: Image, ox: int, oy: int, body: Color, dark: Color,
		glow: Color) -> void:
	for y in range(6, 15):
		for x in range(4, 7):
			img.set_pixel(ox + x, oy + y, body)
	for y in range(3, 15):
		for x in range(9, 12):
			img.set_pixel(ox + x, oy + y, dark)
	for y in range(9, 15):
		for x in range(12, 14):
			img.set_pixel(ox + x, oy + y, body)
	img.set_pixel(ox + 5, oy + 5, glow)
	img.set_pixel(ox + 10, oy + 2, glow)
	img.set_pixel(ox + 13, oy + 8, glow)
	for x in range(2, 15):
		img.set_pixel(ox + x, oy + 15, dark)
