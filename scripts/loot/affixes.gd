class_name Affixes
extends RefCounted
## Prefix and suffix tables, modelled on Diablo's PLStruct tables
## (DevilutionX Source/tables/itemdat.cpp): each affix has a minimum level,
## a drop weight ("chance"), the item types it can roll on, a stat with a
## value range, and an "ok" flag (false = cursed/negative affix).

const W := ["weapon"]
const DEF := ["shield", "armor", "core"]
const ANY := ["weapon", "shield", "engine", "armor", "core"]

const PREFIXES := [
	# Weapon damage ladder (Jagged/Deadly/Heavy/Vicious in Diablo).
	{"name": "Jagged", "lvl": 1, "weight": 3, "slots": W, "stat": "damage_pct", "range": [20, 35]},
	{"name": "Deadly", "lvl": 5, "weight": 3, "slots": W, "stat": "damage_pct", "range": [36, 50]},
	{"name": "Brutal", "lvl": 10, "weight": 3, "slots": W, "stat": "damage_pct", "range": [51, 65]},
	{"name": "Savage", "lvl": 15, "weight": 2, "slots": W, "stat": "damage_pct", "range": [66, 80]},
	{"name": "Merciless", "lvl": 20, "weight": 2, "slots": W, "stat": "damage_pct", "range": [81, 100]},
	{"name": "Ruthless", "lvl": 25, "weight": 1, "slots": W, "stat": "damage_pct", "range": [101, 130]},
	{"name": "Cracked", "lvl": 1, "weight": 2, "slots": W, "stat": "damage_pct", "range": [-35, -10], "ok": false},
	# Elemental adds.
	{"name": "Searing", "lvl": 3, "weight": 2, "slots": W, "stat": "thermal", "range": [2, 6]},
	{"name": "Burning", "lvl": 10, "weight": 2, "slots": W, "stat": "thermal", "range": [7, 14]},
	{"name": "Incinerating", "lvl": 18, "weight": 1, "slots": W, "stat": "thermal", "range": [15, 28]},
	{"name": "Charged", "lvl": 3, "weight": 2, "slots": W, "stat": "emp", "range": [2, 6]},
	{"name": "Arcing", "lvl": 10, "weight": 2, "slots": W, "stat": "emp", "range": [7, 14]},
	{"name": "Storming", "lvl": 18, "weight": 1, "slots": W, "stat": "emp", "range": [15, 28]},
	{"name": "Piercing", "lvl": 5, "weight": 2, "slots": W, "stat": "kinetic", "range": [3, 8]},
	{"name": "Rending", "lvl": 14, "weight": 1, "slots": W, "stat": "kinetic", "range": [9, 20]},
	{"name": "Precise", "lvl": 4, "weight": 2, "slots": W, "stat": "crit_chance", "range": [3, 8]},
	{"name": "Lethal", "lvl": 16, "weight": 1, "slots": W, "stat": "crit_chance", "range": [9, 15]},
	# Shields / defense.
	{"name": "Sturdy", "lvl": 1, "weight": 3, "slots": DEF, "stat": "max_shield", "range": [10, 25]},
	{"name": "Bulwark", "lvl": 9, "weight": 3, "slots": DEF, "stat": "max_shield", "range": [26, 50]},
	{"name": "Aegis", "lvl": 17, "weight": 2, "slots": DEF, "stat": "max_shield", "range": [51, 90]},
	{"name": "Reinforced", "lvl": 1, "weight": 3, "slots": ["armor", "shield"], "stat": "max_hull_pct", "range": [5, 12]},
	{"name": "Fortified", "lvl": 12, "weight": 2, "slots": ["armor", "shield"], "stat": "max_hull_pct", "range": [13, 25]},
	{"name": "Brittle", "lvl": 1, "weight": 1, "slots": ["armor"], "stat": "max_hull_pct", "range": [-20, -5], "ok": false},
	# Power.
	{"name": "Capacitive", "lvl": 2, "weight": 2, "slots": ["core", "shield"], "stat": "max_power", "range": [10, 30]},
	{"name": "Overcharged", "lvl": 8, "weight": 2, "slots": ["core"], "stat": "power_regen_pct", "range": [15, 40]},
	# Engines.
	{"name": "Swift", "lvl": 1, "weight": 3, "slots": ["engine"], "stat": "thrust_pct", "range": [5, 12]},
	{"name": "Racing", "lvl": 10, "weight": 2, "slots": ["engine"], "stat": "thrust_pct", "range": [13, 22]},
	{"name": "Nimble", "lvl": 4, "weight": 2, "slots": ["engine"], "stat": "turn_pct", "range": [8, 20]},
	# Anywhere.
	{"name": "Scavenger's", "lvl": 5, "weight": 2, "slots": ANY, "stat": "loot_find", "range": [10, 25]},
	{"name": "Gilded", "lvl": 3, "weight": 2, "slots": ANY, "stat": "credit_find", "range": [15, 40]},
]

const SUFFIXES := [
	{"name": "of Haste", "lvl": 1, "weight": 3, "slots": W, "stat": "fire_rate_pct", "range": [5, 10]},
	{"name": "of Speed", "lvl": 10, "weight": 2, "slots": W, "stat": "fire_rate_pct", "range": [11, 20]},
	{"name": "of Fury", "lvl": 20, "weight": 1, "slots": W, "stat": "fire_rate_pct", "range": [21, 30]},
	{"name": "of Velocity", "lvl": 2, "weight": 2, "slots": W, "stat": "proj_speed_pct", "range": [10, 30]},
	{"name": "of Ruin", "lvl": 12, "weight": 2, "slots": W, "stat": "crit_mult", "range": [25, 60]},
	{"name": "of the Leech", "lvl": 6, "weight": 2, "slots": ["weapon", "core"], "stat": "leech", "range": [2, 4]},
	{"name": "of the Vampire", "lvl": 18, "weight": 1, "slots": ["weapon", "core"], "stat": "leech", "range": [5, 8]},
	{"name": "of Vitality", "lvl": 1, "weight": 3, "slots": ANY, "stat": "max_hull", "range": [10, 25]},
	{"name": "of Vigor", "lvl": 9, "weight": 3, "slots": ANY, "stat": "max_hull", "range": [26, 50]},
	{"name": "of Life", "lvl": 17, "weight": 2, "slots": ANY, "stat": "max_hull", "range": [51, 90]},
	{"name": "of Mending", "lvl": 4, "weight": 2, "slots": ["armor", "core", "shield"], "stat": "hull_regen", "range": [0.5, 1.5]},
	{"name": "of Regeneration", "lvl": 14, "weight": 1, "slots": ["armor", "core", "shield"], "stat": "hull_regen", "range": [1.6, 3.5]},
	{"name": "of Recharging", "lvl": 3, "weight": 2, "slots": ["shield", "core"], "stat": "shield_regen_pct", "range": [15, 35]},
	{"name": "of Renewal", "lvl": 13, "weight": 2, "slots": ["shield", "core"], "stat": "shield_regen_pct", "range": [36, 70]},
	{"name": "of Readiness", "lvl": 7, "weight": 2, "slots": ["shield"], "stat": "shield_delay_pct", "range": [-35, -15]},
	{"name": "of Warding", "lvl": 6, "weight": 2, "slots": ["armor", "shield"], "stat": "damage_reduction", "range": [2, 5]},
	{"name": "of the Titan", "lvl": 18, "weight": 1, "slots": ["armor", "shield"], "stat": "damage_reduction", "range": [6, 10]},
	{"name": "of Agility", "lvl": 1, "weight": 2, "slots": ["engine", "core"], "stat": "turn_pct", "range": [5, 15]},
	{"name": "of the Comet", "lvl": 5, "weight": 2, "slots": ["engine"], "stat": "cruise_charge_pct", "range": [-40, -15]},
	{"name": "of Energy", "lvl": 2, "weight": 2, "slots": ["core", "engine"], "stat": "power_regen_pct", "range": [10, 25]},
	{"name": "of Greed", "lvl": 3, "weight": 2, "slots": ANY, "stat": "credit_find", "range": [20, 50]},
	{"name": "of Fortune", "lvl": 10, "weight": 1, "slots": ANY, "stat": "loot_find", "range": [15, 35]},
	{"name": "of Rust", "lvl": 1, "weight": 1, "slots": ["armor", "engine"], "stat": "thrust_pct", "range": [-15, -5], "ok": false},
	{"name": "of Fragility", "lvl": 1, "weight": 1, "slots": ANY, "stat": "max_hull", "range": [-25, -10], "ok": false},
]


## Diablo's SelectAffix: affixes whose level lies in [minlvl, maxlvl] and
## that fit the slot are put in a pool once per point of weight, then one is
## drawn. `exclude` keeps rares from repeating the same stat.
static func select(table: Array, slot: String, minlvl: int, maxlvl: int, onlygood: bool,
		rng: RandomNumberGenerator, exclude: Array = []) -> Dictionary:
	var pool: Array = []
	for a in table:
		if not (slot in a["slots"]):
			continue
		var lvl: int = a["lvl"]
		if lvl < minlvl or lvl > maxlvl:
			continue
		if onlygood and not a.get("ok", true):
			continue
		if a["stat"] in exclude:
			continue
		for i in int(a["weight"]):
			pool.append(a)
	if pool.is_empty():
		return {}
	return pool[rng.randi_range(0, pool.size() - 1)]


static func roll_value(affix: Dictionary, rng: RandomNumberGenerator) -> float:
	var lo: float = affix["range"][0]
	var hi: float = affix["range"][1]
	if is_equal_approx(lo, roundf(lo)) and is_equal_approx(hi, roundf(hi)):
		return float(rng.randi_range(int(lo), int(hi)))
	return snappedf(rng.randf_range(lo, hi), 0.1)
