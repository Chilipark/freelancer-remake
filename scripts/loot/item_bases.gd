class_name ItemBases
extends RefCounted
## Base item types, like Diablo's base items (Short Sword, Long Sword, ...).
## `lvl` is the lowest item level that can drop it. Higher tiers of the same
## family replace lower ones as the run goes deeper.

const SLOTS := ["weapon", "shield", "engine", "armor", "core"]
const SLOT_NAMES := {
	"weapon": "Weapon", "shield": "Shield Generator", "engine": "Engine",
	"armor": "Armor Plating", "core": "Power Core",
}

const BASES := [
	# --- Lasers: thermal, all-rounder ---
	{"id": "laser1", "name": "Light Laser", "slot": "weapon", "lvl": 1, "weight": 10, "value": 40,
		"weapon": {"type": "thermal", "dmg": [6, 9], "rate": 4.0, "speed": 600.0, "range": 700.0, "energy": 3.0, "color": Color(1.0, 0.35, 0.2)}},
	{"id": "laser2", "name": "Laser Cannon", "slot": "weapon", "lvl": 9, "weight": 10, "value": 150,
		"weapon": {"type": "thermal", "dmg": [13, 19], "rate": 4.0, "speed": 650.0, "range": 750.0, "energy": 4.0, "color": Color(1.0, 0.35, 0.2)}},
	{"id": "laser3", "name": "Lance Laser", "slot": "weapon", "lvl": 18, "weight": 8, "value": 450,
		"weapon": {"type": "thermal", "dmg": [24, 34], "rate": 4.0, "speed": 700.0, "range": 800.0, "energy": 5.0, "color": Color(1.0, 0.45, 0.25)}},
	# --- Pulse: EMP, shreds shields ---
	{"id": "pulse1", "name": "Ion Pulser", "slot": "weapon", "lvl": 2, "weight": 8, "value": 50,
		"weapon": {"type": "emp", "dmg": [5, 8], "rate": 5.0, "speed": 500.0, "range": 600.0, "energy": 3.0, "color": Color(0.4, 0.7, 1.0)}},
	{"id": "pulse2", "name": "Pulse Cannon", "slot": "weapon", "lvl": 11, "weight": 8, "value": 180,
		"weapon": {"type": "emp", "dmg": [11, 16], "rate": 5.0, "speed": 520.0, "range": 650.0, "energy": 4.0, "color": Color(0.4, 0.7, 1.0)}},
	{"id": "pulse3", "name": "Tempest Array", "slot": "weapon", "lvl": 20, "weight": 6, "value": 500,
		"weapon": {"type": "emp", "dmg": [19, 27], "rate": 5.0, "speed": 560.0, "range": 700.0, "energy": 5.0, "color": Color(0.5, 0.8, 1.0)}},
	# --- Mass drivers: kinetic, slow and hard-hitting ---
	{"id": "mass1", "name": "Mass Driver", "slot": "weapon", "lvl": 4, "weight": 7, "value": 70,
		"weapon": {"type": "kinetic", "dmg": [18, 28], "rate": 1.4, "speed": 900.0, "range": 900.0, "energy": 6.0, "color": Color(0.9, 0.9, 0.6)}},
	{"id": "mass2", "name": "Railgun", "slot": "weapon", "lvl": 14, "weight": 6, "value": 260,
		"weapon": {"type": "kinetic", "dmg": [40, 60], "rate": 1.3, "speed": 1100.0, "range": 1000.0, "energy": 8.0, "color": Color(0.9, 0.95, 0.7)}},
	# --- Scatter guns: kinetic pellets, close range ---
	{"id": "scatter1", "name": "Flak Scattergun", "slot": "weapon", "lvl": 3, "weight": 6, "value": 60,
		"weapon": {"type": "kinetic", "dmg": [3, 5], "rate": 1.8, "speed": 450.0, "range": 350.0, "energy": 5.0, "pellets": 6, "spread": 5.0, "color": Color(1.0, 0.8, 0.4)}},
	{"id": "scatter2", "name": "Shredder", "slot": "weapon", "lvl": 15, "weight": 5, "value": 280,
		"weapon": {"type": "kinetic", "dmg": [8, 12], "rate": 1.8, "speed": 480.0, "range": 400.0, "energy": 7.0, "pellets": 7, "spread": 5.0, "color": Color(1.0, 0.8, 0.4)}},
	# --- Missile pods: slow homing thermal ---
	{"id": "missile1", "name": "Hornet Pod", "slot": "weapon", "lvl": 6, "weight": 5, "value": 110,
		"weapon": {"type": "thermal", "dmg": [30, 45], "rate": 0.8, "speed": 220.0, "range": 1100.0, "energy": 10.0, "homing": 2.5, "color": Color(1.0, 0.6, 0.1)}},
	{"id": "missile2", "name": "Starburst Launcher", "slot": "weapon", "lvl": 17, "weight": 4, "value": 400,
		"weapon": {"type": "thermal", "dmg": [65, 90], "rate": 0.8, "speed": 250.0, "range": 1200.0, "energy": 12.0, "homing": 3.0, "color": Color(1.0, 0.6, 0.1)}},

	# --- Shields ---
	{"id": "shield1", "name": "Deflector Field", "slot": "shield", "lvl": 1, "weight": 10, "value": 40,
		"stats": {"max_shield": 60.0, "shield_regen_pct": 0.0}},
	{"id": "shield2", "name": "Barrier Projector", "slot": "shield", "lvl": 8, "weight": 10, "value": 150,
		"stats": {"max_shield": 130.0}},
	{"id": "shield3", "name": "Graviton Aegis", "slot": "shield", "lvl": 17, "weight": 8, "value": 420,
		"stats": {"max_shield": 240.0}},

	# --- Engines ---
	{"id": "engine1", "name": "Ion Drive", "slot": "engine", "lvl": 1, "weight": 10, "value": 40,
		"stats": {"thrust_pct": 0.0}},
	{"id": "engine2", "name": "Fusion Drive", "slot": "engine", "lvl": 8, "weight": 9, "value": 140,
		"stats": {"thrust_pct": 10.0, "turn_pct": 5.0}},
	{"id": "engine3", "name": "Antimatter Drive", "slot": "engine", "lvl": 17, "weight": 7, "value": 400,
		"stats": {"thrust_pct": 20.0, "turn_pct": 10.0, "cruise_charge_pct": -15.0}},

	# --- Armor ---
	{"id": "armor1", "name": "Alloy Plating", "slot": "armor", "lvl": 1, "weight": 10, "value": 40,
		"stats": {"max_hull": 40.0}},
	{"id": "armor2", "name": "Composite Plating", "slot": "armor", "lvl": 8, "weight": 10, "value": 150,
		"stats": {"max_hull": 100.0, "damage_reduction": 3.0}},
	{"id": "armor3", "name": "Neutronium Plating", "slot": "armor", "lvl": 17, "weight": 8, "value": 420,
		"stats": {"max_hull": 190.0, "damage_reduction": 6.0}},

	# --- Power cores ---
	{"id": "core1", "name": "Fission Core", "slot": "core", "lvl": 1, "weight": 10, "value": 40,
		"stats": {"max_power": 0.0}},
	{"id": "core2", "name": "Fusion Core", "slot": "core", "lvl": 8, "weight": 9, "value": 140,
		"stats": {"max_power": 40.0, "power_regen_pct": 15.0}},
	{"id": "core3", "name": "Zero-Point Core", "slot": "core", "lvl": 17, "weight": 7, "value": 400,
		"stats": {"max_power": 90.0, "power_regen_pct": 35.0}},
]


static func get_base(id: String) -> Dictionary:
	for b in BASES:
		if b["id"] == id:
			return b
	push_error("Unknown item base: " + id)
	return {}


## Picks a random base that can drop at `ilvl`, weighted. Favours the
## highest tiers available, like Diablo's level-gated base item pool.
static func random_base(ilvl: int, rng: RandomNumberGenerator, slot: String = "") -> Dictionary:
	var pool: Array = []
	var total := 0
	for b in BASES:
		if b["lvl"] > ilvl:
			continue
		if slot != "" and b["slot"] != slot:
			continue
		# Bases far below the item level become rarer (but never vanish).
		var gap: int = ilvl - int(b["lvl"])
		var w: int = maxi(1, int(b["weight"]) - gap / 3)
		pool.append([b, w])
		total += w
	if pool.is_empty():
		return BASES[0]
	var roll := rng.randi_range(0, total - 1)
	for entry in pool:
		roll -= int(entry[1])
		if roll < 0:
			return entry[0]
	return pool[-1][0]
