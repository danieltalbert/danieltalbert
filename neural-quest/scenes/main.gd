extends Node2D
## Main: entry point and UI flow owner. Boots to the title screen, builds
## the world on start, routes entity triggers to panels, and shows the
## victory screen when the 20th boss falls.

var overworld: Overworld
var quiz_panel: QuizPanel
var tutor_panel: TutorPanel
var hud: Hud

var _title: TitleScreen
var _boss_was_cleared := false


func _ready() -> void:
	GameState.load_save()
	_title = TitleScreen.new()
	_title.start_game.connect(_on_start_game)
	add_child(_title)


func _on_start_game(new_game: bool) -> void:
	if new_game:
		GameState.reset()
	_title.queue_free()
	_title = null
	_build_world()


func _build_world() -> void:
	overworld = Overworld.new()
	overworld.boss_triggered.connect(_on_boss_triggered)
	overworld.tutor_triggered.connect(_on_tutor_triggered)
	overworld.mini_triggered.connect(_on_mini_triggered)
	overworld.glitch_triggered.connect(_on_glitch_triggered)
	add_child(overworld)

	quiz_panel = QuizPanel.new()
	quiz_panel.closed.connect(_on_quiz_closed)
	add_child(quiz_panel)

	tutor_panel = TutorPanel.new()
	add_child(tutor_panel)

	hud = Hud.new()
	hud.overworld = overworld
	add_child(hud)

	GameState.level_up.connect(_on_level_up)
	GameState.achievement_unlocked.connect(_on_achievement)


func _any_panel_open() -> bool:
	return quiz_panel.visible or tutor_panel.visible


func _on_boss_triggered(world_id: int) -> void:
	if _any_panel_open():
		return
	_boss_was_cleared = GameState.boss_cleared(world_id)
	quiz_panel.open_boss(world_id)


func _on_tutor_triggered(world_id: int) -> void:
	if _any_panel_open():
		return
	tutor_panel.open(world_id)


func _on_mini_triggered(world_id: int) -> void:
	if _any_panel_open():
		return
	quiz_panel.open_mini(world_id)


func _on_glitch_triggered() -> void:
	if _any_panel_open():
		return
	var pool: Array = GameState.engaged_world_ids()
	if pool.is_empty():
		return
	Sfx.play("glitch")
	quiz_panel.open_glitch(int(pool[randi() % pool.size()]))


func _on_quiz_closed(mode: int, won: bool) -> void:
	if mode == QuizPanel.Mode.GLITCH:
		# Caught or escaped, the Glitch always despawns and the respawn
		# timer restarts.
		overworld.despawn_glitch()
	elif mode == QuizPanel.Mode.BOSS and won and not _boss_was_cleared \
			and GameState.all_bosses_cleared():
		var victory := VictoryScreen.new()
		add_child(victory)


func _on_level_up(level: int, title: String) -> void:
	Sfx.play("fanfare")
	Toasts.show_toast("Level %d: %s" % [level, title], true)


func _on_achievement(_id: String, name: String) -> void:
	Sfx.play("fanfare")
	Toasts.show_toast("Achievement: %s" % name, true)
