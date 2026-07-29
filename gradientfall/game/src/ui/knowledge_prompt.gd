class_name KnowledgePrompt
extends CanvasLayer
## The knowledge-channel quiz card — Phase 1 milestone 7 (Knowledge charge v1).
##
## Danny's design (chat, 2026-07-20): the focus special is a COMBINED Kern+Bit
## attack that must be CAST by answering. Pressing "special" with a part-full
## meter opens this card: time crawls and Kern is safe (PlayerCombat owns the
## slow-mo + invulnerability), Bit flies in to channel, and questions from the
## approved bank appear one at a time under a real-time countdown. Each correct
## answer feeds the meter (EventBus.quiz_answered → PlayerCombat.add_charge);
## fill it and the combined strike fires as the channel's climax. A wrong
## answer or a timeout fizzles the cast — accumulated focus is KEPT (all-ages
## kindness), so no attempt is ever wasted.
##
## Every answer reveals the explanation: the teaching beat is the point
## (GDD pillar 3 — "the ML is real and woven in").
##
## All UI is code-built Controls, no assets. The countdown runs on wall-clock
## ticks because Engine.time_scale is lowered while the card is up.

enum State { CLOSED, ASKING, REVEAL }

const QUESTION_TIME: float = 12.0  # real seconds to answer
const REVEAL_TIME: float = 6.5     # explanation beat, skippable
const REVEAL_MIN: float = 0.7      # ignore key mashes right at reveal
const CARD_WIDTH: float = 660.0

# Entrance, on wall-clock milliseconds. `_process`'s delta is scaled by
# Engine.time_scale (0.15 while channelling), so anything timed off delta would
# play seven times too slowly — the same reason the countdown uses ticks.
const OPEN_FADE_MS: float = 180.0
const SCRIM_FADE_MS: float = 240.0
const SCRIM_ALPHA: float = 0.58   # how far the meadow dims behind the card
const OPEN_SCALE_FROM: float = 0.94

# Height reserved for the explanation while the question is still up. Without
# it the card grew when the reveal appeared and the CenterContainer re-centred
# it, so every answer punched the whole card ~70 px up the screen.
const REVEAL_RESERVE: float = 84.0

const COL_BG: Color = Color(0.07, 0.08, 0.12, 0.94)
const COL_GOLD: Color = Color(1.0, 0.82, 0.32)
const COL_BLUE: Color = Color(0.55, 0.78, 1.0)
const COL_DIM: Color = Color(0.62, 0.66, 0.74)
const COL_ROW: Color = Color(0.12, 0.14, 0.20, 0.92)
const COL_ROW_RIGHT: Color = Color(0.13, 0.42, 0.24, 0.95)
const COL_ROW_WRONG: Color = Color(0.48, 0.14, 0.18, 0.95)
const COL_RED: Color = Color(0.95, 0.45, 0.45)

const ANSWER_ACTIONS: Array[StringName] = [
	&"quiz_answer_1", &"quiz_answer_2", &"quiz_answer_3", &"quiz_answer_4",
]

var _picker: QuizPicker = QuizPicker.new()
var _state: int = State.CLOSED
var _question: Dictionary = {}
var _charge_fraction: float = 0.0
var _will_close: bool = false
var _completed: bool = false
var _deadline_ms: int = 0
var _reveal_start_ms: int = 0

var _title_label: Label
var _pips_label: Label
var _question_label: Label
var _choice_rows: Array[PanelContainer] = []
var _choice_labels: Array[Label] = []
var _result_label: Label
var _hint_label: Label
var _timer_bg: Control
var _timer_fill: ColorRect

var _panel: PanelContainer
var _scrim: ColorRect        ## dims the world so the crawl reads as a stop
var _bit_label: Label        ## Bit's line, on the card instead of behind it
var _meter_fill: ColorRect   ## the focus being forged, where the eyes already are
var _meter_label: Label
var _open_ms: int = 0        ## wall-clock start of the entrance

# Live timings. They start at the consts above — those ARE the shipping feel —
# and only `debug_set_timings()` (the dev probe) ever moves them, so an
# automated run can exercise the timeout path without waiting 12 real seconds.
var _question_time: float = QUESTION_TIME
var _reveal_time: float = REVEAL_TIME


# --- Read API (HUD, dev probe, future systems) --------------------------------

## True while the card owns input — the channel is up.
func is_open() -> bool:
	return _state != State.CLOSED


## "CLOSED" / "ASKING" / "REVEAL" — the state machine, for logs and assertions.
func state_name() -> String:
	return ["CLOSED", "ASKING", "REVEAL"][_state]


## The question on screen right now, or {} when none is. Copy, not the original.
func current_question() -> Dictionary:
	return _question.duplicate(true) if _state != State.CLOSED else {}


## Real seconds left to answer, or 0.0 outside State.ASKING.
func seconds_left() -> float:
	if _state != State.ASKING:
		return 0.0
	return maxf(0.0, float(_deadline_ms - Time.get_ticks_msec()) / 1000.0)


## DEV ONLY (`src/dev/channel_probe.gd`). Compresses the answer/reveal clocks so
## an automated pass can reach the timeout branch in a fraction of a second.
## Never called by shipping code — the consts above are the feel.
func debug_set_timings(question_time: float, reveal_time: float) -> void:
	_question_time = maxf(0.05, question_time)
	_reveal_time = maxf(0.05, reveal_time)


func _ready() -> void:
	layer = 20  # above the CombatHud (10)
	visible = false
	_build_card()
	EventBus.knowledge_channel_requested.connect(_on_requested)
	EventBus.knowledge_channel_break_requested.connect(_on_break_requested)
	EventBus.knowledge_charge_changed.connect(_on_charge)
	EventBus.bit_spoke.connect(_on_bit_spoke)
	EventBus.player_died.connect(_on_player_died)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	_tick_entrance(now)
	match _state:
		State.ASKING:
			_tick_asking(now)
		State.REVEAL:
			_tick_reveal(now)


## Fades the scrim up and pops the card in, both on wall-clock: `_delta` here is
## multiplied by Engine.time_scale, which the channel itself has pinned at 0.15.
func _tick_entrance(now: int) -> void:
	if _state == State.CLOSED:
		return
	var since: float = float(now - _open_ms)
	_scrim.color.a = SCRIM_ALPHA * clampf(since / SCRIM_FADE_MS, 0.0, 1.0)
	var t: float = clampf(since / OPEN_FADE_MS, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 3.0)  # ease-out: quick, then settles
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2.ONE * lerpf(OPEN_SCALE_FROM, 1.0, eased)
	_panel.modulate.a = eased


# --- Channel lifecycle -------------------------------------------------------

func _on_requested() -> void:
	if _state != State.CLOSED:
		return
	# Never open under the pack, the notebook, or a conversation: the pack pauses
	# the tree, which would freeze this card's real-time countdown while it kept
	# expiring in wall-clock. See UiModality.
	if UiModality.any_open(get_tree(), self):
		print("KnowledgePrompt: channel declined — %s has the screen." % \
			UiModality.describe(get_tree(), self))
		return
	var q: Dictionary = _picker.next()
	if q.is_empty():
		print("KnowledgePrompt: no questions in the bank at difficulty <= %d." % QuizPicker.max_difficulty())
		return
	_will_close = false
	_completed = false
	_open_ms = Time.get_ticks_msec()
	_bit_label.text = ""
	_scrim.color.a = 0.0
	visible = true
	UiModality.claim(self)
	# Emit before showing so PlayerCombat applies slow-mo/safety this frame.
	EventBus.knowledge_channel_started.emit()
	_show_question(q)


func _close(completed: bool) -> void:
	_state = State.CLOSED
	visible = false
	UiModality.release(self)
	EventBus.knowledge_channel_ended.emit(completed)


func _on_charge(fraction: float) -> void:
	_charge_fraction = fraction
	_draw_meter()


## Repaints the in-card focus meter and the plain-language "how many more".
## `PlayerCombat.CHARGE_PER_QUIZ` is the single source of truth for the count,
## so retuning the meter cannot leave this text lying.
func _draw_meter() -> void:
	if _meter_fill == null:
		return
	var bar: Control = _meter_fill.get_parent() as Control
	_meter_fill.size = Vector2(bar.size.x * clampf(_charge_fraction, 0.0, 1.0), 10.0)
	_meter_fill.color = COL_GOLD if _charge_fraction >= 1.0 else COL_BLUE
	if _charge_fraction >= 1.0:
		_meter_label.text = "the strike is forged"
		_meter_label.add_theme_color_override("font_color", COL_GOLD)
		return
	var needed: int = int(ceil((1.0 - _charge_fraction) / maxf(PlayerCombat.CHARGE_PER_QUIZ, 0.001)))
	_meter_label.text = "1 more answer to forge the strike" if needed <= 1 		else "%d more answers to forge the strike" % needed
	_meter_label.add_theme_color_override("font_color", COL_DIM)


## Bit's cast lines land on the card. Her world label is behind this panel
## while she channels over Kern's head, so it is the only place they can be read.
func _on_bit_spoke(line: String, kind: String) -> void:
	# Guarded on `visible`, NOT on `_state`: the card is shown and Bit is asked
	# to speak before `_show_question` moves the state out of CLOSED, so a
	# state guard here dropped her opening line every single cast.
	if visible and kind == "channel":
		_bit_label.text = "Bit:  " + line


func _on_player_died() -> void:
	if _state != State.CLOSED:
		_close(false)


# --- Asking ------------------------------------------------------------------

func _show_question(q: Dictionary) -> void:
	_question = q
	_state = State.ASKING
	_deadline_ms = Time.get_ticks_msec() + int(_question_time * 1000.0)
	_pips_label.text = "◆".repeat(clampi(int(q.get("difficulty", 1)), 1, 5))
	_question_label.text = str(q.get("question", ""))
	var choices: Array = q.get("choices", [])
	for i: int in _choice_rows.size():
		var text: String = str(choices[i]) if i < choices.size() else ""
		_choice_labels[i].text = "%d.  %s" % [i + 1, text]
		_choice_labels[i].add_theme_color_override("font_color", Color.WHITE)
		_set_row_color(i, COL_ROW)
	_result_label.text = ""
	_draw_meter()
	_hint_label.text = "1–4  answer      Q  break off"


## The special key, pressed again. PlayerCombat owns that key and forwards the
## press here (see EventBus.knowledge_channel_break_requested). Mid-question it
## breaks the cast off and keeps the focus already earned; mid-explanation it
## just skips the beat, because abandoning a cast the player has already
## finished paying for would read as a punishment.
func _on_break_requested() -> void:
	match _state:
		State.ASKING:
			_close(false)
		State.REVEAL:
			_advance_reveal()


func _tick_asking(now: int) -> void:
	# Debug fill (F) or any external top-up completes the cast instantly.
	if _charge_fraction >= 1.0:
		_close(true)
		return
	var remaining: float = float(_deadline_ms - now) / 1000.0
	if remaining <= 0.0:
		_resolve(-1)
		return
	_draw_timer(remaining / _question_time)
	for i: int in ANSWER_ACTIONS.size():
		if Input.is_action_just_pressed(ANSWER_ACTIONS[i]):
			_resolve(i)
			return


# --- Reveal (the teaching beat) ----------------------------------------------

func _resolve(choice: int) -> void:
	_state = State.REVEAL
	_reveal_start_ms = Time.get_ticks_msec()
	var correct_idx: int = int(_question.get("answer_index", 0))
	var correct: bool = choice == correct_idx
	var quiz_id: String = str(_question.get("id", ""))

	# Remember how this one went BEFORE anything else can react: the picker puts
	# missed questions back near the front of the next bag.
	_picker.record(quiz_id, correct)

	# Synchronous chain: PlayerCombat.add_charge fires knowledge_charge_changed
	# before this emit returns, so _charge_fraction is current right after.
	EventBus.quiz_answered.emit(quiz_id, correct)

	_set_row_color(correct_idx, COL_ROW_RIGHT)
	if choice >= 0 and not correct:
		_set_row_color(choice, COL_ROW_WRONG)
	for i: int in _choice_rows.size():
		if i != correct_idx and i != choice:
			_choice_labels[i].add_theme_color_override("font_color", COL_DIM)

	var lead: String
	var lead_color: Color
	if correct and _charge_fraction >= 1.0:
		lead = "The strike is ready!"
		lead_color = COL_GOLD
		_will_close = true
		_completed = true
	elif correct:
		lead = "Focus surges — one more!"
		lead_color = COL_BLUE
		_will_close = false
	elif choice < 0:
		lead = "Out of time — the focus slips…"
		lead_color = COL_RED
		_will_close = true
	else:
		lead = "Not quite — the focus slips…"
		lead_color = COL_RED
		_will_close = true
	_result_label.text = "%s\n%s" % [lead, str(_question.get("explanation", ""))]
	_result_label.add_theme_color_override("font_color", lead_color)
	_hint_label.text = "any answer key continues"
	_draw_timer(0.0)


func _tick_reveal(now: int) -> void:
	var elapsed: float = float(now - _reveal_start_ms) / 1000.0
	var skip: bool = false
	if elapsed > REVEAL_MIN:
		for action: StringName in ANSWER_ACTIONS:
			if Input.is_action_just_pressed(action):
				skip = true
				break
	if not skip and elapsed < _reveal_time:
		return
	_advance_reveal()


## Leaves the explanation beat: either the cast is over (fizzled, or filled and
## about to fire) or the next question comes up. Also the landing spot for a
## deliberate skip, so both routes out of REVEAL run identical code.
func _advance_reveal() -> void:
	if _will_close:
		_close(_completed)
		return
	var q: Dictionary = _picker.next()
	if q.is_empty():
		_close(false)  # bank exhausted mid-cast — end kindly, keep the focus
		return
	_show_question(q)


# --- Code-built card ---------------------------------------------------------

func _build_card() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Behind everything: the meadow dimmed down. The channel drops the world to
	# 0.15 speed, but a bright field behind a floating panel still reads as "the
	# game is running and something is in the way" — the scrim is what makes it
	# read as "everything has stopped for this".
	_scrim = ColorRect.new()
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.color = Color(0.02, 0.03, 0.06, 0.0)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_scrim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	_panel = panel
	panel.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_BG
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(20.0)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)
	_title_label = _label("FOCUS — with Bit", 15, COL_GOLD)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)
	_pips_label = _label("◆", 15, COL_GOLD)
	header.add_child(_pips_label)

	# Bit's voice, on the card. Her floating world label sits at her body, which
	# is directly behind this panel while she channels over Kern's head — every
	# one of her cast lines was rendering unreadable behind the card.
	_bit_label = _label("", 14, COL_BLUE)
	_bit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_bit_label)

	# The focus being forged, repeated here because during a cast the player's
	# eyes are on the card, not on the sliver in the corner of the HUD.
	var meter_row: HBoxContainer = HBoxContainer.new()
	meter_row.add_theme_constant_override("separation", 10)
	meter_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(meter_row)
	var meter_bg: Control = Control.new()
	meter_bg.custom_minimum_size = Vector2(210.0, 10.0)
	meter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter_row.add_child(meter_bg)
	var meter_back: ColorRect = ColorRect.new()
	meter_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	meter_back.color = Color(0.05, 0.05, 0.09, 0.85)
	meter_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter_bg.add_child(meter_back)
	_meter_fill = ColorRect.new()
	_meter_fill.size = Vector2(0.0, 10.0)
	_meter_fill.color = COL_BLUE
	_meter_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter_bg.add_child(_meter_fill)
	_meter_label = _label("", 13, COL_DIM)
	meter_row.add_child(_meter_label)

	_timer_bg = Control.new()
	_timer_bg.custom_minimum_size = Vector2(0.0, 6.0)
	_timer_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_timer_bg)
	var timer_back: ColorRect = ColorRect.new()
	timer_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	timer_back.color = Color(0.05, 0.05, 0.09, 0.8)
	timer_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_bg.add_child(timer_back)
	_timer_fill = ColorRect.new()
	_timer_fill.position = Vector2.ZERO
	_timer_fill.size = Vector2(0.0, 6.0)
	_timer_fill.color = COL_BLUE
	_timer_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_bg.add_child(_timer_fill)

	# The countdown belongs at the card's top edge, away from the focus meter:
	# side by side, two blue bars of similar weight read as one broken widget.
	vbox.move_child(_timer_bg, 0)

	_question_label = _label("", 20, Color.WHITE)
	_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_question_label)

	for i: int in 4:
		var row: PanelContainer = PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row_sb: StyleBoxFlat = StyleBoxFlat.new()
		row_sb.bg_color = COL_ROW
		row_sb.set_corner_radius_all(8)
		row_sb.set_content_margin_all(10.0)
		row.add_theme_stylebox_override("panel", row_sb)
		vbox.add_child(row)
		var choice: Label = _label("", 17, Color.WHITE)
		choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(choice)
		_choice_rows.append(row)
		_choice_labels.append(choice)

	# Always present, never hidden: it holds the card's height steady so the
	# reveal doesn't shove the whole panel up the screen (see REVEAL_RESERVE).
	_result_label = _label("", 16, COL_BLUE)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.custom_minimum_size = Vector2(0.0, REVEAL_RESERVE)
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vbox.add_child(_result_label)

	_hint_label = _label("", 13, COL_DIM)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_hint_label)


func _label(text: String, size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _set_row_color(index: int, color: Color) -> void:
	var sb: StyleBoxFlat = _choice_rows[index].get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.bg_color = color


func _draw_timer(fraction: float) -> void:
	var f: float = clampf(fraction, 0.0, 1.0)
	_timer_fill.size = Vector2(_timer_bg.size.x * f, 6.0)
	if f < 0.25:
		_timer_fill.color = COL_RED
	elif f < 0.5:
		_timer_fill.color = COL_GOLD
	else:
		_timer_fill.color = COL_BLUE
