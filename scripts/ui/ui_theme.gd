class_name UITheme
extends RefCounted
## A dark sci-fi theme built in code, plus small UI helpers.

const PANEL_BG := Color(0.04, 0.06, 0.1, 0.92)
const BORDER := Color(0.3, 0.55, 0.75, 0.9)
const ACCENT := Color(0.45, 0.8, 1.0)
const TEXT := Color(0.85, 0.9, 0.95)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 17
	t.set_stylebox("panel", "Panel", _box(PANEL_BG, BORDER, 2))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL_BG, BORDER, 2))
	t.set_stylebox("normal", "Button", _box(Color(0.08, 0.12, 0.18, 0.95), Color(0.25, 0.4, 0.55), 1))
	t.set_stylebox("hover", "Button", _box(Color(0.12, 0.2, 0.3, 0.95), ACCENT, 1))
	t.set_stylebox("pressed", "Button", _box(Color(0.15, 0.28, 0.4, 0.95), ACCENT, 2))
	t.set_stylebox("disabled", "Button", _box(Color(0.06, 0.07, 0.09, 0.9), Color(0.2, 0.22, 0.25), 1))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.5))
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 8)
	_theme = t
	return t


static func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(4)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func label(text: String, size: int = 17, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func button(text: String, callback: Callable, min_width: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.x = min_width
	b.pressed.connect(callback)
	return b


## A full-screen dimmer with a centered panel; returns [root, content VBox].
static func modal(title: String, width: int = 900, height: int = 600) -> Array:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, height)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	if title != "":
		vb.add_child(label(title, 26, ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
		vb.add_child(HSeparator.new())
	return [root, vb]
