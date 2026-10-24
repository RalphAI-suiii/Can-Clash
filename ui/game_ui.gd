extends RefCounted

const FONT = preload("res://assets/fonts/TitanOne-Regular.ttf")

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = FONT
	result.default_font_size = 26
	for kind in ["Label", "Button", "LineEdit"]:
		result.set_color("font_color", kind, Color("fff5dc"))
		result.set_color("font_outline_color", kind, Color("20130f"))
		result.set_constant("outline_size", kind, 5)
	result.set_color("font_disabled_color", "Button", Color("c9b890"))
	result.set_color("font_hover_color", "Button", Color("ffffff"))
	result.set_stylebox("normal", "Button", panel(Color("08702c"), 4))
	result.set_stylebox("hover", "Button", panel(Color("168f43"), 4))
	result.set_stylebox("pressed", "Button", panel(Color("ee9c14"), 4))
	result.set_stylebox("disabled", "Button", panel(Color("624228"), 4))
	var focus := panel(Color(0, 0, 0, 0), 3)
	focus.border_color = Color("fff0a8")
	result.set_stylebox("focus", "Button", focus)
	result.set_stylebox("normal", "LineEdit", panel(Color("fff5dc"), 3))
	result.set_color("font_color", "LineEdit", Color("4f321c"))
	result.set_constant("outline_size", "LineEdit", 0)
	return result

static func panel(color: Color = Color("ba500d"), border: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("20130f")
	style.set_border_width_all(border)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.12, 0.06, 0.02, 0.35)
	style.shadow_size = 12
	style.shadow_offset = Vector2(4, 8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style

static func label(text: String, size: int = 26) -> Label:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size", size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func button(text: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(200, 64)
	node.pressed.connect(callback)
	return node

static func modal(parent: Node, title: String, body: String) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.layer = 20
	parent.add_child(layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.08, 0.04, 0.01, 0.72)
	layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.theme = theme()
	layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(1000, 0)
	card.add_theme_stylebox_override("panel", panel())
	center.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	card.add_child(content)
	content.add_child(label(title, 42))
	var copy := label(body, 26)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.custom_minimum_size = Vector2(950, 0)
	content.add_child(copy)
	return {"layer": layer, "content": content}
