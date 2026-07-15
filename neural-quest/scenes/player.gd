class_name Player
extends Node2D
## Player: 4-direction movement with grid collision, hold-to-sprint with
## dust particles, walk animation, and a gold crown once all bosses fall.
## Collision is a foot box tested against the solid-tile grid (no physics).

const TILE := 16
# Foot collision box, relative to the node origin (sprite center).
const BOX_HALF_W := 5.0
const BOX_TOP := 2.0
const BOX_BOTTOM := 7.0

var facing := "down"
var frame := 0
var moving := false
var sprinting := false

# Touch controls write into these; keyboard input is merged in.
var external_input := Vector2.ZERO
var external_sprint := false

var _frames: Dictionary = {}
var _anim_time := 0.0
var _sprite: Sprite2D
var _dust: CPUParticles2D
var camera: Camera2D


func _ready() -> void:
	_frames = PixelArt.player_frames(GameState.all_bosses_cleared())
	GameState.progress_changed.connect(_refresh_crown)

	_sprite = Sprite2D.new()
	_sprite.texture = _frames["down_0"]
	add_child(_sprite)

	_dust = CPUParticles2D.new()
	_dust.texture = PixelArt.dot_texture(Color("#d8cfae"), 2)
	_dust.amount = 10
	_dust.lifetime = 0.4
	_dust.emitting = false
	_dust.position = Vector2(0, 6)
	_dust.direction = Vector2(0, -1)
	_dust.spread = 60.0
	_dust.initial_velocity_min = 8.0
	_dust.initial_velocity_max = 16.0
	_dust.gravity = Vector2.ZERO
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.0
	add_child(_dust)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()


func _refresh_crown() -> void:
	_frames = PixelArt.player_frames(GameState.all_bosses_cleared())
	_update_sprite()


func _physics_process(delta: float) -> void:
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up"))
	if input == Vector2.ZERO:
		input = external_input
	sprinting = Input.is_action_pressed("sprint") or external_sprint

	moving = input.length_squared() > 0.01
	if moving:
		input = input.normalized()
		var speed := float(ContentDb.constant("player_speed"))
		if sprinting:
			speed *= float(ContentDb.constant("sprint_factor"))
		_move_with_collision(input * speed * delta)
		if absf(input.x) >= absf(input.y):
			facing = "side"
			_sprite.flip_h = input.x < 0
		else:
			facing = "down" if input.y > 0 else "up"
		_anim_time += delta
		var step := 0.12 if sprinting else 0.18
		if _anim_time >= step:
			_anim_time = 0.0
			frame = 1 - frame
	else:
		frame = 0
		_anim_time = 0.0
	_dust.emitting = moving and sprinting
	_update_sprite()


func _update_sprite() -> void:
	_sprite.texture = _frames["%s_%d" % [facing, frame]]


func _move_with_collision(motion: Vector2) -> void:
	# Axis-separated moves let the player slide along walls.
	if motion.x != 0.0 and _box_clear(position + Vector2(motion.x, 0)):
		position.x += motion.x
	if motion.y != 0.0 and _box_clear(position + Vector2(0, motion.y)):
		position.y += motion.y


func _box_clear(at: Vector2) -> bool:
	var corners := [
		Vector2(at.x - BOX_HALF_W, at.y + BOX_TOP),
		Vector2(at.x + BOX_HALF_W, at.y + BOX_TOP),
		Vector2(at.x - BOX_HALF_W, at.y + BOX_BOTTOM),
		Vector2(at.x + BOX_HALF_W, at.y + BOX_BOTTOM),
	]
	for c in corners:
		if ContentDb.is_solid(int(floor(c.x / TILE)), int(floor(c.y / TILE))):
			return false
	return true


func tile_pos() -> Vector2i:
	return Vector2i(int(floor(position.x / TILE)), int(floor(position.y / TILE)))
