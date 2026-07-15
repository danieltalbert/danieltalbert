class_name QuizPanel
extends CanvasLayer
## QuizPanel: one panel reused for boss portals, mini monsters, and the
## Golden Glitch via a Mode enum. Pauses the tree while open. Wrong answers
## allow retry in BOSS and MINI modes; GLITCH mode is one-shot.

signal closed(mode: int, won: bool)

enum Mode { BOSS, MINI, GLITCH }

const PANEL_BG := Color("#141728")
const PANEL_BORDER := Color("#3a3f5c")
const TEXT := Color("#e8e6f0")
const DIM_TEXT := Color("#9aa0b8")
const GOLD := Color("#ffd45e")
const GREEN := Color("#58e07a")
const RED := Color("#ff5c72")
const XP_BLUE := Color("#7ee0ff")

var mode: int = Mode.BOSS
var world_id := 1

var _review := false
var _had_wrong := false
var _done := false
var _won := false
var _option_order: Array = []
var _correct_index := 0

var _root: Control
var _panel: PanelContainer
var _header: Label
var _topic: Label
var _prep: Label
var _definition: Label
var _question: Label
var _buttons: Array = []
var _feedback: Label
var _vocab: Label
var _close_btn: Button


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(224, 0)
	_panel.pivot_offset = Vector2(112, 140)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_panel.add_child(vbox)

	_header = _make_label(vbox, 8, GOLD)
	_topic = _make_label(vbox, 8, TEXT)
	_prep = _make_label(vbox, 7, DIM_TEXT)
	vbox.add_child(HSeparator.new())
	_definition = _make_label(vbox, 7, DIM_TEXT)
	_question = _make_label(vbox, 8, TEXT)

	for i in 3:
		var b := Button.new()
		b.custom_minimum_size = Vector2(212, 24)
		b.add_theme_font_size_override("font_size", 7)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_on_answer.bind(i))
		vbox.add_child(b)
		_buttons.append(b)

	_feedback = _make_label(vbox, 8, TEXT)
	_vocab = _make_label(vbox, 7, XP_BLUE)
	_vocab.visible = false

	_close_btn = Button.new()
	_close_btn.custom_minimum_size = Vector2(212, 24)
	_close_btn.add_theme_font_size_override("font_size", 8)
	_close_btn.text = "Leave"
	_close_btn.pressed.connect(close)
	vbox.add_child(_close_btn)


func _make_label(parent: Node, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(212, 0)
	parent.add_child(l)
	return l


func open_boss(id: int) -> void:
	mode = Mode.BOSS
	world_id = id
	var w := ContentDb.world(id)
	var act := ContentDb.act_for_world(id)
	_review = GameState.boss_cleared(id)
	var review_tag := "  [REVIEW]" if _review else ""
	_header.text = "%s  World %d: %s%s" % [act["label"], id, w["world"], review_tag]
	_topic.text = "Topic: %s" % w["topic"]
	_prep.text = "Zone prep: tutor %s   mini %s" % [
		"[read]" if GameState.tutor_read(id) else "[not read]",
		"[beaten]" if GameState.mini_beaten(id) else "[not beaten]"]
	_prep.visible = true
	_definition.text = w["definition"]
	_definition.visible = true
	_open_common(w["question"], w["options"], int(w["answer"]))


func open_mini(id: int) -> void:
	mode = Mode.MINI
	world_id = id
	var w := ContentDb.world(id)
	var m: Dictionary = w["mini"]
	_review = GameState.mini_beaten(id)
	var review_tag := "  [REVIEW]" if _review else ""
	_header.text = "Mini battle: %s%s" % [m["name"], review_tag]
	_topic.text = "Drills: %s" % w["topic"]
	_prep.visible = false
	_definition.visible = false
	_open_common(m["question"], m["options"], int(m["answer"]))


func open_glitch(id: int) -> void:
	mode = Mode.GLITCH
	world_id = id
	var w := ContentDb.world(id)
	_review = false
	_header.text = "The GOLDEN GLITCH crackles!"
	_topic.text = "Remix: %s" % w["topic"]
	_prep.text = "One shot. Answer wrong and it escapes."
	_prep.visible = true
	_definition.visible = false
	_open_common(w["question"], w["options"], int(w["answer"]))


func _open_common(question: String, options: Array, answer: int) -> void:
	_had_wrong = false
	_done = false
	_won = false
	_question.text = question
	_feedback.text = ""
	_vocab.visible = false
	_close_btn.text = "Leave"

	_option_order = [0, 1, 2]
	_option_order.shuffle()
	for i in 3:
		var src: int = _option_order[i]
		_buttons[i].text = str(options[src])
		_buttons[i].disabled = false
		_buttons[i].modulate = Color.WHITE
		if src == answer:
			_correct_index = i

	visible = true
	get_tree().paused = true
	Sfx.play("panel_open")
	_panel.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	for i in 3:
		if event.is_action_pressed("answer_%d" % (i + 1)):
			_on_answer(i)
			return
	if _done and (event.is_action_pressed("ui_confirm") or event.is_action_pressed("ui_back")):
		close()
	elif event.is_action_pressed("ui_back"):
		close()


func _on_answer(i: int) -> void:
	if _done or not visible:
		return
	if _buttons[i].disabled:
		return
	if i == _correct_index:
		_handle_correct()
	else:
		_handle_wrong(i)


func _handle_correct() -> void:
	_done = true
	_won = true
	var first_try := not _had_wrong
	Sfx.play("correct")
	for b in _buttons:
		b.disabled = true
	_buttons[_correct_index].modulate = GREEN

	var gained := 0
	match mode:
		Mode.BOSS:
			if not _review:
				gained = GameState.grant_xp(int(ContentDb.constant(
					"xp_boss_first_try" if first_try else "xp_boss_retry")))
				GameState.mark_boss_cleared(world_id, first_try)
			var w := ContentDb.world(world_id)
			_vocab.text = "Vocab loot: %s" % w["vocab"]
			_vocab.visible = true
		Mode.MINI:
			if not _review:
				gained = GameState.grant_xp(int(ContentDb.constant("xp_mini")))
				GameState.mark_mini_beaten(world_id)
		Mode.GLITCH:
			gained = GameState.grant_xp(int(ContentDb.constant("xp_glitch")))
			GameState.mark_glitch_catch()
	GameState.record_answer(first_try)

	if _review and mode != Mode.GLITCH:
		_feedback.text = "Correct! (review, no XP)"
	else:
		_feedback.text = "Correct!  +%d XP" % gained
	_feedback.add_theme_color_override("font_color", GREEN)
	_close_btn.text = "Continue"


func _handle_wrong(i: int) -> void:
	Sfx.play("wrong")
	_had_wrong = true
	GameState.record_answer(false)
	if mode == Mode.GLITCH:
		_done = true
		_won = false
		for b in _buttons:
			b.disabled = true
		_buttons[_correct_index].modulate = GREEN
		_buttons[i].modulate = RED
		_feedback.text = "The Glitch escapes! The answer glows green."
		_feedback.add_theme_color_override("font_color", RED)
		_close_btn.text = "Continue"
	else:
		_buttons[i].disabled = true
		_buttons[i].modulate = RED
		_feedback.text = "Not quite. Try again!"
		_feedback.add_theme_color_override("font_color", RED)


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	closed.emit(mode, _won)
