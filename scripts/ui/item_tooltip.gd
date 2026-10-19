class_name ItemTooltip
extends PanelContainer
## Diablo-style item tooltip that follows the mouse. Shows the hovered item
## and, below it, what's currently equipped in that slot for comparison.

var _vb: VBoxContainer


func _ready() -> void:
	theme = UITheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_vb = VBoxContainer.new()
	_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vb)
	visible = false


func show_item(item: Item, compare: Item = null, extra: String = "") -> void:
	for c in _vb.get_children():
		c.queue_free()
	_add_lines(item)
	if item.is_weapon():
		var w := ShipStats._weapon(item, 0.0)
		_vb.add_child(UITheme.label("≈ %d damage per second" % int(ShipStats.weapon_dps(w)), 15, Color(0.7, 0.9, 0.7), HORIZONTAL_ALIGNMENT_CENTER))
	if extra != "":
		_vb.add_child(UITheme.label(extra, 15, Color(0.9, 0.85, 0.5), HORIZONTAL_ALIGNMENT_CENTER))
	if compare != null and compare != item:
		_vb.add_child(HSeparator.new())
		_vb.add_child(UITheme.label("Currently equipped:", 14, Color(0.6, 0.6, 0.65), HORIZONTAL_ALIGNMENT_CENTER))
		_add_lines(compare, 14)
	visible = true
	reset_size()
	_follow()


func _add_lines(item: Item, size: int = 16) -> void:
	var first := true
	for line in item.tooltip_lines():
		var l := UITheme.label(line[0], size + (3 if first else 0), line[1], HORIZONTAL_ALIGNMENT_CENTER)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vb.add_child(l)
		first = false


func hide_item() -> void:
	visible = false


func _process(_dt: float) -> void:
	if visible:
		_follow()


func _follow() -> void:
	var vp := get_viewport_rect().size
	var m := get_viewport().get_mouse_position()
	var pos := m + Vector2(22, 12)
	if pos.x + size.x > vp.x:
		pos.x = m.x - size.x - 22
	if pos.y + size.y > vp.y:
		pos.y = vp.y - size.y - 4
	global_position = pos.max(Vector2.ZERO)
