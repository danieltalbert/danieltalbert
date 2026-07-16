class_name LabPanel
extends CanvasLayer
## LabPanel: hosts one interactive lab from LabLibrary. Input comes from
## the keyboard or gamepad (move actions plus confirm) and from on-screen
## arrow buttons so touch players can drive every lab too.

signal closed

const PANEL_BG := Color("#141728")
const PANEL_BORDER := Color("#3a3f5c")
const TEXT := Color("#e8e6f0")
const DIM_TEXT := Color("#9aa0b8")
const GOLD := Color("#ffd45e")
const GREEN := Color("#58e07a")
const XP_BLUE := Color("#7ee0ff")

var world_id := 1

var _lab: LabLibrary.BaseLab
var _rewarded := false
var _panel: PanelContainer
var _title: Label
var _goal: Label
var _canvas: Control
var _status: Label
var _flash: Label
var _close_btn: Button


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
	dim.color = Color(0, 0, 0, 0.6)
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
	style.set_content_margin_all(5)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(228, 0)
	_panel.pivot_offset = Vector2(114, 150)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_panel.add_child(vbox)

	_title = _label(vbox, 8, GOLD)
	_goal = _label(vbox, 7, DIM_TEXT)

	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(216, 118)
	_canvas.draw.connect(_on_canvas_draw)
	vbox.add_child(_canvas)

	_status = _label(vbox, 7, XP_BLUE)
	_flash = _label(vbox, 7, TEXT)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)
	for spec in [["<", "left"], ["v", "down"], ["^", "up"], [">", "right"], ["OK", "ok"]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(34 if spec[0] == "OK" else 26, 22)
		b.add_theme_font_size_override("font_size", 8)
		b.focus_mode = Control.FOCUS_NONE
		var act: String = spec[1]
		b.pressed.connect(func(): _apply(act))
		row.add_child(b)

	_close_btn = Button.new()
	_close_btn.custom_minimum_size = Vector2(216, 22)
	_close_btn.add_theme_font_size_override("font_size", 8)
	_close_btn.text = "Leave"
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.pressed.connect(close)
	vbox.add_child(_close_btn)


func _label(parent: Node, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(216, 0)
	parent.add_child(l)
	return l


func _on_canvas_draw() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color(0, 0, 0, 0.45))
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size),
		GOLD if _lab != null and _lab.done else PANEL_BORDER, false, 1.0)
	if _lab != null:
		_lab.render(_canvas)


func open(id: int) -> void:
	world_id = id
	_lab = LabLibrary.make(id)
	_rewarded = GameState.lab_done(id)
	var w := ContentDb.world(id)
	var lab_meta: Dictionary = w["lab"]
	var replay := "  [REPLAY]" if _rewarded else ""
	_title.text = "LAB: %s%s" % [lab_meta["name"], replay]
	_goal.text = str(lab_meta["goal"])
	_flash.text = str(_lab.hint())
	_refresh()

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
	if event.is_action_pressed("move_left", true):
		_apply("left")
	elif event.is_action_pressed("move_right", true):
		_apply("right")
	elif event.is_action_pressed("move_up", true):
		_apply("up")
	elif event.is_action_pressed("move_down", true):
		_apply("down")
	elif event.is_action_pressed("ui_confirm"):
		_apply("ok")
	elif event.is_action_pressed("ui_back"):
		close()


func _apply(action: String) -> void:
	if _lab == null:
		return
	var was_done := _lab.done
	_lab.flash = ""
	_lab.handle(action)
	if _lab.done and not was_done:
		Sfx.play("correct")
		_close_btn.text = "Continue"
		if not _rewarded:
			_rewarded = true
			var gained := GameState.grant_xp(int(ContentDb.constant("xp_lab")))
			GameState.mark_lab_done(world_id)
			_flash.text = "Lab complete!  +%d XP" % gained
		else:
			_flash.text = "Lab complete! (replay, no XP)"
		_flash.add_theme_color_override("font_color", GREEN)
	elif _lab.flash != "":
		Sfx.play("blip")
		_flash.text = _lab.flash
		_flash.add_theme_color_override("font_color", TEXT)
	_refresh()


func _refresh() -> void:
	_status.text = str(_lab.status())
	_canvas.queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	closed.emit()
