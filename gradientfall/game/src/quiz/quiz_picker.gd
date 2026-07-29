class_name QuizPicker
extends RefCounted
## Selects questions from the approved ContentDB quiz bank for the knowledge
## channel — Phase 1 milestone 7.
##
## Difficulty gating is the WORLDBOOK Part III rule verbatim: D1–2 anywhere;
## D3 after Shrine 3; D4 after Shrine 6; D5 only in the Citadel / endgame.
## Shrines don't exist yet, so the gate reads the shrine flags they WILL set
## (`shrine_N_cleared`, N 1..9) and resolves to D1–2 across the whole
## vertical slice — it scales automatically as the campaign lands.
##
## Selection is a shuffle bag — no question repeats until every eligible one
## has been asked — but the bag is ORDERED BY WHAT KERN STILL NEEDS, in three
## tiers drawn in turn:
##
##   1. never seen        — new ground first
##   2. seen and missed   — the ones he got wrong come back around
##   3. seen and answered — only once the first two run dry
##
## That ordering is the whole point of a teaching game (GDD pillar 3): a flat
## shuffle would ask a player the question they already aced three times before
## re-asking the one that beat them. Mastery rides in `GameState.flags`, which
## is already serialized, so none of this changes the save shape or needs a
## SAVE_VERSION bump — the same trick milestone 13's iris specimens use.

## Flag prefixes. Kept here so the save file's keys have one definition.
const SEEN_PREFIX: String = "quiz_seen_"
const MISSED_PREFIX: String = "quiz_missed_"

var _bag: Array[Dictionary] = []
var _bag_limit: int = -1
var _last_id: String = ""


## The campaign-progress → max-difficulty function (WORLDBOOK Part III).
static func max_difficulty() -> int:
	if GameState.current_region == "corpus_citadel" or GameState.has_flag("endgame_unlocked"):
		return 5
	var shrines: int = 0
	for i: int in range(1, 10):
		if GameState.has_flag("shrine_%d_cleared" % i):
			shrines += 1
	if shrines >= 6:
		return 4
	if shrines >= 3:
		return 3
	return 2


## Next question at the allowed difficulty, or {} if the bank has none.
func next() -> Dictionary:
	var limit: int = max_difficulty()
	if _bag.is_empty() or _bag_limit != limit:
		_refill(limit)
	if _bag.is_empty():
		return {}
	var q: Dictionary = _bag.pop_back()
	# Don't let a fresh shuffle immediately repeat the last question asked.
	if str(q.get("id", "")) == _last_id and not _bag.is_empty():
		_bag.push_front(q)
		q = _bag.pop_back()
	_last_id = str(q.get("id", ""))
	return q


## Records how an answer went, so the next bag can put the missed ones first.
## Called by KnowledgePrompt as it resolves. A question answered correctly stops
## being "missed" — a miss is a debt, not a permanent mark against the player.
func record(quiz_id: String, correct: bool) -> void:
	if quiz_id.is_empty():
		return
	GameState.set_flag(SEEN_PREFIX + quiz_id, true)
	GameState.set_flag(MISSED_PREFIX + quiz_id, not correct)


## How many eligible questions exist right now — the honest size of the bank at
## the player's current difficulty gate. Used by the boot log and the probe.
static func eligible_count() -> int:
	var limit: int = max_difficulty()
	var n: int = 0
	for quiz: Dictionary in ContentDB.get_all("quizzes"):
		if int(quiz.get("difficulty", 99)) <= limit:
			n += 1
	return n


## Rebuilds the bag: three shuffled tiers, stacked so `pop_back()` serves the
## neediest first (the array is drawn from the END, so tier 1 is appended last).
func _refill(limit: int) -> void:
	_bag_limit = limit
	_bag.clear()
	var unseen: Array[Dictionary] = []
	var missed: Array[Dictionary] = []
	var known: Array[Dictionary] = []
	for quiz: Dictionary in ContentDB.get_all("quizzes"):
		if int(quiz.get("difficulty", 99)) > limit:
			continue
		var id: String = str(quiz.get("id", ""))
		if not GameState.has_flag(SEEN_PREFIX + id):
			unseen.append(quiz)
		elif GameState.has_flag(MISSED_PREFIX + id):
			missed.append(quiz)
		else:
			known.append(quiz)
	unseen.shuffle()
	missed.shuffle()
	known.shuffle()
	_bag.append_array(known)
	_bag.append_array(missed)
	_bag.append_array(unseen)
