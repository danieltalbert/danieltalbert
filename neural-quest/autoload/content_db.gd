extends Node
## ContentDb: loads all game content from res://data and registers input
## actions. Every other system reads content through this autoload; no
## teaching strings live anywhere else.

var worlds: Array = []
var meta: Dictionary = {}
var map: Dictionary = {}

var _worlds_by_id: Dictionary = {}


func _init() -> void:
	_register_inputs()


func _ready() -> void:
	worlds = _load_json("res://data/worlds.json")
	meta = _load_json("res://data/meta.json")
	map = _load_json("res://data/map.json")
	for w in worlds:
		_worlds_by_id[int(w["id"])] = w
	assert(worlds.size() == 20, "content: expected 20 worlds")
	assert(map["shards"].size() == 60, "content: expected 60 shards")


func world(id: int) -> Dictionary:
	return _worlds_by_id.get(id, {})


func act(act_id: int) -> Dictionary:
	for a in meta.get("acts", []):
		if int(a["id"]) == act_id:
			return a
	return {}


func act_for_world(id: int) -> Dictionary:
	var w := world(id)
	return act(int(w.get("act", 1)))


func constant(key: String) -> Variant:
	return meta.get("constants", {}).get(key)


func titles() -> Array:
	return meta.get("titles", [])


func achievements() -> Dictionary:
	return meta.get("achievements", {})


func palette_color(act_id: int, key: String) -> Color:
	var a := act(act_id)
	return Color(str(a.get("palette", {}).get(key, "#ff00ff")))


func tile_at(x: int, y: int) -> String:
	var rows: Array = map.get("rows", [])
	if y < 0 or y >= rows.size():
		return "#"
	var row: String = rows[y]
	if x < 0 or x >= row.length():
		return "#"
	return row[x]


func is_solid(x: int, y: int) -> bool:
	return tile_at(x, y) == "#"


func _load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "content: missing " + path)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	assert(parsed != null, "content: invalid JSON in " + path)
	return parsed


## Input actions are registered in code so project.godot stays free of
## hand-written InputEventKey blobs (see CLAUDE.md architecture notes).
func _register_inputs() -> void:
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("sprint", [KEY_SHIFT])
	_add_action("ui_confirm", [KEY_ENTER, KEY_SPACE, KEY_Z])
	_add_action("ui_back", [KEY_ESCAPE, KEY_X])
	_add_action("answer_1", [KEY_1])
	_add_action("answer_2", [KEY_2])
	_add_action("answer_3", [KEY_3])
	_add_action("toggle_mute", [KEY_M])
	_add_action("toggle_map", [KEY_TAB])


func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	_add_gamepad(action)


## Gamepad bindings: left stick and dpad move, A confirms, B backs out,
## X or right shoulder sprints, Y toggles the minimap.
func _add_gamepad(action: String) -> void:
	var axes := {
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
	}
	var buttons := {
		"move_up": [JOY_BUTTON_DPAD_UP], "move_down": [JOY_BUTTON_DPAD_DOWN],
		"move_left": [JOY_BUTTON_DPAD_LEFT], "move_right": [JOY_BUTTON_DPAD_RIGHT],
		"sprint": [JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER],
		"ui_confirm": [JOY_BUTTON_A], "ui_back": [JOY_BUTTON_B],
		"toggle_map": [JOY_BUTTON_Y],
	}
	if axes.has(action):
		var m := InputEventJoypadMotion.new()
		m.axis = axes[action][0]
		m.axis_value = axes[action][1]
		InputMap.action_add_event(action, m)
	for b in buttons.get(action, []):
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)
