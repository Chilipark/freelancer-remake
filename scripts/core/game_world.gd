class_name GameWorld
extends Node3D
## Runs one playthrough: owns the player, camera, current sector, HUD and
## menus, and handles jumping between sectors, events, death and victory.

signal run_ended

const HULL_STYLES := {"kestrel": "fighter", "warden": "heavy", "marauder": "raider"}

var player: PlayerShip
var camera: ChaseCamera
var sector: Sector
var ui_layer: CanvasLayer
var hud: HUD
var modal: Control
var fade: ColorRect
var jumping := false
var ended := false


func _ready() -> void:
	player = PlayerShip.new()
	player.name = "Player"
	player.add_to_group("player")
	var hid: String = Run.hull_def["id"]
	player.setup_ship(Run.stats, HULL_STYLES.get(hid, "fighter"), Run.hull_def["color"], Color(0.4, 0.75, 1.0), 4.5)
	player.hull = Run.hull
	add_child(player)
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

	_enter_sector()
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.8)


func _exit_tree() -> void:
	if Run.loadout_changed.is_connected(_on_loadout_changed):
		Run.loadout_changed.disconnect(_on_loadout_changed)
	get_tree().paused = false


func _enter_sector() -> void:
	if sector:
		remove_child(sector)
		sector.queue_free()
	sector = Sector.new()
	add_child(sector)
	sector.build(Run.current_node(), player)
	sector.boss_defeated.connect(func(): Run.message.emit("The Warlord is destroyed! Head for the escape gate.", Color(1, 0.85, 0.3)))
	sector.gate_entered.connect(_on_gate_entered)
	player.world = sector
	player.global_transform = Transform3D(Basis.IDENTITY, Sector.ARRIVAL)
	player.flight.velocity = Vector3(0, 0, -50)
	player.flight.ang_vel = Vector3.ZERO
	player.flight.throttle = 0.5
	player.flight.set_cruise(false)
	player.target = null
	camera.snap()
	hud.sector = sector
	var node := Run.current_node()
	Run.message.emit("Entered %s — %s" % [node["name"], RunMap.TYPE_NAMES[node["type"]]], RunMap.TYPE_COLORS[node["type"]])
	match String(node["type"]):
		"start":
			Run.message.emit("Pirates ahead. Steer with the mouse, shoot with left click.", Color(0.7, 0.85, 1))
			Run.message.emit("Fly through a jump gate to move on. M shows the map.", Color(0.7, 0.85, 1))
		"station":
			Run.message.emit("A trade station. Fly close and press F to dock.", Color(0.5, 1, 0.6))
		"event":
			Run.message.emit("Unknown signal detected. Investigate with F.", Color(0.8, 0.6, 1))
		"boss":
			Run.message.emit("The Warlord's dreadnought blocks the way out!", Color(1, 0.3, 0.3))


func _process(_dt: float) -> void:
	if player and player.alive and not get_tree().paused:
		Run.hull = player.hull
	if sector:
		match sector.interaction_available():
			"station":
				hud.prompt = "[F] Dock at " + sector.station.station_name
			"event":
				hud.prompt = "[F] Investigate: " + String(sector.event_def["title"])
			_:
				hud.prompt = ""


func _unhandled_input(event: InputEvent) -> void:
	if modal or ended or jumping:
		return
	if event.is_action_pressed("inventory"):
		_open_inventory(null)
	elif event.is_action_pressed("map"):
		_open_map()
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
		player.controls_enabled = true
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
		player.hull = Run.hull


func _open_map() -> void:
	var m := MapUI.new()
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
	_open_modal(inv)


func _open_pause() -> void:
	var m := UITheme.modal("Paused", 420, 240)
	var root: Control = m[0]
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var vb: VBoxContainer = m[1]
	vb.add_child(UITheme.button("Resume", _close_modal))
	vb.add_child(UITheme.button("Sector Map", _open_map))
	vb.add_child(UITheme.button("Abandon Run", func(): _end_run(false)))
	_open_modal(root)


func _on_interact() -> void:
	if modal or sector == null:
		return
	match sector.interaction_available():
		"station":
			player.flight.velocity = Vector3.ZERO
			player.flight.throttle = 0.0
			Run.message.emit("Docked at " + sector.station.station_name, Color(0.5, 1, 0.6))
			_open_inventory(sector.station)
		"event":
			var ev := EventUI.new()
			ev.event_def = sector.event_def
			ev.level = sector.level()
			ev.chosen.connect(func(i): _resolve_event(ev, i))
			ev.closed.connect(_close_modal)
			_open_modal(ev)


func _resolve_event(ev: EventUI, choice: int) -> void:
	var text := SectorEvents.resolve(sector.event_def, choice, self)
	if not text.begins_with("You can't afford"):
		sector.event_done = true
	ev.show_result(text)


func _on_tractor() -> void:
	var n := sector.tractor_all() if sector else 0
	if n == 0:
		Run.message.emit("Nothing in tractor range.", Color(0.6, 0.6, 0.65))


func _on_jettison(item: Item) -> void:
	sector.spawn_item(player.global_position - player.forward() * 40.0, item)


func _on_loadout_changed() -> void:
	if player and player.alive:
		player.apply_stats(Run.stats)
		player.hull = Run.hull


# --- Travel / end of run ---------------------------------------------------

func _on_gate_entered(target_id: int) -> void:
	if jumping or ended:
		return
	if target_id == -2:
		_end_run(true)
		return
	jumping = true
	Run.hull = player.hull
	player.controls_enabled = false
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	tw.tween_callback(func():
		Run.travel_to(target_id)
		_enter_sector()
		player.controls_enabled = true
		jumping = false)
	tw.tween_property(fade, "color:a", 0.0, 0.7)


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
	return sector.rng


func level() -> int:
	return sector.level()


func spawn_pirates(count: int, rank_name: String) -> void:
	sector.spawn_pirates_near_player(count, rank_name)


func drop_loot(source: int, count: int) -> void:
	sector.drop_loot_near_player(source, count)


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
