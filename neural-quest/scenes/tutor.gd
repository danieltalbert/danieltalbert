class_name Tutor
extends Wanderer
## Tutor: a robed NPC who teaches this zone's topic in two pages.
## Shows a "?" indicator until read; re-readable forever.

var world_id := 1


func _ready() -> void:
	super()
	var act: Dictionary = ContentDb.act_for_world(world_id)
	var accent := Color(str(act.get("palette", {}).get("accent", "#ffffff")))
	sprite.texture = PixelArt.tutor_texture(accent)
	indicator.text = "?"
	_refresh()
	GameState.progress_changed.connect(_refresh)


func _refresh() -> void:
	indicator.visible = not GameState.tutor_read(world_id)
