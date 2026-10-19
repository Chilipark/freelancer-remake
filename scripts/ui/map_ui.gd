class_name MapUI
extends Control
## The run's sector map: layers left to right, gates as lines.

signal closed

var _canvas: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var m := UITheme.modal("Sector Map", 1180, 600)
	add_child(m[0])
	var vb: VBoxContainer = m[1]
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(1140, 470)
	_canvas.draw.connect(_draw_map)
	vb.add_child(_canvas)
	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	for t in ["combat", "elite", "station", "event", "boss"]:
		legend.add_child(UITheme.label("●", 18, RunMap.TYPE_COLORS[t]))
		legend.add_child(UITheme.label(RunMap.TYPE_NAMES[t] + "   ", 14))
	legend.add_child(UITheme.button("Close", func(): closed.emit(), 120))
	vb.add_child(legend)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _pos(n: Dictionary) -> Vector2:
	var w := _canvas.size.x - 60
	var h := _canvas.size.y - 40
	var x := 30.0 + w * float(n["depth"]) / float(RunMap.DEPTH - 1)
	var y := 20.0 + h * (float(n["lane"]) + 0.5) / float(n["lanes"])
	return Vector2(x, y)


func _draw_map() -> void:
	var map := Run.map
	var cur := Run.current_node()
	for n in map.nodes:
		for nid in n["next"]:
			var m: Dictionary = map.node_at(nid)
			var walked: bool = n["id"] in Run.visited and nid in Run.visited
			var col := Color(0.9, 0.9, 0.5, 0.9) if walked else Color(0.4, 0.5, 0.6, 0.35)
			if n["id"] == cur["id"]:
				col = Color(0.6, 1.0, 0.7, 0.9)
			_canvas.draw_line(_pos(n), _pos(m), col, 3.0 if walked or n["id"] == cur["id"] else 1.5)
	var font := ThemeDB.fallback_font
	for n in map.nodes:
		var p := _pos(n)
		var col: Color = RunMap.TYPE_COLORS[n["type"]]
		var r := 9.0
		if n["type"] == "boss":
			r = 14.0
		if not (n["id"] in Run.visited) and int(n["depth"]) <= int(cur["depth"]):
			col = col.darkened(0.6)
		_canvas.draw_circle(p, r, col)
		if n["id"] == cur["id"]:
			_canvas.draw_arc(p, r + 6, 0, TAU, 24, Color.WHITE, 2.5)
			_canvas.draw_string(font, p + Vector2(-14, -18), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		elif n["id"] in cur["next"]:
			_canvas.draw_arc(p, r + 5, 0, TAU, 24, Color(0.6, 1.0, 0.7), 1.5)
	for d in RunMap.DEPTH:
		var x := 30.0 + (_canvas.size.x - 60) * float(d) / float(RunMap.DEPTH - 1)
		_canvas.draw_string(font, Vector2(x - 12, _canvas.size.y - 2), "Lv%d" % RunMap.level_for_depth(d), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.55, 0.6))
