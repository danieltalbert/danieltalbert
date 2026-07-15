extends Node2D
## Main: entry point. Boots into the overworld and owns the UI flow
## (quiz panel now; title, tutor panel, and victory flow in later
## milestones).

var overworld: Overworld
var quiz_panel: QuizPanel
var tutor_panel: TutorPanel
var hud: Hud


func _ready() -> void:
	GameState.load_save()

	overworld = Overworld.new()
	overworld.boss_triggered.connect(_on_boss_triggered)
	overworld.tutor_triggered.connect(_on_tutor_triggered)
	overworld.mini_triggered.connect(_on_mini_triggered)
	add_child(overworld)

	quiz_panel = QuizPanel.new()
	add_child(quiz_panel)

	tutor_panel = TutorPanel.new()
	add_child(tutor_panel)

	hud = Hud.new()
	hud.overworld = overworld
	add_child(hud)

	GameState.level_up.connect(_on_level_up)
	GameState.achievement_unlocked.connect(_on_achievement)


func _on_level_up(level: int, title: String) -> void:
	Sfx.play("fanfare")
	Toasts.show_toast("Level %d: %s" % [level, title], true)


func _on_achievement(_id: String, name: String) -> void:
	Sfx.play("fanfare")
	Toasts.show_toast("Achievement: %s" % name, true)


func _any_panel_open() -> bool:
	return quiz_panel.visible or tutor_panel.visible


func _on_boss_triggered(world_id: int) -> void:
	if _any_panel_open():
		return
	quiz_panel.open_boss(world_id)


func _on_tutor_triggered(world_id: int) -> void:
	if _any_panel_open():
		return
	tutor_panel.open(world_id)


func _on_mini_triggered(world_id: int) -> void:
	if _any_panel_open():
		return
	quiz_panel.open_mini(world_id)
