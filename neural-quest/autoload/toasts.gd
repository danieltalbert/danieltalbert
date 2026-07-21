extends CanvasLayer
## Toasts: queued pop-in notifications (achievements, level ups, hints).
## One toast shows at a time, sliding in from the top of the screen.

const SHOW_TIME := 2.0
const PANEL_BG := Color("#141728")
const PANEL_BORDER := Color("#3a3f5c")
const TEXT_COLOR := Color("#e8e6f0")
const GOLD := Color("#ffd45e")

var _queue: Array = []
var _busy := false


func _ready() -> void:
	layer = 100
	# Toasts keep animating while quiz panels pause the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_toast(text: String, gold: bool = false) -> void:
	_queue.append({"text": text, "gold": gold})
	if not _busy:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var item: Dictionary = _queue.pop_front()

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = GOLD if item["gold"] else PANEL_BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = item["text"]
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", GOLD if item["gold"] else TEXT_COLOR)
	panel.add_child(label)
	add_child(panel)

	panel.reset_size()
	var vp := get_viewport().get_visible_rect().size
	var w := panel.size.x
	panel.position = Vector2(roundf((vp.x - w) / 2.0), -20)

	var tw := create_tween()
	tw.tween_property(panel, "position:y", 6.0, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(SHOW_TIME)
	tw.tween_property(panel, "position:y", -24.0, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(panel.queue_free)
	tw.tween_callback(_show_next)
