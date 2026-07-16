class_name Journal
extends PanelContainer
## Quest journal: one row per zone showing tutor, mini, lab, boss, and
## shard progress. Toggled with J, gamepad, or the LOG button.

const TEXT := Color("#e8e6f0")
const DIM := Color("#9aa0b8")
const GOLD := Color("#ffd45e")

var _rows: Array = []
var _totals: Label


func _ready() -> void:
	visible = false
	position = Vector2(8, 26)
	custom_minimum_size = Vector2(224, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.078, 0.09, 0.157, 0.94)
	style.border_color = Color("#3a3f5c")
	style.set_border_width_all(1)
	style.set_content_margin_all(5)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	add_child(vbox)

	var header := Label.new()
	header.text = "QUEST JOURNAL  [T]utor [M]ini [L]ab [B]oss [R]ematch"
	header.add_theme_font_size_override("font_size", 7)
	header.add_theme_color_override("font_color", GOLD)
	vbox.add_child(header)

	_totals = Label.new()
	_totals.add_theme_font_size_override("font_size", 7)
	_totals.add_theme_color_override("font_color", DIM)
	vbox.add_child(_totals)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(214, 230)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)

	for i in 20:
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 7)
		list.add_child(row)
		_rows.append(row)


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	var per_zone := 0
	for id in range(1, 21):
		var w := ContentDb.world(id)
		var t := GameState.tutor_read(id)
		var m := GameState.mini_beaten(id)
		var l := GameState.lab_done(id)
		var b := GameState.boss_cleared(id)
		var s := 0
		for k in 3:
			if GameState.shard_collected((id - 1) * 3 + k):
				s += 1
		var complete := t and m and l and b and s == 3
		if complete:
			per_zone += 1
		var marks := "%s%s%s%s%s S%d/3" % [
			"T" if t else "-", "M" if m else "-",
			"L" if l else "-", "B" if b else "-",
			"R" if GameState.battle_won(id) else "-", s]
		var row: Label = _rows[id - 1]
		row.text = "%s%2d %s  %s" % ["* " if complete else "  ", id, w["world"], marks]
		row.add_theme_color_override("font_color", GOLD if complete else TEXT)
	_totals.text = "Zones fully cleared: %d/20   XP %d   %s" % [
		per_zone, GameState.xp, GameState.current_title()]
