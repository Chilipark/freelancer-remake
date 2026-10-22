class_name HUD
extends Control
## In-flight HUD drawn by hand: reticle, target box, lead indicator,
## waypoint markers, status bars, speed and messages.

var player: PlayerShip
var camera: Camera3D
var galaxy: Galaxy
var prompt := ""
var _messages: Array = []   # [text, color, time_left]
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	Run.message.connect(add_message)


func add_message(text: String, color: Color) -> void:
	_messages.push_front([text, color, 5.0])
	if _messages.size() > 7:
		_messages.pop_back()


func _process(dt: float) -> void:
	for m in _messages:
		m[2] -= dt
	_messages = _messages.filter(func(m): return m[2] > 0.0)
	queue_redraw()


func _draw() -> void:
	if player == null or not is_instance_valid(player) or camera == null:
		return
	var vp := size
	_draw_markers(vp)
	_draw_target(vp)
	_draw_reticle()
	_draw_status(vp)
	_draw_speed(vp)
	_draw_sector_info()
	_draw_objectives(vp)
	_draw_messages(vp)
	if prompt != "":
		_text_centered(prompt, Vector2(vp.x * 0.5, vp.y - 150), 22, Color(0.6, 1.0, 0.7))
	if not player.mouse_flight:
		_text_centered("Mouse flight OFF — press Space", Vector2(vp.x * 0.5, vp.y - 120), 16, Color(1, 0.8, 0.4))
	_text(_font, Vector2(vp.x - 680, 24), "I Cargo · J Journal · M Map · G Autopilot · T Tractor · R Target · C Cruise · Tab Boost · F Dock/Lane", 14, Color(0.55, 0.65, 0.75))


func _text(font: Font, pos: Vector2, s: String, fsize: int, col: Color) -> void:
	draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 4, Color(0, 0, 0, 0.8))
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _text_centered(s: String, pos: Vector2, fsize: int, col: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	_text(_font, pos - Vector2(w * 0.5, 0), s, fsize, col)


func _bar(pos: Vector2, w: float, h: float, frac: float, col: Color) -> void:
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(pos, Vector2(w * clampf(frac, 0.0, 1.0), h)), col)
	draw_rect(Rect2(pos, Vector2(w, h)), Color(1, 1, 1, 0.25), false, 1.0)


func _on_screen(world_pos: Vector3) -> Array:
	# Returns [visible: bool, screen_pos: Vector2]
	if camera.is_position_behind(world_pos):
		return [false, Vector2.ZERO]
	var p := camera.unproject_position(world_pos)
	var r := Rect2(Vector2.ZERO, size)
	return [r.has_point(p), p]


func _edge_arrow(world_pos: Vector3, col: Color, label: String) -> void:
	var center := size * 0.5
	var local := camera.global_transform.basis.inverse() * (world_pos - camera.global_position)
	var dir := Vector2(local.x, -local.y).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var radius := minf(size.x, size.y) * 0.42
	var p := center + dir * radius
	var ang := dir.angle()
	var pts := PackedVector2Array([p + Vector2(12, 0).rotated(ang), p + Vector2(-6, 7).rotated(ang), p + Vector2(-6, -7).rotated(ang)])
	draw_colored_polygon(pts, col)
	if label != "":
		_text(_font, p + Vector2(10, 18), label, 12, col)


func _draw_markers(_vp: Vector2) -> void:
	var ppos := player.global_position
	# Gates
	for g in get_tree().get_nodes_in_group("gates"):
		var gate := g as JumpGate
		if gate.used:
			continue
		var d := ppos.distance_to(gate.global_position)
		var lbl := gate.label_text.split("\n")[0] + "  " + _km(d)
		var s := _on_screen(gate.global_position)
		if s[0]:
			draw_arc(s[1], 10, 0, TAU, 16, gate.color, 2.0)
			_text(_font, s[1] + Vector2(14, 5), lbl, 13, gate.color)
		else:
			_edge_arrow(gate.global_position, gate.color, lbl)
	if galaxy:
		_draw_galaxy_markers()
	# Enemies
	for n in get_tree().get_nodes_in_group("ships"):
		var e := n as Ship
		if e == null or e.faction != "enemy" or not e.alive or e == player.target:
			continue
		var col := Color(1, 0.35, 0.3) if e.rank == "normal" else Color(1, 0.75, 0.2)
		var s := _on_screen(e.global_position)
		if s[0]:
			var r := 9.0 if e.rank == "normal" else 14.0
			draw_rect(Rect2(s[1] - Vector2(r, r), Vector2(r, r) * 2), col, false, 1.5)
		else:
			_edge_arrow(e.global_position, col, "")
	# Loot within range
	for l in get_tree().get_nodes_in_group("loot"):
		var lp := l as LootPickup
		if lp.global_position.distance_to(ppos) > 900.0:
			continue
		var s := _on_screen(lp.global_position)
		if s[0]:
			var col := Color(1, 0.85, 0.3) if lp.item == null else lp.item.color()
			draw_colored_polygon(PackedVector2Array([s[1] + Vector2(0, -6), s[1] + Vector2(6, 0), s[1] + Vector2(0, 6), s[1] + Vector2(-6, 0)]), col)


func _km(d: float) -> String:
	return "%.1f km" % (d / 1000.0) if d >= 1000.0 else "%dm" % int(d)


func _draw_galaxy_markers() -> void:
	var r := galaxy.current_region()
	if r:
		if r.station:
			_marker(r.station.global_position, Color(0.5, 1, 0.6), r.station.station_name)
		if r.event_beacon:
			_marker(r.event_beacon.global_position, Color(0.8, 0.6, 1), String(r.state["event"]["title"]))
	# Other sectors in scanner range.
	var pabs := galaxy.player_abs()
	for n in Run.map.nodes:
		var d: float = pabs.distance_to(n["pos"])
		if int(n["id"]) == Run.node_id and d < Galaxy.REGION_RADIUS:
			continue
		var is_wp := int(n["id"]) == Run.waypoint
		if d > 45000.0 and not is_wp:
			continue
		var col: Color = RunMap.TYPE_COLORS[n["type"]]
		var nm: String = n["name"]
		if n["type"] == "event" and not (int(n["id"]) in Run.visited):
			nm += " (?)"
		var local := galaxy.to_local_pos(n["pos"])
		# Project far points onto a nearby sphere so the camera can place them.
		var shown := player.position + (local - player.position).normalized() * minf(d, 30000.0)
		var s := _on_screen(shown)
		var lbl := ("WAYPOINT  " if is_wp else "") + nm + "  " + _km(d)
		if s[0]:
			draw_arc(s[1], 7, 0, TAU, 12, col, 2.0)
			if is_wp:
				draw_arc(s[1], 12, 0, TAU, 16, Color.WHITE, 1.5)
			_text(_font, s[1] + Vector2(12, 5), lbl, 12, col)
		elif is_wp:
			_edge_arrow(shown, Color.WHITE, lbl)
	# Nearby trade lane entrances.
	if galaxy.trip.is_empty():
		var shown_lanes := 0
		for L in galaxy.lanes:
			var start: Vector3 = L["start"]
			var end: Vector3 = L["end"]
			for e in [[start, L["name_b"]], [end, L["name_a"]]]:
				var d2: float = pabs.distance_to(e[0])
				if d2 > 9000.0 or shown_lanes >= 5:
					continue
				shown_lanes += 1
				var s2 := _on_screen(galaxy.to_local_pos(e[0]))
				if s2[0]:
					var p: Vector2 = s2[1]
					draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color(0.95, 0.8, 0.4), false, 2.0)
					_text(_font, p + Vector2(10, 4), "Lane → %s  %s" % [e[1], _km(d2)], 12, Color(0.95, 0.8, 0.4))
	# Autopilot status and where it's heading.
	var ap := galaxy.autopilot
	if ap.active:
		_text_centered(ap.status_text(), Vector2(size.x * 0.5, 108), 16, Color(0.6, 0.9, 1))
		var l := ap.current_leg()
		if not l.is_empty() and galaxy.trip.is_empty():
			var lp := galaxy.to_local_pos(l["pos"])
			var shown := player.position + (lp - player.position).normalized() * minf(player.position.distance_to(lp), 30000.0)
			var s3 := _on_screen(shown)
			var apc := Color(0.6, 0.9, 1)
			if s3[0]:
				var c: Vector2 = s3[1]
				draw_polyline(PackedVector2Array([c + Vector2(0, -10), c + Vector2(10, 0), c + Vector2(0, 10), c + Vector2(-10, 0), c + Vector2(0, -10)]), apc, 2.0)
				_text(_font, c + Vector2(14, -8), "AUTOPILOT  " + _km(player.position.distance_to(lp)), 12, apc)
			else:
				_edge_arrow(shown, apc, "AUTOPILOT")
	# Jamming warning.
	if player.is_jammed():
		_text_centered("⚠ JAMMED — cruise and trade lanes offline", Vector2(size.x * 0.5, 130), 20, Color(1, 0.3, 0.35))


func _marker(pos: Vector3, col: Color, label: String) -> void:
	var d := player.global_position.distance_to(pos)
	var s := _on_screen(pos)
	var lbl := label + "  " + _km(d)
	if s[0]:
		draw_rect(Rect2(s[1] - Vector2(8, 8), Vector2(16, 16)), col, false, 2.0)
		_text(_font, s[1] + Vector2(14, 5), lbl, 13, col)
	else:
		_edge_arrow(pos, col, lbl)


func _draw_target(vp: Vector2) -> void:
	var t := player.target
	if t == null or not is_instance_valid(t) or not t.alive:
		return
	var col := Color(1, 0.4, 0.35)
	if t.rank == "elite":
		col = Color(1, 0.8, 0.25)
	elif t.rank == "boss":
		col = Color(1, 0.25, 0.2)
	var s := _on_screen(t.global_position)
	if s[0]:
		var r := clampf(t.radius * 900.0 / maxf(1.0, camera.global_position.distance_to(t.global_position)), 14.0, 80.0)
		var c: Vector2 = s[1]
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var p: Vector2 = c + corner * r
			draw_line(p, p - Vector2(corner.x * 8, 0), col, 2.0)
			draw_line(p, p - Vector2(0, corner.y * 8), col, 2.0)
	else:
		_edge_arrow(t.global_position, col, "TARGET")
	if player.has_lead:
		var l := _on_screen(player.lead_point)
		if l[0]:
			var p: Vector2 = l[1]
			draw_polyline(PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0), p + Vector2(0, -7)]), Color(0.6, 1, 0.6), 1.5)
	# Target box (top center)
	var box := Rect2(Vector2(vp.x * 0.5 - 170, 14), Vector2(340, 74))
	draw_rect(box, Color(0, 0.03, 0.06, 0.6))
	_text_centered(t.display_name, Vector2(vp.x * 0.5, 34), 17, col)
	var sub := "Level %d · %dm" % [t.level, int(player.global_position.distance_to(t.global_position))]
	if t is EnemyShip and not (t as EnemyShip).mods.is_empty():
		sub = (t as EnemyShip).mod_names() + " · " + sub
	_text_centered(sub, Vector2(vp.x * 0.5, 52), 13, Color(0.75, 0.75, 0.8))
	if t.stats.max_shield > 0.0:
		_bar(Vector2(vp.x * 0.5 - 150, 60), 300, 6, t.shield / t.stats.max_shield, Color(0.35, 0.65, 1.0))
	_bar(Vector2(vp.x * 0.5 - 150, 70), 300, 8, t.hull / t.stats.max_hull, Color(0.95, 0.3, 0.25))


func _draw_reticle() -> void:
	var m := get_viewport().get_mouse_position()
	var col := Color(0.6, 0.9, 1.0, 0.9)
	draw_arc(m, 14, 0, TAU, 24, col, 1.5)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(m + d * 8, m + d * 20, col, 1.5)
	# Where the nose points.
	var nose := _on_screen(player.global_position + player.forward() * 600.0)
	if nose[0]:
		draw_circle(nose[1], 3, Color(1, 1, 1, 0.6))


func _draw_status(vp: Vector2) -> void:
	var x := 24.0
	var y := vp.y - 100
	draw_rect(Rect2(Vector2(x - 10, y - 26), Vector2(330, 104)), Color(0, 0.03, 0.06, 0.55))
	var s := player.stats
	_text(_font, Vector2(x, y - 8), "SHIELD  %d / %d" % [int(player.shield), int(s.max_shield)], 13, Color(0.5, 0.75, 1.0))
	_bar(Vector2(x, y), 300, 10, player.shield / maxf(1.0, s.max_shield), Color(0.35, 0.65, 1.0))
	_text(_font, Vector2(x, y + 28), "HULL  %d / %d" % [int(player.hull), int(s.max_hull)], 13, Color(1, 0.55, 0.5))
	_bar(Vector2(x, y + 36), 300, 12, player.hull / s.max_hull, Color(0.95, 0.3, 0.25))
	_text(_font, Vector2(x, y + 64), "POWER", 13, Color(1, 0.9, 0.5))
	_bar(Vector2(x + 56, y + 55), 244, 8, player.power / s.max_power, Color(1, 0.85, 0.3))


func _draw_speed(vp: Vector2) -> void:
	var x := vp.x - 300
	var y := vp.y - 100
	draw_rect(Rect2(Vector2(x - 10, y - 26), Vector2(290, 104)), Color(0, 0.03, 0.06, 0.55))
	var f := player.flight
	_text(_font, Vector2(x, y), "%d m/s" % int(f.speed()), 26, Color.WHITE)
	_text(_font, Vector2(x + 140, y - 6), "THROTTLE", 12, Color(0.6, 0.7, 0.8))
	_bar(Vector2(x + 140, y), 120, 8, absf(f.throttle), Color(0.4, 0.9, 0.6) if f.throttle >= 0 else Color(1, 0.6, 0.3))
	var state := ""
	var col := Color(0.6, 0.9, 1.0)
	if galaxy and not galaxy.trip.is_empty():
		state = "TRADE LANE"
		col = Color(0.95, 0.8, 0.4)
	elif f.is_cruising():
		state = "CRUISE"
	elif f.cruise_active:
		state = "CRUISE CHARGING"
		_bar(Vector2(x, y + 34), 260, 8, f.cruise_progress(), Color(0.5, 0.85, 1.0))
	elif f.afterburner:
		state = "AFTERBURNER"
		col = Color(1, 0.7, 0.3)
	_text(_font, Vector2(x, y + 26), state, 15, col)
	_text(_font, Vector2(x, y + 64), "Credits %d   Cargo %d/%d" % [Run.credits, Run.cargo.size(), Run.CARGO_SIZE], 14, Color(1, 0.85, 0.4))


func _draw_sector_info() -> void:
	var node := Run.current_node()
	var col: Color = RunMap.TYPE_COLORS[node["type"]]
	var inside := galaxy == null or galaxy.player_abs().distance_to(node["pos"]) < Galaxy.REGION_RADIUS
	if inside:
		_text(_font, Vector2(24, 32), String(node["name"]), 22, Color.WHITE)
		_text(_font, Vector2(24, 54), "%s · Level %d · Depth %d / %d" % [RunMap.TYPE_NAMES[node["type"]], node["level"], int(node["depth"]) + 1, RunMap.DEPTH], 14, col)
	else:
		_text(_font, Vector2(24, 32), "Open space", 22, Color.WHITE)
		_text(_font, Vector2(24, 54), "Threat level %d · Last sector: %s" % [galaxy.level_here(), node["name"]], 14, Color(0.7, 0.75, 0.8))
	var hostiles := 0
	for n in get_tree().get_nodes_in_group("ships"):
		var sh := n as Ship
		if sh.faction == "enemy" and sh.position.distance_to(player.position) < 5000.0:
			hostiles += 1
	if hostiles > 0:
		_text(_font, Vector2(24, 74), "%d hostiles nearby" % hostiles, 14, Color(1, 0.5, 0.4))


## Objective tracker (top right): main story step plus active contracts.
func _draw_objectives(vp: Vector2) -> void:
	var m := Run.missions
	if m == null:
		return
	var x := vp.x - 430.0
	var y := 56.0
	var lines: Array = []   # [text, colour]
	var main := "▶ " + m.main_text()
	var t := m.main_target()
	if t >= 0 and galaxy:
		main += "  (%s)" % _km(galaxy.player_abs().distance_to(Run.map.node_at(t)["pos"]))
	lines.append([main, Color(1, 0.85, 0.3)])
	for c in m.contracts:
		var s := "• " + String(c["title"])
		if galaxy:
			s += "  (%s)" % _km(galaxy.player_abs().distance_to(Run.map.node_at(int(c["target"]))["pos"]))
		lines.append([s, Color(0.6, 0.9, 1)])
	draw_rect(Rect2(Vector2(x - 10, y - 18), Vector2(420, 10 + lines.size() * 20)), Color(0, 0.03, 0.06, 0.5))
	for l in lines:
		_text(_font, Vector2(x, y), l[0], 14, l[1])
		y += 20


func _draw_messages(vp: Vector2) -> void:
	var y := vp.y * 0.5 - 40
	for m in _messages:
		var c: Color = m[1]
		c.a = clampf(m[2], 0.0, 1.0)
		_text(_font, Vector2(24, y), m[0], 15, c)
		y += 22
