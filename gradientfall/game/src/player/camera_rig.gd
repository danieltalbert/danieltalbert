class_name CameraRig
extends Node3D
## Kern's camera: first-person by default, third-person orbit on demand.
##
## Yaw lives on this node, pitch on the SpringArm3D. The rig is top_level — it
## follows the player by position (smoothed) and never inherits the body's
## rotation, so the camera stays put while Kern turns.
##
## **First person is the default view** (Danny's call): the arm collapses to
## zero length so the camera sits exactly at eye height, Kern's body is hidden
## so we are never looking out from inside his own head, and the pitch range
## opens up to a full look-up/look-down. Mouse moves the view the conventional
## way — mouse up looks up, mouse right looks right, no inversion. **V** (or
## clicking the right stick) toggles to the third-person orbit and back.
##
## Third person keeps the spring arm, which shortens through geometry so the
## camera never ends up inside a hill or a wall — the "seeing through the
## ground" failure. Its margin is deliberately generous for the same reason:
## the camera stops short of surfaces instead of grazing their back faces,
## which are invisible on single-sided terrain.

const MOUSE_SENSITIVITY: float = 0.003
const STICK_SENSITIVITY: float = 2.6  # radians/second at full deflection
## Third-person pitch stays modest so the orbit never looks straight down the
## character's head; first person gets the full human range.
const PITCH_MIN_THIRD: float = -1.1
const PITCH_MAX_THIRD: float = 0.5
const PITCH_MIN_FIRST: float = -1.45
const PITCH_MAX_FIRST: float = 1.45
## Eye height above Kern's feet, in metres — the camera's home in first person.
const EYE_HEIGHT: float = 1.62
## Third person orbits from a slightly lower pivot so the shoulder framing reads.
const FOLLOW_HEIGHT: float = 1.65
const THIRD_PERSON_DISTANCE: float = 5.0
## Metres the spring arm keeps between the camera and any surface it hits.
## Larger than the default because grazing a single-sided terrace lets you see
## straight through the terrain.
const ARM_MARGIN: float = 0.45
## Near clip. Small enough to stand against a wall without the wall vanishing,
## large enough to keep depth precision across a 2.4 km region.
const NEAR_CLIP: float = 0.05
const FOLLOW_SPEED: float = 14.0
const FOV_BASE: float = 64.0
const FOV_SPRINT: float = 72.0
const FOV_LERP: float = 5.0
const SPRINT_FOV_THRESHOLD: float = 5.5  # between walk and run top speed
const SHAKE_DECAY: float = 1.9           # trauma units/second
const SHAKE_MAX_POS: float = 0.28        # metres of camera kick at full trauma
const SHAKE_MAX_ROLL: float = 0.06       # radians of roll at full trauma

var _target: CharacterBody3D
var _pitch: float = 0.0
var _trauma: float = 0.0
## True while the camera sits at Kern's eyes. Starts true — first person is the
## default view. Kern's Visual is hidden whenever this is set.
var _first_person: bool = true
var _target_visual: Node3D

@onready var _arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	_arm.rotation.x = _pitch
	_arm.margin = ARM_MARGIN
	_camera.near = NEAR_CLIP
	EventBus.combat_shake.connect(_on_combat_shake)


func setup(target: CharacterBody3D) -> void:
	_target = target
	_target_visual = target.get_node_or_null("Visual") as Node3D
	# The arm must never collide with Kern himself, or first person would push
	# the camera out of his own body every frame.
	_arm.add_excluded_object(target.get_rid())
	global_position = target.global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	_apply_view_mode()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Whether the camera is currently at Kern's eyes. Read by systems that need to
## know whether the player can see his body (combat framing, screenshot rigs).
func is_first_person() -> bool:
	return _first_person


## Switch between eye-level and orbit. Screenshot/dev rigs call this so captures
## can be taken in third person while the game itself plays in first.
func set_first_person(enabled: bool) -> void:
	if _first_person == enabled:
		return
	_first_person = enabled
	_apply_view_mode()


## Applies everything that differs between the two views: arm length, pitch
## limits, and whether Kern's body is drawn at all.
func _apply_view_mode() -> void:
	_arm.spring_length = 0.0 if _first_person else THIRD_PERSON_DISTANCE
	# Re-clamp immediately: a steep first-person pitch would otherwise survive
	# the switch and leave the orbit camera staring at the sky or the dirt.
	_pitch = clampf(_pitch, _pitch_min(), _pitch_max())
	_arm.rotation.x = _pitch
	if _target_visual != null:
		_target_visual.visible = not _first_person


func _pitch_min() -> float:
	return PITCH_MIN_FIRST if _first_person else PITCH_MIN_THIRD


func _pitch_max() -> float:
	return PITCH_MAX_FIRST if _first_person else PITCH_MAX_THIRD


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var motion: InputEventMouseMotion = event
			_apply_look(
				-motion.relative.x * MOUSE_SENSITIVITY,
				-motion.relative.y * MOUSE_SENSITIVITY
			)
	elif event.is_action_pressed(&"toggle_view"):
		set_first_person(not _first_person)
	elif event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var stick: Vector2 = Input.get_vector(
		&"cam_left", &"cam_right", &"cam_up", &"cam_down"
	)
	if stick.length_squared() > 0.0:
		_apply_look(
			-stick.x * STICK_SENSITIVITY * delta,
			-stick.y * STICK_SENSITIVITY * delta
		)
	if _target == null:
		return
	# First person rides the head exactly — any smoothing here reads as the world
	# sliding around while you walk. Third person keeps the smoothed follow.
	var pivot: Vector3 = _target.global_position + Vector3(
		0.0, EYE_HEIGHT if _first_person else FOLLOW_HEIGHT, 0.0
	)
	if _first_person:
		global_position = pivot
	else:
		global_position = global_position.lerp(pivot, minf(1.0, FOLLOW_SPEED * delta))
	var ground_speed: float = Vector2(_target.velocity.x, _target.velocity.z).length()
	var fov_target: float = FOV_SPRINT if ground_speed > SPRINT_FOV_THRESHOLD else FOV_BASE
	_camera.fov = lerpf(_camera.fov, fov_target, minf(1.0, FOV_LERP * delta))
	_apply_shake(delta)


func _on_combat_shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Shake moves the camera with h_offset/v_offset, NEVER with `position`.
## SpringArm3D positions its children itself every frame (that is how the camera
## ends up `spring_length` behind Kern); writing `_camera.position` fights it and
## wins, which snapped the view back to the arm's origin — i.e. inside Kern's
## head — on every frame, not just while shaking. h_offset/v_offset exist for
## exactly this and leave the arm's transform alone.
func _apply_shake(delta: float) -> void:
	if _trauma <= 0.0:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		_camera.rotation.z = 0.0
		return
	_trauma = maxf(0.0, _trauma - SHAKE_DECAY * delta)
	var s: float = _trauma * _trauma  # perceptually nicer falloff
	_camera.h_offset = randf_range(-1.0, 1.0) * SHAKE_MAX_POS * s
	_camera.v_offset = randf_range(-1.0, 1.0) * SHAKE_MAX_POS * s
	_camera.rotation.z = randf_range(-1.0, 1.0) * SHAKE_MAX_ROLL * s


## Mouse/stick look. Deltas arrive already negated by the callers, which is what
## makes the controls conventional: mouse up looks up, mouse right looks right.
func _apply_look(yaw_delta: float, pitch_delta: float) -> void:
	rotation.y += yaw_delta
	_pitch = clampf(_pitch + pitch_delta, _pitch_min(), _pitch_max())
	_arm.rotation.x = _pitch
