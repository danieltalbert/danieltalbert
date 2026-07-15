extends Node2D
## Main: entry point and UI flow owner. Boots to the title screen, builds
## the world on start, routes entity triggers to panels, and shows the
## victory screen when the 20th boss falls.

## Set to false to disable the CRT scanline overlay.
const SCANLINES := true

var overworld: Overworld
var quiz_panel: QuizPanel
var tutor_panel: TutorPanel
var hud: Hud

var _title: TitleScreen
var _boss_was_cleared := false
var _boss_opening := false


func _ready() -> void:
	GameState.load_save()
	_title = TitleScreen.new()
	_title.start_game.connect(_on_start_game)
	add_child(_title)
	if SCANLINES:
		add_child(_make_scanlines())


func _make_scanlines() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 90
	var img := Image.create(4, 2, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, 4, 1), Color(0, 0, 0, 0.0))
	img.fill_rect(Rect2i(0, 1, 4, 1), Color(0, 0, 0, 0.13))
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(img)
	rect.stretch_mode = TextureRect.STRETCH_TILE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	return layer


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
	if _any_panel_open() or _boss_opening:
		return
	_boss_opening = true
	_boss_was_cleared = GameState.boss_cleared(world_id)
	# A brief shake before the panel pops in sells the boss entry.
	overworld.shake(0.22, 2.5)
	await get_tree().create_timer(0.24).timeout
	_boss_opening = false
	if not _any_panel_open():
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
	if won:
		overworld.burst_at(overworld.player.position, Color("#ffd45e"))
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
