class_name TitleScreen
extends CanvasLayer
## Title screen: Continue (when a save exists) and New Game (erase save).

signal start_game(new_game: bool)

const BG := Color("#0b0c14")
const GOLD := Color("#ffd45e")
const CYAN := Color("#4de3d1")
const DIM_TEXT := Color("#9aa0b8")


func _ready() -> void:
	layer = 60
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "NEURAL QUEST"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Descend. Learn. Defeat all 20 bosses."
	subtitle.add_theme_font_size_override("font_size", 8)
	subtitle.add_theme_color_override("font_color", CYAN)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(Control.new())

	if GameState.has_save():
		var cont := _button("Continue")
		cont.pressed.connect(func(): start_game.emit(false))
		vbox.add_child(cont)
		var stats := Label.new()
		stats.text = "LV %d  %s  |  Bosses %d/20" % [
			GameState.level(), GameState.current_title(),
			GameState.bosses_cleared_count()]
		stats.add_theme_font_size_override("font_size", 7)
		stats.add_theme_color_override("font_color", DIM_TEXT)
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(stats)

	var new_btn := _button("New Game (erase save)" if GameState.has_save() else "New Game")
	new_btn.pressed.connect(func(): start_game.emit(true))
	vbox.add_child(new_btn)
	# Focus the safest default so gamepad and keyboard can navigate.
	if GameState.has_save():
		(vbox.get_child(3) as Button).grab_focus()
	else:
		new_btn.grab_focus()

	var help := Label.new()
	help.text = "WASD / arrows to move, Shift to run, M to mute"
	help.add_theme_font_size_override("font_size", 7)
	help.add_theme_color_override("font_color", DIM_TEXT)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(help)


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 24)
	b.add_theme_font_size_override("font_size", 8)
	return b
