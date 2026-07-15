class_name VictoryScreen
extends CanvasLayer
## Victory screen: shown once when the 20th boss falls. The world stays
## open for free roam afterward, crown included.

signal closed

const GOLD := Color("#ffd45e")
const TEXT := Color("#e8e6f0")
const DIM_TEXT := Color("#9aa0b8")


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "ALL 20 BOSSES CLEARED"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var body := Label.new()
	body.text = "You wear the golden crown of the\nLatent Space. The world is yours to\nroam: shards, reviews, and the\nGolden Glitch await."
	body.add_theme_font_size_override("font_size", 8)
	body.add_theme_color_override("font_color", TEXT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(body)

	var stats := Label.new()
	stats.text = "XP %d   LV %d %s\nShards %d/60   Glitches caught %d" % [
		GameState.xp, GameState.level(), GameState.current_title(),
		GameState.shards.size(), GameState.glitch_catches]
	stats.add_theme_font_size_override("font_size", 7)
	stats.add_theme_color_override("font_color", DIM_TEXT)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats)

	var btn := Button.new()
	btn.text = "Keep exploring"
	btn.custom_minimum_size = Vector2(150, 24)
	btn.add_theme_font_size_override("font_size", 8)
	btn.pressed.connect(_close)
	vbox.add_child(btn)

	Sfx.play("fanfare")


func _close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()
