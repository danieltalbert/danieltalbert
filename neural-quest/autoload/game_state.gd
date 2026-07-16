extends Node
## GameState: progress, XP, streak, achievements, save and load.
## Persistent fields go to user://neural_quest_save.json. The streak is
## session-only by design and is never saved.

signal xp_gained(amount: int, total: int)
signal level_up(level: int, title: String)
signal streak_changed(streak: int, multiplier: float)
signal achievement_unlocked(id: String, name: String)
signal progress_changed

const SAVE_PATH := "user://neural_quest_save.json"
const SAVE_VERSION := 1

var xp: int = 0
var bosses: Dictionary = {}        # id (int) -> {"first_try": bool}
var minis: Dictionary = {}         # id (int) -> true
var tutors: Dictionary = {}        # id (int) -> true
var labs: Dictionary = {}          # id (int) -> true
var shards: Dictionary = {}        # shard index (int) -> true
var achievements: Dictionary = {}  # ach id (String) -> true
var glitch_catches: int = 0
var muted: bool = false

# Session-only.
var streak: int = 0


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func reset() -> void:
	xp = 0
	bosses = {}
	minis = {}
	tutors = {}
	labs = {}
	shards = {}
	achievements = {}
	glitch_catches = 0
	streak = 0
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


func save() -> void:
	var data := {
		"v": SAVE_VERSION,
		"xp": xp,
		"bosses": _keys_to_str(bosses),
		"minis": _keys_to_str(minis),
		"tutors": _keys_to_str(tutors),
		"labs": _keys_to_str(labs),
		"shards": _keys_to_str(shards),
		"achievements": achievements,
		"glitch_catches": glitch_catches,
		"muted": muted,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("GameState: could not open save file for writing")
		return
	f.store_string(JSON.stringify(data))


func load_save() -> void:
	if not has_save():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("GameState: corrupt save, starting fresh")
		return
	xp = int(data.get("xp", 0))
	bosses = _keys_to_int(data.get("bosses", {}))
	minis = _keys_to_int(data.get("minis", {}))
	tutors = _keys_to_int(data.get("tutors", {}))
	labs = _keys_to_int(data.get("labs", {}))
	shards = _keys_to_int(data.get("shards", {}))
	achievements = data.get("achievements", {})
	glitch_catches = int(data.get("glitch_catches", 0))
	muted = bool(data.get("muted", false))


# ---- XP, levels, streak ----

func level() -> int:
	return int(xp / int(ContentDb.constant("xp_per_level"))) + 1


func title_for_level(lv: int) -> String:
	var t: Array = ContentDb.titles()
	return t[clampi(lv - 1, 0, t.size() - 1)]


func current_title() -> String:
	return title_for_level(level())


func streak_multiplier() -> float:
	var mults: Array = ContentDb.constant("streak_multipliers")
	return float(mults[clampi(streak, 0, mults.size() - 1)])


## Award base XP scaled by the current streak multiplier. Returns the
## actual amount granted. Emits level_up if a level boundary was crossed.
func grant_xp(base: int) -> int:
	var amount := int(floor(base * streak_multiplier()))
	var old_level := level()
	xp += amount
	xp_gained.emit(amount, xp)
	if level() > old_level:
		level_up.emit(level(), current_title())
	save()
	return amount


## Record the outcome of a quiz answer for streak purposes.
## first_try_win extends the streak even in review mode (reviews grant no XP
## but can keep a streak alive). Any wrong answer resets it.
func record_answer(first_try_win: bool) -> void:
	if first_try_win:
		streak += 1
		_check_streak_achievements()
	else:
		streak = 0
	streak_changed.emit(streak, streak_multiplier())


# ---- Progress marks ----

func mark_boss_cleared(id: int, first_try: bool) -> void:
	bosses[id] = {"first_try": first_try}
	_check_boss_achievements()
	progress_changed.emit()
	save()


func boss_cleared(id: int) -> bool:
	return bosses.has(id)


func bosses_cleared_count() -> int:
	return bosses.size()


func all_bosses_cleared() -> bool:
	return bosses.size() >= 20


func mark_mini_beaten(id: int) -> void:
	minis[id] = true
	if minis.size() >= 20:
		unlock("minis_all")
	progress_changed.emit()
	save()


func mini_beaten(id: int) -> bool:
	return minis.has(id)


func mark_lab_done(id: int) -> void:
	labs[id] = true
	unlock("labs_first")
	if labs.size() >= 20:
		unlock("labs_all")
	progress_changed.emit()
	save()


func lab_done(id: int) -> bool:
	return labs.has(id)


func mark_tutor_read(id: int) -> void:
	tutors[id] = true
	if tutors.size() >= 20:
		unlock("tutors_all")
	progress_changed.emit()
	save()


func tutor_read(id: int) -> bool:
	return tutors.has(id)


func mark_shard(index: int) -> void:
	shards[index] = true
	if shards.size() >= int(ContentDb.constant("shard_count")):
		unlock("shards_all")
	save()


func shard_collected(index: int) -> bool:
	return shards.has(index)


func mark_glitch_catch() -> void:
	glitch_catches += 1
	unlock("glitch_first")
	if glitch_catches >= 5:
		unlock("glitch_five")
	save()


## Topics the player has engaged with in any way (tutor, mini, or boss).
## The Golden Glitch draws its remix questions from this pool.
func engaged_world_ids() -> Array:
	var ids := {}
	for id in bosses:
		ids[id] = true
	for id in minis:
		ids[id] = true
	for id in tutors:
		ids[id] = true
	for id in labs:
		ids[id] = true
	var out: Array = ids.keys()
	out.sort()
	return out


# ---- Achievements ----

func unlock(id: String) -> void:
	if achievements.has(id):
		return
	var defs: Dictionary = ContentDb.achievements()
	if not defs.has(id):
		push_warning("GameState: unknown achievement " + id)
		return
	achievements[id] = true
	achievement_unlocked.emit(id, defs[id]["name"])
	save()


func _check_boss_achievements() -> void:
	if bosses.size() >= 1:
		unlock("boss_first")
	if bosses.size() >= 10:
		unlock("boss_ten")
	if bosses.size() >= 20:
		unlock("boss_all")
	var first_try_count := 0
	for id in bosses:
		if bosses[id].get("first_try", false):
			first_try_count += 1
	if first_try_count >= 10:
		unlock("first_try_ten")


func _check_streak_achievements() -> void:
	if streak >= 5:
		unlock("streak_five")


# ---- helpers ----

func _keys_to_str(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[str(k)] = d[k]
	return out


func _keys_to_int(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[int(k)] = d[k]
	return out
