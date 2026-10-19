class_name Sector
extends Node3D
## One sector of the run: backdrop, asteroids, jump gates and whatever the
## map node says is here (pirates, an elite, a station, an event, the boss).
## Also handles loot drops and pickup.

signal gate_entered(target_id: int)
signal boss_defeated

const ARRIVAL := Vector3(0, 0, 1700)
const GATE_Z := -1900.0
const EVENT_RANGE := 320.0

var node: Dictionary = {}
var rng := RandomNumberGenerator.new()
var player: PlayerShip
var station: Station
var event_def: Dictionary = {}
var event_done := false
var event_beacon: Node3D
var boss: EnemyShip
var _env: WorldEnvironment


func build(map_node: Dictionary, p: PlayerShip) -> void:
	node = map_node
	player = p
	rng.seed = int(node["seed"])
	name = "Sector"
	_build_backdrop()
	_build_asteroids(rng.randi_range(18, 40))
	var arrival := JumpGate.new()
	arrival.label_text = "Arrival"
	arrival.used = true
	arrival.position = ARRIVAL + Vector3(0, 0, 160)
	add_child(arrival)

	var lvl := level()
	match String(node["type"]):
		"start":
			_spawn_group(Vector3(0, 0, -200), 2, "normal")
		"combat":
			_spawn_group(Vector3(rng.randf_range(-500, 500), rng.randf_range(-100, 100), rng.randf_range(-300, 300)), rng.randi_range(2, 3 + lvl / 8), "normal")
			_spawn_group(Vector3(rng.randf_range(-700, 700), rng.randf_range(-150, 150), -1200), rng.randi_range(2, 3), "normal")
		"elite":
			var pos := Vector3(rng.randf_range(-400, 400), 0, rng.randf_range(-600, 0))
			_spawn_group(pos, 1, "elite")
			_spawn_group(pos + Vector3(60, 0, 60), rng.randi_range(2, 3), "normal")
		"station":
			station = Station.new()
			station.station_name = String(node["name"]) + " Station"
			station.position = Vector3(rng.randf_range(-300, 300), 0, 0)
			add_child(station)
			station.generate_stock(lvl, rng)
			if rng.randf() < 0.35:
				_spawn_group(Vector3(0, 0, -1300), 2, "normal")
		"event":
			event_def = SectorEvents.pick(rng)
			_build_event_beacon()
		"boss":
			boss = _spawn_enemy(Vector3(0, 40, -700), "boss")
			boss.spawn_escorts.connect(_on_boss_escorts)
			_spawn_group(Vector3(0, 0, -500), 3, "normal")

	if node["type"] != "boss":
		_build_gates()


func level() -> int:
	return int(node["level"])


func _build_backdrop() -> void:
	var hue := rng.randf()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/space_sky.gdshader")
	sky_mat.set_shader_parameter("nebula_a", Color.from_hsv(hue, 0.75, 0.55))
	sky_mat.set_shader_parameter("nebula_b", Color.from_hsv(fmod(hue + rng.randf_range(0.1, 0.3), 1.0), 0.7, 0.45))
	sky_mat.set_shader_parameter("nebula_strength", rng.randf_range(0.45, 0.9))
	sky_mat.set_shader_parameter("seed", rng.randf_range(0.0, 50.0))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	_env = WorldEnvironment.new()
	_env.environment = env
	add_child(_env)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.3
	sun.light_color = Color.from_hsv(fmod(hue + 0.5, 1.0), 0.15, 1.0)
	sun.rotation = Vector3(rng.randf_range(-1.0, -0.3), rng.randf_range(0, TAU), 0)
	add_child(sun)

	# A distant planet.
	var planet_col := Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.7), rng.randf_range(0.4, 0.8))
	var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.4), rng.randf_range(-1, 1)).normalized()
	var r := rng.randf_range(1500, 3200)
	var planet := FX.mesh_node(FX.sphere(r, 48), FX.mat(planet_col, 0.0, 0.0, 0.9), dir * 14000.0)
	add_child(planet)
	if rng.randf() < 0.6:
		var ring := FX.mesh_node(FX.torus(r * 1.35, r * 1.9, 64), FX.glow_mat(planet_col.lightened(0.3), 0.4, 0.35),
			dir * 14000.0, Vector3(1, 0.02, 1), Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)))
		add_child(ring)


func _build_asteroids(count: int) -> void:
	var rock := FX.mat(Color(0.42, 0.38, 0.35), 0.0, 0.1, 0.95)
	var mesh := FX.sphere(1.0, 7)
	# Decorative small rocks in one MultiMesh.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 300
	for i in mm.instance_count:
		var p := Vector3(rng.randf_range(-2500, 2500), rng.randf_range(-600, 600), rng.randf_range(-2500, 2500))
		var s := rng.randf_range(2.0, 9.0)
		var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)).scaled(Vector3(s, s * rng.randf_range(0.6, 1.0), s * rng.randf_range(0.7, 1.2)))
		mm.set_instance_transform(i, Transform3D(b, p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = rock
	add_child(mmi)
	# Big rocks you can crash into.
	for i in count:
		var p := Vector3(rng.randf_range(-2200, 2200), rng.randf_range(-400, 400), rng.randf_range(-1500, 1500))
		if p.distance_to(ARRIVAL) < 300.0 or absf(p.z - GATE_Z) < 250.0 or p.length() < 200.0:
			continue
		var r := rng.randf_range(15.0, 60.0)
		var a := FX.mesh_node(mesh, rock, p, Vector3(r, r * rng.randf_range(0.6, 1.0), r * rng.randf_range(0.7, 1.3)),
			Vector3(rng.randf() * TAU, rng.randf() * TAU, 0))
		a.add_to_group("obstacles")
		a.set_meta("radius", r * 0.85)
		add_child(a)


func _build_gates() -> void:
	var nexts: Array = node["next"]
	var k := nexts.size()
	for i in k:
		var target: Dictionary = Run.map.node_at(nexts[i])
		var g := JumpGate.new()
		g.setup(target)
		g.position = Vector3((i - (k - 1) * 0.5) * 900.0, rng.randf_range(-120, 120), GATE_Z)
		add_child(g)
		g.look_at(Vector3(0, 0, 0), Vector3.UP)
		g.entered.connect(func(gate): gate_entered.emit(gate.target_id))


func spawn_victory_gate() -> void:
	var g := JumpGate.new()
	g.target_id = -2
	g.color = Color(1.0, 0.85, 0.3)
	g.label_text = "Escape Gate\nFly through to win the run"
	g.position = Vector3(0, 0, -1500)
	add_child(g)
	g.look_at(Vector3.ZERO, Vector3.UP)
	g.entered.connect(func(_gate): gate_entered.emit(-2))


func _build_event_beacon() -> void:
	event_beacon = Node3D.new()
	event_beacon.position = Vector3(rng.randf_range(-200, 200), rng.randf_range(-50, 50), rng.randf_range(-400, 0))
	add_child(event_beacon)
	match String(event_def["model"]):
		"freighter":
			var f := ShipMesh.build("freighter", Color(0.5, 0.48, 0.42), Color(0.3, 0.3, 0.3))
			f.scale = Vector3.ONE * 3.0
			f.rotation = Vector3(0.3, 0.8, 0.5)
			event_beacon.add_child(f)
		"rocks":
			for i in 8:
				var r := rng.randf_range(8, 25)
				event_beacon.add_child(FX.mesh_node(FX.sphere(1.0, 7), FX.mat(Color(0.55, 0.5, 0.42), 0.2, 0.6, 0.6),
					Vector3(rng.randf_range(-80, 80), rng.randf_range(-40, 40), rng.randf_range(-80, 80)), Vector3.ONE * r))
		"anomaly":
			event_beacon.add_child(FX.mesh_node(FX.sphere(30, 24), FX.glow_mat(Color(0.7, 0.4, 1.0), 3.0, 0.5)))
			event_beacon.add_child(FX.mesh_node(FX.torus(45, 52, 48), FX.glow_mat(Color(0.5, 0.8, 1.0), 4.0)))
		_:
			event_beacon.add_child(FX.mesh_node(FX.box(Vector3(12, 8, 16)), FX.mat(Color(0.6, 0.5, 0.2), 0.3, 0.7, 0.4)))
	var light := OmniLight3D.new()
	light.light_color = Color(0.75, 0.55, 1.0)
	light.light_energy = 3.0
	light.omni_range = 300.0
	event_beacon.add_child(light)
	var label := Label3D.new()
	label.text = String(event_def["title"]) + "\n[F] Investigate"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.4
	label.font_size = 48
	label.outline_size = 12
	label.modulate = Color(0.8, 0.6, 1.0)
	label.position = Vector3(0, 90, 0)
	label.no_depth_test = true
	event_beacon.add_child(label)


func _spawn_group(center: Vector3, count: int, rank_name: String) -> void:
	for i in count:
		var offset := Vector3(rng.randf_range(-80, 80), rng.randf_range(-30, 30), rng.randf_range(-80, 80))
		_spawn_enemy(center + offset, rank_name)


func _spawn_enemy(pos: Vector3, rank_name: String) -> EnemyShip:
	var e := EnemyShip.new()
	e.setup_enemy(level(), rank_name, rng.randi())
	e.position = pos
	e.world = self
	e.rotation.y = rng.randf() * TAU
	e.died.connect(_on_enemy_died)
	add_child(e)
	return e


## Spawns attackers a little way off from the player (events, ambushes).
func spawn_pirates_near_player(count: int, rank_name: String) -> void:
	for i in count:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3), rng.randf_range(-1, 1)).normalized()
		var e := _spawn_enemy(player.global_position + dir * rng.randf_range(500, 800), rank_name)
		e.state = EnemyShip.State.ATTACK


func _on_boss_escorts(b: EnemyShip, count: int) -> void:
	for i in count:
		var e := _spawn_enemy(b.global_position + Vector3(rng.randf_range(-60, 60), rng.randf_range(-30, 30), rng.randf_range(-60, 60)), "normal")
		e.state = EnemyShip.State.ATTACK
	Run.message.emit("The Warlord calls in reinforcements!", Color(1, 0.4, 0.3))


func _on_enemy_died(ship: Ship) -> void:
	var e := ship as EnemyShip
	Run.kills += 1
	var pos := e.global_position
	var credit_find := Run.stats.credit_find
	var credits := int(e.credit_value * rng.randf_range(0.7, 1.3) * (1.0 + credit_find / 100.0))
	spawn_credits(pos, credits)
	var drops := 0
	match e.rank:
		"elite":
			Run.elites_killed += 1
			drops = rng.randi_range(2, 3)
		"boss":
			Run.bosses_killed += 1
			drops = 5
		_:
			drops = 1 if rng.randf() < 0.32 else 0
	for i in drops:
		var item := LootGenerator.generate(level(), e.loot_source, rng, Run.stats.loot_find)
		spawn_item(pos, item)
	if e == boss:
		boss = null
		spawn_victory_gate()
		boss_defeated.emit()


func drop_loot_near_player(source: int, count: int) -> void:
	var pos := player.global_position + player.forward() * 80.0
	for i in count:
		spawn_item(pos, LootGenerator.generate(level(), source, rng, Run.stats.loot_find))


func spawn_item(pos: Vector3, item: Item) -> void:
	var p := LootPickup.new()
	p.item = item
	p.position = pos
	p.drift = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(10, 30)
	add_child(p)


func spawn_credits(pos: Vector3, amount: int) -> void:
	if amount <= 0:
		return
	var p := LootPickup.new()
	p.credits = amount
	p.position = pos
	p.drift = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * 15.0
	add_child(p)


func tractor_all() -> int:
	var n := 0
	for l in get_tree().get_nodes_in_group("loot"):
		var lp := l as LootPickup
		if lp and lp.global_position.distance_to(player.global_position) < 600.0:
			lp.tractored = true
			n += 1
	return n


## What the player could interact with right now: "station", "event" or "".
func interaction_available() -> String:
	if player == null:
		return ""
	if station and player.global_position.distance_to(station.global_position) < Station.DOCK_RANGE:
		return "station"
	if event_beacon and not event_done and player.global_position.distance_to(event_beacon.global_position) < EVENT_RANGE:
		return "event"
	return ""


func _process(dt: float) -> void:
	if player == null or not is_instance_valid(player) or not player.alive:
		return
	var ppos := player.global_position
	for g in get_tree().get_nodes_in_group("gates"):
		(g as JumpGate).check_player(ppos)
	for l in get_tree().get_nodes_in_group("loot"):
		var lp := l as LootPickup
		if lp.credits > 0 and lp.global_position.distance_to(ppos) < 60.0:
			lp.tractored = true
		if lp.pull_toward(ppos, dt):
			_collect(lp)
	_collide(player)
	for s in get_tree().get_nodes_in_group("ships"):
		if s != player:
			_collide(s as Ship)


func _collect(lp: LootPickup) -> void:
	if lp.credits > 0:
		Run.add_credits(lp.credits)
		Run.message.emit("+%d credits" % lp.credits, Color(1.0, 0.85, 0.3))
		lp.queue_free()
	elif lp.item:
		if Run.add_to_cargo(lp.item):
			lp.queue_free()
		else:
			lp.tractored = false


## Pushes a ship out of rocks and stations; hard crashes hurt.
func _collide(s: Ship) -> void:
	if s == null or not s.alive:
		return
	for o in get_tree().get_nodes_in_group("obstacles"):
		var on := o as Node3D
		var r: float = float(on.get_meta("radius", 10.0)) + s.radius
		var d := s.global_position - on.global_position
		if d.length_squared() < r * r:
			var n := d.normalized()
			s.global_position = on.global_position + n * r
			var vn := s.flight.velocity.dot(n)
			if vn < 0.0:
				s.flight.velocity -= n * vn * 1.4
				if -vn > 35.0 and s.faction == "player":
					s.take_damage({"kinetic": -vn * 0.25, "thermal": 0.0, "emp": 0.0})
					s.flight.set_cruise(false)
