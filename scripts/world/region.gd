class_name Region
extends Node3D
## The fixed contents of one sector: rocks, a planet, and whatever the map
## node says lives here (station, signal, boss arena). Loaded and unloaded by
## the Galaxy as the player comes and goes; enemies are spawned by the Galaxy
## from `spawn_list()` so it can remember which ones you've killed.

var node: Dictionary = {}
var state: Dictionary = {}
var rng := RandomNumberGenerator.new()
var station: Station
var event_beacon: Node3D
var escape_gate: JumpGate


func setup(map_node: Dictionary, site_state: Dictionary) -> void:
	node = map_node
	state = site_state
	rng.seed = int(node["seed"])
	name = "Region_%d" % node["id"]


func _ready() -> void:
	_build_planet()
	_build_asteroids(rng.randi_range(14, 30))
	var beacon := Label3D.new()
	beacon.text = String(node["name"])
	beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	beacon.pixel_size = 6.0
	beacon.font_size = 64
	beacon.outline_size = 12
	beacon.modulate = Color(RunMap.TYPE_COLORS[node["type"]], 0.5)
	beacon.position = Vector3(0, 1800, 0)
	add_child(beacon)
	match String(node["type"]):
		"station":
			station = Station.new()
			station.station_name = String(node["name"]) + " Station"
			station.position = Vector3(rng.randf_range(-300, 300), 0, rng.randf_range(-300, 300))
			add_child(station)
			if not state.has("stock"):
				station.generate_stock(level(), rng)
				state["stock"] = station.stock
			station.stock = state["stock"]
		"event":
			if not state.has("event"):
				state["event"] = SectorEvents.pick(rng)
			if not state.get("event_done", false):
				_build_event_beacon()
		"boss":
			if 0 in state.get("dead", []):
				spawn_escape_gate()


func level() -> int:
	return int(node["level"])


## Enemies that belong here: [{"pos": Vector3 (local), "rank": String}].
## Index in this list is how the Galaxy remembers kills.
func spawn_list() -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = int(node["seed"]) + 77
	var out: Array = []
	var lvl := level()
	match String(node["type"]):
		"start":
			_group(out, Vector3(600, 0, 300), 2, "normal", r)
		"combat":
			_group(out, Vector3(r.randf_range(-600, 600), r.randf_range(-100, 100), r.randf_range(-600, 600)), r.randi_range(2, 3 + lvl / 8), "normal", r)
			_group(out, Vector3(r.randf_range(-1500, 1500), r.randf_range(-200, 200), r.randf_range(-1500, 1500)), r.randi_range(2, 3), "normal", r)
		"elite":
			var p := Vector3(r.randf_range(-500, 500), 0, r.randf_range(-500, 500))
			_group(out, p, 1, "elite", r)
			_group(out, p + Vector3(60, 0, 60), r.randi_range(2, 3), "normal", r)
		"station":
			if r.randf() < 0.35:
				_group(out, Vector3(1800, 0, 0), 2, "normal", r)
		"boss":
			out.append({"pos": Vector3(0, 40, 0), "rank": "boss"})
			_group(out, Vector3(200, 0, 200), 3, "normal", r)
			out.append({"pos": Vector3(-900, 100, 500), "rank": "jammer"})
	return out


func _group(out: Array, center: Vector3, count: int, rank_name: String, r: RandomNumberGenerator) -> void:
	for i in count:
		out.append({"pos": center + Vector3(r.randf_range(-80, 80), r.randf_range(-30, 30), r.randf_range(-80, 80)), "rank": rank_name})


func _build_planet() -> void:
	var hue := rng.randf()
	var planet_col := Color.from_hsv(hue, rng.randf_range(0.3, 0.7), rng.randf_range(0.4, 0.8))
	var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3), rng.randf_range(-1, 1)).normalized()
	var r := rng.randf_range(2500, 5000)
	var pos := dir * rng.randf_range(16000, 22000)
	add_child(FX.mesh_node(FX.sphere(r, 48), FX.mat(planet_col, 0.05, 0.0, 0.9), pos))
	if rng.randf() < 0.5:
		add_child(FX.mesh_node(FX.torus(r * 1.35, r * 1.9, 64), FX.glow_mat(planet_col.lightened(0.3), 0.4, 0.3),
			pos, Vector3(1, 0.02, 1), Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))))


const ROCK_MODELS := ["meteor-detailed", "rock-largea", "rock-largeb", "meteor", "rock-crystalslargea", "rock"]


func _build_asteroids(count: int) -> void:
	var rock := FX.mat(Color(0.42, 0.38, 0.35), 0.0, 0.1, 0.95)
	# Kenney rock models if present, else faceted spheres. Each entry: [mesh, unit scale, centre].
	var kinds: Array = []
	for m in ROCK_MODELS:
		var u := Assets.unit_mesh(m)
		if not u.is_empty():
			kinds.append(u)
	if kinds.is_empty():
		kinds.append([FX.sphere(1.0, 7), 1.0, Vector3.ZERO])
	var use_override := kinds.size() == 1 and kinds[0][0] is SphereMesh
	# Decorative small rocks, one MultiMesh per rock type.
	var per_kind := 260 / kinds.size()
	for k in kinds:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = k[0]
		mm.instance_count = per_kind
		for i in per_kind:
			var p := Vector3(rng.randf_range(-3000, 3000), rng.randf_range(-700, 700), rng.randf_range(-3000, 3000))
			var sc := rng.randf_range(2.0, 9.0) * float(k[1])
			var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)).scaled(Vector3(sc, sc * rng.randf_range(0.6, 1.0), sc * rng.randf_range(0.7, 1.2)))
			mm.set_instance_transform(i, Transform3D(b, p - b * Vector3(k[2])))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if use_override:
			mmi.material_override = rock
		add_child(mmi)
	# Big rocks you can crash into.
	for i in count:
		var p := Vector3(rng.randf_range(-2600, 2600), rng.randf_range(-500, 500), rng.randf_range(-2600, 2600))
		# Keep the middle (station / arena) and the lane approaches clear.
		if p.length() < 500.0 or absf(p.z) < 250.0 and absf(p.y) < 250.0:
			continue
		var r := rng.randf_range(15.0, 60.0)
		var k: Array = kinds[rng.randi_range(0, kinds.size() - 1)]
		var holder := Node3D.new()
		holder.position = p
		holder.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
		var sc := r * float(k[1])
		var mi := FX.mesh_node(k[0], rock if use_override else null, -Vector3(k[2]) * sc, Vector3(sc, sc * rng.randf_range(0.7, 1.0), sc))
		holder.add_child(mi)
		holder.add_to_group("obstacles")
		holder.set_meta("radius", r * 0.85)
		add_child(holder)


func spawn_escape_gate() -> void:
	if escape_gate:
		return
	escape_gate = JumpGate.new()
	escape_gate.target_id = -2
	escape_gate.color = Color(1.0, 0.85, 0.3)
	escape_gate.label_text = "Escape Jump Gate\nFly through to win the run"
	escape_gate.position = Vector3(1200, 0, 0)
	add_child(escape_gate)
	escape_gate.look_at(global_position, Vector3.UP)


func _build_event_beacon() -> void:
	var ev: Dictionary = state["event"]
	event_beacon = Node3D.new()
	event_beacon.position = Vector3(rng.randf_range(-300, 300), rng.randf_range(-50, 50), rng.randf_range(-300, 300))
	add_child(event_beacon)
	match String(ev["model"]):
		"freighter":
			var f := ShipMesh.build("freighter", Color(0.5, 0.48, 0.42), Color(0.3, 0.3, 0.3), "freighter", 70.0)
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
	label.text = String(ev["title"]) + "\n[F] Investigate"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.4
	label.font_size = 48
	label.outline_size = 12
	label.modulate = Color(0.8, 0.6, 1.0)
	label.position = Vector3(0, 90, 0)
	label.no_depth_test = true
	event_beacon.add_child(label)


func finish_event() -> void:
	state["event_done"] = true
	if event_beacon:
		event_beacon.queue_free()
		event_beacon = null
