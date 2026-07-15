class_name GoldenGlitch
extends Wanderer
## Golden Glitch: a rare gold sparkle that wanders faster than any other
## entity. Touching it opens a one-shot remix question. Spawn, relocation,
## and despawn timing live in Overworld; this node just roams and shimmers.

var _textures: Array = []


func _ready() -> void:
	super()
	_textures = PixelArt.glitch_textures()
	sprite.texture = _textures[0]
	indicator.visible = false
	speed = float(ContentDb.constant("glitch_speed"))
	leash = 6.0 * TILE


func _on_frame(f: int) -> void:
	sprite.texture = _textures[f]


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 90.0
	sprite.modulate.a = 0.75 + 0.25 * sin(t)


func relocate(to: Vector2) -> void:
	position = to
	home = to
