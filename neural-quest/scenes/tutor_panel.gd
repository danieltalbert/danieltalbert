class_name TutorPanel
extends CanvasLayer
## TutorPanel: two-page lesson dialog. Marks the tutor as read when the
## last page is closed. Re-readable forever.

signal closed

const PANEL_BG := Color("#141728")
const PANEL_BORDER := Color("#3a3f5c")
const TEXT := Color("#e8e6f0")
const GOLD := Color("#ffd45e")
const DIM_TEXT := Color("#9aa0b8")

var world_id := 1

var _page := 0
var _panel: PanelContainer
var _name_label: Label
var _topic_label: Label
var _body: Label
var _page_label: Label
var _next_btn: Button


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
	style.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(224, 0)
	_panel.pivot_offset = Vector2(112, 100)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 8)
	_name_label.add_theme_color_override("font_color", GOLD)
	vbox.add_child(_name_label)

	_topic_label = Label.new()
	_topic_label.add_theme_font_size_override("font_size", 7)
	_topic_label.add_theme_color_override("font_color", DIM_TEXT)
	vbox.add_child(_topic_label)

	vbox.add_child(HSeparator.new())

	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 8)
	_body.add_theme_color_override("font_color", TEXT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(212, 120)
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vbox.add_child(_body)

	_page_label = Label.new()
	_page_label.add_theme_font_size_override("font_size", 7)
	_page_label.add_theme_color_override("font_color", DIM_TEXT)
	vbox.add_child(_page_label)

	_next_btn = Button.new()
	_next_btn.custom_minimum_size = Vector2(212, 24)
	_next_btn.add_theme_font_size_override("font_size", 8)
	_next_btn.pressed.connect(_on_next)
	vbox.add_child(_next_btn)


func open(id: int) -> void:
	world_id = id
	_page = 0
	_show_page()
	visible = true
	get_tree().paused = true
	Sfx.play("panel_open")
	_next_btn.grab_focus()
	_panel.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_page() -> void:
	var w := ContentDb.world(world_id)
	var tut: Dictionary = w["tutor"]
	var pages: Array = tut["pages"]
	_name_label.text = "%s" % tut["name"]
	_topic_label.text = "Lesson: %s" % w["topic"]
	_body.text = str(pages[_page])
	_page_label.text = "Page %d of %d" % [_page + 1, pages.size()]
	_next_btn.text = "Next" if _page < pages.size() - 1 else "Thanks!"


func _on_next() -> void:
	var w := ContentDb.world(world_id)
	var pages: Array = w["tutor"]["pages"]
	if _page < pages.size() - 1:
		_page += 1
		Sfx.play("page")
		_show_page()
	else:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_confirm"):
		_on_next()
	elif event.is_action_pressed("ui_back"):
		_finish()


func _finish() -> void:
	if not visible:
		return
	# Reading counts once the dialog is dismissed from the last page; an
	# early exit still counts as read only if the last page was reached.
	var w := ContentDb.world(world_id)
	if _page >= (w["tutor"]["pages"] as Array).size() - 1:
		GameState.mark_tutor_read(world_id)
	visible = false
	get_tree().paused = false
	closed.emit()
