class_name Wanderer
extends Node2D
## Wanderer: base class for entities that roam on a short leash around a
## home point (tutors, mini monsters, and the Golden Glitch). Movement uses
## the same grid collision as the player. Subclasses provide the sprite and
## an indicator, and react to the player touching them via `triggered`.

signal triggered

const TILE := 16
const BOX_HALF_W := 5.0
const BOX_TOP := 2.0
const BOX_BOTTOM := 7.0
const TRIGGER_RADIUS := 10.0
const REARM_RADIUS := 22.0

var home := Vector2.ZERO
var speed := 18.0
var leash := 48.0

var _armed := true
var _target := Vector2.ZERO
var _idle_time := 0.0
var _walking := false
var _anim_time := 0.0
var _frame := 0

var sprite: Sprite2D
var indicator: Label


func _ready() -> void:
	home = position
	sprite = Sprite2D.new()
	add_child(sprite)

	indicator = Label.new()
	indicator.add_theme_font_size_override("font_size", 8)
	indicator.add_theme_color_override("font_color", Color("#ffd45e"))
	indicator.add_theme_color_override("font_outline_color", Color("#101020"))
	indicator.add_theme_constant_override("outline_size", 2)
	indicator.position = Vector2(-3, -16)
	add_child(indicator)

	speed = float(ContentDb.constant("npc_speed"))
	leash = float(ContentDb.constant("npc_leash_tiles")) * TILE
	_idle_time = randf_range(0.2, 1.5)


func _physics_process(delta: float) -> void:
	if _walking:
		var to_target := _target - position
		if to_target.length() < 2.0:
			_walking = false
			_idle_time = randf_range(0.8, 2.4)
		else:
			var motion := to_target.normalized() * speed * delta
			var before := position
			_move_with_collision(motion)
			if position.distance_to(before) < motion.length() * 0.3:
				_walking = false
				_idle_time = randf_range(0.5, 1.2)
			_anim_time += delta
			if _anim_time >= 0.25:
				_anim_time = 0.0
				_frame = 1 - _frame
				_on_frame(_frame)
	else:
		_idle_time -= delta
		if _idle_time <= 0.0:
			_pick_target()
	indicator.position.y = -16 + sin(Time.get_ticks_msec() / 250.0) * 1.5


func _pick_target() -> void:
	for _attempt in 6:
		var offset := Vector2(randf_range(-leash, leash), randf_range(-leash, leash))
		var candidate := home + offset
		var tx := int(floor(candidate.x / TILE))
		var ty := int(floor(candidate.y / TILE))
		if not ContentDb.is_solid(tx, ty):
			_target = candidate
			_walking = true
			if sprite != null:
				sprite.flip_h = candidate.x < position.x
			return
	_idle_time = 1.0


func _on_frame(_f: int) -> void:
	pass


func _move_with_collision(motion: Vector2) -> void:
	if motion.x != 0.0 and _box_clear(position + Vector2(motion.x, 0)):
		position.x += motion.x
	if motion.y != 0.0 and _box_clear(position + Vector2(0, motion.y)):
		position.y += motion.y


func _box_clear(at: Vector2) -> bool:
	for c in [
		Vector2(at.x - BOX_HALF_W, at.y + BOX_TOP),
		Vector2(at.x + BOX_HALF_W, at.y + BOX_TOP),
		Vector2(at.x - BOX_HALF_W, at.y + BOX_BOTTOM),
		Vector2(at.x + BOX_HALF_W, at.y + BOX_BOTTOM),
	]:
		if ContentDb.is_solid(int(floor(c.x / TILE)), int(floor(c.y / TILE))):
			return false
	return true


func check_player(player_pos: Vector2) -> void:
	var dist := position.distance_to(player_pos)
	if _armed and dist < TRIGGER_RADIUS:
		_armed = false
		triggered.emit()
	elif not _armed and dist > REARM_RADIUS:
		_armed = true
