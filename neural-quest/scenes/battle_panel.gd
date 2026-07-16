class_name BattlePanel
extends CanvasLayer
## BattlePanel: turn-based card duel against a cleared boss. Your deck is
## one concept card per topic you have engaged with (named after its vocab
## term). Playing a card asks one of that topic's questions: a correct
## answer strikes the boss for the card's power, a wrong answer costs you a
## heart and reveals the truth. Knowledge is the only weapon.

signal closed

const PANEL_BG := Color("#141728")
const PANEL_BORDER := Color("#3a3f5c")
const TEXT := Color("#e8e6f0")
const DIM_TEXT := Color("#9aa0b8")
const GOLD := Color("#ffd45e")
const GREEN := Color("#58e07a")
const RED := Color("#ff5c72")
const XP_BLUE := Color("#7ee0ff")

enum Phase { PICK, ANSWER, RESOLVE, END }

var world_id := 1

var _phase: int = Phase.PICK
var _boss_hp := 3
var _player_hp := 3
var _hand: Array = []          # world ids
var _active_card := -1
var _correct_index := 0
var _won := false
var _first_win := false

var _panel: PanelContainer
var _title: Label
var _boss_sprite: TextureRect
var _boss_hp_row: HBoxContainer
var _player_hp_row: HBoxContainer
var _prompt: Label
var _buttons: Array = []
var _feedback: Label
var _continue_btn: Button


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(226, 0)
	_panel.pivot_offset = Vector2(113, 150)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_panel.add_child(vbox)

	_title = _label(vbox, 8, GOLD)

	var arena := HBoxContainer.new()
	arena.add_theme_constant_override("separation", 8)
	vbox.add_child(arena)

	var left := VBoxContainer.new()
	arena.add_child(left)
	var you := Label.new()
	you.text = "YOU"
	you.add_theme_font_size_override("font_size", 7)
	you.add_theme_color_override("font_color", XP_BLUE)
	left.add_child(you)
	_player_hp_row = _hp_row(left)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena.add_child(spacer)

	var right := VBoxContainer.new()
	arena.add_child(right)
	_boss_sprite = TextureRect.new()
	_boss_sprite.custom_minimum_size = Vector2(48, 48)
	_boss_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	_boss_sprite.pivot_offset = Vector2(24, 24)
	right.add_child(_boss_sprite)
	_boss_hp_row = _hp_row(right)

	_prompt = _label(vbox, 8, TEXT)

	for i in 3:
		var b := Button.new()
		b.custom_minimum_size = Vector2(214, 24)
		b.add_theme_font_size_override("font_size", 7)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_on_button.bind(i))
		vbox.add_child(b)
		_buttons.append(b)

	_feedback = _label(vbox, 7, DIM_TEXT)

	_continue_btn = Button.new()
	_continue_btn.custom_minimum_size = Vector2(214, 22)
	_continue_btn.add_theme_font_size_override("font_size", 8)
	_continue_btn.text = "Flee"
	_continue_btn.pressed.connect(_on_continue)
	vbox.add_child(_continue_btn)


func _label(parent: Node, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(214, 0)
	parent.add_child(l)
	return l


func _hp_row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)
	return row


func _set_hp(row: HBoxContainer, hp: int, max_hp: int, color: Color) -> void:
	for child in row.get_children():
		child.queue_free()
	for i in max_hp:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(9, 9)
		pip.color = color if i < hp else Color(color, 0.15)
		row.add_child(pip)


func _card_name(id: int) -> String:
	var vocab := str(ContentDb.world(id).get("vocab", "Concept:"))
	return vocab.split(":")[0].strip_edges()


func _card_power(id: int) -> int:
	var act := int(ContentDb.world(id).get("act", 1))
	return [1, 2, 2, 3][act - 1]


func open(id: int) -> void:
	world_id = id
	_boss_hp = int(ContentDb.constant("battle_hp"))
	_player_hp = int(ContentDb.constant("battle_hp"))
	_won = false
	_first_win = false
	var w := ContentDb.world(id)
	_title.text = "REMATCH: %s  (%s)" % [w["mini"]["name"], w["topic"]]
	var act: Dictionary = ContentDb.act_for_world(id)
	var body := Color(str(act.get("palette", {}).get("obstacle_b", "#888888")))
	_boss_sprite.texture = PixelArt.monster_textures(body, id % 3)[0]
	_continue_btn.text = "Flee"
	_feedback.text = "Cards are topics you have studied. Power grows with depth."
	_deal_hand()
	_enter_pick()

	visible = true
	get_tree().paused = true
	Sfx.play("panel_open")
	_panel.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _deal_hand() -> void:
	var pool: Array = GameState.engaged_world_ids()
	if not pool.has(world_id):
		pool.append(world_id)
	_hand = []
	var options := pool.duplicate()
	options.shuffle()
	for i in 3:
		if i < options.size():
			_hand.append(options[i])
		else:
			_hand.append(pool[randi() % pool.size()])


func _enter_pick() -> void:
	_phase = Phase.PICK
	_prompt.text = "Choose a concept card to play:"
	_set_hp(_player_hp_row, _player_hp, int(ContentDb.constant("battle_hp")), XP_BLUE)
	_set_hp(_boss_hp_row, _boss_hp, int(ContentDb.constant("battle_hp")), RED)
	for i in 3:
		var cid: int = _hand[i]
		_buttons[i].text = "%s  [PWR %d]  (%s)" % [
			_card_name(cid), _card_power(cid),
			ContentDb.world(cid)["topic"]]
		_buttons[i].disabled = false
		_buttons[i].modulate = Color.WHITE
		_buttons[i].visible = true


func _enter_answer(card_i: int) -> void:
	_phase = Phase.ANSWER
	_active_card = _hand[card_i]
	var w := ContentDb.world(_active_card)
	var pools: Array = [
		{"question": w["question"], "options": w["options"], "answer": w["answer"]},
		w["remix"],
		w["mini"],
	]
	var q: Dictionary = pools[randi() % pools.size()]
	_prompt.text = str(q["question"])
	var order := [0, 1, 2]
	order.shuffle()
	for i in 3:
		var src: int = order[i]
		_buttons[i].text = str(q["options"][src])
		_buttons[i].disabled = false
		_buttons[i].modulate = Color.WHITE
		if src == int(q["answer"]):
			_correct_index = i
	Sfx.play("page")


func _on_button(i: int) -> void:
	if not visible:
		return
	match _phase:
		Phase.PICK:
			_enter_answer(i)
		Phase.ANSWER:
			_resolve(i)


func _resolve(i: int) -> void:
	_phase = Phase.RESOLVE
	for b in _buttons:
		b.disabled = true
	_buttons[_correct_index].modulate = GREEN
	if i == _correct_index:
		var dmg := _card_power(_active_card)
		_boss_hp = maxi(0, _boss_hp - dmg)
		GameState.record_answer(true)
		Sfx.play("correct")
		_feedback.text = "%s strikes for %d!" % [_card_name(_active_card), dmg]
		_feedback.add_theme_color_override("font_color", GREEN)
		var tw := create_tween()
		tw.tween_property(_boss_sprite, "scale", Vector2(1.25, 0.8), 0.08)
		tw.tween_property(_boss_sprite, "scale", Vector2.ONE, 0.12)
	else:
		_buttons[i].modulate = RED
		_player_hp = maxi(0, _player_hp - 1)
		GameState.record_answer(false)
		Sfx.play("wrong")
		_feedback.text = "The boss counterattacks! The truth glows green."
		_feedback.add_theme_color_override("font_color", RED)
	_set_hp(_player_hp_row, _player_hp, int(ContentDb.constant("battle_hp")), XP_BLUE)
	_set_hp(_boss_hp_row, _boss_hp, int(ContentDb.constant("battle_hp")), RED)

	if _boss_hp <= 0:
		_end(true)
	elif _player_hp <= 0:
		_end(false)
	else:
		_prompt.text = "Press Continue for the next turn."
		_continue_btn.text = "Continue"


func _end(won: bool) -> void:
	_phase = Phase.END
	_won = won
	for b in _buttons:
		b.visible = false
	if won:
		var gained := 0
		if not GameState.battle_won(world_id):
			gained = GameState.grant_xp(int(ContentDb.constant("xp_battle")))
			GameState.mark_battle_won(world_id)
			_first_win = true
		Sfx.play("fanfare")
		_prompt.text = "The boss dissolves into clean data!"
		if _first_win:
			_feedback.text = "Rematch won!  +%d XP" % gained
		else:
			_feedback.text = "Rematch won! (repeat, no XP)"
		_feedback.add_theme_color_override("font_color", GOLD)
	else:
		_prompt.text = "You are out of hearts. Study and return!"
		_feedback.text = "No penalty. The tutors are patient."
		_feedback.add_theme_color_override("font_color", DIM_TEXT)
	_continue_btn.text = "Leave"


func _on_continue() -> void:
	match _phase:
		Phase.RESOLVE:
			_deal_hand()
			_enter_pick()
			_continue_btn.text = "Flee"
		_:
			close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	for i in 3:
		if event.is_action_pressed("answer_%d" % (i + 1)):
			if _buttons[i].visible and not _buttons[i].disabled:
				_on_button(i)
			return
	if event.is_action_pressed("ui_confirm"):
		if _phase == Phase.RESOLVE or _phase == Phase.END:
			_on_continue()
	elif event.is_action_pressed("ui_back"):
		close()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	closed.emit()
