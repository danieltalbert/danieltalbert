class_name Monster
extends Wanderer
## Mini-battle monster: roams its zone and drills the topic with one
## question for +15 XP on the first win. Shows "!" until beaten.

var world_id := 1

var _textures: Array = []


func _ready() -> void:
	super()
	var act: Dictionary = ContentDb.act_for_world(world_id)
	var body := Color(str(act.get("palette", {}).get("obstacle_b", "#888888")))
	_textures = PixelArt.monster_textures(body)
	sprite.texture = _textures[0]
	indicator.text = "!"
	_refresh()
	GameState.progress_changed.connect(_refresh)


func _refresh() -> void:
	indicator.visible = not GameState.mini_beaten(world_id)


func _on_frame(f: int) -> void:
	sprite.texture = _textures[f]
