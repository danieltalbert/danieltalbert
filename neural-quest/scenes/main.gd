extends Node2D
## Main: entry point. Boots into the title screen, then swaps to the
## overworld. Later milestones add the victory screen and scanline overlay.

func _ready() -> void:
	GameState.load_save()
	print("Neural Quest booted. Worlds loaded: %d" % ContentDb.worlds.size())
