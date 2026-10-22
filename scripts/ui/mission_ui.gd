class_name MissionUI
extends Control
## Three screens in one: the opening briefing, the journal (J) and a
## station's mission board.

signal closed
signal back_to_shop

enum Mode { BRIEFING, JOURNAL, BOARD }

var mode := Mode.JOURNAL
var station_node := -1
var galaxy: Galaxy
var _vb: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var title := "Journal"
	if mode == Mode.BRIEFING:
		title = Missions.STORY_TITLE
	elif mode == Mode.BOARD:
		title = "Mission Board — " + String(Run.map.node_at(station_node)["name"])
	var m := UITheme.modal(title, 860, 520)
	add_child(m[0])
	_vb = m[1]
	if not Run.missions.changed.is_connected(_rebuild):
		Run.missions.changed.connect(_rebuild)
	_rebuild()


func _exit_tree() -> void:
	if Run.missions.changed.is_connected(_rebuild):
		Run.missions.changed.disconnect(_rebuild)


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.BRIEFING:
		return
	if event.is_action_pressed("journal") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _wrap(text: String, size: int = 16, color: Color = UITheme.TEXT) -> Label:
	var l := UITheme.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 820
	return l


func _rebuild() -> void:
	if _vb == null:
		return
	var keep := 2 if _vb.get_child_count() >= 2 else 0   # title + separator
	for i in range(_vb.get_child_count() - 1, keep - 1, -1):
		_vb.get_child(i).queue_free()
	match mode:
		Mode.BRIEFING:
			_vb.add_child(_wrap(Missions.STORY, 17))
			_vb.add_child(HSeparator.new())
			_vb.add_child(_wrap("First objective: " + Run.missions.main_text(), 17, Color(1, 0.85, 0.3)))
			_vb.add_child(_wrap("Tip: your current objective is set as your waypoint. Press G for autopilot, J for the journal, M for the nav map.", 14, Color(0.6, 0.7, 0.8)))
			_vb.add_child(UITheme.button("Launch", func(): closed.emit()))
		Mode.JOURNAL:
			_vb.add_child(UITheme.label("Main objective", 18, UITheme.ACCENT))
			_vb.add_child(_wrap("▶ " + Run.missions.main_text(), 17, Color(1, 0.85, 0.3)))
			_add_track_button(Run.missions.main_target())
			_vb.add_child(HSeparator.new())
			_vb.add_child(UITheme.label("Contracts (%d / %d)" % [Run.missions.contracts.size(), Missions.MAX_CONTRACTS], 18, UITheme.ACCENT))
			if Run.missions.contracts.is_empty():
				_vb.add_child(_wrap("No contracts. Dock at a trade station and check its Mission Board.", 15, Color(0.6, 0.65, 0.7)))
			for c in Run.missions.contracts.duplicate():
				_contract_row(c, false)
			_vb.add_child(HSeparator.new())
			var story := _wrap(Missions.STORY, 13, Color(0.6, 0.65, 0.72))
			_vb.add_child(story)
			_vb.add_child(UITheme.button("Close", func(): closed.emit()))
		Mode.BOARD:
			var offers: Array = Run.missions.board(station_node)
			if offers.is_empty():
				_vb.add_child(_wrap("No work available here right now.", 16, Color(0.6, 0.65, 0.7)))
			for c in offers.duplicate():
				_contract_row(c, true)
			_vb.add_child(HSeparator.new())
			_vb.add_child(UITheme.label("Active contracts: %d / %d" % [Run.missions.contracts.size(), Missions.MAX_CONTRACTS], 15))
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_child(UITheme.button("Back to Shop", func(): back_to_shop.emit(), 160))
			row.add_child(UITheme.button("Undock", func(): closed.emit(), 120))
			_vb.add_child(row)


func _add_track_button(target: int) -> void:
	if target < 0:
		return
	var row := HBoxContainer.new()
	var n: Dictionary = Run.map.node_at(target)
	var dist := ""
	if galaxy:
		dist = "  ·  %.1f km" % (galaxy.player_abs().distance_to(n["pos"]) / 1000.0)
	row.add_child(UITheme.label("Location: %s%s" % [n["name"], dist], 14, Color(0.7, 0.75, 0.8)))
	var b := UITheme.button("Tracked" if Run.waypoint == target else "Track (set waypoint)", _track.bind(target), 190)
	b.disabled = Run.waypoint == target
	row.add_child(b)
	_vb.add_child(row)


func _contract_row(c: Dictionary, offer: bool) -> void:
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var head := HBoxContainer.new()
	var title := UITheme.label(String(c["title"]), 17, Color(0.6, 0.9, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UITheme.label("%d credits + gear  ·  Level %d" % [c["credits"], c["level"]], 14, Color(1, 0.85, 0.4)))
	vb.add_child(head)
	var d := _wrap(String(c["desc"]), 14)
	d.custom_minimum_size.x = 780
	vb.add_child(d)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	if offer:
		var acc := UITheme.button("Accept", func(): _accept(c), 120)
		acc.disabled = not Run.missions.can_accept()
		row.add_child(acc)
	else:
		var target: int = c["target"]
		var tr := UITheme.button("Tracked" if Run.waypoint == target else "Track", _track.bind(target), 110)
		tr.disabled = Run.waypoint == target
		row.add_child(tr)
		row.add_child(UITheme.button("Abandon", func(): Run.missions.abandon(c), 110))
	vb.add_child(row)
	_vb.add_child(panel)


func _accept(c: Dictionary) -> void:
	if Run.missions.accept(c):
		if Run.waypoint < 0:
			Run.waypoint = int(c["target"])
		if galaxy:
			galaxy.refresh_bounties()


func _track(target: int) -> void:
	Run.waypoint = target
	_rebuild()
