class_name Overworld
extends Node2D
## Overworld: builds the terrain TileMapLayer from data/map.json, spawns the
## player and all entities, and routes touch triggers (portals, tutors,
## minis, shards, glitch) to the panels. Signals let Main own the UI flow.

signal boss_triggered(world_id: int)
signal tutor_triggered(world_id: int)
signal mini_triggered(world_id: int)

const TILE := 16

var player: Player
var act_of_row: PackedInt32Array = []
var glitch: Node2D = null

var _portals: Array = []
var _tutors: Array = []
var _minis: Array = []
var _shards: Array = []


func _ready() -> void:
	_build_act_lookup()
	_build_terrain()
	_spawn_player()
	_spawn_portals()
	_spawn_npcs()
	_spawn_shards()


func _build_act_lookup() -> void:
	var height := int(ContentDb.map["height"])
	act_of_row.resize(height)
	for y in height:
		act_of_row[y] = 1
	for z in ContentDb.map["zones"]:
		for y in range(int(z["y0"]), int(z["y1"]) + 1):
			act_of_row[y] = int(z["act"])
	var last_zone: Dictionary = ContentDb.map["zones"][-1]
	for y in range(int(last_zone["y1"]) + 1, height):
		act_of_row[y] = int(last_zone["act"])


func _build_terrain() -> void:
	var atlas := PixelArt.build_terrain_atlas(ContentDb.meta["acts"])
	var src := TileSetAtlasSource.new()
	src.texture = atlas
	src.texture_region_size = Vector2i(TILE, TILE)
	for x in 4:
		for y in ContentDb.meta["acts"].size():
			src.create_tile(Vector2i(x, y))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_source(src, 0)

	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	add_child(layer)

	var width := int(ContentDb.map["width"])
	var height := int(ContentDb.map["height"])
	for y in height:
		var act_row := act_of_row[y] - 1
		for x in width:
			var col := 0
			match ContentDb.tile_at(x, y):
				"P":
					col = 2
				"#":
					col = 3
				_:
					col = 1 if (x * 7 + y * 13) % 7 == 0 else 0
			layer.set_cell(Vector2i(x, y), 0, Vector2i(col, act_row))


func _spawn_player() -> void:
	player = Player.new()
	var spawn: Array = ContentDb.map["spawn"]
	player.position = tile_center(int(spawn[0]), int(spawn[1]))
	add_child(player)
	var cam := player.camera
	cam.limit_left = 0
	cam.limit_right = int(ContentDb.map["width"]) * TILE
	cam.limit_top = 0
	cam.limit_bottom = int(ContentDb.map["height"]) * TILE


func _spawn_portals() -> void:
	for p in ContentDb.map["portals"]:
		var portal := Portal.new()
		portal.world_id = int(p["id"])
		portal.position = tile_center(int(p["x"]), int(p["y"]))
		portal.triggered.connect(func(): boss_triggered.emit(portal.world_id))
		add_child(portal)
		_portals.append(portal)


func _spawn_npcs() -> void:
	for t in ContentDb.map["tutors"]:
		var tutor := Tutor.new()
		tutor.world_id = int(t["id"])
		tutor.position = tile_center(int(t["x"]), int(t["y"]))
		tutor.triggered.connect(func(): tutor_triggered.emit(tutor.world_id))
		add_child(tutor)
		_tutors.append(tutor)
	for m in ContentDb.map["minis"]:
		var monster := Monster.new()
		monster.world_id = int(m["id"])
		monster.position = tile_center(int(m["x"]), int(m["y"]))
		monster.triggered.connect(func(): mini_triggered.emit(monster.world_id))
		add_child(monster)
		_minis.append(monster)


func _spawn_shards() -> void:
	var coords: Array = ContentDb.map["shards"]
	for i in coords.size():
		if GameState.shard_collected(i):
			continue
		var shard := Shard.new()
		shard.index = i
		shard.position = tile_center(int(coords[i][0]), int(coords[i][1]))
		shard.collected.connect(_on_shard_collected)
		add_child(shard)
		_shards.append(shard)


func _on_shard_collected(index: int) -> void:
	GameState.grant_xp(int(ContentDb.constant("xp_shard")))
	GameState.mark_shard(index)


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	for portal in _portals:
		portal.check_player(player.position)
	for tutor in _tutors:
		tutor.check_player(player.position)
	for monster in _minis:
		monster.check_player(player.position)
	for shard in _shards:
		if is_instance_valid(shard):
			shard.check_player(player.position)


func tile_center(x: int, y: int) -> Vector2:
	return Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)


func world_position_of_portal(world_id: int) -> Vector2:
	for p in ContentDb.map["portals"]:
		if int(p["id"]) == world_id:
			return tile_center(int(p["x"]), int(p["y"]))
	return Vector2.ZERO
