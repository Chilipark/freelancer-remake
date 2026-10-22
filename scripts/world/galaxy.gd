class_name Galaxy
extends Node3D
## The whole open-world system. Owns everything in space and handles:
## - floating origin: the world is shifted so the player stays near (0,0,0),
##   keeping 32-bit float positions precise across hundreds of kilometres;
## - streaming: sectors and jammer sites load when you get close and unload
##   when you leave, remembering kills, loot taken and events done;
## - Freelancer trade lanes: fly through any ring (or press F next to one)
##   and ride the lane at ~2200 m/s to the far end;
## - ambushes: lanes can be disrupted mid-trip, some lanes are blocked by a
##   pirate jammer, and long cruises through open space draw interdictors;
## - jamming: jammers and interdictors block cruise and lane travel nearby.
## Children of this node use "local" positions; `origin` is the absolute
## position of local (0,0,0).

signal victory
signal region_entered(id: int)
signal lane_started(lane: Dictionary)
signal lane_ended(reason: String)

const LOAD_RANGE := 15000.0
const UNLOAD_RANGE := 21000.0
const CLEANUP_RANGE := 25000.0
const REGION_RADIUS := 6000.0
const ORIGIN_SHIFT := 3000.0
const LANE_END_OFFSET := 2400.0     # lanes start this far from a sector's centre
const RING_SPACING := 1500.0
const RING_RADIUS := 45.0
const LANE_SPEED := 2200.0
const LANE_ACCEL := 900.0
const LANE_ENTRY_RANGE := 220.0
const JAM_STOP_DISTANCE := 1600.0
const EVENT_RANGE := 320.0
const INTERDICT_EVERY := 16.0       # seconds of open-space cruising between rolls

var map: RunMap
var player: PlayerShip
var origin := Vector3.ZERO
var rng := RandomNumberGenerator.new()
## Lanes: {a, b, start, end, dir, length, count, jam_t, jam_site, name_a, name_b}
var lanes: Array = []
## Sites: {id, kind: "region"/"jam", pos, level, node, lane, loaded: Node3D, state}
var sites: Array = []
var trip: Dictionary = {}           # active lane trip
var autopilot := Autopilot.new()
var _prev_lane_t: Dictionary = {}   # lane index -> last along-lane distance near it
var _stream_timer := 0.0
var _interdict_timer := 0.0
var _jam_msg_cd := 0.0
var _sky: ShaderMaterial
var _sky_a := Color()
var _sky_b := Color()
var _sky_target_a := Color()
var _sky_target_b := Color()


func build(run_map: RunMap, p: PlayerShip, seed_value: int) -> void:
	map = run_map
	player = p
	rng.seed = seed_value
	name = "Galaxy"
	_build_environment()
	_build_lanes()
	for n in map.nodes:
		sites.append({"id": sites.size(), "kind": "region", "pos": n["pos"], "level": n["level"],
			"node": n, "loaded": null, "state": {"dead": []}})
	for i in lanes.size():
		var L: Dictionary = lanes[i]
		if L["jam_t"] < 0.0:
			continue
		var ldir: Vector3 = L["dir"]
		var side := ldir.cross(Vector3.UP).normalized() * 350.0
		var site := {"id": sites.size(), "kind": "jam", "pos": L["start"] + L["dir"] * L["jam_t"] + side,
			"level": RunMap.level_at(L["start"] + L["dir"] * L["jam_t"]), "lane": i, "loaded": null, "state": {"dead": []}}
		L["jam_site"] = site["id"]
		sites.append(site)
	Run.missions.jam_cleared = lane_jam_cleared
	autopilot.galaxy = self
	player.autopilot = autopilot
	lane_ended.connect(autopilot.on_lane_ended)
	var start: Dictionary = map.node_at(map.start_id())
	origin = start["pos"]
	_build_ring_meshes()
	add_child(player)
	place_player(Vector3(-1200, 0, 0), Vector3(1, 0, 0))
	_stream(true)


func place_player(local_pos: Vector3, facing: Vector3) -> void:
	player.global_transform = Transform3D(Basis.looking_at(facing, Vector3.UP), local_pos)
	player.flight.velocity = facing * 40.0
	player.flight.throttle = 0.5


func to_local_pos(abs_pos: Vector3) -> Vector3:
	return abs_pos - origin


func player_abs() -> Vector3:
	return origin + player.position


func level_here() -> int:
	return RunMap.level_at(player_abs())


# --- Construction ----------------------------------------------------------

func _build_environment() -> void:
	_sky = ShaderMaterial.new()
	_sky.shader = load("res://shaders/space_sky.gdshader")
	_sky.set_shader_parameter("nebula_strength", 0.7)
	_sky.set_shader_parameter("seed", rng.randf_range(0.0, 50.0))
	var sky := Sky.new()
	sky.sky_material = _sky
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
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.rotation = Vector3(-0.6, 0.8, 0)
	add_child(sun)
	_sky_target_a = _region_colors(map.nodes[0])[0]
	_sky_target_b = _region_colors(map.nodes[0])[1]
	_sky_a = _sky_target_a
	_sky_b = _sky_target_b


static func _region_colors(n: Dictionary) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = int(n["seed"]) + 5
	var hue := r.randf()
	return [Color.from_hsv(hue, 0.75, 0.55), Color.from_hsv(fmod(hue + r.randf_range(0.1, 0.3), 1.0), 0.7, 0.45)]


func _build_lanes() -> void:
	lanes.clear()
	for l in map.lanes:
		var a: Dictionary = map.node_at(l["a"])
		var b: Dictionary = map.node_at(l["b"])
		var dir: Vector3 = (b["pos"] - a["pos"]).normalized()
		var start: Vector3 = a["pos"] + dir * LANE_END_OFFSET
		var end: Vector3 = b["pos"] - dir * LANE_END_OFFSET
		var length := start.distance_to(end)
		var count := maxi(2, int(round(length / RING_SPACING)) + 1)
		var jam_t := -1.0
		if float(l["jam"]) >= 0.0:
			jam_t = length * float(l["jam"])
		lanes.append({"a": l["a"], "b": l["b"], "start": start, "end": end, "dir": dir, "length": length,
			"count": count, "spacing": length / float(count - 1), "jam_t": jam_t, "jam_site": -1,
			"name_a": a["name"], "name_b": b["name"]})


## All rings of all lanes as two MultiMeshes (frames and lights).
func _build_ring_meshes() -> void:
	var frame_mm := MultiMesh.new()
	frame_mm.transform_format = MultiMesh.TRANSFORM_3D
	frame_mm.mesh = FX.torus(RING_RADIUS, RING_RADIUS + 9.0, 32)
	var light_mm := MultiMesh.new()
	light_mm.transform_format = MultiMesh.TRANSFORM_3D
	light_mm.mesh = FX.torus(RING_RADIUS - 2.5, RING_RADIUS, 32)
	var total := 0
	for L in lanes:
		total += int(L["count"])
	frame_mm.instance_count = total
	light_mm.instance_count = total
	var i := 0
	for L in lanes:
		var dir: Vector3 = L["dir"]
		# Torus axis is +Y; turn it to point along the lane.
		var basis := Basis(Quaternion(Vector3.UP, dir))
		for k in int(L["count"]):
			var p: Vector3 = L["start"] + dir * (k * float(L["spacing"]))
			frame_mm.set_instance_transform(i, Transform3D(basis, p))
			light_mm.set_instance_transform(i, Transform3D(basis, p))
			i += 1
	var frames := MultiMeshInstance3D.new()
	frames.name = "LaneFrames"
	frames.multimesh = frame_mm
	frames.material_override = FX.mat(Color(0.5, 0.52, 0.58), 0.0, 0.8, 0.35)
	frames.position = -origin
	add_child(frames)
	# A faint beam down each lane so lanes read from far away.
	var beam_mm := MultiMesh.new()
	beam_mm.transform_format = MultiMesh.TRANSFORM_3D
	beam_mm.mesh = FX.cylinder(1.0, 1.0, 1.0, 6)
	beam_mm.instance_count = lanes.size()
	for b in lanes.size():
		var L: Dictionary = lanes[b]
		var bdir: Vector3 = L["dir"]
		var mid: Vector3 = (L["start"] + L["end"]) * 0.5
		var basis := Basis(Quaternion(Vector3.UP, bdir)) * Basis.from_scale(Vector3(3.0, float(L["length"]), 3.0))
		beam_mm.set_instance_transform(b, Transform3D(basis, mid))
	var beams := MultiMeshInstance3D.new()
	beams.name = "LaneBeams"
	beams.multimesh = beam_mm
	beams.material_override = FX.glow_mat(Color(0.95, 0.75, 0.35), 1.2, 0.1)
	beams.position = -origin
	add_child(beams)
	var lights := MultiMeshInstance3D.new()
	lights.name = "LaneLights"
	lights.multimesh = light_mm
	lights.material_override = FX.glow_mat(Color(0.95, 0.75, 0.35), 4.0)
	lights.position = -origin
	add_child(lights)


# --- Per frame ---------------------------------------------------------------

func _process(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_shift_origin()
	_update_sky(dt)
	_jam_msg_cd = maxf(0.0, _jam_msg_cd - dt)
	_stream_timer -= dt
	if _stream_timer <= 0.0:
		_stream_timer = 0.4
		_stream(false)
	if not player.alive:
		return
	if not trip.is_empty():
		_update_trip(dt)
	else:
		_check_lane_entry()
		_check_jamming()
		_interdiction(dt)
	for g in get_tree().get_nodes_in_group("gates"):
		(g as JumpGate).check_player(player.position)
	_update_loot(dt)
	if trip.is_empty():
		_collide(player)
	for s in get_tree().get_nodes_in_group("ships"):
		if s != player:
			_collide(s as Ship)
	_collide_ships()


func _shift_origin() -> void:
	var off := player.position
	if off.length() < ORIGIN_SHIFT:
		return
	origin += off
	for c in get_children():
		if c is Node3D:
			c.position -= off
			if c.has_method("shift_origin"):
				c.shift_origin(off)


func _update_sky(dt: float) -> void:
	var k := 1.0 - exp(-0.5 * dt)
	_sky_a = _sky_a.lerp(_sky_target_a, k)
	_sky_b = _sky_b.lerp(_sky_target_b, k)
	_sky.set_shader_parameter("nebula_a", _sky_a)
	_sky.set_shader_parameter("nebula_b", _sky_b)


# --- Streaming ---------------------------------------------------------------

func _stream(force: bool) -> void:
	var pabs := player_abs()
	for s in sites:
		var d: float = pabs.distance_to(s["pos"])
		if s["loaded"] == null and (d < LOAD_RANGE or (force and d < LOAD_RANGE)):
			_load_site(s)
		elif s["loaded"] != null and d > UNLOAD_RANGE:
			_unload_site(s)
	# Which sector are we in?
	var near := map.nearest_node(pabs)
	if pabs.distance_to(near["pos"]) < REGION_RADIUS and Run.node_id != int(near["id"]):
		Run.travel_to(int(near["id"]))
		region_entered.emit(int(near["id"]))
		Run.missions.on_event("enter", {"node": int(near["id"])})
	var cols := _region_colors(near)
	_sky_target_a = cols[0]
	_sky_target_b = cols[1]
	# Free stray ambushers and loot that were left far behind.
	for n in get_tree().get_nodes_in_group("ships"):
		var e := n as EnemyShip
		if e and not e.has_meta("site") and e.position.length() > CLEANUP_RANGE:
			if e.has_meta("contract"):
				for c in Run.missions.contracts:
					if int(c["id"]) == int(e.get_meta("contract")):
						c["spawned"] = false
			e.remove_from_group("ships")
			e.remove_from_group("jammers")
			e.queue_free()
	for l in get_tree().get_nodes_in_group("loot"):
		if (l as Node3D).position.length() > CLEANUP_RANGE:
			l.queue_free()


func _load_site(s: Dictionary) -> void:
	var local := to_local_pos(s["pos"])
	var spawns: Array = []
	if s["kind"] == "region":
		var r := Region.new()
		r.setup(s["node"], s["state"])
		r.position = local
		add_child(r)
		s["loaded"] = r
		if r.escape_gate:
			r.escape_gate.entered.connect(func(_g): victory.emit())
		spawns = r.spawn_list()
	else:
		var holder := Node3D.new()
		holder.name = "JamSite_%d" % s["id"]
		holder.position = local
		add_child(holder)
		s["loaded"] = holder
		spawns = [{"pos": Vector3.ZERO, "rank": "jammer"}]
		for i in 3:
			spawns.append({"pos": Vector3(rng.randf_range(-150, 150), rng.randf_range(-40, 40), rng.randf_range(-150, 150)), "rank": "normal"})
	s["spawn_count"] = spawns.size()
	var dead: Array = s["state"]["dead"]
	for i in spawns.size():
		if i in dead:
			continue
		var sp: Dictionary = spawns[i]
		var e := _spawn_enemy(local + sp["pos"], sp["rank"], int(s["level"]))
		e.set_meta("site", s["id"])
		e.set_meta("index", i)
	if s["kind"] == "region":
		spawn_bounties(s)


## Spawns pirate aces for accepted bounty contracts in a loaded sector.
func spawn_bounties(s: Dictionary) -> void:
	if s["loaded"] == null or s["kind"] != "region":
		return
	for c in Run.missions.bounties_at(int(s["node"]["id"])):
		var local := to_local_pos(s["pos"]) + Vector3(rng.randf_range(-900, 900), rng.randf_range(-150, 150), rng.randf_range(-900, 900))
		var ace := _spawn_enemy(local, "elite", int(c["level"]))
		ace.display_name = "%s (bounty)" % c["ace"]
		ace.set_meta("contract", int(c["id"]))
		c["spawned"] = true
		for i in 2:
			_spawn_enemy(local + Vector3(rng.randf_range(-80, 80), 0, rng.randf_range(-80, 80)), "normal", int(c["level"]))


## Call after accepting a contract so a bounty in a nearby sector appears.
func refresh_bounties() -> void:
	for s in sites:
		if s["loaded"] != null:
			spawn_bounties(s)


func lane_jam_cleared(lane_index: int) -> bool:
	var L: Dictionary = lanes[lane_index]
	if float(L["jam_t"]) < 0.0:
		return true
	return 0 in sites[int(L["jam_site"])]["state"]["dead"]


func _unload_site(s: Dictionary) -> void:
	for n in get_tree().get_nodes_in_group("ships"):
		if n is EnemyShip and n.get_meta("site", -1) == s["id"]:
			n.remove_from_group("ships")
			n.remove_from_group("jammers")
			n.queue_free()
	(s["loaded"] as Node).queue_free()
	s["loaded"] = null


func loaded_regions() -> Array:
	var out: Array = []
	for s in sites:
		if s["kind"] == "region" and s["loaded"] != null:
			out.append(s["loaded"])
	return out


func current_region() -> Region:
	for s in sites:
		if s["kind"] == "region" and s["loaded"] != null and int(s["node"]["id"]) == Run.node_id:
			return s["loaded"]
	return null


# --- Enemies, loot -------------------------------------------------------------

func _spawn_enemy(local_pos: Vector3, rank_name: String, lvl: int, interdictor: bool = false) -> EnemyShip:
	var e := EnemyShip.new()
	e.setup_enemy(lvl, rank_name, rng.randi(), interdictor)
	e.position = local_pos
	e.world = self
	e.rotation.y = rng.randf() * TAU
	e.died.connect(_on_enemy_died)
	if rank_name == "boss":
		e.spawn_escorts.connect(_on_boss_escorts)
	add_child(e)
	return e


## Pirates that come straight for the player (events, ambushes).
func spawn_pirates_near_player(count: int, rank_name: String, min_d: float = 500.0, max_d: float = 800.0, interdictors: int = 0) -> void:
	var lvl := level_here()
	for i in count:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3), rng.randf_range(-1, 1)).normalized()
		var e := _spawn_enemy(player.position + dir * rng.randf_range(min_d, max_d), rank_name, lvl, i < interdictors)
		e.state = EnemyShip.State.ATTACK


func _on_boss_escorts(b: EnemyShip, count: int) -> void:
	for i in count:
		var e := _spawn_enemy(b.position + Vector3(rng.randf_range(-60, 60), rng.randf_range(-30, 30), rng.randf_range(-60, 60)), "normal", b.level)
		e.state = EnemyShip.State.ATTACK
	Run.message.emit("The Warlord calls in reinforcements!", Color(1, 0.4, 0.3))


func _on_enemy_died(ship: Ship) -> void:
	var e := ship as EnemyShip
	Run.kills += 1
	if e.has_meta("site"):
		var s: Dictionary = sites[int(e.get_meta("site"))]
		s["state"]["dead"].append(int(e.get_meta("index")))
		if s["kind"] == "jam" and e.rank == "jammer":
			Run.message.emit("Jammer destroyed! The trade lane is clear.", Color(0.5, 1, 0.6))
			Run.missions.on_event("jammer", {"lane": int(s["lane"])})
		if int(s["id"]) == 0 and s["state"]["dead"].size() >= int(s.get("spawn_count", 0)):
			Run.missions.on_event("raiders_cleared")
	if e.has_meta("contract"):
		Run.missions.on_event("kill", {"contract": int(e.get_meta("contract"))})
	var pos := e.position
	var credits := int(e.credit_value * rng.randf_range(0.7, 1.3) * (1.0 + Run.stats.credit_find / 100.0))
	spawn_credits(pos, credits)
	var drops := 0
	match e.rank:
		"elite":
			Run.elites_killed += 1
			drops = rng.randi_range(2, 3)
		"boss":
			Run.bosses_killed += 1
			drops = 5
		"jammer":
			drops = 1
		_:
			drops = 1 if rng.randf() < 0.32 else 0
	for i in drops:
		spawn_item(pos, LootGenerator.generate(e.level, e.loot_source, rng, Run.stats.loot_find))
	if e.rank == "jammer" and e.jam_radius > 0.0:
		Run.message.emit("Jamming field down.", Color(0.5, 1, 0.6))
	if e.rank == "boss":
		for r in loaded_regions():
			if (r as Region).node["type"] == "boss":
				(r as Region).spawn_escape_gate()
				(r as Region).escape_gate.entered.connect(func(_g): victory.emit())
		Run.message.emit("The Warlord is destroyed! Fly through the escape gate.", Color(1, 0.85, 0.3))
		Run.missions.on_event("boss")


func drop_loot_near_player(source: int, count: int) -> void:
	var pos := player.position + player.forward() * 80.0
	for i in count:
		spawn_item(pos, LootGenerator.generate(level_here(), source, rng, Run.stats.loot_find))


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
		if lp and lp.position.distance_to(player.position) < 600.0:
			lp.tractored = true
			n += 1
	return n


func _update_loot(dt: float) -> void:
	var ppos := player.position
	for l in get_tree().get_nodes_in_group("loot"):
		var lp := l as LootPickup
		if lp.credits > 0 and lp.position.distance_to(ppos) < 60.0:
			lp.tractored = true
		if lp.pull_toward(ppos, dt):
			if lp.credits > 0:
				Run.add_credits(lp.credits)
				Run.message.emit("+%d credits" % lp.credits, Color(1.0, 0.85, 0.3))
				lp.queue_free()
			elif lp.item:
				if Run.add_to_cargo(lp.item):
					Sfx.play(self, "pickup", -10.0)
					lp.queue_free()
				else:
					lp.tractored = false


const CRASH_SAFE_SPEED := 15.0     # m/s of closing speed before it hurts
const CRASH_DAMAGE := 1.1          # damage per m/s above that


## Pushes a ship out of rocks and stations. Hitting them hurts, more so the
## faster you were going (a cruise-speed crash can wreck a light fighter).
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
				_crash(s, -vn, on.global_position + n * float(on.get_meta("radius", 10.0)))


## Ships bumping into each other. Momentum is shared by size (a fighter
## bounces off the dreadnought), and both take damage from the impact.
func _collide_ships() -> void:
	var ships := get_tree().get_nodes_in_group("ships")
	for i in ships.size():
		var a := ships[i] as Ship
		if a == null or not a.alive or a.on_rails:
			continue
		for j in range(i + 1, ships.size()):
			var b := ships[j] as Ship
			if b == null or not b.alive or b.on_rails:
				continue
			var r := a.radius + b.radius
			var d := a.global_position - b.global_position
			if d.length_squared() >= r * r or d.length_squared() < 0.0001:
				continue
			var n := d.normalized()
			var ma := pow(a.radius, 3.0) * (50.0 if a.stats.top_speed <= 0.0 else 1.0)
			var mb := pow(b.radius, 3.0) * (50.0 if b.stats.top_speed <= 0.0 else 1.0)
			var overlap := r - d.length()
			a.global_position += n * overlap * mb / (ma + mb)
			b.global_position -= n * overlap * ma / (ma + mb)
			var closing := (a.flight.velocity - b.flight.velocity).dot(n)
			if closing >= 0.0:
				continue
			a.flight.velocity -= n * closing * 1.5 * mb / (ma + mb)
			b.flight.velocity += n * closing * 1.5 * ma / (ma + mb)
			var contact := b.global_position + n * b.radius
			_crash(a, -closing * 2.0 * mb / (ma + mb), contact)
			_crash(b, -closing * 2.0 * ma / (ma + mb), contact)


func _crash(s: Ship, impact_speed: float, at: Vector3) -> void:
	if impact_speed <= CRASH_SAFE_SPEED or not s.alive:
		return
	# Don't hit the same ship again for a moment (it may still be touching).
	var now := Time.get_ticks_msec()
	if now - int(s.get_meta("last_crash", -10000)) < 400:
		return
	s.set_meta("last_crash", now)
	var dmg := (impact_speed - CRASH_SAFE_SPEED) * CRASH_DAMAGE
	if s.faction == "player":
		dmg = minf(dmg, s.stats.max_hull * 0.6)   # a bad crash hurts, but one alone won't kill you
	s.take_damage({"kinetic": dmg, "thermal": 0.0, "emp": 0.0})
	s.flight.set_cruise(false)
	FX.flash(self, at, Color(1.0, 0.8, 0.5), clampf(dmg * 0.05, 2.0, 12.0), 0.3)
	Sfx.play_at(self, "hit_hull", at, -4.0)
	if s.faction == "player" and dmg > 8.0:
		Run.message.emit("Collision! -%d" % int(dmg), Color(1, 0.5, 0.3))


# --- Interaction ---------------------------------------------------------------

## What the player can use right now with F: "station", "event", "lane" or "".
func interaction_available() -> String:
	if player == null or not trip.is_empty():
		return ""
	var r := current_region()
	if r:
		if r.station and player.global_position.distance_to(r.station.global_position) < Station.DOCK_RANGE:
			return "station"
		if r.event_beacon and player.global_position.distance_to(r.event_beacon.global_position) < EVENT_RANGE:
			return "event"
	if not nearest_ring().is_empty():
		return "lane"
	return ""


## The lane ring next to the player: {lane, t, dir_sign, dest_name} or {}.
func nearest_ring() -> Dictionary:
	var pabs := player_abs()
	for i in lanes.size():
		var L: Dictionary = lanes[i]
		var rel: Vector3 = pabs - L["start"]
		var t: float = rel.dot(L["dir"])
		if t < -LANE_ENTRY_RANGE or t > float(L["length"]) + LANE_ENTRY_RANGE:
			continue
		var k := clampi(int(round(t / float(L["spacing"]))), 0, int(L["count"]) - 1)
		var ring_t := k * float(L["spacing"])
		var ring_pos: Vector3 = L["start"] + L["dir"] * ring_t
		if pabs.distance_to(ring_pos) > LANE_ENTRY_RANGE:
			continue
		var facing := player.forward().dot(L["dir"])
		var sgn := 1 if facing >= 0.0 else -1
		if k == int(L["count"]) - 1:
			sgn = -1
		elif k == 0:
			sgn = 1
		return {"lane": i, "t": ring_t, "sign": sgn, "dest": L["name_b"] if sgn > 0 else L["name_a"]}
	return {}


func use_nearest_lane() -> void:
	var r := nearest_ring()
	if not r.is_empty():
		start_trip(int(r["lane"]), float(r["t"]), int(r["sign"]))


# --- Trade lanes ---------------------------------------------------------------

func _check_lane_entry() -> void:
	if not player.controls_enabled:
		return
	var pabs := player_abs()
	for i in lanes.size():
		var L: Dictionary = lanes[i]
		var ldir: Vector3 = L["dir"]
		var rel: Vector3 = pabs - L["start"]
		var t: float = rel.dot(ldir)
		var perp := (rel - ldir * t).length()
		if perp > RING_RADIUS or t < -50.0 or t > float(L["length"]) + 50.0:
			_prev_lane_t.erase(i)
			continue
		if _prev_lane_t.has(i):
			var prev: float = _prev_lane_t[i]
			var sp: float = L["spacing"]
			# Did we pass through a ring since last frame?
			var k_lo := int(ceil(minf(prev, t) / sp))
			var k_hi := int(floor(maxf(prev, t) / sp))
			if k_lo <= k_hi and absf(t - prev) > 0.001:
				var sgn := 1 if t > prev else -1
				var k := k_lo if sgn > 0 else k_hi
				var at_end := (sgn > 0 and k >= int(L["count"]) - 1) or (sgn < 0 and k <= 0)
				if not at_end:
					_prev_lane_t.clear()
					start_trip(i, k * sp, sgn)
					return
		_prev_lane_t[i] = t


func start_trip(lane_index: int, t: float, sgn: int) -> void:
	var L: Dictionary = lanes[lane_index]
	if player.is_jammed():
		Run.message.emit("Lane entry jammed! Destroy the jammer first.", Color(1, 0.3, 0.35))
		return
	var target_t := float(L["length"]) if sgn > 0 else 0.0
	var stop_t := target_t
	var reason := "arrived"
	# A pirate jammer on this lane stops you short of it.
	if L["jam_t"] >= 0.0 and not (0 in sites[int(L["jam_site"])]["state"]["dead"]):
		var jt: float = L["jam_t"]
		if (sgn > 0 and jt > t) or (sgn < 0 and jt < t):
			stop_t = jt - sgn * JAM_STOP_DISTANCE
			reason = "jammed"
	# Random disruption ambush, more likely deeper in.
	var dest: Dictionary = map.node_at(L["b"] if sgn > 0 else L["a"])
	var chance := 0.1 + int(dest["depth"]) * 0.018
	if rng.randf() < chance:
		var ambush_t := t + sgn * absf(stop_t - t) * rng.randf_range(0.3, 0.7)
		if absf(ambush_t - t) > 3000.0:
			stop_t = ambush_t
			reason = "ambush"
	if sgn * (stop_t - t) <= 100.0:
		Run.message.emit("Lane blocked ahead by a jammer!", Color(1, 0.3, 0.35))
		return
	trip = {"lane": lane_index, "t": t, "sign": sgn, "stop_t": stop_t, "reason": reason,
		"speed": maxf(player.flight.speed(), 50.0)}
	player.on_rails = true
	player.controls_enabled = false
	player.flight.set_cruise(false)
	Run.message.emit("Trade lane to %s" % dest["name"], Color(0.95, 0.8, 0.4))
	Run.missions.on_event("lane")
	lane_started.emit(L)


func _update_trip(dt: float) -> void:
	var L: Dictionary = lanes[int(trip["lane"])]
	var sgn: int = trip["sign"]
	var t: float = trip["t"]
	var remaining := absf(float(trip["stop_t"]) - t)
	var want := minf(LANE_SPEED, sqrt(2.0 * LANE_ACCEL * remaining) + 40.0)
	var speed := move_toward(float(trip["speed"]), want, LANE_ACCEL * dt)
	t += sgn * speed * dt
	var done := sgn * (t - float(trip["stop_t"])) >= 0.0
	if done:
		t = trip["stop_t"]
	trip["t"] = t
	trip["speed"] = speed
	var dir: Vector3 = L["dir"] * sgn
	var pabs: Vector3 = L["start"] + L["dir"] * t
	player.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), to_local_pos(pabs))
	player.flight.velocity = dir * speed
	if done:
		_end_trip(String(trip["reason"]))
	elif is_jammed(player.position):
		_end_trip("interdicted")


func _end_trip(reason: String) -> void:
	var dir: Vector3 = lanes[int(trip["lane"])]["dir"] * int(trip["sign"])
	trip = {}
	player.on_rails = false
	player.controls_enabled = true
	player.flight.velocity = dir * 60.0
	player.flight.throttle = 0.6
	_prev_lane_t.clear()
	match reason:
		"ambush":
			Run.message.emit("TRADE LANE DISRUPTED! Pirate ambush!", Color(1, 0.3, 0.3))
			var lvl := level_here()
			spawn_pirates_near_player(3 + lvl / 7, "normal", 400.0, 700.0)
			if lvl >= 9 and rng.randf() < 0.4:
				spawn_pirates_near_player(1, "elite", 600.0, 800.0)
			# The ambushers bring a jammer so you can't just cruise off.
			var j := _spawn_enemy(player.position + player.forward() * 500.0 + Vector3(rng.randf_range(-300, 300), rng.randf_range(-100, 100), 0), "jammer", lvl)
			j.state = EnemyShip.State.ATTACK
		"jammed":
			Run.message.emit("Lane blocked! A pirate jammer has shut it down. Destroy it.", Color(1, 0.3, 0.35))
		"interdicted":
			Run.message.emit("Pulled out of the lane by a jamming field!", Color(1, 0.3, 0.35))
	lane_ended.emit(reason)


# --- Jamming & interdiction ----------------------------------------------------

func is_jammed(local_pos: Vector3) -> bool:
	for n in get_tree().get_nodes_in_group("jammers"):
		var e := n as EnemyShip
		if e and e.alive and e.position.distance_to(local_pos) < e.jam_radius:
			return true
	return false


func _check_jamming() -> void:
	if player.flight.cruise_active and is_jammed(player.position):
		player.flight.set_cruise(false)
		if _jam_msg_cd <= 0.0:
			_jam_msg_cd = 4.0
			Run.message.emit("Cruise disrupted by a jamming field!", Color(1, 0.3, 0.35))


## Long cruises through open space can get you pulled over by pirates.
func _interdiction(dt: float) -> void:
	if not player.flight.is_cruising():
		return
	var near := map.nearest_node(player_abs())
	if player_abs().distance_to(near["pos"]) < REGION_RADIUS:
		_interdict_timer = 0.0
		return
	_interdict_timer += dt
	if _interdict_timer < INTERDICT_EVERY:
		return
	_interdict_timer = 0.0
	if rng.randf() > 0.4:
		return
	var lvl := level_here()
	Run.message.emit("Interdictor ahead! Pirates are pulling you out of cruise!", Color(1, 0.3, 0.3))
	var ahead := player.position + player.forward() * 1500.0
	for i in 2 + lvl / 8:
		var e := _spawn_enemy(ahead + Vector3(rng.randf_range(-200, 200), rng.randf_range(-60, 60), rng.randf_range(-200, 200)), "normal", lvl, i == 0)
		e.state = EnemyShip.State.ATTACK
