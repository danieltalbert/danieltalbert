class_name ChannelProbe
extends Node
## Dev-only automated pass over the knowledge channel — Phase 1 milestone 7.
##
## Milestone 7 was built across three sessions that had no Godot at all, so
## every one of its branches shipped unexecuted: the card, the slow-mo, the
## fizzle, the auto-firing strike. This probe is the tool that makes it
## verifiable without a human at the keyboard. It drives the REAL input path
## (`Input.parse_input_event`, the same route the OS takes) rather than poking
## private state, so what it proves is what a player gets.
##
## Run it:
##     godot --path game --headless -- --test-channel
## It prints one line per assertion, a PASS/FAIL tally, and quits with exit
## code 0 only if every scenario passed — so CI or a session can trust it.
##
## Frame-timing contract this relies on, and why it matters:
##   * `process_priority` is very low, so the probe's `_process` runs BEFORE
##     KnowledgePrompt's in the same frame. An event injected here is therefore
##     visible to the card's `Input.is_action_just_pressed` this same frame.
##   * A physics reader (PlayerCombat) sees that same event on the NEXT physics
##     step. That one-step skew is not an artifact of the probe — it is exactly
##     what happens with a real keyboard, and scenario `cancel_no_reopen` exists
##     because it once caused a real bug.

## Emitted when the whole pass finishes, so a harness can react. `failures` is 0
## on a clean run.
signal finished(passed: int, failures: int)

## Stands in for the real picker to stage the "bank has nothing eligible" case
## without putting a test branch in shipping code.
class EmptyPicker extends QuizPicker:
	func next() -> Dictionary:
		return {}


const ANSWER_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]

# Compressed clocks so the timeout branch costs a fraction of a second instead
# of the shipping 12 s. Only the probe ever moves them.
const PROBE_QUESTION_TIME: float = 0.6
const PROBE_REVEAL_TIME: float = 0.25

var _prompt: KnowledgePrompt
var _combat: PlayerCombat
var _passed: int = 0
var _failed: int = 0
var _log: PackedStringArray = []
var _channel_ends: Array[bool] = []


## Wired by main.gd. With `shot_dir` empty it runs the assertion pass
## (`--test-channel`); with a directory it instead drives the card through its
## states and saves a PNG at each one (`--shot-channel=DIR`), which is how a
## session satisfies GDD §10 for a surface that only exists mid-combat.
func setup(prompt: KnowledgePrompt, combat: PlayerCombat, shot_dir: String = "") -> void:
	_prompt = prompt
	_combat = combat
	process_priority = -1000
	EventBus.knowledge_channel_ended.connect(func(completed: bool) -> void:
		_channel_ends.append(completed))
	if shot_dir.is_empty():
		_run()
	else:
		_run_shots(shot_dir)


# --- Visual evidence ---------------------------------------------------------

## Poses the card in each of its states and photographs it. Runs at the SHIPPING
## timings (no `debug_set_timings`), so what lands on disk is what a player sees.
func _run_shots(dir: String) -> void:
	await _settle(90)  # terrain, shadows and TAA converge
	print("=== knowledge-channel shots -> %s ===" % dir)

	await _tap_special()
	await _settle(6)
	await _shoot(dir, "channel_question")

	# The teaching beat, both ways round. Wrong first: it fizzles and closes,
	# so the correct-answer shot needs its own fresh cast afterwards.
	await _answer(_wrong_index())
	await _settle(8)
	await _shoot(dir, "channel_reveal_wrong")
	await _wait_real(KnowledgePrompt.REVEAL_TIME + 0.4)

	_zero_charge()
	await _tap_special()
	await _settle(6)
	await _answer(_correct_index())
	await _settle(8)
	await _shoot(dir, "channel_reveal_correct")

	# Ride the same cast to a full meter and photograph the climax frame.
	var guard: int = 0
	while _prompt.is_open() and guard < 40:
		guard += 1
		if _prompt.state_name() == "ASKING":
			if _combat.charge() + PlayerCombat.CHARGE_PER_QUIZ >= 1.0:
				await _shoot(dir, "channel_last_question")
			await _answer(_correct_index())
			await _settle(8)
			if _prompt.is_open() and _combat.charge() >= 0.99:
				await _shoot(dir, "channel_strike_ready")
			# Return the instant the card closes: the strike fires on close and
			# lives well under a second, so sleeping out the full reveal here
			# photographed an empty meadow long after the nova had gone.
			await _wait_until_closed(KnowledgePrompt.REVEAL_TIME + 0.6)
		else:
			# Sit out the explanation on ITS clock, not on a frame count: the
			# shots run at shipping timings, so a reveal lasts REVEAL_TIME.
			await _wait_real(0.25)
	# The strike rides PlayerCombat's 0.05-scale hitstop, so the nova blooms in
	# slow motion for ~90 ms of wall clock. Catch it early and again as it opens.
	await _settle(3)
	await _shoot(dir, "channel_strike")
	await _settle(9)
	await _shoot(dir, "channel_strike_bloom")
	await _settle(40)
	await _shoot(dir, "channel_after")
	get_tree().quit()


func _shoot(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = dir.path_join(shot_name + ".png")
	var err: int = img.save_png(path)
	print("Screenshot %s -> %s" % ["OK" if err == OK else "FAILED", path])


# --- The pass ----------------------------------------------------------------

func _run() -> void:
	await _settle(20)
	_prompt.debug_set_timings(PROBE_QUESTION_TIME, PROBE_REVEAL_TIME)
	print("\n=== knowledge-channel probe: milestone 7 ===")

	await _scenario_open()
	await _scenario_correct_answer()
	await _scenario_wrong_answer()
	await _scenario_timeout()
	await _scenario_cancel_no_reopen()
	await _scenario_fill_and_fire()
	await _scenario_death_closes()
	await _scenario_empty_bank()
	await _scenario_no_double_open()
	await _scenario_invuln_released()
	await _scenario_modal_exclusion()
	_scenario_mastery_ordering()
	_scenario_bank_health()

	print("=== probe: %d passed, %d failed ===" % [_passed, _failed])
	for line: String in _log:
		print("   ", line)
	finished.emit(_passed, _failed)
	get_tree().quit(0 if _failed == 0 else 1)


# --- Scenarios ---------------------------------------------------------------

## Pressing the special with a part-full meter must open the card, crawl time,
## and make Kern untouchable.
func _scenario_open() -> void:
	_reset()
	await _tap_special()
	await _settle(4)
	_check("open/card is up", _prompt.is_open())
	_check("open/state is ASKING", _prompt.state_name() == "ASKING")
	_check("open/combat knows it is channeling", _combat.is_channeling())
	_check("open/time crawls (%.3f)" % Engine.time_scale,
		is_equal_approx(Engine.time_scale, PlayerCombat.CHANNEL_TIME_SCALE))
	_check("open/a real question is on screen",
		not str(_prompt.current_question().get("question", "")).is_empty())
	_check("open/countdown is running", _prompt.seconds_left() > 0.0)
	await _force_close()


## A correct answer feeds the meter by exactly CHARGE_PER_QUIZ and moves to the
## explanation beat rather than closing.
func _scenario_correct_answer() -> void:
	_reset()
	await _tap_special()
	await _settle(4)
	var before: float = _combat.charge()
	await _answer(_correct_index())
	await _settle(3)
	_check("correct/moves to REVEAL", _prompt.state_name() == "REVEAL")
	_check("correct/meter gained one quiz (%.3f -> %.3f)" % [before, _combat.charge()],
		is_equal_approx(_combat.charge(), before + PlayerCombat.CHARGE_PER_QUIZ))
	_check("correct/card stays up for the next question", _prompt.is_open())
	await _settle(int(PROBE_REVEAL_TIME * 70.0) + 20)
	_check("correct/asks another question", _prompt.state_name() == "ASKING")
	await _force_close()


## A wrong answer fizzles the cast but KEEPS the focus already earned — the
## all-ages kindness in the design brief.
func _scenario_wrong_answer() -> void:
	_reset()
	_combat.add_charge(PlayerCombat.CHARGE_PER_QUIZ)
	await _tap_special()
	await _settle(4)
	var before: float = _combat.charge()
	await _answer(_wrong_index())
	await _settle(3)
	_check("wrong/moves to REVEAL", _prompt.state_name() == "REVEAL")
	_check("wrong/meter is untouched (%.3f)" % _combat.charge(),
		is_equal_approx(_combat.charge(), before))
	await _settle(int(PROBE_REVEAL_TIME * 70.0) + 25)
	_check("wrong/card closes", not _prompt.is_open())
	_check("wrong/focus survives the fizzle (%.3f)" % _combat.charge(),
		is_equal_approx(_combat.charge(), before))
	_check("wrong/reported an incomplete channel",
		_channel_ends.size() > 0 and _channel_ends[-1] == false)
	_check("wrong/time is restored (%.3f)" % Engine.time_scale,
		is_equal_approx(Engine.time_scale, 1.0))


## Letting the countdown run out fizzles the same way a wrong answer does.
func _scenario_timeout() -> void:
	_reset()
	await _tap_special()
	await _settle(4)
	var before: float = _combat.charge()
	await _wait_real(PROBE_QUESTION_TIME + 0.15)
	_check("timeout/moves to REVEAL", _prompt.state_name() == "REVEAL")
	await _wait_real(PROBE_REVEAL_TIME + 0.3)
	_check("timeout/card closes", not _prompt.is_open())
	_check("timeout/focus kept (%.3f)" % _combat.charge(),
		is_equal_approx(_combat.charge(), before))
	_check("timeout/time is restored", is_equal_approx(Engine.time_scale, 1.0))


## Breaking off with the special key must close the card and STAY closed. The
## card reads input on the process frame and PlayerCombat on the next physics
## step, so a naive implementation re-opens the channel one tick later.
func _scenario_cancel_no_reopen() -> void:
	_reset()
	await _tap_special()
	await _settle(4)
	if not _prompt.is_open():
		_check("cancel/card opened to be cancelled", false)
		return
	await _settle(4)
	await _tap_special()
	await _settle(3)
	_check("cancel/card closes on the break-off press", not _prompt.is_open())
	await _settle(20)  # long enough for several physics steps to re-read the key
	_check("cancel/card does NOT re-open a tick later", not _prompt.is_open())
	_check("cancel/combat stopped channeling", not _combat.is_channeling())
	_check("cancel/time is restored (%.3f)" % Engine.time_scale,
		is_equal_approx(Engine.time_scale, 1.0))


## Three correct answers fill the meter; the combined strike fires itself as the
## channel's climax and spends the charge.
func _scenario_fill_and_fire() -> void:
	_reset()
	_zero_charge()
	await _tap_special()
	await _settle(4)
	var casts: int = 0
	while casts < 6 and _prompt.is_open():
		if _prompt.state_name() == "ASKING":
			await _answer(_correct_index())
			casts += 1
		await _settle(4)
		if _prompt.state_name() == "REVEAL":
			await _settle(int(PROBE_REVEAL_TIME * 70.0) + 20)
	_check("fill/card closed after filling the meter", not _prompt.is_open())
	_check("fill/reported a COMPLETED channel",
		_channel_ends.size() > 0 and _channel_ends[-1] == true)
	_check("fill/strike spent the charge (%.3f)" % _combat.charge(),
		_combat.charge() < 0.001)
	# The combined strike is a visible surface — assert it actually spawned,
	# not merely that the meter emptied.
	var struck: bool = false
	for node: Node in get_tree().current_scene.get_children():
		if node is FocusStrike:
			struck = true
			break
	_check("fill/combined strike VFX spawned", struck)
	_check("fill/needed %d correct answers" % casts, casts == 3)
	await _wait_real(0.25)  # the strike's hitstop owns the clock briefly
	_check("fill/time is restored (%.3f)" % Engine.time_scale,
		is_equal_approx(Engine.time_scale, 1.0))


## Dying mid-channel must tear the card down cleanly and hand back time.
func _scenario_death_closes() -> void:
	_reset()
	await _tap_special()
	await _settle(4)
	EventBus.player_died.emit()
	await _settle(4)
	_check("death/card closes", not _prompt.is_open())
	_check("death/combat stopped channeling", not _combat.is_channeling())
	_check("death/time is restored (%.3f)" % Engine.time_scale,
		is_equal_approx(Engine.time_scale, 1.0))


## With no eligible questions the channel must decline gracefully — no card, no
## slow-mo, no stuck invulnerability. Reachable for real: the WORLDBOOK
## difficulty gate can filter the whole approved bank away. Staged by swapping
## in a picker that always comes up empty, so no test branch has to exist in
## shipping code.
func _scenario_empty_bank() -> void:
	_reset()
	var real_picker: QuizPicker = _prompt._picker
	_prompt._picker = EmptyPicker.new()
	await _tap_special()
	await _settle(6)
	_check("empty/no card opened", not _prompt.is_open())
	_check("empty/not left channeling", not _combat.is_channeling())
	_check("empty/time untouched (%.3f)" % Engine.time_scale,
		is_equal_approx(Engine.time_scale, 1.0))
	_prompt._picker = real_picker


## A second special press while the card is already up must not stack channels.
func _scenario_no_double_open() -> void:
	_reset()
	await _tap_special()
	await _settle(4)
	var q_first: String = str(_prompt.current_question().get("id", ""))
	EventBus.knowledge_channel_requested.emit()
	await _settle(3)
	_check("double/question did not change under the player",
		str(_prompt.current_question().get("id", "")) == q_first)
	_check("double/still exactly one channel", _combat.is_channeling())
	await _force_close()


## Kern is untouchable while he channels — and must stop being untouchable the
## instant the card closes. A stuck `set_external_invuln(true)` would make the
## rest of the fight free, and nothing else in the game would report it.
func _scenario_invuln_released() -> void:
	_reset()
	var player: Node = get_tree().get_first_node_in_group(&"player")
	var health: Health = player.get_node("Health") as Health
	await _tap_special()
	await _settle(4)
	_check("invuln/held during the channel", health.is_invulnerable())
	await _force_close()
	await _settle(4)
	_check("invuln/released when the card closes", not health.is_invulnerable())


## The card, the pack, the notebook and a conversation are all full-screen. Only
## one may hold the screen: the pack in particular pauses the tree, which would
## freeze the card's countdown while wall-clock kept running it down.
func _scenario_modal_exclusion() -> void:
	_reset()
	var tree: SceneTree = get_tree()
	await _tap_special()
	await _settle(4)
	_check("modal/channel claimed the screen", UiModality.any_open(tree, _prompt) == false
		and _prompt.is_in_group(UiModality.GROUP))

	var pack: InventoryScreen = _find(&"InventoryScreen") as InventoryScreen
	pack.open()
	await _settle(2)
	_check("modal/pack declines under the card", not pack.is_open())
	_check("modal/tree was never paused", not tree.paused)

	var notebook: CompendiumUi = _find(&"CompendiumUi") as CompendiumUi
	if notebook != null:
		notebook.set_open(true)
		await _settle(2)
		_check("modal/notebook declines under the card", not notebook.is_open)

	await _force_close()
	await _settle(4)
	_check("modal/screen released when the card closes", not UiModality.any_open(tree))

	# And the other way round: the channel must decline under the pack.
	pack.open()
	await _settle(2)
	_check("modal/pack opens once the card is gone", pack.is_open())
	await _tap_special()
	await _settle(6)
	_check("modal/channel declines under the pack", not _prompt.is_open())
	_check("modal/no slow-mo leaked from the refusal (%.3f)" % Engine.time_scale,
		is_equal_approx(Engine.time_scale, 1.0))
	pack.close()
	await _settle(2)
	_check("modal/pack closed and unpaused", not tree.paused)


## The bag must serve what Kern still needs: unseen first, then the ones he got
## wrong, and only then ones he has already answered correctly. Driven straight
## against QuizPicker — no card, no frames, so it is exhaustive and instant.
func _scenario_mastery_ordering() -> void:
	var all: Array[Dictionary] = ContentDB.get_all("quizzes")
	var eligible: Array[String] = []
	for q: Dictionary in all:
		if int(q.get("difficulty", 99)) <= QuizPicker.max_difficulty():
			eligible.append(str(q.get("id", "")))
	if eligible.size() < 3:
		_check("mastery/bank too small to test ordering", false)
		return

	# Mark everything answered, then fail exactly one: it must come up first.
	for id: String in eligible:
		GameState.set_flag(QuizPicker.SEEN_PREFIX + id, true)
		GameState.set_flag(QuizPicker.MISSED_PREFIX + id, false)
	var debt: String = eligible[eligible.size() / 2]
	GameState.set_flag(QuizPicker.MISSED_PREFIX + debt, true)
	var picker: QuizPicker = QuizPicker.new()
	_check("mastery/a missed question comes back first",
		str(picker.next().get("id", "")) == debt)

	# An unseen question outranks even a missed one.
	var fresh: String = eligible[0]
	GameState.set_flag(QuizPicker.SEEN_PREFIX + fresh, false)
	picker = QuizPicker.new()
	_check("mastery/an unseen question outranks a missed one",
		str(picker.next().get("id", "")) == fresh)

	# Answering it correctly clears the debt.
	picker.record(debt, true)
	_check("mastery/a correct answer clears the debt",
		not GameState.has_flag(QuizPicker.MISSED_PREFIX + debt))

	# The bag still never repeats until it is exhausted.
	for id: String in eligible:
		GameState.set_flag(QuizPicker.SEEN_PREFIX + id, false)
		GameState.set_flag(QuizPicker.MISSED_PREFIX + id, false)
	picker = QuizPicker.new()
	var seen: Dictionary = {}
	var repeats: int = 0
	for i: int in eligible.size():
		var id: String = str(picker.next().get("id", ""))
		if seen.has(id):
			repeats += 1
		seen[id] = true
	_check("mastery/no repeat inside one bag of %d" % eligible.size(), repeats == 0)


## Not a code test — a content test. The channel can only ever draw questions
## the WORLDBOOK difficulty gate allows, and a cast spends up to three of them.
## If the eligible bank is small the player sees the same questions within an
## evening, which is a real quality failure even though nothing crashes.
func _scenario_bank_health() -> void:
	var eligible: int = QuizPicker.eligible_count()
	var casts: int = eligible / 3
	print("  [info] eligible bank: %d questions at difficulty <= %d = ~%d full casts"
		% [eligible, QuizPicker.max_difficulty(), casts])
	var topics: Dictionary = {}
	for q: Dictionary in ContentDB.get_all("quizzes"):
		if int(q.get("difficulty", 99)) <= QuizPicker.max_difficulty():
			topics[str(q.get("topic", "?"))] = true
	print("  [info] eligible topics: %s" % ", ".join(topics.keys()))
	_check("bank/at least 30 eligible questions (have %d)" % eligible, eligible >= 30)
	_check("bank/at least 4 eligible topics (have %d)" % topics.size(), topics.size() >= 4)


# --- Driving -----------------------------------------------------------------

## Finds a named singleton UI node anywhere under the current scene.
func _find(node_name: StringName) -> Node:
	return get_tree().current_scene.find_child(String(node_name), true, false)

## Injects a real key press/release through the Input singleton — the same path
## the OS uses, so action remaps and the just_pressed frame rules all apply.
func _tap_key(key: Key) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	await get_tree().process_frame
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _tap_special() -> void:
	await _tap_key(KEY_Q)


func _answer(index: int) -> void:
	await _tap_key(ANSWER_KEYS[clampi(index, 0, 3)])


func _correct_index() -> int:
	return int(_prompt.current_question().get("answer_index", 0))


func _wrong_index() -> int:
	return (_correct_index() + 1) % 4


## Waits N rendered frames. `Engine.time_scale` is low during a channel, so the
## probe counts FRAMES, never in-game seconds.
func _settle(frames: int) -> void:
	for i: int in frames:
		await get_tree().process_frame


## Waits up to `seconds`, returning early the moment the card closes. The strike
## spawns on close and is short-lived, so a fixed sleep misses it entirely.
func _wait_until_closed(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until and _prompt.is_open():
		await get_tree().process_frame


## Waits real wall-clock seconds — the card's own clock, immune to slow-mo.
func _wait_real(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _force_close() -> void:
	if _prompt.is_open():
		EventBus.player_died.emit()
	await _settle(4)
	_reset()


func _reset() -> void:
	_channel_ends.clear()


## Drains the focus meter so a scenario starts from a known zero. Charge is
## deliberately KEPT across fizzles, so it bleeds between scenarios otherwise.
func _zero_charge() -> void:
	_combat.add_charge(-1.0)


# --- Reporting ---------------------------------------------------------------

func _check(what: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  [pass] ", what)
	else:
		_failed += 1
		print("  [FAIL] ", what)
		_log.append("FAIL: " + what)
