extends Node2D
## Main: entry point. Boots into the overworld and owns the UI flow
## (quiz panel now; title, tutor panel, and victory flow in later
## milestones).

var overworld: Overworld
var quiz_panel: QuizPanel


func _ready() -> void:
	GameState.load_save()

	overworld = Overworld.new()
	overworld.boss_triggered.connect(_on_boss_triggered)
	add_child(overworld)

	quiz_panel = QuizPanel.new()
	add_child(quiz_panel)


func _on_boss_triggered(world_id: int) -> void:
	if quiz_panel.visible:
		return
	quiz_panel.open_boss(world_id)
