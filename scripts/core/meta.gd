extends Node
## Progress kept between runs (autoload "Meta"): salvage currency, Hangar
## upgrades and unlocked ships. Saved to user://meta.cfg.

const SAVE_PATH := "user://meta.cfg"

const UPGRADES := [
	{"id": "hull", "name": "Hull Plating", "desc": "+8% hull per level", "max": 5, "cost": 60},
	{"id": "shield", "name": "Shield Tuning", "desc": "+8% shield capacity per level", "max": 5, "cost": 60},
	{"id": "luck", "name": "Lucky Charm", "desc": "+10% loot find per level", "max": 5, "cost": 80},
	{"id": "credits", "name": "Trade Contacts", "desc": "+150 starting credits per level", "max": 3, "cost": 50},
	{"id": "salvage", "name": "Salvage Rights", "desc": "+15% salvage earned per level", "max": 3, "cost": 90},
	{"id": "cache", "name": "Starting Cache", "desc": "Start with a magic item per level", "max": 2, "cost": 150},
]

var salvage := 0
var levels: Dictionary = {}
var unlocked_hulls: Array = ["kestrel"]
var best_depth := 0
var runs := 0
var wins := 0
var save_path := SAVE_PATH


func _ready() -> void:
	load_meta()


func level(id: String) -> int:
	return int(levels.get(id, 0))


func upgrade_cost(id: String) -> int:
	for u in UPGRADES:
		if u["id"] == id:
			return int(u["cost"]) * (level(id) + 1)
	return 0


func can_upgrade(id: String) -> bool:
	for u in UPGRADES:
		if u["id"] == id:
			return level(id) < int(u["max"]) and salvage >= upgrade_cost(id)
	return false


func buy_upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	salvage -= upgrade_cost(id)
	levels[id] = level(id) + 1
	save_meta()
	return true


func unlock_hull(id: String) -> bool:
	var h := Hulls.get_hull(id)
	if id in unlocked_hulls or salvage < int(h["cost"]):
		return false
	salvage -= int(h["cost"])
	unlocked_hulls.append(id)
	save_meta()
	return true


## Bonuses handed to ShipStats.compute and the run setup.
func bonuses() -> Dictionary:
	return {
		"hull_pct": level("hull") * 8.0,
		"shield_pct": level("shield") * 8.0,
		"loot_find": level("luck") * 10.0,
		"start_credits": level("credits") * 150,
		"salvage_pct": level("salvage") * 15.0,
		"start_items": level("cache"),
	}


func record_run(depth: int, earned: int, won: bool) -> void:
	runs += 1
	if won:
		wins += 1
	best_depth = maxi(best_depth, depth)
	salvage += earned
	save_meta()


func save_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "salvage", salvage)
	cfg.set_value("meta", "levels", levels)
	cfg.set_value("meta", "unlocked_hulls", unlocked_hulls)
	cfg.set_value("meta", "best_depth", best_depth)
	cfg.set_value("meta", "runs", runs)
	cfg.set_value("meta", "wins", wins)
	cfg.save(save_path)


func load_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	salvage = cfg.get_value("meta", "salvage", 0)
	levels = cfg.get_value("meta", "levels", {})
	unlocked_hulls = cfg.get_value("meta", "unlocked_hulls", ["kestrel"])
	best_depth = cfg.get_value("meta", "best_depth", 0)
	runs = cfg.get_value("meta", "runs", 0)
	wins = cfg.get_value("meta", "wins", 0)


func reset() -> void:
	salvage = 0
	levels = {}
	unlocked_hulls = ["kestrel"]
	best_depth = 0
	runs = 0
	wins = 0
