class_name MeadowSites
extends Node3D
## Every approved Datasedge Meadows point of interest, standing in the world.
##
## The region's POIs existed as reviewed JSON in `content/approved/pois/` and as
## Bit's naming anchors long before anything was built for them — walk to "the
## Seed Vault ruins" and you found bare grass. This builds the missing ones as
## real, collidable props at authored coordinates spread across the 2.4 km
## region, so every place the content database and the companion talk about is
## somewhere you can actually stand.
##
## Sited here (Bootstrap, the mill and the Perceptron Vault are built by their
## own systems): the Seed Vault ruins and the Shrine of First Light, the
## Whispering Well, Hivewise Apiary, the Old Boundary Stones, Ascent Tally
## Knoll, Deepgreen Overlook, the Goose Hoard, the Sluicework Chest, the
## Florist's Lockbox, the Tempering Pool, the Hill-Watcher's Camp, the Sunken
## Granary, the Petal-Broker's Wagon, the Wayfinder's Nook, the Long Fallow, and
## the Thresher's fallow arena.
##
## Geometry is code-only (TownKit primitives + toon materials) so the sites share
## Bootstrap's visual language. Everything samples MeadowTerrain.get_height, so
## props sit on real ground and stay correct if the terrain is retuned.

const SITE_SEED: int = 20260726

## World XZ for every site, in metres. Kept in one table because placement is a
## map-design decision — spacing, sightlines and which quarter of the region a
## discovery belongs to — and reads better reviewed together than scattered
## through the builders.
const SITES: Dictionary = {
	"seed_vault_ruins": Vector2(-320.0, -260.0),
	"shrine_first_light": Vector2(-436.0, -150.0),
	"whispering_well": Vector2(212.0, 62.0),
	"hivewise_apiary": Vector2(332.0, -120.0),
	"boundary_stones": Vector2(150.0, -430.0),
	"ascent_tally_knoll": Vector2(-90.0, -764.0),
	"deepgreen_overlook": Vector2(1046.0, 120.0),
	"goose_hoard": Vector2(140.0, 64.0),
	"sluicework_chest": Vector2(-182.0, 286.0),
	"florists_lockbox": Vector2(-624.0, 60.0),
	"tempering_pool": Vector2(262.0, 782.0),
	"hillwatchers_camp": Vector2(-520.0, -520.0),
	"sunken_granary": Vector2(-762.0, 424.0),
	"petal_brokers_wagon": Vector2(-880.0, -122.0),
	"wayfinders_nook": Vector2(-140.0, 380.0),
	"long_fallow": Vector2(624.0, 520.0),
	"thresher_fallow": Vector2(760.0, -560.0),
}

# Shared palette so the sites read as one region's built environment.
const STONE: Color = Color(0.50, 0.49, 0.45)
const STONE_DARK: Color = Color(0.35, 0.345, 0.32)
const STONE_PALE: Color = Color(0.62, 0.61, 0.56)
const WOOD: Color = Color(0.36, 0.25, 0.15)
const WOOD_PALE: Color = Color(0.55, 0.42, 0.26)
const THATCH: Color = Color(0.62, 0.50, 0.24)
const IRON: Color = Color(0.22, 0.23, 0.25)
const CANVAS: Color = Color(0.72, 0.68, 0.56)
const VAULT_VIOLET: Color = Color(0.55, 0.33, 0.78)

## Blender-authored props, keyed by the name `tools/make_props.py` exports.
## These replace the code-built box assemblies for objects the player walks up
## to: bevelled edges, radial masonry, spoked wheels and shingled roofs are
## worth authoring in a modeller, not stacking out of primitives in GDScript.
## A missing file is not an error — the site simply keeps its blockout, so the
## game still runs from a fresh clone before anyone has run Blender.
const PROP_MODEL_DIR: String = "res://assets/models/props/"

var _terrain: MeadowTerrain
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_terrain = get_node_or_null("../Terrain") as MeadowTerrain
	if _terrain == null:
		push_error("MeadowSites: no sibling Terrain node; sites cannot be placed.")
		return
	_rng.seed = SITE_SEED
	var start_ms: int = Time.get_ticks_msec()

	_build_seed_vault_ruins()
	_build_shrine_of_first_light()
	_build_whispering_well()
	_build_hivewise_apiary()
	_build_boundary_stones()
	_build_ascent_tally_knoll()
	_build_deepgreen_overlook()
	_build_goose_hoard()
	_build_sluicework_chest()
	_build_florists_lockbox()
	_build_tempering_pool()
	_build_hillwatchers_camp()
	_build_sunken_granary()
	_build_petal_brokers_wagon()
	_build_wayfinders_nook()
	_build_long_fallow()
	_build_thresher_fallow()

	print("MeadowSites: %d points of interest raised in %d ms." % [
		SITES.size(), Time.get_ticks_msec() - start_ms,
	])


# ---------------------------------------------------------------- helpers ----

## Ground height at a site, so every prop's origin sits on the real surface.
func _ground(key: String) -> Vector3:
	var flat: Vector2 = SITES[key]
	return Vector3(flat.x, _terrain.get_height(flat.x, flat.y), flat.y)


## Root node for one site: named, positioned on the ground, and registered as a
## Bit landmark so the companion notices and names it on approach.
func _site(key: String, display_name: String, radius: float, lines: Array[String],
		senses: bool = false) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = key.to_pascal_case()
	root.position = _ground(key)
	add_child(root)
	var landmark: BitLandmark = BitLandmark.new()
	landmark.name = "Landmark"
	landmark.configure(key, display_name, radius, lines, senses)
	landmark.position = Vector3(0.0, 1.2, 0.0)
	root.add_child(landmark)
	return root


## A static body carrying one toon box — the workhorse for walls, stones, crates.
func _solid(parent: Node3D, part_name: String, size: Vector3, pos: Vector3,
		color: Color, yaw: float = 0.0) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = part_name
	body.position = pos
	body.rotation.y = yaw
	parent.add_child(body)
	TownKit.part(body, "Mesh", TownKit.box(size), Vector3.ZERO, TownKit.toon(color))
	TownKit.collide_box(body, size, Vector3.ZERO)
	return body


## A rough boulder/rubble lump: a squashed, rotated sphere with no collision
## (small debris the player walks over) or with, for the big blocks.
func _rubble(parent: Node3D, part_name: String, radius: float, pos: Vector3,
		color: Color) -> MeshInstance3D:
	var mesh: SphereMesh = TownKit.ball(radius, 8, 5)
	var mi: MeshInstance3D = TownKit.part(
		parent, part_name, mesh, pos, TownKit.toon(color)
	)
	mi.scale = Vector3(
		_rng.randf_range(0.8, 1.3), _rng.randf_range(0.45, 0.75), _rng.randf_range(0.8, 1.3)
	)
	mi.rotation.y = _rng.randf_range(0.0, TAU)
	return mi


## Instances a Blender-authored prop under `root`, returning true if it loaded.
## Callers use the return value to decide whether to also build the GDScript
## blockout, so the world is never empty if the .glb has not been generated.
func _load_prop(root: Node3D, model_name: String, yaw: float = 0.0,
		prop_scale: float = 1.0) -> bool:
	var path: String = PROP_MODEL_DIR + model_name + ".glb"
	if not ResourceLoader.exists(path):
		return false
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return false
	var prop: Node3D = scene.instantiate() as Node3D
	if prop == null:
		return false
	prop.name = "Model"
	prop.rotation.y = yaw
	prop.scale = Vector3.ONE * prop_scale
	root.add_child(prop)
	_add_prop_collision(root, prop)
	return true


## Props are exported as plain meshes, so they arrive without physics. Rather
## than hand-authoring a shape per prop, this wraps each mesh in a static
## trimesh body — accurate, and correct for objects that never move.
func _add_prop_collision(root: Node3D, prop: Node3D) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "ModelCollision"
	root.add_child(body)
	for child in prop.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = mesh_instance.mesh.create_trimesh_shape()
		shape.transform = prop.transform * mesh_instance.transform
		body.add_child(shape)


## Drops the POI's approved reward items on the ground as real pickups, so a
## discovery pays out what `content/approved/pois/` promises.
func _drop_rewards(root: Node3D, poi_id: String) -> void:
	var poi: Dictionary = ContentDB.get_entry("pois", poi_id)
	if poi.is_empty():
		return
	var rewards: Array = poi.get("reward_items", [])
	for i in rewards.size():
		var item: Dictionary = ContentDB.get_entry("items", String(rewards[i]))
		if item.is_empty():
			continue
		var angle: float = TAU * float(i) / maxf(float(rewards.size()), 1.0)
		ItemPickup.spawn(root, item, root.global_position + Vector3(
			cos(angle) * 1.4, 1.0, sin(angle) * 1.4
		))


# ------------------------------------------------------------------ sites ----

## The shattered stone throat where Kern was found: a broken ring of vault wall
## sunk into the turf, spilled rubble, and a violet gleam still alive in the
## machinery underneath. The region's most story-critical place to stand.
func _build_seed_vault_ruins() -> void:
	var root: Node3D = _site("seed_vault_ruins", "the Seed Vault ruins", 34.0, [
		"The Seed Vault ruins. This is where they found you, Kern. The old machines still stir when you come near — don't ask me how I know. I just do.",
		"Careful in the ruins. The Vault remembers things even you don't.",
	], true)
	# A broken ring: eight wall segments with two deliberate gaps for the throat.
	for i in 8:
		if i == 2 or i == 6:
			continue
		var angle: float = TAU * float(i) / 8.0
		var lean: float = _rng.randf_range(-0.16, 0.16)
		var height: float = _rng.randf_range(3.4, 6.2)
		var wall: StaticBody3D = _solid(
			root, "VaultWall_%d" % i, Vector3(5.4, height, 1.5),
			Vector3(cos(angle) * 11.0, height * 0.5 - 0.6, sin(angle) * 11.0),
			STONE_DARK if i % 2 == 0 else STONE, -angle
		)
		wall.rotation.x = lean
	# The throat itself — a sunken slab mouth angled into the ground.
	var throat: StaticBody3D = _solid(
		root, "VaultThroat", Vector3(7.0, 1.0, 9.0), Vector3(0.0, -0.5, 0.0), STONE_DARK
	)
	throat.rotation.x = -0.22
	TownKit.part(root, "ThroatGlow", TownKit.box(Vector3(4.6, 0.12, 6.4)),
		Vector3(0.0, 0.25, 0.0), TownKit.emissive(VAULT_VIOLET, 1.6, 0.75))
	# Spilled masonry, thickest on the downhill side of the breach.
	for i in 22:
		var angle: float = _rng.randf_range(0.0, TAU)
		var reach: float = _rng.randf_range(7.0, 26.0)
		_rubble(root, "Rubble_%d" % i, _rng.randf_range(0.5, 1.7),
			Vector3(cos(angle) * reach, 0.1, sin(angle) * reach),
			STONE if i % 3 else STONE_PALE)
	_drop_rewards(root, "poi_seed_vault_outer_ruins")


## Shrine 1 of the nine Memory Shrines (WORLDBOOK): where the prologue ends and
## Bit's Vault Sense is granted. A standing plinth with a lit sigil — deliberately
## architectural, set against the ruins' collapse a short walk east.
func _build_shrine_of_first_light() -> void:
	var root: Node3D = _site("shrine_first_light", "the Shrine of First Light", 26.0, [
		"A Memory Shrine — the first one. It's been waiting for you longer than either of us has been awake.",
	], true)
	_solid(root, "ShrineBase", Vector3(7.0, 0.7, 7.0), Vector3(0.0, 0.35, 0.0), STONE_PALE)
	_solid(root, "ShrineStep", Vector3(5.0, 0.5, 5.0), Vector3(0.0, 0.95, 0.0), STONE)
	# Four leaning pillars framing a floating sigil.
	for i in 4:
		var angle: float = TAU * float(i) / 4.0 + PI * 0.25
		var pillar: StaticBody3D = _solid(
			root, "Pillar_%d" % i, Vector3(0.8, 4.6, 0.8),
			Vector3(cos(angle) * 2.4, 3.5, sin(angle) * 2.4), STONE_PALE, angle
		)
		pillar.rotation.z = cos(angle) * 0.06
		pillar.rotation.x = sin(angle) * 0.06
	TownKit.part(root, "Sigil", TownKit.ball(0.85, 14, 9), Vector3(0.0, 4.4, 0.0),
		TownKit.emissive(Color(1.0, 0.93, 0.72), 2.4))
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "ShrineLight"
	light.position = Vector3(0.0, 4.4, 0.0)
	light.light_color = Color(1.0, 0.92, 0.74)
	light.light_energy = 2.2
	light.omni_range = 22.0
	root.add_child(light)


## An old stone well that hums at dusk and rounds your Tokens up if you ask
## nicely. Ring, two posts, a crossbeam, and a bucket on a rope.
func _build_whispering_well() -> void:
	var root: Node3D = _site("whispering_well", "the Whispering Well", 18.0, [
		"Ooh — the Whispering Well! Toss in a Token, make a wish, and it rounds up if you ask nicely. I have tested this thoroughly.",
	], true)
	# The Blender well carries wedge-cut masonry, a shingled roof and a spoked
	# windlass; the box ring below is only the fallback when it is absent.
	if _load_prop(root, "well", 0.35):
		_drop_rewards(root, "poi_whispering_well")
		return
	for i in 12:
		var angle: float = TAU * float(i) / 12.0
		_solid(root, "Ring_%d" % i, Vector3(0.62, 0.95, 0.42),
			Vector3(cos(angle) * 1.5, 0.48, sin(angle) * 1.5),
			STONE if i % 2 == 0 else STONE_DARK, -angle)
	TownKit.part(root, "Water", TownKit.cyl(1.25, 1.25, 0.08),
		Vector3(0.0, 0.2, 0.0), TownKit.emissive(Color(0.22, 0.4, 0.5), 0.35, 0.9))
	_solid(root, "PostL", Vector3(0.22, 2.4, 0.22), Vector3(-1.5, 1.2, 0.0), WOOD)
	_solid(root, "PostR", Vector3(0.22, 2.4, 0.22), Vector3(1.5, 1.2, 0.0), WOOD)
	TownKit.plank(root, "Beam", Vector3(3.4, 0.2, 0.24), Vector3(0.0, 2.45, 0.0), WOOD)
	TownKit.plank(root, "Roof", Vector3(3.8, 0.14, 1.9), Vector3(0.0, 2.72, 0.0), THATCH)
	TownKit.plank(root, "Rope", Vector3(0.05, 1.1, 0.05), Vector3(0.35, 1.9, 0.0), Color(0.6, 0.55, 0.4))
	TownKit.part(root, "Bucket", TownKit.cyl(0.26, 0.22, 0.36),
		Vector3(0.35, 1.2, 0.0), TownKit.toon(WOOD_PALE))
	_drop_rewards(root, "poi_whispering_well")


## Rows of white hives humming like a contented town; the keeper trades in
## honey and rotation lore. Hives are ordered — the bees keep a strict route.
func _build_hivewise_apiary() -> void:
	var root: Node3D = _site("hivewise_apiary", "Hivewise Apiary", 24.0, [
		"Hivewise Apiary. Every bee here has a route and sticks to it. Try to keep up — they will not slow down for you.",
	])
	for row in 3:
		for col in 4:
			var pos: Vector3 = Vector3(-6.0 + float(col) * 4.0, 0.0, -3.5 + float(row) * 3.5)
			var yaw: float = _rng.randf_range(-0.08, 0.08)
			_solid(root, "HiveStand_%d_%d" % [row, col], Vector3(1.2, 0.45, 1.2),
				pos + Vector3(0.0, 0.22, 0.0), WOOD, yaw)
			# Stacked supers, slightly offset — a working hive, not a monument.
			for box_index in 3:
				TownKit.plank(root, "HiveBox_%d_%d_%d" % [row, col, box_index],
					Vector3(1.05, 0.42, 1.05),
					pos + Vector3(_rng.randf_range(-0.05, 0.05), 0.66 + float(box_index) * 0.42, 0.0),
					Color(0.86, 0.85, 0.8), Vector3(0.0, yaw, 0.0))
			TownKit.plank(root, "HiveLid_%d_%d" % [row, col], Vector3(1.22, 0.12, 1.22),
				pos + Vector3(0.0, 1.98, 0.0), Color(0.72, 0.7, 0.66), Vector3(0.0, yaw, 0.0))
	# The keeper's smoker and a leaning skep by the path.
	TownKit.part(root, "Smoker", TownKit.cyl(0.16, 0.2, 0.5),
		Vector3(8.4, 0.25, 1.2), TownKit.toon(IRON))
	TownKit.part(root, "Skep", TownKit.ball(0.7, 10, 6), Vector3(9.2, 0.4, 2.2),
		TownKit.toon(THATCH))
	_drop_rewards(root, "poi_hivewise_apiary")


## Ancient standing stones marking a line nothing visible needs marking. Farmers
## plow around them; offerings left on one side stay on that side.
func _build_boundary_stones() -> void:
	var root: Node3D = _site("boundary_stones", "the Old Boundary Stones", 28.0, [
		"The Old Boundary Stones. They mark a line nobody can see anymore, and the farmers plow around them without asking why. I ask why constantly.",
	])
	# Seven stones on a dead-straight line — the line is the point.
	for i in 7:
		var along: float = (float(i) - 3.0) * 6.5
		var height: float = _rng.randf_range(2.2, 3.8)
		var stone: StaticBody3D = _solid(
			root, "Stone_%d" % i, Vector3(1.5, height, 0.9),
			Vector3(along, height * 0.45 - 0.2, _rng.randf_range(-0.5, 0.5)),
			STONE_DARK if i % 2 == 0 else STONE, _rng.randf_range(-0.2, 0.2)
		)
		stone.rotation.z = _rng.randf_range(-0.13, 0.13)
	# A small offering ledge at the middle stone.
	TownKit.plank(root, "OfferingSlab", Vector3(1.6, 0.2, 1.0), Vector3(0.0, 0.25, 1.3), STONE_PALE)
	_drop_rewards(root, "poi_old_boundary_stones")


## A grassy knob crowned with a cairn — one stone per visitor, leaning north
## toward the peaks. The region's best look at the Gradient Peaks.
func _build_ascent_tally_knoll() -> void:
	var root: Node3D = _site("ascent_tally_knoll", "Ascent Tally Knoll", 30.0, [
		"Ascent Tally Knoll. One stone for every soul who ever meant to climb those peaks. The pile leans north, like it wants to go without us.",
	])
	# A tapering cairn that leans north (-z) as the description promises.
	var courses: int = 11
	for i in courses:
		var t: float = float(i) / float(courses - 1)
		var radius: float = lerpf(1.9, 0.25, t)
		var ring: int = maxi(int(lerpf(7.0, 2.0, t)), 1)
		for j in ring:
			var angle: float = TAU * float(j) / float(ring) + float(i) * 0.5
			TownKit.part(root, "Cairn_%d_%d" % [i, j],
				TownKit.ball(_rng.randf_range(0.22, 0.4), 7, 5),
				Vector3(cos(angle) * radius, 0.25 + t * 3.1, sin(angle) * radius - t * 0.75),
				TownKit.toon(STONE if (i + j) % 3 else STONE_PALE))
	_drop_rewards(root, "poi_ascent_tally_knoll")


## A split-rail fence at the meadow's eastern hem, sagging from generations of
## leaners, looking into the Latent Forest's poured green.
func _build_deepgreen_overlook() -> void:
	var root: Node3D = _site("deepgreen_overlook", "Deepgreen Overlook", 30.0, [
		"Deepgreen Overlook. That treeline is the Latent Forest — bigger inside than out. Lean on the rail a while; everyone does.",
	])
	for i in 9:
		var along: float = (float(i) - 4.0) * 3.2
		_solid(root, "Post_%d" % i, Vector3(0.22, 1.5, 0.22),
			Vector3(along, 0.7, 0.0), WOOD, _rng.randf_range(-0.1, 0.1))
		if i < 8:
			# Rails sag between posts — generations of leaning.
			for rail in 2:
				var rail_mesh: MeshInstance3D = TownKit.plank(
					root, "Rail_%d_%d" % [i, rail], Vector3(3.3, 0.14, 0.1),
					Vector3(along + 1.6, 1.18 - float(rail) * 0.45, 0.0), WOOD_PALE
				)
				rail_mesh.rotation.z = _rng.randf_range(-0.05, 0.05)
	_drop_rewards(root, "poi_deepgreen_overlook")


## A hollow under the millrace bank where Bootstrap's geese bank every shiny
## thing the town has lost — sorted, somehow.
func _build_goose_hoard() -> void:
	var root: Node3D = _site("goose_hoard", "the Goose Hoard", 16.0, [
		"Under that bank — the geese have been hiding the town's lost buttons for years. Sorted by size. I refuse to explain it.",
	], true)
	# A root curtain over a dark hollow in the bank.
	_solid(root, "BankSlab", Vector3(4.6, 1.8, 2.2), Vector3(0.0, 0.6, 0.0), Color(0.32, 0.26, 0.17))
	TownKit.part(root, "Hollow", TownKit.box(Vector3(2.0, 1.1, 0.6)),
		Vector3(0.0, 0.55, 1.05), TownKit.flat(Color(0.05, 0.05, 0.06)))
	for i in 9:
		TownKit.plank(root, "Root_%d" % i, Vector3(0.07, 1.25, 0.07),
			Vector3(-0.95 + float(i) * 0.24, 0.62, 1.16), Color(0.3, 0.22, 0.13),
			Vector3(0.0, 0.0, _rng.randf_range(-0.3, 0.3)))
	# The hoard itself, glinting in the dark.
	for i in 7:
		TownKit.part(root, "Trinket_%d" % i, TownKit.ball(0.09, 6, 4),
			Vector3(_rng.randf_range(-0.7, 0.7), 0.2, 1.0 + _rng.randf_range(-0.15, 0.2)),
			TownKit.emissive(Color(0.95, 0.82, 0.4), 0.8))
	_drop_rewards(root, "poi_goose_hoard")


## An iron-strapped chest in a dry basin at the foot of the irrigation ditches:
## open the gates and water finds its own steepest way down to the lowest sink.
func _build_sluicework_chest() -> void:
	var root: Node3D = _site("sluicework_chest", "the Sluicework", 24.0, [
		"The Sluicework. Open the gates and the water always picks the steepest way down — then pools where it can't sink any lower. Gradient descent, with mud.",
	])
	# Three ditches converging on one basin, each with a gate.
	for i in 3:
		var angle: float = -0.9 + float(i) * 0.9
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		for seg in 5:
			var along: float = 6.0 + float(seg) * 3.4
			TownKit.plank(root, "Ditch_%d_%d" % [i, seg], Vector3(1.9, 0.3, 3.2),
				Vector3(direction.x * along, -0.1, direction.y * along),
				Color(0.34, 0.27, 0.18), Vector3(0.0, -angle, 0.0))
		_solid(root, "Gate_%d" % i, Vector3(1.7, 1.3, 0.22),
			Vector3(direction.x * 5.0, 0.65, direction.y * 5.0), WOOD, -angle)
		TownKit.plank(root, "GateWheel_%d" % i, Vector3(0.5, 0.5, 0.12),
			Vector3(direction.x * 5.0, 1.5, direction.y * 5.0), IRON, Vector3(0.0, -angle, 0.0))
	# The dry basin and its chest.
	TownKit.part(root, "Basin", TownKit.cyl(3.4, 2.6, 0.5), Vector3(0.0, -0.2, 0.0),
		TownKit.toon(Color(0.4, 0.33, 0.22)))
	_build_chest(root, Vector3(0.0, 0.4, 0.0), 0.3)
	_drop_rewards(root, "poi_sluicework_chest")


## A brass lockbox in the iris flats whose four dials are petal length, petal
## width, and two more for the leaves — the Iris dataset, as a lock.
func _build_florists_lockbox() -> void:
	var root: Node3D = _site("florists_lockbox", "the Florist's Lockbox", 16.0, [
		"A lockbox with four dials — petal length, petal width, and two for the leaves. Measure the bloom on the lid and it opens. Someone had a sense of humour.",
	], true)
	var plinth: StaticBody3D = _solid(
		root, "Plinth", Vector3(1.4, 0.5, 1.0), Vector3(0.0, 0.25, 0.0), Color(0.33, 0.28, 0.2)
	)
	plinth.rotation.y = 0.4
	TownKit.part(root, "Box", TownKit.box(Vector3(1.0, 0.6, 0.72)), Vector3(0.0, 0.8, 0.0),
		TownKit.toon(Color(0.66, 0.52, 0.22)), Vector3(0.0, 0.4, 0.0))
	# Four dials in a row along the clasp.
	for i in 4:
		TownKit.part(root, "Dial_%d" % i, TownKit.cyl(0.09, 0.09, 0.06),
			Vector3(-0.3 + float(i) * 0.2, 0.83, 0.37), TownKit.toon(Color(0.78, 0.66, 0.3)),
			Vector3(PI * 0.5, 0.4, 0.0))
	# The live bloom grown over the lid.
	TownKit.part(root, "BloomStem", TownKit.cyl(0.03, 0.03, 0.45), Vector3(0.1, 1.3, -0.1),
		TownKit.toon(Color(0.26, 0.42, 0.16)))
	for i in 5:
		var angle: float = TAU * float(i) / 5.0
		TownKit.part(root, "Petal_%d" % i, TownKit.box(Vector3(0.1, 0.02, 0.26)),
			Vector3(0.1 + cos(angle) * 0.12, 1.52, -0.1 + sin(angle) * 0.12),
			TownKit.toon(Color(0.55, 0.35, 0.7)), Vector3(0.0, angle, 0.4))
	_drop_rewards(root, "poi_florists_lockbox")


## A steaming pool in a fold of the southern downs, rimmed with stones worn
## perfectly smooth. Sink in and every ache "settles to its lowest."
func _build_tempering_pool() -> void:
	var root: Node3D = _site("tempering_pool", "the Tempering Pool", 22.0, [
		"The Tempering Pool. Shepherds say you sit still and let every ache settle to its lowest. I say it's a hot puddle, but a very good one.",
	])
	TownKit.part(root, "Water", TownKit.cyl(3.6, 3.0, 0.3), Vector3(0.0, 0.05, 0.0),
		TownKit.emissive(Color(0.34, 0.58, 0.6), 0.5, 0.88))
	for i in 16:
		var angle: float = TAU * float(i) / 16.0
		var stone: MeshInstance3D = _rubble(root, "RimStone_%d" % i,
			_rng.randf_range(0.45, 0.75),
			Vector3(cos(angle) * 4.0, 0.1, sin(angle) * 4.0), STONE_PALE)
		stone.scale.y *= 0.6
	var steam: GPUParticles3D = TownKit.smoke(9.0, 1.5, Color(0.9, 0.94, 0.95))
	steam.name = "Steam"
	steam.position = Vector3(0.0, 0.3, 0.0)
	root.add_child(steam)
	_drop_rewards(root, "poi_tempering_pool")


## A patched tent, a kettle, and a hermit who forecasts weather by asking the
## five nearest hills what they did last time — k-nearest neighbours, in a coat.
func _build_hillwatchers_camp() -> void:
	var root: Node3D = _site("hillwatchers_camp", "the Hill-Watcher's Camp", 24.0, [
		"The Hill-Watcher. He forecasts weather by asking the five nearest hills what they did last time, and he is almost never wrong. Nobody knows why. He least of all.",
	])
	# A-frame tent: two leaning panels and a ridge pole.
	for side in 2:
		var sign: float = 1.0 if side == 0 else -1.0
		var panel: MeshInstance3D = TownKit.plank(
			root, "TentPanel_%d" % side, Vector3(3.6, 0.1, 2.9),
			Vector3(sign * 0.85, 1.0, 0.0), CANVAS, Vector3(sign * 0.95, 0.0, 0.0)
		)
		panel.rotation = Vector3(0.0, 0.0, sign * 0.95)
	TownKit.plank(root, "Ridge", Vector3(3.7, 0.1, 0.1), Vector3(0.0, 2.0, 0.0), WOOD)
	# Fire ring, kettle on a tripod, and a log to sit on.
	for i in 9:
		var angle: float = TAU * float(i) / 9.0
		_rubble(root, "FireStone_%d" % i, 0.26,
			Vector3(3.4 + cos(angle) * 1.0, 0.1, sin(angle) * 1.0), STONE_DARK)
	TownKit.part(root, "Embers", TownKit.cyl(0.55, 0.55, 0.1), Vector3(3.4, 0.12, 0.0),
		TownKit.emissive(Color(1.0, 0.45, 0.14), 1.4))
	for i in 3:
		var angle: float = TAU * float(i) / 3.0
		TownKit.plank(root, "Tripod_%d" % i, Vector3(0.07, 1.5, 0.07),
			Vector3(3.4 + cos(angle) * 0.45, 0.75, sin(angle) * 0.45), WOOD,
			Vector3(sin(angle) * 0.3, 0.0, -cos(angle) * 0.3))
	TownKit.part(root, "Kettle", TownKit.ball(0.3, 9, 6), Vector3(3.4, 1.05, 0.0),
		TownKit.toon(IRON))
	TownKit.part(root, "SitLog", TownKit.cyl(0.32, 0.32, 2.4), Vector3(5.4, 0.32, 1.4),
		TownKit.toon(WOOD), Vector3(0.0, 0.0, PI * 0.5))
	_drop_rewards(root, "poi_hillwatchers_camp")


## A collapsed stone granary half-swallowed by turf — the cooperative that
## stocked nothing but turnips because one turnip year "worked once."
func _build_sunken_granary() -> void:
	var root: Node3D = _site("sunken_granary", "the Sunken Granary", 26.0, [
		"The Sunken Granary. One good turnip year, so they planted nothing but turnips forever after. It worked once, so it must always. It did not.",
	], true)
	# A ring wall sunk and broken open on one side, roof caved into it.
	for i in 12:
		if i == 4 or i == 5:
			continue
		var angle: float = TAU * float(i) / 12.0
		var height: float = _rng.randf_range(1.6, 3.4)
		var wall: StaticBody3D = _solid(
			root, "GranaryWall_%d" % i, Vector3(2.4, height, 1.1),
			Vector3(cos(angle) * 5.0, height * 0.4 - 0.7, sin(angle) * 5.0),
			STONE if i % 2 else STONE_DARK, -angle
		)
		wall.rotation.x = _rng.randf_range(-0.2, 0.2)
	var roof: MeshInstance3D = TownKit.part(
		root, "CavedRoof", TownKit.cyl(0.2, 4.4, 2.6), Vector3(0.6, 0.7, 0.4),
		TownKit.toon(THATCH)
	)
	roof.rotation = Vector3(0.5, 0.3, 0.35)
	for i in 14:
		var angle: float = _rng.randf_range(0.0, TAU)
		_rubble(root, "GranaryRubble_%d" % i, _rng.randf_range(0.35, 0.9),
			Vector3(cos(angle) * _rng.randf_range(3.0, 11.0), 0.1,
				sin(angle) * _rng.randf_range(3.0, 11.0)), STONE)
	_drop_rewards(root, "poi_sunken_granary")


## A green wagon parked deep in the iris flats, found mostly by accident. The
## broker buys petals — but only with their measurements neatly noted.
func _build_petal_brokers_wagon() -> void:
	var root: Node3D = _site("petal_brokers_wagon", "the Petal-Broker's Wagon", 20.0, [
		"The Petal-Broker! She pays triple for a bloom that refuses to classify. I have opinions about which of us that describes.",
	])
	# The Blender wagon has a swept canvas tilt and real spoked wheels.
	if _load_prop(root, "wagon", -0.6):
		_drop_rewards(root, "poi_petal_brokers_wagon")
		return
	_solid(root, "WagonBed", Vector3(3.6, 1.1, 2.0), Vector3(0.0, 1.05, 0.0), Color(0.2, 0.42, 0.26))
	# Canvas tilt: five hoops with a cover over them.
	for i in 5:
		var hoop: MeshInstance3D = TownKit.part(
			root, "Hoop_%d" % i, TownKit.cyl(1.05, 1.05, 0.08),
			Vector3(-1.4 + float(i) * 0.7, 2.05, 0.0), TownKit.toon(WOOD),
			Vector3(0.0, 0.0, PI * 0.5)
		)
		hoop.scale.z = 0.06
	TownKit.part(root, "Tilt", TownKit.cyl(1.15, 1.15, 3.4), Vector3(0.0, 2.05, 0.0),
		TownKit.toon(CANVAS), Vector3(0.0, 0.0, PI * 0.5))
	for side in 2:
		var sign: float = 1.0 if side == 0 else -1.0
		for wheel in 2:
			var along: float = -1.2 + float(wheel) * 2.4
			var w: MeshInstance3D = TownKit.part(
				root, "Wheel_%d_%d" % [side, wheel], TownKit.cyl(0.62, 0.62, 0.14),
				Vector3(along, 0.6, sign * 1.05), TownKit.toon(WOOD_PALE),
				Vector3(0.0, 0.0, PI * 0.5)
			)
			w.rotation.x = PI * 0.5
	# The trade counter: a fold-down board with sample blooms pinned to it.
	TownKit.plank(root, "Counter", Vector3(1.8, 0.1, 0.9), Vector3(2.4, 1.1, 0.0), WOOD_PALE,
		Vector3(0.0, 0.0, -0.12))
	for i in 3:
		TownKit.part(root, "Sample_%d" % i, TownKit.ball(0.13, 7, 5),
			Vector3(2.1 + float(i) * 0.34, 1.28, 0.0),
			TownKit.toon([Color(0.5, 0.32, 0.68), Color(0.72, 0.62, 0.86), Color(0.34, 0.3, 0.6)][i]))
	_drop_rewards(root, "poi_petal_brokers_wagon")


## A knee-high roadside shrine with a carved wooden face worn kind by weather.
## However it is turned overnight, by morning it faces the road again.
func _build_wayfinders_nook() -> void:
	var root: Node3D = _site("wayfinders_nook", "the Wayfinder's Nook", 18.0, [
		"The Wayfinder's Nook. Turn the little face any way you like — come morning it's looking down the road again, waiting for someone to need it.",
	])
	_solid(root, "NookBase", Vector3(1.1, 0.5, 1.1), Vector3(0.0, 0.25, 0.0), STONE)
	# A small hooded box, open to the road.
	_solid(root, "NookBack", Vector3(0.9, 1.0, 0.14), Vector3(0.0, 1.0, -0.38), WOOD)
	_solid(root, "NookSideL", Vector3(0.14, 1.0, 0.7), Vector3(-0.38, 1.0, 0.0), WOOD)
	_solid(root, "NookSideR", Vector3(0.14, 1.0, 0.7), Vector3(0.38, 1.0, 0.0), WOOD)
	TownKit.part(root, "NookRoof", TownKit.prism(Vector3(1.25, 0.45, 1.0)),
		Vector3(0.0, 1.72, 0.0), TownKit.toon(THATCH))
	# The carved face, turned to the road.
	TownKit.part(root, "Face", TownKit.ball(0.26, 10, 7), Vector3(0.0, 1.0, 0.0),
		TownKit.toon(WOOD_PALE))
	for i in 2:
		TownKit.part(root, "Eye_%d" % i, TownKit.ball(0.045, 6, 4),
			Vector3(-0.09 + float(i) * 0.18, 1.06, 0.21), TownKit.toon(Color(0.15, 0.12, 0.1)))
	# Tokens left by farmers trying a new way to town.
	for i in 4:
		TownKit.part(root, "Token_%d" % i, TownKit.cyl(0.06, 0.06, 0.02),
			Vector3(_rng.randf_range(-0.25, 0.25), 0.52, _rng.randf_range(0.1, 0.35)),
			TownKit.emissive(Color(0.9, 0.76, 0.35), 0.5))
	_drop_rewards(root, "poi_wayfinders_nook")


## A field no one farms, mown anyway in perfectly straight rows by something
## heavy and methodical in the night. A scarred oak chest sits mid-field.
func _build_long_fallow() -> void:
	var root: Node3D = _site("long_fallow", "the Long Fallow", 40.0, [
		"The Long Fallow. Nobody farms it, and yet it's mown — dead straight rows, cut in the night by something heavy. We are absolutely not staying till dark.",
	])
	# The rows themselves: long, low, dead-parallel cut lines.
	for i in 14:
		TownKit.plank(root, "CutRow_%d" % i, Vector3(0.9, 0.06, 74.0),
			Vector3(-26.0 + float(i) * 4.0, 0.03, 0.0), Color(0.44, 0.4, 0.2))
	_build_chest(root, Vector3(0.0, 0.4, 0.0), -0.2)
	# A snapped scythe-blade left in the turf — the only thing it ever dropped.
	var blade: MeshInstance3D = TownKit.part(
		root, "BrokenBlade", TownKit.box(Vector3(0.1, 0.05, 1.5)), Vector3(3.2, 0.3, 2.0),
		TownKit.toon(IRON)
	)
	blade.rotation = Vector3(0.0, 0.7, 0.5)
	_drop_rewards(root, "poi_long_fallow_chest")


## The Thresher's ground (WORLDBOOK world boss): a vast fallow where the rogue
## harvest colossus only ever charges in straight rows. The arena is built now;
## the boss itself waits on the world-boss milestone.
func _build_thresher_fallow() -> void:
	var root: Node3D = _site("thresher_fallow", "the Thresher's Fallow", 46.0, [
		"Careful. Those cut lines are fresh, and they only ever run straight. Whatever makes them does not turn quickly — remember that if it wakes.",
	])
	# Cut lines radiating in three sheared directions — its charge lanes.
	for lane in 3:
		var yaw: float = -0.5 + float(lane) * 0.5
		for i in 6:
			TownKit.plank(root, "Lane_%d_%d" % [lane, i], Vector3(1.6, 0.05, 90.0),
				Vector3(-14.0 + float(i) * 5.6, 0.03, 0.0), Color(0.46, 0.41, 0.2),
				Vector3(0.0, yaw, 0.0))
	# Wrecked harvest gear at the field's edge: this thing has been fought before.
	for i in 5:
		var angle: float = _rng.randf_range(0.0, TAU)
		var reach: float = _rng.randf_range(16.0, 30.0)
		var wreck: MeshInstance3D = TownKit.part(
			root, "Wreck_%d" % i, TownKit.box(Vector3(
				_rng.randf_range(0.8, 2.4), _rng.randf_range(0.3, 0.8), _rng.randf_range(0.6, 1.8)
			)), Vector3(cos(angle) * reach, 0.3, sin(angle) * reach), TownKit.toon(IRON)
		)
		wreck.rotation = Vector3(
			_rng.randf_range(-0.4, 0.4), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.4, 0.4)
		)
	# A warning cairn the farmers keep rebuilding at the safe edge.
	for i in 5:
		_rubble(root, "WarnStone_%d" % i, _rng.randf_range(0.3, 0.5),
			Vector3(-30.0, 0.2 + float(i) * 0.42, 22.0), STONE_DARK)


## The region's shared treasure chest: iron-strapped oak with a lid.
func _build_chest(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var chest: StaticBody3D = StaticBody3D.new()
	chest.name = "Chest"
	chest.position = pos
	chest.rotation.y = yaw
	parent.add_child(chest)
	TownKit.part(chest, "Body", TownKit.box(Vector3(1.3, 0.8, 0.85)), Vector3.ZERO,
		TownKit.toon(WOOD))
	TownKit.part(chest, "Lid", TownKit.box(Vector3(1.36, 0.18, 0.9)), Vector3(0.0, 0.48, 0.0),
		TownKit.toon(WOOD_PALE))
	for i in 2:
		TownKit.part(chest, "Strap_%d" % i, TownKit.box(Vector3(0.1, 0.95, 0.9)),
			Vector3(-0.4 + float(i) * 0.8, 0.1, 0.0), TownKit.toon(IRON))
	TownKit.part(chest, "Lock", TownKit.box(Vector3(0.2, 0.24, 0.12)), Vector3(0.0, 0.18, 0.45),
		TownKit.toon(Color(0.72, 0.6, 0.26)))
	TownKit.collide_box(chest, Vector3(1.3, 0.98, 0.85), Vector3(0.0, 0.1, 0.0))
