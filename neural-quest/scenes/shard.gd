class_name Shard
extends Node2D
## Data shard: a small collectible on the path. +2 XP (streak-scaled),
## sparkle burst and blip on pickup, persisted by index.

signal collected(index: int)

const PICKUP_RADIUS := 9.0

var index := 0

var _sprite: Sprite2D
var _time := 0.0
var _picked := false


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.shard_texture()
	add_child(_sprite)


func _process(delta: float) -> void:
	_time += delta
	_sprite.position.y = sin(_time * 3.0 + index) * 1.5
	_sprite.modulate.a = 0.85 + 0.15 * sin(_time * 5.0 + index)


func check_player(player_pos: Vector2) -> void:
	if _picked:
		return
	if position.distance_to(player_pos) < PICKUP_RADIUS:
		_picked = true
		_burst()
		Sfx.play("blip")
		collected.emit(index)
		_sprite.visible = false
		# Freed after the burst finishes.
		get_tree().create_timer(0.6).timeout.connect(queue_free)


func _burst() -> void:
	var p := CPUParticles2D.new()
	p.texture = PixelArt.dot_texture(Color("#7ee0ff"), 2)
	p.amount = 12
	p.lifetime = 0.4
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 45.0
	p.gravity = Vector2.ZERO
	p.emitting = true
	add_child(p)
