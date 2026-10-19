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


## Plays through sectors by script: kills pirates, picks up loot, uses a gate.
func _test_playthrough() -> void:
	var run := root.get_node("Run")
	run.start("kestrel", 1234)
	check(run.stats.weapons.size() == 2, "run starts with two guns")
	var world = load("res://scripts/core/game_world.gd").new()
	root.add_child(world)
	for i in 5:
		await process_frame
	var sector = world.sector
	check(sector != null, "sector built")
	var enemies := get_nodes_in_group("ships").filter(func(n): return n is EnemyShip)
	check(enemies.size() >= 2, "start sector has pirates")
	var gates := get_nodes_in_group("gates").filter(func(g): return not g.used)
	check(gates.size() == run.current_node()["next"].size(), "one gate per exit")

	# Let the AI fly and shoot for a bit.
	for i in 90:
		await physics_frame
	var player = world.player
	check(player.alive, "player survives the opening seconds")

	# Destroy every pirate and check drops.
	var credits_before: int = run.credits
	for e in enemies:
		if is_instance_valid(e):
			e.take_damage({"thermal": 99999.0, "kinetic": 0.0, "emp": 0.0}, player)
	await process_frame
	check(run.kills == enemies.size(), "kills counted")
	var loot := get_nodes_in_group("loot")
	check(loot.size() >= enemies.size(), "pirates drop credits (and maybe items)")
	# Tractor everything in and fly to it.
	for l in loot:
		l.global_position = player.global_position + Vector3(0, 0, -30)
	sector.tractor_all()
	for i in 30:
		await process_frame
	check(run.credits > credits_before, "credits collected")

	# Force a guaranteed item drop and pick it up.
	var cargo_before: int = run.cargo.size()
	sector.spawn_item(player.global_position, LootGenerator.generate(5, LootGenerator.Source.BOSS, sector.rng))
	for i in 5:
		await process_frame
	check(run.cargo.size() == cargo_before + 1, "item picked up into cargo")
	var item: Item = run.cargo[-1]
	run.equip(item)
	check(not (item in run.cargo), "equipped item left cargo")
	check(item in run.loadout.values(), "item is in the loadout")
	check(player.stats == run.stats, "player ship uses the new stats")

	# Fly through the first gate.
	var start_id: int = run.node_id
	var gate: JumpGate = gates[0]
	var target_id := gate.target_id
	var gx := gate.global_transform
	player.global_position = gx * Vector3(0, 0, 60)
	await process_frame
	player.global_position = gx * Vector3(0, 0, -20)
	await process_frame
	for i in 120:
		await process_frame
	check(run.node_id == target_id and run.node_id != start_id, "jumped through the gate to the next sector")
	check(world.sector != sector, "a new sector was built")
	check(run.visited.size() == 2, "visit recorded")

	# Die and finish the run.
	var salvage_before: int = root.get_node("Meta").salvage
	player.take_damage({"thermal": 999999.0, "kinetic": 0.0, "emp": 0.0})
	check(not player.alive, "player can die")
	for i in 150:
		await process_frame
	await create_timer(2.2).timeout
	check(world.ended, "run ends after death")
	check(root.get_node("Meta").salvage > salvage_before, "salvage awarded")
	world.queue_free()
	await process_frame
