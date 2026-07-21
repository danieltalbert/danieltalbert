class_name FloatText
extends Node2D
## FloatText: small text that rises and fades, then frees itself.
## Used for +XP feedback in the world.


static func spawn(parent: Node, pos: Vector2, text: String,
		color: Color = Color("#7ee0ff")) -> void:
	var node := FloatText.new()
	node.position = pos
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#101020"))
	label.add_theme_constant_override("outline_size", 2)
	node.add_child(label)
	label.position = Vector2(-label.size.x / 2.0, -14)
	parent.add_child(node)

	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "position:y", pos.y - 14.0, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 0.0, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(node.queue_free)
