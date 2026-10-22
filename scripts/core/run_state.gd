extends Node
## The current run (autoload "Run"): ship, loadout, cargo, credits, map.

signal loadout_changed
signal credits_changed
signal message(text: String, color: Color)

const CARGO_SIZE := 24

var active := false
var rng := RandomNumberGenerator.new()
var hull_def: Dictionary = {}
var loadout: Dictionary = {}
var cargo: Array = []
var credits := 0
var hull := 0.0                  # current hull, carried between sectors
var map := RunMap.new()
var node_id := 0
var visited: Array = []
var waypoint := -1               # map node the player marked on the nav map
var kills := 0
var elites_killed := 0
var bosses_killed := 0
var won := false
var stats: ShipStats
## Run-long bonuses from events: stat -> value.
var buffs: Dictionary = {}
var missions := Missions.new()


func start(hull_id: String, seed_value: int = -1) -> void:
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var bonus: Dictionary = Meta.bonuses()
	hull_def = Hulls.get_hull(hull_id)
	loadout.clear()
	cargo.clear()
	var weapon_index := 0
	for base_id in hull_def["start"]:
		var it := LootGenerator.make_normal(base_id)
		if it.is_weapon():
			loadout["weapon%d" % weapon_index] = it
			weapon_index += 1
		else:
			loadout[it.slot()] = it
	for i in int(bonus["start_items"]):
		var cache_item := LootGenerator.generate(3, LootGenerator.Source.VENDOR, rng)
		cargo.append(cache_item)
	credits = 100 + int(bonus["start_credits"])
	map = RunMap.new()
	map.generate(rng)
	node_id = map.start_id()
	visited = [node_id]
	waypoint = -1
	missions = Missions.new()
	missions.setup(map, rng.randi())
	kills = 0
	elites_killed = 0
	bosses_killed = 0
	won = false
	buffs = {}
	active = true
	recompute()
	hull = stats.max_hull


func current_node() -> Dictionary:
	return map.node_at(node_id)


## The deepest sector reached this run.
func depth() -> int:
	var d := 0
	for id in visited:
		d = maxi(d, int(map.node_at(id)["depth"]))
	return d


## Called when the player flies into a sector.
func travel_to(id: int) -> void:
	node_id = id
	if not (id in visited):
		visited.append(id)
	if waypoint == id:
		waypoint = -1


func recompute() -> void:
	var old_max := stats.max_hull if stats else 0.0
	stats = ShipStats.compute(hull_def, loadout, stat_bonuses())
	# Keep the same hull fraction when max hull changes.
	if old_max > 0.0:
		hull = clampf(hull * stats.max_hull / old_max, 1.0, stats.max_hull)
	loadout_changed.emit()


## Hangar upgrades plus event buffs, in the form ShipStats.compute expects.
func stat_bonuses() -> Dictionary:
	var b: Dictionary = Meta.bonuses().duplicate()
	b["hull_pct"] = float(b["hull_pct"]) + float(buffs.get("max_hull_pct", 0.0))
	b["loot_find"] = float(b["loot_find"]) + float(buffs.get("loot_find", 0.0))
	b["damage_pct"] = float(buffs.get("all_damage_pct", 0.0))
	return b


func add_buff(stat: String, value: float) -> void:
	buffs[stat] = float(buffs.get(stat, 0.0)) + value
	recompute()


func add_credits(amount: int) -> void:
	credits += amount
	credits_changed.emit()


func add_to_cargo(item: Item) -> bool:
	if cargo.size() >= CARGO_SIZE:
		message.emit("Cargo hold full!", Color(1, 0.4, 0.4))
		return false
	cargo.append(item)
	message.emit("Picked up " + item.display_name(), item.color())
	return true


## Slot keys an item can go into.
func slots_for(item: Item) -> Array:
	if item.is_weapon():
		var keys: Array = []
		for i in int(hull_def["hardpoints"]):
			keys.append("weapon%d" % i)
		return keys
	return [item.slot()]


## Equips a cargo item, swapping whatever was there back into cargo.
## For weapons it picks the first empty hardpoint, else `prefer_key` or the first.
func equip(item: Item, prefer_key: String = "") -> void:
	var keys := slots_for(item)
	var key: String = keys[0]
	if prefer_key in keys:
		key = prefer_key
	else:
		for k in keys:
			if loadout.get(k) == null:
				key = k
				break
	var old: Item = loadout.get(key)
	cargo.erase(item)
	loadout[key] = item
	if old != null:
		cargo.append(old)
	recompute()


func unequip(key: String) -> void:
	var old: Item = loadout.get(key)
	if old == null or cargo.size() >= CARGO_SIZE:
		return
	loadout[key] = null
	cargo.append(old)
	recompute()


func sell(item: Item) -> void:
	if cargo.has(item):
		cargo.erase(item)
		add_credits(item.value())
		loadout_changed.emit()


## Salvage earned so far if the run ended now.
func salvage_earned() -> int:
	var base := depth() * 12 + kills * 2 + elites_killed * 10 + bosses_killed * 80
	if won:
		base += 150
	return int(base * (1.0 + float(Meta.bonuses()["salvage_pct"]) / 100.0))


func finish(did_win: bool) -> int:
	won = did_win
	var earned := salvage_earned()
	Meta.record_run(depth(), earned, did_win)
	active = false
	return earned
