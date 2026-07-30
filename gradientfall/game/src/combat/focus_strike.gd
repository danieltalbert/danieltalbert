class_name FocusStrike
extends Node3D
## The combined Kern + Bit strike — the climax of the knowledge channel
## (Phase 1 milestone 7). Fire-and-forget: `FocusStrike.fire(world, origin)`
## spawns one, plays out, and frees itself.
##
## This is the payoff for a cast the player earned by answering questions, so it
## reads as two forces meeting rather than one explosion: Bit's motes spiral IN
## and collapse to the point where Kern strikes, a column of light goes up, and
## the shockwave rings go OUT along the ground to exactly `SPECIAL_RADIUS` —
## the same radius that actually damages, so the ring TEACHES the hitbox instead
## of decorating it. A brief omni flash lights the real world geometry, which is
## what stops the effect reading as a flat decal pasted over the meadow.
##
## Everything is built in code from primitive meshes and unshaded additive
## materials (project rule: no imported assets), so it renders identically
## everywhere and costs nothing to load.
##
## Timing runs on SCALED delta on purpose. `PlayerCombat._try_special` fires a
## hitstop at the same moment, so the first ~90 ms of this effect plays at 0.05
## speed and then snaps to full — the nova blooms in slow motion exactly as the
## hit lands. That is the intent, not an oversight.

const RING_TIME: float = 0.55       ## shockwave ring: spawn → gone
const RING_TIME_INNER: float = 0.34 ## the second, faster ring
const COLUMN_TIME: float = 0.30     ## vertical light column
const MOTE_TIME: float = 0.30       ## Bit's motes collapsing inward
const FLASH_TIME: float = 0.28      ## omni light flash
const MOTE_COUNT: int = 14
const MOTE_START_RADIUS: float = 3.1
const RING_HEIGHT: float = 0.55     ## the sward is tall; ride above it
const COLUMN_HEIGHT: float = 7.0
const FLASH_ENERGY: float = 11.0

const COL_GOLD: Color = Color(1.0, 0.86, 0.42)  ## Kern's focus
const COL_BLUE: Color = Color(0.62, 0.83, 1.0)  ## Bit's light

var _age: float = 0.0
var _radius: float = 1.0

var _ring: MeshInstance3D
var _ring_inner: MeshInstance3D
var _column: MeshInstance3D
var _flash: OmniLight3D
var _motes: Array[MeshInstance3D] = []
var _mote_angles: PackedFloat32Array = []

var _ring_mat: StandardMaterial3D
var _ring_inner_mat: StandardMaterial3D
var _column_mat: StandardMaterial3D
var _mote_mat: StandardMaterial3D


## Spawns the strike at `world_position`. `radius` should be the special's real
## damage radius so the shockwave ring lands exactly on what it hit.
static func fire(host: Node, world_position: Vector3, radius: float) -> void:
	if host == null or not host.is_inside_tree():
		return
	var fx: FocusStrike = FocusStrike.new()
	host.add_child(fx)
	fx.global_position = world_position
	fx._build(radius)


func _build(radius: float) -> void:
	_radius = maxf(radius, 0.5)

	# Ground shockwave. A torus already lies flat in XZ in Godot, so it needs no
	# rotation — it is scaled outward each frame rather than rebuilt.
	_ring_mat = _additive(COL_GOLD, 3.4)
	_ring = _ring_mesh(_ring_mat, 0.962, 1.0)
	_ring_inner_mat = _additive(COL_BLUE, 4.2)
	_ring_inner = _ring_mesh(_ring_inner_mat, 0.975, 1.0)

	# The column: Kern's strike going up out of the collapse point.
	_column_mat = _additive(COL_GOLD.lerp(COL_BLUE, 0.35), 2.2)
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.015         # tapers to a point — a blade, not a pipe
	cyl.bottom_radius = 0.30
	cyl.height = COLUMN_HEIGHT
	cyl.radial_segments = 14
	_column = MeshInstance3D.new()
	_column.mesh = cyl
	_column.material_override = _column_mat
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_column.position = Vector3(0.0, COLUMN_HEIGHT * 0.5, 0.0)
	add_child(_column)

	# Bit's motes: they start out at arm's length and collapse to the centre,
	# so the strike reads as her light being spent into Kern's blow.
	_mote_mat = _additive(COL_BLUE, 2.4)
	var mote_mesh: BoxMesh = BoxMesh.new()
	mote_mesh.size = Vector3(0.16, 0.16, 0.16)
	for i: int in MOTE_COUNT:
		var mote: MeshInstance3D = MeshInstance3D.new()
		mote.mesh = mote_mesh
		mote.material_override = _mote_mat
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mote)
		_motes.append(mote)
		_mote_angles.append(TAU * float(i) / float(MOTE_COUNT) + randf() * 0.4)

	# The flash is what makes it look like it happened IN the meadow: it lights
	# the real grass and Kern rather than floating over them.
	_flash = OmniLight3D.new()
	_flash.light_color = COL_GOLD
	_flash.light_energy = FLASH_ENERGY
	_flash.omni_range = _radius * 2.6
	_flash.shadow_enabled = false
	_flash.position = Vector3(0.0, 1.0, 0.0)
	add_child(_flash)


func _process(delta: float) -> void:
	_age += delta
	_tick_ring(_ring, _ring_mat, RING_TIME, 0.9, 3.4)
	_tick_ring(_ring_inner, _ring_inner_mat, RING_TIME_INNER, 0.55, 4.2)
	_tick_column(delta)
	_tick_motes()
	_tick_flash()
	if _age >= maxf(RING_TIME, COLUMN_TIME):
		queue_free()


## Expands one ring from the strike point out to the damage radius, easing out
## so it leaves fast and settles — a shockwave, not a balloon.
func _tick_ring(ring: MeshInstance3D, mat: StandardMaterial3D, life: float,
		reach: float, energy: float) -> void:
	var t: float = clampf(_age / life, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 2.6)
	var r: float = lerpf(0.2, _radius * reach, eased)
	ring.scale = Vector3(r, 1.0 - t * 0.6, r)
	mat.albedo_color.a = 1.0 - t
	mat.emission_energy_multiplier = energy * (1.0 - t)
	ring.visible = t < 1.0


func _tick_column(delta: float) -> void:
	var t: float = clampf(_age / COLUMN_TIME, 0.0, 1.0)
	# Punches up instantly, then thins away rather than shrinking uniformly.
	var rise: float = 1.0 - pow(1.0 - t, 3.0)
	_column.scale = Vector3(1.0 - t * 0.75, clampf(rise * 1.15, 0.05, 1.0), 1.0 - t * 0.75)
	_column.position.y = COLUMN_HEIGHT * 0.5 * _column.scale.y
	_column.rotate_y(delta * 5.5)
	_column_mat.albedo_color.a = 1.0 - t
	_column.visible = t < 1.0


func _tick_motes() -> void:
	var t: float = clampf(_age / MOTE_TIME, 0.0, 1.0)
	var pull: float = 1.0 - pow(1.0 - t, 2.2)   # accelerates as it collapses
	var r: float = lerpf(MOTE_START_RADIUS, 0.0, pull)
	for i: int in _motes.size():
		var mote: MeshInstance3D = _motes[i]
		# Spirals rather than falling straight in — Bit orbits, she doesn't drop.
		var angle: float = _mote_angles[i] + pull * 3.4
		mote.position = Vector3(cos(angle) * r, lerpf(1.7, 0.9, pull), sin(angle) * r)
		mote.scale = Vector3.ONE * (1.0 - t * 0.5)
		mote.visible = t < 1.0
	_mote_mat.albedo_color.a = 1.0 - t * t


func _tick_flash() -> void:
	var t: float = clampf(_age / FLASH_TIME, 0.0, 1.0)
	# Squared falloff: a hard pop that decays, not a lamp being dimmed.
	_flash.light_energy = FLASH_ENERGY * pow(1.0 - t, 2.0)
	_flash.visible = t < 1.0


# --- Builders ----------------------------------------------------------------

func _ring_mesh(mat: StandardMaterial3D, inner: float, outer: float) -> MeshInstance3D:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 28
	torus.ring_segments = 5
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = torus
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Clear of the SWARD, not the ground: the meadow's photoreal blades stand
	# well above the terrain, and a ring at ankle height expands invisibly
	# inside the grass.
	mi.position = Vector3(0.0, 0.55, 0.0)
	add_child(mi)
	return mi


## Unshaded + additive so the effect reads as light rather than as a painted
## object, and so it never picks up the meadow's shading (DamageShards uses the
## same treatment — the two are meant to look like one family).
func _additive(color: Color, energy: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	return mat
