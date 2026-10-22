class_name GameWorld
extends Node3D
## Runs one playthrough: owns the galaxy, player, camera, HUD and menus, and
## handles docking, events, death and victory.

signal run_ended

const HULL_STYLES := {"kestrel": "fighter", "warden": "heavy", "marauder": "raider"}

var player: PlayerShip
var camera: ChaseCamera
var galaxy: Galaxy
var ui_layer: CanvasLayer
var hud: HUD
var modal: Control
var fade: ColorRect
var ended := false
var show_briefing := true        # tests turn this off
var engine_hum: AudioStreamPlayer


func _ready() -> void:
	player = PlayerShip.new()
	player.name = "Player"
	player.add_to_group("player")
	var hid: String = Run.hull_def["id"]
	var lengths := {"kestrel": 14.0, "warden": 24.0, "marauder": 15.0}
	player.setup_ship(Run.stats, HULL_STYLES.get(hid, "fighter"), Run.hull_def["color"], Color(0.4, 0.75, 1.0),
		6.0 if hid == "warden" else 4.5, "player_" + hid, lengths.get(hid, 14.0))
	player.hull = Run.hull

	galaxy = Galaxy.new()
	add_child(galaxy)
	galaxy.build(Run.map, player, int(Run.map.nodes[0]["seed"]))
	player.world = galaxy
	galaxy.victory.connect(_on_victory)
	galaxy.region_entered.connect(_on_region_entered)

	camera = ChaseCamera.new()
	camera.target = player
	add_child(camera)
	camera.current = true
	player.camera = camera

	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	hud = HUD.new()
	hud.player = player
	hud.camera = camera
	hud.galaxy = galaxy
	ui_layer.add_child(hud)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(fade)

	player.died.connect(_on_player_died)
	player.interact_pressed.connect(_on_interact)
	player.tractor_pressed.connect(_on_tractor)
	Run.loadout_changed.connect(_on_loadout_changed)

	engine_hum = Sfx.make_loop("spaceEngineLow_000", -22.0)
	if engine_hum:
		add_child(engine_hum)
		engine_hum.play()
	galaxy.lane_started.connect(func(_l): Sfx.play(self, "lane", -6.0))

	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.8)
	if show_briefing:
		_open_mission_ui.call_deferred(MissionUI.Mode.BRIEFING)
	Run.message.emit("Objective: " + Run.missions.main_text(), Color(1, 0.85, 0.3))
	Run.message.emit("Pirates ahead. Steer with the mouse, shoot with left click.", Color(0.7, 0.85, 1))
	Run.message.emit("Fly through a trade lane ring to travel fast. M opens the nav map.", Color(0.7, 0.85, 1))


func _exit_tree() -> void:
	if engine_hum:
		engine_hum.stop()
	if Run.loadout_changed.is_connected(_on_loadout_changed):
		Run.loadout_changed.disconnect(_on_loadout_changed)
	get_tree().paused = false


func _on_region_entered(id: int) -> void:
	var node: Dictionary = Run.map.node_at(id)
	Run.message.emit("Entering %s — %s" % [node["name"], RunMap.TYPE_NAMES[node["type"]]], RunMap.TYPE_COLORS[node["type"]])
	match String(node["type"]):
		"station":
			Run.message.emit("A trade station. Fly close and press F to dock.", Color(0.5, 1, 0.6))
		"event":
			Run.message.emit("Unknown signal detected. Investigate with F.", Color(0.8, 0.6, 1))
		"boss":
			Run.message.emit("The Warlord's dreadnought guards the escape gate!", Color(1, 0.3, 0.3))


func _process(_dt: float) -> void:
	if player and player.alive and not get_tree().paused:
		Run.hull = player.hull
	if engine_hum:
		# Engine pitch and volume follow speed; silent when dead.
		var spd := player.flight.speed() if player.alive else 0.0
		var k := clampf(spd / 300.0, 0.0, 1.0)
		engine_hum.pitch_scale = 0.75 + k * 0.7 + (0.3 if not galaxy.trip.is_empty() else 0.0)
		engine_hum.volume_db = -60.0 if not player.alive else lerpf(-24.0, -12.0, k)
	if galaxy:
		match galaxy.interaction_available():
			"station":
				hud.prompt = "[F] Dock at " + galaxy.current_region().station.station_name
			"event":
				hud.prompt = "[F] Investigate: " + String(galaxy.current_region().state["event"]["title"])
			"lane":
				hud.prompt = "[F] Enter trade lane to " + String(galaxy.nearest_ring()["dest"])
			_:
				hud.prompt = ""


func _unhandled_input(event: InputEvent) -> void:
	if modal or ended:
		return
	if event.is_action_pressed("inventory"):
		_open_inventory(null)
	elif event.is_action_pressed("map"):
		_open_map()
	elif event.is_action_pressed("journal"):
		_open_mission_ui(MissionUI.Mode.JOURNAL)
	elif event.is_action_pressed("pause"):
		_open_pause()


# --- Modals -----------------------------------------------------------------

func _open_modal(c: Control) -> void:
	if modal:
		_close_modal()
	modal = c
	ui_layer.add_child(c)
	get_tree().paused = true
	player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_modal() -> void:
	if modal:
		modal.queue_free()
		modal = null
	get_tree().paused = false
	if not ended:
		player.controls_enabled = galaxy.trip.is_empty()
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
		player.hull = Run.hull


func _open_map() -> void:
	var m := MapUI.new()
	m.galaxy = galaxy
	m.closed.connect(_close_modal)
	_open_modal(m)


func _leave_run() -> void:
	get_tree().paused = false
	run_ended.emit()


func _open_inventory(station: Station) -> void:
	var inv := InventoryUI.new()
	inv.station = station
	inv.closed.connect(_close_modal)
	inv.jettison.connect(_on_jettison)
	if station:
		inv.board_requested.connect(_open_mission_ui.bind(MissionUI.Mode.BOARD, station))
	_open_modal(inv)


func _open_mission_ui(mode: int, station: Station = null) -> void:
	var m := MissionUI.new()
	m.mode = mode
	m.galaxy = galaxy
	var r := galaxy.current_region()
	if r:
		m.station_node = int(r.node["id"])
	m.closed.connect(_close_modal)
	if station:
		m.back_to_shop.connect(_open_inventory.bind(station))
	_open_modal(m)


func _open_pause() -> void:
	var m := UITheme.modal("Paused", 420, 240)
	var root: Control = m[0]
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var vb: VBoxContainer = m[1]
	vb.add_child(UITheme.button("Resume", _close_modal))
	vb.add_child(UITheme.button("Nav Map", _open_map))
	vb.add_child(UITheme.button("Abandon Run", func(): _end_run(false)))
	_open_modal(root)


func _on_interact() -> void:
	if modal or galaxy == null:
		return
	match galaxy.interaction_available():
		"station":
			var st := galaxy.current_region().station
			player.flight.velocity = Vector3.ZERO
			player.flight.throttle = 0.0
			Run.message.emit("Docked at " + st.station_name, Color(0.5, 1, 0.6))
			Sfx.play(self, "dock", -4.0)
			Run.missions.on_event("dock", {"node": int(galaxy.current_region().node["id"])})
			_open_inventory(st)
		"event":
			var region := galaxy.current_region()
			var ev := EventUI.new()
			ev.event_def = region.state["event"]
			ev.level = region.level()
			ev.chosen.connect(func(i): _resolve_event(ev, region, i))
			ev.closed.connect(_close_modal)
			_open_modal(ev)
		"lane":
			galaxy.use_nearest_lane()


func _resolve_event(ev: EventUI, region: Region, choice: int) -> void:
	var text := SectorEvents.resolve(region.state["event"], choice, self)
	if not text.begins_with("You can't afford"):
		region.finish_event()
		Run.missions.on_event("signal", {"node": int(region.node["id"])})
	ev.show_result(text)


func _on_tractor() -> void:
	if galaxy and galaxy.tractor_all() == 0:
		Run.message.emit("Nothing in tractor range.", Color(0.6, 0.6, 0.65))


func _on_jettison(item: Item) -> void:
	galaxy.spawn_item(player.position - player.forward() * 40.0, item)


func _on_loadout_changed() -> void:
	if player and player.alive:
		player.apply_stats(Run.stats)
		player.hull = Run.hull


# --- End of run ---------------------------------------------------------------

func _on_victory() -> void:
	Run.missions.on_event("escape")
	_end_run(true)


func _on_player_died(_s: Ship) -> void:
	Run.hull = 0.0
	var t := get_tree().create_timer(2.0)
	t.timeout.connect(func(): _end_run(false))


func _end_run(did_win: bool) -> void:
	if ended:
		return
	ended = true
	var earned := Run.finish(did_win)
	var es := EndScreen.new()
	es.won = did_win
	es.earned = earned
	es.done.connect(_leave_run)
	_open_modal(es)


# --- Event context (used by SectorEvents.resolve) --------------------------

func rng() -> RandomNumberGenerator:
	return galaxy.rng


func level() -> int:
	return galaxy.level_here()


func spawn_pirates(count: int, rank_name: String) -> void:
	galaxy.spawn_pirates_near_player(count, rank_name)


func drop_loot(source: int, count: int) -> void:
	galaxy.drop_loot_near_player(source, count)


func add_credits(amount: int) -> void:
	Run.add_credits(amount)
	Run.message.emit("+%d credits" % amount, Color(1.0, 0.85, 0.3))


func spend_credits(amount: int) -> bool:
	if Run.credits < amount:
		return false
	Run.add_credits(-amount)
	return true


func damage_player(fraction: float) -> void:
	var amount := Run.stats.max_hull * fraction
	Run.hull = maxf(1.0, Run.hull - amount)
	player.hull = Run.hull


func add_buff(stat: String, value: float) -> void:
	Run.add_buff(stat, value)
