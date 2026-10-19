class_name Uniques
extends RefCounted
## Fixed-name unique items (gold), like Diablo's UniqueItems table: a base
## item, a minimum level and a fixed list of stats.

const LIST := [
	{"id": "gravedigger", "name": "Gravedigger", "base": "scatter1", "lvl": 4,
		"stats": {"damage_pct": 45.0, "leech": 6.0, "max_hull": 20.0}},
	{"id": "wanderers_heart", "name": "Wanderer's Heart", "base": "engine1", "lvl": 3,
		"stats": {"thrust_pct": 25.0, "cruise_charge_pct": -40.0, "loot_find": 20.0}},
	{"id": "iron_coffin", "name": "The Iron Coffin", "base": "armor1", "lvl": 5,
		"stats": {"max_hull": 150.0, "damage_reduction": 10.0, "thrust_pct": -15.0}},
	{"id": "ghostwall", "name": "Ghostwall", "base": "shield1", "lvl": 7,
		"stats": {"max_shield": 70.0, "shield_regen_pct": 50.0, "shield_delay_pct": -40.0}},
	{"id": "hornets_nest", "name": "The Hornet's Nest", "base": "missile1", "lvl": 9,
		"stats": {"fire_rate_pct": 60.0, "damage_pct": 30.0, "thermal": 10.0}},
	{"id": "widowmaker", "name": "Widowmaker", "base": "mass1", "lvl": 11,
		"stats": {"crit_chance": 25.0, "crit_mult": 100.0, "proj_speed_pct": 40.0}},
	{"id": "midas_drive", "name": "Midas Drive", "base": "engine2", "lvl": 12,
		"stats": {"credit_find": 80.0, "loot_find": 40.0, "thrust_pct": 10.0}},
	{"id": "tempest", "name": "Eye of the Tempest", "base": "pulse2", "lvl": 14,
		"stats": {"emp": 30.0, "fire_rate_pct": 25.0, "max_shield": 40.0}},
	{"id": "starforge", "name": "Starforge Heart", "base": "core2", "lvl": 15,
		"stats": {"power_regen_pct": 100.0, "max_power": 60.0, "all_damage_pct": 15.0}},
	{"id": "solaris", "name": "Solaris Lance", "base": "laser3", "lvl": 20,
		"stats": {"damage_pct": 90.0, "thermal": 25.0, "fire_rate_pct": 15.0, "leech": 4.0}},
	{"id": "colossus", "name": "Colossus Bulwark", "base": "armor3", "lvl": 21,
		"stats": {"max_hull_pct": 40.0, "damage_reduction": 12.0, "hull_regen": 4.0}},
]

## Diablo 2 builds rare names from two random word lists.
const RARE_FIRST := [
	"Doom", "Storm", "Grim", "Void", "Dread", "Star", "Blood", "Ghost", "Iron",
	"Solar", "Night", "Ash", "Plague", "Rune", "Venom", "Wraith", "Nova", "Havoc",
]
const RARE_SECOND := [
	"Fang", "Spire", "Ward", "Song", "Reaver", "Wing", "Shroud", "Edge", "Coil",
	"Heart", "Bane", "Lash", "Mantle", "Talon", "Brand", "Veil", "Thorn", "Howl",
]


static func get_unique(id: String) -> Dictionary:
	for u in LIST:
		if u["id"] == id:
			return u
	return {}


static func candidates(ilvl: int) -> Array:
	var out: Array = []
	for u in LIST:
		if int(u["lvl"]) <= ilvl:
			out.append(u)
	return out
