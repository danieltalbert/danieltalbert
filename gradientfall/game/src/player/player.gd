class_name Player
extends CharacterBody3D
## Kern's third-person character controller — Phase 1 milestone 2.
##
## Feel targets (the "feel pass"): responsive starts (high ground accel),
## no ice on stop (decel above accel), a BOTW-ish jump arc (floatier rise,
## heavier fall, early-release cut), coyote time + a jump buffer so hops
## never feel stolen, camera-relative movement, the body turning smoothly
## toward travel direction, and a visual-only squash/stretch on jump/land.
## All tunables are consts up top — the numbers ARE the feel pass.

const WALK_SPEED: float = 4.0
const RUN_SPEED: float = 7.5
const GROUND_ACCEL: float = 30.0
const GROUND_DECEL: float = 42.0
const AIR_ACCEL: float = 12.0
const JUMP_VELOCITY: float = 8.5  # ~1.5 m apex with RISE_GRAVITY
const RISE_GRAVITY: float = 24.0
const FALL_GRAVITY: float = 34.0
const MAX_FALL_SPEED: float = 40.0
const JUMP_CUT_FACTOR: float = 0.45  # early release trims the arc
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER: float = 0.15
const TURN_SPEED: float = 12.0
const SQUASH_MIN_AIR_TIME: float = 0.2  # no squash for curb-sized drops
const KNOCKBACK_DECAY: float = 7.0
const DOWNED_TIME: float = 1.4          # come-apart → reform beat
const REFORM_IFRAMES: float = 1.6
## Metres Kern may be below the analytic ground before the guard hauls him out.
## Trimesh collision can be tunnelled through at high fall speed, on a steep
## slope, or where two surfaces meet (the terrain/mountain seam); when that
## happens the player falls forever with no way back. The terrain's own
## get_height() is the ground truth, so we can always find the surface again.
## The threshold is loose enough that legitimately being under an overhang or
## inside the Perceptron Vault never trips it.
const FALL_THROUGH_TOLERANCE: float = 3.0
## Metres above the recovered surface Kern is placed when the guard fires.
const RECOVERY_CLEARANCE: float = 1.2

var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _air_time: float = 0.0
var _was_on_floor: bool = true
var _scale_tween: Tween
var _knockback: Vector3 = Vector3.ZERO
var _downed: bool = false
## Resolved once, lazily: the two surfaces that know their own analytic height.
var _terrain: MeadowTerrain
var _peaks: GradientPeaks
var _surfaces_resolved: bool = false

@onready var _visual: Node3D = $Visual
@onready var _rig: CameraRig = $CameraRig
@onready var _health: Health = $Health
@onready var _combat: PlayerCombat = $Combat


func _ready() -> void:
	InputSetup.ensure()
	_rig.setup(self)
	add_to_group(&"player")
	add_to_group(&"hittable")
	_health.invuln_after_hit = 0.5
	_health.setup(float(GameState.hearts_max), true)
	_health.changed.connect(_on_health_changed)
	_health.died.connect(_on_health_died)
	_combat.setup(self, _visual, _rig, _health)
	EventBus.player_spawned.emit(self)


## Re-announce hearts so a HUD created after us (main.gd) shows the right value.
func broadcast_hearts() -> void:
	EventBus.player_hearts_changed.emit(_health.current, _health.max_hearts)


func _on_health_changed(current: float, max_hearts: float) -> void:
	EventBus.player_hearts_changed.emit(current, max_hearts)


func _physics_process(delta: float) -> void:
	# The grass field parts around Kern (grass_field.gdshader trample).
	RenderingServer.global_shader_parameter_set(&"gf_player_pos", global_position)
	if _downed:
		_apply_gravity(delta)
		var h: Vector2 = Vector2(velocity.x, velocity.z).move_toward(Vector2.ZERO, GROUND_DECEL * delta)
		velocity.x = h.x
		velocity.z = h.y
		move_and_slide()
		return
	_combat.tick(delta)
	_tick_timers(delta)
	_apply_gravity(delta)
	if not _combat.blocks_jump():
		_handle_jump()
	_handle_move(delta)
	_apply_knockback(delta)
	move_and_slide()
	_guard_against_falling_through()
	_handle_landing()
	_was_on_floor = is_on_floor()


## Safety net against tunnelling through the world.
##
## Collision here is a trimesh generated from the terrain and the mountain
## heightfields; a fast fall, a steep face, or the seam where the two surfaces
## meet can let a capsule slip through, after which the player falls out of the
## world with no recovery. Both surfaces can answer "how high is the ground at
## (x, z)?" analytically, so we ask, and if Kern is meaningfully below that
## answer we lift him back out and kill the downward velocity.
##
## Deliberately tolerant (FALL_THROUGH_TOLERANCE): this must never fight
## legitimate below-surface play such as the Perceptron Vault's sunken floor.
func _guard_against_falling_through() -> void:
	if not _surfaces_resolved:
		_resolve_surfaces()
	var surface_y: float = _surface_height(global_position.x, global_position.z)
	if is_inf(surface_y) or global_position.y >= surface_y - FALL_THROUGH_TOLERANCE:
		return
	global_position.y = surface_y + RECOVERY_CLEARANCE
	velocity.y = 0.0
	push_warning("Player: recovered from a fall through the world at (%.1f, %.1f)." % [
		global_position.x, global_position.z,
	])


## Caches the terrain and mountain surfaces. Looked up by node path rather than
## injected so the controller keeps working in scenes that have neither (the
## dev harnesses), where the guard simply never fires.
func _resolve_surfaces() -> void:
	_surfaces_resolved = true
	var world: Node = get_parent().get_node_or_null("World")
	if world == null:
		return
	_terrain = world.get_node_or_null("Terrain") as MeadowTerrain
	_peaks = world.get_node_or_null("Vistas/ClimbablePeaks") as GradientPeaks


## Analytic ground height, or INF where nothing authoritative covers this point
## (outside the region, where the guard must stay out of the way).
func _surface_height(x: float, z: float) -> float:
	if _peaks != null and _peaks.in_bounds(x, z):
		return _peaks.get_height(x, z)
	if _terrain != null and absf(x) <= MeadowTerrain.SIZE * 0.5 \
			and absf(z) <= MeadowTerrain.SIZE * 0.5:
		return _terrain.get_height(x, z)
	return INF


func _apply_knockback(delta: float) -> void:
	if _knockback.length_squared() < 0.0001:
		return
	velocity.x += _knockback.x
	velocity.z += _knockback.z
	_knockback = _knockback.lerp(Vector3.ZERO, 1.0 - exp(-KNOCKBACK_DECAY * delta))


func _tick_timers(delta: float) -> void:
	_coyote_left = maxf(0.0, _coyote_left - delta)
	_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)
	if is_on_floor():
		_coyote_left = COYOTE_TIME
		_air_time = 0.0
	else:
		_air_time += delta
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_left = JUMP_BUFFER


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var gravity: float = RISE_GRAVITY if velocity.y > 0.0 else FALL_GRAVITY
	velocity.y = maxf(velocity.y - gravity * delta, -MAX_FALL_SPEED)


func _handle_jump() -> void:
	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		_play_scale(Vector3(0.92, 1.1, 0.92))
	if velocity.y > 0.0 and Input.is_action_just_released(&"jump"):
		velocity.y *= JUMP_CUT_FACTOR


func _handle_move(delta: float) -> void:
	# A dodge roll drives velocity directly; skip normal steering this frame.
	if _combat.use_velocity_override:
		var ov: Vector3 = _combat.velocity_override
		velocity.x = ov.x
		velocity.z = ov.z
		_face_yaw(_combat.facing_yaw, delta)
		return

	var input_vec: Vector2 = Input.get_vector(
		&"move_left", &"move_right", &"move_forward", &"move_back"
	)
	var cam_basis: Basis = _rig.global_transform.basis
	var forward: Vector3 = -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = cam_basis.x
	right.y = 0.0
	right = right.normalized()
	var dir: Vector3 = right * input_vec.x - forward * input_vec.y
	if dir.length_squared() > 1.0:
		dir = dir.normalized()

	# Combat trims the top speed (0 mid-swing, a crawl while guarding).
	var base_speed: float = RUN_SPEED if Input.is_action_pressed(&"sprint") else WALK_SPEED
	var top_speed: float = base_speed * _combat.move_scale
	var target: Vector2 = Vector2(dir.x, dir.z) * top_speed
	var horizontal: Vector2 = Vector2(velocity.x, velocity.z)
	var accel: float = GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	if is_on_floor() and target.length_squared() < horizontal.length_squared():
		accel = GROUND_DECEL
	horizontal = horizontal.move_toward(target, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y

	if _combat.lock_facing:
		# Face the swing/guard/aim direction chosen by combat.
		_face_yaw(_combat.facing_yaw, delta, 1.4)
	elif dir.length_squared() > 0.0001:
		# Model forward is -Z (Godot convention), hence the negations.
		_face_yaw(atan2(-dir.x, -dir.z), delta)


func _face_yaw(yaw: float, delta: float, rate_mul: float = 1.0) -> void:
	_visual.rotation.y = lerp_angle(
		_visual.rotation.y, yaw, minf(1.0, TURN_SPEED * rate_mul * delta)
	)


func _handle_landing() -> void:
	if is_on_floor() and not _was_on_floor and _air_time > SQUASH_MIN_AIR_TIME:
		_play_scale(Vector3(1.12, 0.85, 1.12))


func _play_scale(from_scale: Vector3) -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_visual.scale = from_scale
	_scale_tween = create_tween()
	_scale_tween.set_trans(Tween.TRANS_BACK)
	_scale_tween.set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(_visual, "scale", Vector3.ONE, 0.18)


# --- Taking damage (group "hittable"; called by enemy melee & projectiles) ---

func apply_hit(amount: float, from_position: Vector3, knockback: float) -> void:
	if _downed or _health.is_invulnerable():
		return
	var dmg: float = amount
	if _combat.block_active():
		dmg = amount * _combat.on_blocked(from_position)
		if dmg <= 0.0:
			return  # fully parried or guarded head-on
	if not _health.apply(dmg, from_position):
		return
	var away: Vector3 = global_position - from_position
	away.y = 0.0
	if away.length() > 0.01:
		_knockback = away.normalized() * knockback
	EventBus.player_hit.emit(dmg)
	EventBus.combat_shake.emit(0.16)


func _on_health_died() -> void:
	if _downed:
		return
	# All-ages: Kern doesn't die, he comes apart and reforms (GDD tone).
	_downed = true
	_knockback = Vector3.ZERO
	EventBus.player_died.emit()
	EventBus.combat_shake.emit(0.45)
	DamageShards.burst(get_tree().current_scene, global_position + Vector3(0.0, 0.9, 0.0),
		Color(0.62, 0.82, 1.0), 26, 5.0, 2.6, 1.2)
	_visual.visible = false
	get_tree().create_timer(DOWNED_TIME).timeout.connect(_reform)


func _reform() -> void:
	_health.refill()
	_health.grant_iframes(REFORM_IFRAMES)
	_visual.visible = true
	_visual.scale = Vector3.ONE
	_downed = false
	EventBus.player_reformed.emit()
