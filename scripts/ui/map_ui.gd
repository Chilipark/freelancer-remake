class_name MapUI
extends Control
## Freelancer-style nav map: the whole system seen from above, with trade
## lanes, your position and known jammed lanes. Click a sector to set a
## waypoint (it gets a marker on the HUD).

signal closed

var galaxy: Galaxy
var _canvas: Control
var _info: Label
var _hover := -1
var _min := Vector2.ZERO
var _max := Vector2.ONE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var m := UITheme.modal("Nav Map", 1240, 680)
	add_child(m[0])
	var vb: VBoxContainer = m[1]
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(1200, 520)
	_canvas.draw.connect(_draw_map)
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	vb.add_child(_canvas)
	_info = UITheme.label("Click a sector to set a waypoint.", 15, Color(0.75, 0.8, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(_info)
	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	for t in ["combat", "elite", "station", "event", "boss"]:
		legend.add_child(UITheme.label("●", 18, RunMap.TYPE_COLORS[t]))
		legend.add_child(UITheme.label(RunMap.TYPE_NAMES[t] + "  ", 14))
	legend.add_child(UITheme.label("━", 18, Color(0.95, 0.8, 0.4)))
	legend.add_child(UITheme.label("Trade lane  ", 14))
	legend.add_child(UITheme.label("━", 18, Color(1, 0.25, 0.3)))
	legend.add_child(UITheme.label("Jammed  ", 14))
	legend.add_child(UITheme.button("Autopilot to waypoint (G)", _autopilot, 220))
	legend.add_child(UITheme.button("Close", func(): closed.emit(), 110))
	vb.add_child(legend)
	_compute_bounds()


func _autopilot() -> void:
	if galaxy and galaxy.autopilot.engage(Run.waypoint):
		closed.emit()
	else:
		_info.text = "Pick a reachable sector first (click it)." if Run.waypoint < 0 else "Autopilot can't engage right now."


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("autopilot"):
		get_viewport().set_input_as_handled()
		_autopilot()
		return
	if event.is_action_pressed("map") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _compute_bounds() -> void:
	_min = Vector2(INF, INF)
	_max = Vector2(-INF, -INF)
	for n in Run.map.nodes:
		var p := Vector2(n["pos"].x, n["pos"].z)
		_min = _min.min(p)
		_max = _max.max(p)
	_min -= Vector2(8000, 8000)
	_max += Vector2(8000, 8000)


## Absolute world position -> canvas pixel.
func _to_canvas(p: Vector3) -> Vector2:
	var sz := _canvas.size
	var span := _max - _min
	var scale := minf(sz.x / span.x, sz.y / span.y)
	var off := (sz - span * scale) * 0.5
	return off + (Vector2(p.x, p.z) - _min) * scale


func _lane_jammed(L: Dictionary) -> bool:
	if galaxy == null or float(L["jam_t"]) < 0.0:
		return false
	var site: Dictionary = galaxy.sites[int(L["jam_site"])]
	# Only show jams you've run into or are close to (Freelancer hides them too).
	var known: bool = site.get("known", false) or site["loaded"] != null
	if known:
		site["known"] = true
	return known and not (0 in site["state"]["dead"])


func _draw_map() -> void:
	var font := ThemeDB.fallback_font
	if galaxy:
		for L in galaxy.lanes:
			var col := Color(1, 0.25, 0.3) if _lane_jammed(L) else Color(0.95, 0.8, 0.4, 0.75)
			_canvas.draw_line(_to_canvas(L["start"]), _to_canvas(L["end"]), col, 2.5)
		# Planned / active autopilot route.
		var legs: Array = galaxy.autopilot.legs if galaxy.autopilot.active else ([] if Run.waypoint < 0 else galaxy.autopilot.plan(Run.waypoint))
		var from := _to_canvas(galaxy.player_abs())
		for l in legs:
			var to := _to_canvas(l["pos"])
			_canvas.draw_dashed_line(from, to, Color(0.6, 0.9, 1), 2.0, 6.0)
			if int(l["lane"]) >= 0:
				var L2: Dictionary = galaxy.lanes[int(l["lane"])]
				var exit_pos: Vector3 = L2["end"] if int(l["sign"]) > 0 else L2["start"]
				_canvas.draw_line(_to_canvas(L2["start"]), _to_canvas(L2["end"]), Color(0.6, 0.9, 1), 4.0)
				from = _to_canvas(exit_pos)
			else:
				from = to
	for n in Run.map.nodes:
		var p := _to_canvas(n["pos"])
		var col: Color = RunMap.TYPE_COLORS[n["type"]]
		var r := 7.0 if n["type"] != "boss" else 11.0
		var visited: bool = int(n["id"]) in Run.visited
		_canvas.draw_circle(p, r, col if visited or n["type"] == "boss" else col.darkened(0.25))
		if not visited:
			_canvas.draw_arc(p, r + 2, 0, TAU, 16, Color(0, 0, 0, 0.6), 2.0)
		if int(n["id"]) == Run.waypoint:
			_canvas.draw_arc(p, r + 7, 0, TAU, 24, Color.WHITE, 2.0)
		if int(n["id"]) == _hover:
			_canvas.draw_arc(p, r + 4, 0, TAU, 24, Color(0.6, 1, 0.7), 2.0)
		_canvas.draw_string(font, p + Vector2(-30, -12), String(n["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.85, 0.9, 0.8))
	if galaxy:
		var pp := _to_canvas(galaxy.player_abs())
		var fwd := galaxy.player.forward()
		var dir := Vector2(fwd.x, fwd.z).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		var tri := PackedVector2Array([pp + dir * 11, pp + dir.rotated(2.5) * 8, pp + dir.rotated(-2.5) * 8])
		_canvas.draw_colored_polygon(tri, Color.WHITE)
		_canvas.draw_string(font, pp + Vector2(10, 16), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	# Scale bar.
	var a := _to_canvas(Vector3(_min.x + 2000, 0, _max.y - 3000))
	var b := _to_canvas(Vector3(_min.x + 12000, 0, _max.y - 3000))
	_canvas.draw_line(a, b, Color(0.7, 0.75, 0.8), 2.0)
	_canvas.draw_string(font, a + Vector2(0, -6), "10 km", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.75, 0.8))


func _node_at(pos: Vector2) -> int:
	for n in Run.map.nodes:
		if _to_canvas(n["pos"]).distance_to(pos) < 14.0:
			return int(n["id"])
	return -1


func _on_canvas_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h := _node_at(ev.position)
		if h != _hover:
			_hover = h
			if h >= 0:
				var n: Dictionary = Run.map.node_at(h)
				var t: String = RunMap.TYPE_NAMES[n["type"]]
				if n["type"] == "event" and not (h in Run.visited):
					t = "Unknown"
				var d := galaxy.player_abs().distance_to(n["pos"]) / 1000.0 if galaxy else 0.0
				_info.text = "%s — %s · Level %d · %.1f km away" % [n["name"], t, n["level"], d]
			else:
				_info.text = "Click a sector to set a waypoint."
			_canvas.queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var id := _node_at(ev.position)
		if id >= 0:
			Run.waypoint = -1 if Run.waypoint == id else id
			_canvas.queue_redraw()
