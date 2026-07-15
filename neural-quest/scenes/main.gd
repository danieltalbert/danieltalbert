extends Node2D
## Main: entry point. Boots into the overworld. Title screen, quiz panels,
## and victory flow arrive in later milestones.

var overworld: Overworld


func _ready() -> void:
	GameState.load_save()
	overworld = Overworld.new()
	overworld.boss_triggered.connect(_on_boss_triggered)
	add_child(overworld)


func _on_boss_triggered(world_id: int) -> void:
	# Placeholder until the QuizPanel milestone.
	print("Boss portal %d triggered" % world_id)
