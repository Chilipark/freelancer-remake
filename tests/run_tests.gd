extends SceneTree
## Headless tests:
##   godot --headless --path . --script res://tests/run_tests.gd

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + msg)


func _run() -> void:
	var meta := root.get_node_or_null("Meta")
	check(meta != null, "Meta autoload present")
	meta.save_path = "user://test_meta.cfg"
	meta.reset()
	InputSetup.ensure()
	_test_loot_rules()
	_test_loot_distribution()
	_test_flight()
	_test_ship_stats()
	_test_run_map()
	_test_damage()
	_test_assets()
	await _test_playthrough()
	print("TESTS %s (%d checks, %d failures)" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_meta.cfg"))
	quit(1 if failures > 0 else 0)


func _affix_def(name: String, prefix: bool) -> Dictionary:
	for a in (Affixes.PREFIXES if prefix else Affixes.SUFFIXES):
		if a["name"] == name:
			return a
	return {}


func _test_loot_rules() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 6000:
		var lvl := rng.randi_range(1, 30)
		var src := rng.randi_range(0, 4)
		var slot: String = "" if i % 3 else ItemBases.SLOTS[i % 5]
		var it := LootGenerator.generate(lvl, src, rng, float(rng.randi_range(0, 200)), slot)
		var b := it.base()
		check(not b.is_empty(), "item has a base")
		check(int(b["lvl"]) <= it.ilvl, "base %s level %d <= ilvl %d" % [b["id"], b["lvl"], it.ilvl])
		if slot != "":
			check(it.slot() == slot, "slot filter respected")
		if src == LootGenerator.Source.BOSS:
			check(it.ilvl == lvl + 4, "boss drops are ilvl + 4")
		if src == LootGenerator.Source.VENDOR or src == LootGenerator.Source.BOSS or src == LootGenerator.Source.ELITE:
			check(it.rarity != Item.Rarity.NORMAL, "onlygood sources never drop plain items")
		match it.rarity:
			Item.Rarity.NORMAL:
				check(it.affixes.is_empty(), "normal items have no affixes")
			Item.Rarity.MAGIC:
				var pre := it.affixes.filter(func(a): return a["prefix"]).size()
				var suf := it.affixes.size() - pre
				check(it.affixes.size() >= 1 and pre <= 1 and suf <= 1, "magic: 1 prefix + 1 suffix max")
				for a in it.affixes:
					var d := _affix_def(a["name"], a["prefix"])
					check(not d.is_empty(), "affix exists")
					check(it.slot() in d["slots"], "affix %s allowed on %s" % [a["name"], it.slot()])
					var minlvl := mini(it.ilvl / 2, 25)
					if src == LootGenerator.Source.VENDOR:
						minlvl = it.ilvl / 2
					# The window only widens (single affix) when nothing fit it.
					var in_window: bool = int(d["lvl"]) >= minlvl and int(d["lvl"]) <= it.ilvl
					check(in_window or (it.affixes.size() == 1 and int(d["lvl"]) <= it.ilvl), "magic affix level in [ilvl/2, ilvl]")
					check(float(a["value"]) >= float(d["range"][0]) and float(a["value"]) <= float(d["range"][1]), "affix value in range")
					if src != LootGenerator.Source.NORMAL and src != LootGenerator.Source.CACHE:
						check(d.get("ok", true), "onlygood sources skip cursed affixes")
				check(it.display_name() != b["name"], "magic name includes an affix")
			Item.Rarity.RARE:
				var pre2 := it.affixes.filter(func(a): return a["prefix"]).size()
				var suf2 := it.affixes.size() - pre2
				check(it.affixes.size() >= 2 and it.affixes.size() <= 6, "rare has 2-6 affixes")
				check(pre2 <= 3 and suf2 <= 3, "rare: at most 3 prefixes and 3 suffixes")
				var stats_seen := {}
				for a in it.affixes:
					check(not stats_seen.has(a["stat"]), "rare stats don't repeat")
					stats_seen[a["stat"]] = true
					check(_affix_def(a["name"], a["prefix"]).get("ok", true), "rares have no cursed affixes")
				check(it.rare_name.split(" ").size() == 2, "rare has a two-word name")
			Item.Rarity.UNIQUE:
				var u := Uniques.get_unique(it.unique_id)
				check(not u.is_empty(), "unique exists")
				check(int(u["lvl"]) <= it.ilvl, "unique level <= ilvl")
				check(it.base_id == u["base"], "unique uses its base")
		check(it.value() > 0, "item has a value")
		var round_trip := Item.from_dict(it.to_dict())
		check(round_trip.display_name() == it.display_name(), "item survives to_dict/from_dict")


func _rarity_counts(lvl: int, src: int, n: int, mf: float, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var counts := [0, 0, 0, 0]
	for i in n:
		counts[LootGenerator.generate(lvl, src, rng, mf).rarity] += 1
	return counts


func _test_loot_distribution() -> void:
	var n := 20000
	var low := _rarity_counts(1, LootGenerator.Source.NORMAL, n, 0.0, 1)
	var high := _rarity_counts(25, LootGenerator.Source.NORMAL, n, 0.0, 2)
	var mf := _rarity_counts(25, LootGenerator.Source.NORMAL, n, 200.0, 3)
	var boss := _rarity_counts(25, LootGenerator.Source.BOSS, n, 0.0, 4)
	print("Rarity [normal, magic, rare, unique] of %d drops:" % n)
	print("  level 1 pirate:  ", low)
	print("  level 25 pirate: ", high)
	print("  level 25 + 200%% loot find: ", mf)
	print("  level 25 boss:   ", boss)
	# Diablo magic chance at level 1 is about 1 - 0.90*0.99 ≈ 11%.
	var magic_low := float(n - low[0]) / n
	check(magic_low > 0.07 and magic_low < 0.16, "level 1 magic chance ≈ 11%% (got %.3f)" % magic_low)
	check(high[0] < low[0], "deeper sectors drop more magic items")
	check(mf[2] + mf[3] > high[2] + high[3], "loot find raises rare + unique count")
	check(boss[3] > high[3] * 5, "bosses drop far more uniques")
	check(boss[0] == 0, "bosses never drop plain items")


func _test_flight() -> void:
	var f := FlightModel.new()
	var xf := Transform3D.IDENTITY
	f.throttle = 1.0
	for i in 600:
		xf = f.step(xf, 1.0 / 60.0, Vector3.ZERO, Vector2.ZERO)
	check(absf(f.speed() - 80.0) < 1.0, "full throttle settles at top speed (got %.1f)" % f.speed())
	check(xf.origin.z < -500.0, "ship moves forward (-Z)")
	f.throttle = -1.0
	for i in 600:
		xf = f.step(xf, 1.0 / 60.0, Vector3.ZERO, Vector2.ZERO)
	check(absf(f.speed() - 32.0) < 1.0, "reverse is 40%% of top speed (got %.1f)" % f.speed())
	# Frame-rate independence.
	var a := FlightModel.new()
	var b := FlightModel.new()
	a.throttle = 1.0
	b.throttle = 1.0
	var xa := Transform3D.IDENTITY
	var xb := Transform3D.IDENTITY
	for i in 30:
		xa = a.step(xa, 1.0 / 30.0, Vector3.ZERO, Vector2.ZERO)
	for i in 144:
		xb = b.step(xb, 1.0 / 144.0, Vector3.ZERO, Vector2.ZERO)
	check(absf(a.speed() - b.speed()) < 0.5, "speed is the same at 30 and 144 fps")
	# Cruise.
	var c := FlightModel.new()
	var xc := Transform3D.IDENTITY
	c.set_cruise(true)
	for i in int(4.0 * 60):
		xc = c.step(xc, 1.0 / 60.0, Vector3.ZERO, Vector2.ZERO)
	check(not c.is_cruising() and c.speed() < 90.0, "still charging cruise after 4 s")
	for i in int(10.0 * 60):
		xc = c.step(xc, 1.0 / 60.0, Vector3.ZERO, Vector2.ZERO)
	check(c.is_cruising() and c.speed() > 280.0, "cruise reaches ~300 m/s (got %.1f)" % c.speed())
	# Turning: positive yaw turns left (forward rotates toward -X).
	var t := FlightModel.new()
	var xt := Transform3D.IDENTITY
	for i in 30:
		xt = t.step(xt, 1.0 / 60.0, Vector3(0, 1, 0), Vector2.ZERO)
	check((-xt.basis.z).x < -0.1, "yaw input turns the nose left")
	check(t.ang_vel.y > 0.0 and t.ang_vel.y <= t.turn_rate + 0.001, "turn rate is capped")


func _test_ship_stats() -> void:
	var hull := Hulls.get_hull("kestrel")
	var loadout := {
		"weapon0": LootGenerator.make_normal("laser1"),
		"weapon1": LootGenerator.make_normal("laser1"),
		"shield": LootGenerator.make_normal("shield1"),
		"armor": LootGenerator.make_normal("armor1"),
	}
	var s := ShipStats.compute(hull, loadout)
	check(is_equal_approx(s.max_hull, 260.0), "kestrel hull 220 + plating 40 (got %.1f)" % s.max_hull)
	check(is_equal_approx(s.max_shield, 60.0), "shield from generator")
	check(s.weapons.size() == 2, "two weapons")
	var hot := LootGenerator.make_normal("laser1")
	hot.rarity = Item.Rarity.MAGIC
	hot.affixes = [{"name": "Jagged", "stat": "damage_pct", "value": 100.0, "prefix": true},
		{"name": "of Vitality", "stat": "max_hull", "value": 20.0, "prefix": false}]
	loadout["weapon0"] = hot
	var s2 := ShipStats.compute(hull, loadout)
	check(is_equal_approx(float(s2.weapons[0]["min"]), 12.0), "+100% damage doubles that weapon")
	check(is_equal_approx(float(s2.weapons[1]["min"]), 6.0), "local damage doesn't affect the other gun")
	check(is_equal_approx(s2.max_hull, 280.0), "non-weapon stats on a weapon are global")
	var s3 := ShipStats.compute(hull, loadout, {"hull_pct": 10.0, "damage_pct": 50.0})
	check(is_equal_approx(s3.max_hull, 308.0), "hangar hull bonus applies")
	check(is_equal_approx(float(s3.weapons[1]["min"]), 9.0), "run damage buff applies to all guns")
	check(ShipStats.weapon_dps(s.weapons[0]) > 20.0, "light laser dps is sensible")


func _test_run_map() -> void:
	for seed_value in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var map := RunMap.new()
		map.generate(rng)
		var depths := {}
		for n in map.nodes:
			depths[n["depth"]] = true
			if int(n["depth"]) < RunMap.DEPTH - 1:
				check(not n["next"].is_empty(), "every sector has an exit gate")
				check(n["next"].size() <= 3, "at most 3 gates")
				for nid in n["next"]:
					check(int(map.node_at(nid)["depth"]) == int(n["depth"]) + 1, "gates lead one layer deeper")
		check(depths.size() == RunMap.DEPTH, "all layers present")
		check(map.nodes[0]["type"] == "start", "starts at departure")
		check(map.nodes[-1]["type"] == "boss", "ends at the boss")
		check(map.lanes.size() == map.nodes.reduce(func(acc, n): return acc + n["next"].size(), 0), "a lane for every link")
		for n in map.nodes:
			check(n.has("pos"), "sector has a position")
			for nid in n["next"]:
				check(n["pos"].distance_to(map.node_at(nid)["pos"]) > 15000.0, "linked sectors are far apart")
		# Reachability from the start.
		var seen := {0: true}
		var queue := [0]
		while not queue.is_empty():
			var cur: int = queue.pop_front()
			for nid in map.node_at(cur)["next"]:
				if not seen.has(nid):
					seen[nid] = true
					queue.append(nid)
		check(seen.size() == map.nodes.size(), "every sector reachable (seed %d)" % seed_value)
		for d in [6, RunMap.DEPTH - 2]:
			check(map.nodes.any(func(n): return n["depth"] == d and n["type"] == "station"), "station offered at depth %d" % d)


func _test_assets() -> void:
	for n in ["player_kestrel", "player_warden", "player_marauder", "pirate_fighter", "pirate_fighter2", "pirate_raider",
			"pirate_elite", "pirate_interdictor", "jammer", "boss_dreadnought", "freighter"]:
		var m := Assets.ship(n, 20.0, Color.WHITE)
		check(m != null, "ship model loads: " + n)
		if m:
			check(m.get_meta("hardpoints").size() >= 3, "model has hardpoints: " + n)
			check(not m.get_meta("engines").is_empty(), "model has engines: " + n)
			m.free()
	check(Assets.ship("does_not_exist", 10.0, Color.WHITE) == null, "missing model falls back")
	var fb := ShipMesh.build("fighter", Color.WHITE, Color.WHITE, "does_not_exist", 10.0)
	check(fb.get_child_count() > 0, "procedural fallback still builds")
	fb.free()
	for r in ["meteor-detailed", "rock-largea"]:
		check(not Assets.unit_mesh(r).is_empty(), "rock mesh loads: " + r)
	for snd in Sfx.SETS:
		for f in Sfx.SETS[snd]:
			check(Assets.sound(f) != null, "sound loads: " + f)


func _test_damage() -> void:
	var s := Ship.new()
	var st := ShipStats.new()
	st.max_hull = 100.0
	st.max_shield = 50.0
	st.damage_reduction = 0.0
	s.setup_ship(st, "fighter", Color.WHITE, Color.WHITE, 4.0)
	s.take_damage({"emp": 10.0, "thermal": 0.0, "kinetic": 0.0})
	check(is_equal_approx(s.shield, 30.0), "EMP does double damage to shields")
	s.take_damage({"kinetic": 50.0, "thermal": 0.0, "emp": 0.0})
	# 30 shield absorbs 30/(50*0.6)=all of it.
	check(is_equal_approx(s.shield, 0.0) and is_equal_approx(s.hull, 100.0), "kinetic hits shield at 60%")
	s.take_damage({"kinetic": 20.0, "thermal": 0.0, "emp": 0.0})
	check(is_equal_approx(s.hull, 75.0), "kinetic does 125%% to hull (got %.1f)" % s.hull)
	st.damage_reduction = 20.0
	s.take_damage({"thermal": 10.0, "kinetic": 0.0, "emp": 0.0})
	check(is_equal_approx(s.hull, 67.0), "damage reduction applies to hull")
	s.free()


## Plays the open world by script: fights, loot, floating origin, lanes,
## jammers, interdiction, death.
func _test_playthrough() -> void:
	var run := root.get_node("Run")
	run.start("kestrel", 1234)
	check(run.stats.weapons.size() == 2, "run starts with two guns")
	var world = load("res://scripts/core/game_world.gd").new()
	root.add_child(world)
	for i in 5:
		await process_frame
	var galaxy = world.galaxy
	var player = world.player
	check(galaxy != null, "galaxy built")
	check(galaxy.lanes.size() == run.map.lanes.size(), "one trade lane per map link")
	for L in galaxy.lanes:
		check(int(L["count"]) >= 2 and float(L["length"]) > 10000.0, "lanes are long with several rings")
	var enemies := get_nodes_in_group("ships").filter(func(n): return n is EnemyShip)
	check(enemies.size() >= 2, "start sector has pirates")

	for i in 90:
		await physics_frame
	check(player.alive, "player survives the opening seconds")

	# Destroy the start pirates, collect drops.
	var credits_before: int = run.credits
	for e in enemies:
		if is_instance_valid(e):
			e.take_damage({"thermal": 99999.0, "kinetic": 0.0, "emp": 0.0}, player)
	await process_frame
	check(run.kills == enemies.size(), "kills counted")
	check(galaxy.sites[0]["state"]["dead"].size() == enemies.size(), "sector remembers its dead pirates")
	var loot := get_nodes_in_group("loot")
	check(loot.size() >= enemies.size(), "pirates drop credits (and maybe items)")
	for l in loot:
		l.position = player.position + Vector3(0, 0, -30)
	galaxy.tractor_all()
	for i in 30:
		await process_frame
	check(run.credits > credits_before, "credits collected")

	var cargo_before: int = run.cargo.size()
	galaxy.spawn_item(player.position, LootGenerator.generate(5, LootGenerator.Source.BOSS, galaxy.rng))
	for i in 5:
		await process_frame
	check(run.cargo.size() == cargo_before + 1, "item picked up into cargo")
	var item: Item = run.cargo[-1]
	run.equip(item)
	check(item in run.loadout.values() and player.stats == run.stats, "equipped item applies to the ship")

	# Floating origin keeps the player near (0,0,0) without moving them in the world.
	var abs_before: Vector3 = galaxy.player_abs()
	player.position += Vector3(5000, 0, 0)
	await process_frame
	await process_frame
	check(player.position.length() < 3000.0, "world recentred on the player")
	check(galaxy.player_abs().distance_to(abs_before + Vector3(5000, 0, 0)) < 50.0, "absolute position preserved across shift")

	# Fly through the second ring of a lane out of the start sector and ride it.
	var li := -1
	for i in galaxy.lanes.size():
		if galaxy.lanes[i]["a"] == 0:
			li = i
			break
	var L: Dictionary = galaxy.lanes[li]
	var dir: Vector3 = L["dir"]
	var entry: Vector3 = L["start"] + dir * (float(L["spacing"]) - 80.0)
	player.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), galaxy.to_local_pos(entry))
	player.flight.velocity = dir * 80.0
	player.flight.throttle = 1.0
	for i in 200:
		await process_frame
		if not galaxy.trip.is_empty():
			break
	check(not galaxy.trip.is_empty(), "flying through a ring starts lane travel")
	if not galaxy.trip.is_empty():
		galaxy.trip["stop_t"] = L["length"]
		galaxy.trip["reason"] = "arrived"
		var max_speed := 0.0
		var t0 := Time.get_ticks_msec()
		while not galaxy.trip.is_empty() and Time.get_ticks_msec() - t0 < 60000:
			await process_frame
			max_speed = maxf(max_speed, player.flight.speed())
		check(galaxy.trip.is_empty(), "lane trip finishes")
		check(max_speed > 2000.0, "lanes reach ~2200 m/s (got %d)" % int(max_speed))
		check(galaxy.player_abs().distance_to(L["end"]) < 100.0, "arrived at the far end of the lane")
		check(player.controls_enabled and not player.on_rails, "control returned after the lane")
		await create_timer(0.6).timeout
		check(run.node_id == int(L["b"]), "entered the sector at the end of the lane")

	# Jammers block cruise; killing them frees it.
	var jammer = galaxy._spawn_enemy(player.position + Vector3(400, 0, 0), "jammer", 3)
	await process_frame
	check(player.is_jammed(), "jammer field detected")
	player.toggle_cruise()
	check(not player.flight.cruise_active, "can't cruise while jammed")
	jammer.take_damage({"thermal": 999999.0, "kinetic": 0.0, "emp": 0.0}, player)
	await process_frame
	check(not player.is_jammed(), "jamming ends when the jammer dies")
	player.toggle_cruise()
	check(player.flight.cruise_active, "cruise works again")
	player.flight.set_cruise(false)

	# A jammed lane stops you short of the jammer until it's destroyed.
	var jl := -1
	for i in galaxy.lanes.size():
		if float(galaxy.lanes[i]["jam_t"]) >= 0.0:
			jl = i
			break
	check(jl >= 0, "the map has at least one jammed lane")
	if jl >= 0:
		var J: Dictionary = galaxy.lanes[jl]
		var jdir: Vector3 = J["dir"]
		player.global_transform = Transform3D(Basis.looking_at(jdir, Vector3.UP), galaxy.to_local_pos(J["start"] + jdir * 10.0))
		await process_frame
		galaxy.trip = {}
		galaxy.start_trip(jl, 0.0, 1)
		check(not galaxy.trip.is_empty(), "jammed lane can still be entered")
		check(float(galaxy.trip["stop_t"]) <= float(J["jam_t"]) - galaxy.JAM_STOP_DISTANCE + 1.0, "trip stops before the jammer")
		galaxy._end_trip("test")
		var stop_abs: Vector3 = J["start"] + jdir * (float(J["jam_t"]) - galaxy.JAM_STOP_DISTANCE)
		player.global_transform = Transform3D(Basis.looking_at(jdir, Vector3.UP), galaxy.to_local_pos(stop_abs))
		await create_timer(0.6).timeout
		var site_id: int = J["jam_site"]
		var lane_jammer = null
		for n in get_nodes_in_group("ships"):
			if n is EnemyShip and n.get_meta("site", -1) == site_id and n.rank == "jammer":
				lane_jammer = n
		check(lane_jammer != null, "lane jammer site streamed in")
		if lane_jammer:
			lane_jammer.take_damage({"thermal": 999999.0, "kinetic": 0.0, "emp": 0.0}, player)
			await process_frame
			check(0 in galaxy.sites[site_id]["state"]["dead"], "jammer kill remembered")
			for n in get_nodes_in_group("jammers"):
				n.take_damage({"thermal": 999999.0, "kinetic": 0.0, "emp": 0.0}, player)
			await process_frame
			var here_t: float = (galaxy.player_abs() - J["start"]).dot(jdir)
			galaxy.start_trip(jl, here_t, 1)
			check(not galaxy.trip.is_empty() and galaxy.trip["reason"] != "jammed", "lane clear once the jammer is dead")
			galaxy._end_trip("test")

	# Open-space interdiction while cruising.
	for n in get_nodes_in_group("ships"):
		if n is EnemyShip:
			n.remove_from_group("ships")
			n.remove_from_group("jammers")
			n.queue_free()
	await process_frame
	var mid: Vector3 = (run.map.node_at(0)["pos"] + run.map.node_at(run.map.node_at(0)["next"][0])["pos"]) * 0.5 + Vector3(0, 4000, 0)
	player.global_transform = Transform3D(Basis.looking_at(Vector3(1, 0, 0), Vector3.UP), galaxy.to_local_pos(mid))
	player.flight.set_cruise(true)
	player.flight.cruise_elapsed = 99.0
	var got := false
	for i in 40:
		galaxy._interdiction(galaxy.INTERDICT_EVERY + 0.1)
		if get_nodes_in_group("jammers").size() > 0:
			got = true
			break
	check(got, "cruising through open space draws an interdictor")
	if got:
		var inter = get_nodes_in_group("jammers")[0]
		player.position = inter.position + Vector3(0, 0, 300)
		galaxy._check_jamming()
		check(not player.flight.cruise_active, "interdictor knocks you out of cruise")

	# Autopilot: plan a multi-lane route and fly the first legs for real.
	for n in get_nodes_in_group("ships"):
		if n is EnemyShip:
			n.remove_from_group("ships")
			n.remove_from_group("jammers")
			n.queue_free()
	await process_frame
	var ap = galaxy.autopilot
	player.flight.set_cruise(false)
	var home: Dictionary = run.map.node_at(0)
	player.global_transform = Transform3D(Basis.looking_at(Vector3(1, 0, 0), Vector3.UP), galaxy.to_local_pos(home["pos"]))
	player.flight.velocity = Vector3.ZERO
	await process_frame
	# Pick a sector two layers deep.
	var goal := -1
	for n in run.map.nodes:
		if int(n["depth"]) == 2:
			goal = int(n["id"])
			break
	var route: Array = ap.plan(goal)
	check(route.size() >= 3, "route to depth 2 uses at least two lanes (got %d legs)" % route.size())
	check(route[-1]["lane"] == -1 and route[-1]["pos"] == run.map.node_at(goal)["pos"], "route ends at the target sector")
	var prev_node := 0
	for l in route.slice(0, route.size() - 1):
		var LL: Dictionary = galaxy.lanes[int(l["lane"])]
		var from_node: int = LL["a"] if int(l["sign"]) > 0 else LL["b"]
		check(from_node == prev_node, "each lane starts where the previous one ended")
		prev_node = LL["b"] if int(l["sign"]) > 0 else LL["a"]
	check(prev_node == goal, "last lane arrives at the target sector")
	run.waypoint = goal
	check(ap.engage(goal), "autopilot engages")
	check(ap.status_text().begins_with("AUTOPILOT"), "HUD status text")
	var t1 := Time.get_ticks_msec()
	while galaxy.trip.is_empty() and ap.active and Time.get_ticks_msec() - t1 < 45000:
		await process_frame
	check(not galaxy.trip.is_empty(), "autopilot flies to the lane and enters it")
	check(ap.active, "autopilot still engaged on the lane")
	if not galaxy.trip.is_empty():
		var LL2: Dictionary = galaxy.lanes[int(galaxy.trip["lane"])]
		galaxy.trip["stop_t"] = LL2["length"] if int(galaxy.trip["sign"]) > 0 else 0.0
		galaxy.trip["reason"] = "arrived"
		galaxy.trip["speed"] = 2200.0
		var t2 := Time.get_ticks_msec()
		while not galaxy.trip.is_empty() and Time.get_ticks_msec() - t2 < 60000:
			await process_frame
		check(ap.active and ap.leg == 1, "after the lane, autopilot moves on to the next leg")
	# Touching the controls or taking fire hands control back.
	player.take_damage({"thermal": 1.0, "kinetic": 0.0, "emp": 0.0})
	check(not ap.active, "taking fire disengages autopilot")
	check(not ap.engage(-1), "no waypoint, no autopilot")
	# Final approach: put the ship just outside the target and let it arrive.
	ap.engage(goal)
	ap.leg = ap.legs.size() - 1
	var gpos: Vector3 = run.map.node_at(goal)["pos"]
	player.global_transform = Transform3D(Basis.looking_at(Vector3(1, 0, 0), Vector3.UP), galaxy.to_local_pos(gpos - Vector3(1600, 0, 0)))
	player.flight.velocity = Vector3(60, 0, 0)
	var t3 := Time.get_ticks_msec()
	while ap.active and Time.get_ticks_msec() - t3 < 30000:
		await process_frame
	check(not ap.active and galaxy.player_abs().distance_to(gpos) < 1200.0, "autopilot arrives and hands back control")

	# Die and finish the run.
	var salvage_before: int = root.get_node("Meta").salvage
	player.take_damage({"thermal": 999999.0, "kinetic": 0.0, "emp": 0.0})
	check(not player.alive, "player can die")
	await create_timer(2.3).timeout
	check(world.ended, "run ends after death")
	check(root.get_node("Meta").salvage > salvage_before, "salvage awarded")
	world.queue_free()
	await process_frame
