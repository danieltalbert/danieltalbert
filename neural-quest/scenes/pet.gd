class_name Pet
extends Node2D
## Databot: a tiny drone companion that hatches after your first boss and
## floats along behind you. Purely cosmetic, purely morale.

var target_node: Node2D

var _trail: Array = []
var _sprite: Sprite2D
var _time := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.pet_texture()
	add_child(_sprite)


func _physics_process(_delta: float) -> void:
	if target_node == null:
		return
	_trail.append(target_node.position)
	if _trail.size() > 14:
		var goal: Vector2 = _trail.pop_front() + Vector2(-7, -11)
		position = position.lerp(goal, 0.25)


func _process(delta: float) -> void:
	_time += delta
	_sprite.position.y = sin(_time * 3.2) * 1.6
	_sprite.modulate.a = 0.9 + 0.1 * sin(_time * 6.0)
