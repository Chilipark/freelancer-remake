class_name ShipStats
extends RefCounted
## Final ship numbers worked out from the hull, equipped items and meta upgrades.

const CRUISE_SPEED := 300.0       # Freelancer CRUISING_SPEED
const CRUISE_CHARGE_TIME := 5.0   # Freelancer CRUISE_ACCEL_TIME

var max_hull := 100.0
var hull_regen := 0.0
var max_shield := 0.0
var shield_regen := 0.0          # per second
var shield_delay := 3.0          # seconds after a hit before recharging
var max_power := 100.0
var power_regen := 30.0
var top_speed := 80.0
var turn_rate := 1.8             # rad/s
var cruise_charge := CRUISE_CHARGE_TIME
var damage_reduction := 0.0      # percent
var leech := 0.0                 # percent
var loot_find := 0.0
var credit_find := 0.0
## One entry per equipped weapon: see _weapon().
var weapons: Array = []


## `loadout` maps slot keys ("weapon0".., "shield", "engine", "armor", "core")
## to Item (or null). `meta` holds percentage bonuses from Hangar upgrades.
static func compute(hull: Dictionary, loadout: Dictionary, meta: Dictionary = {}) -> ShipStats:
	var s := ShipStats.new()
	var g: Dictionary = {}   # global stat totals
	for key in loadout:
		var item: Item = loadout[key]
		if item == null:
			continue
		var st := item.stats()
		for k in st:
			if item.is_weapon() and k in Stats.LOCAL_WEAPON:
				continue
			g[k] = float(g.get(k, 0.0)) + float(st[k])

	s.max_hull = (float(hull["hull"]) + g.get("max_hull", 0.0)) \
		* (1.0 + (g.get("max_hull_pct", 0.0) + meta.get("hull_pct", 0.0)) / 100.0)
	s.max_hull = maxf(20.0, s.max_hull)
	s.hull_regen = g.get("hull_regen", 0.0)
	s.max_shield = g.get("max_shield", 0.0) * (1.0 + meta.get("shield_pct", 0.0) / 100.0)
	s.shield_regen = s.max_shield * 0.12 * (1.0 + g.get("shield_regen_pct", 0.0) / 100.0)
	s.shield_delay = 3.0 * maxf(0.2, 1.0 + g.get("shield_delay_pct", 0.0) / 100.0)
	s.max_power = float(hull["power"]) + g.get("max_power", 0.0)
	s.power_regen = float(hull["power_regen"]) * (1.0 + g.get("power_regen_pct", 0.0) / 100.0)
	s.top_speed = float(hull["speed"]) * maxf(0.3, 1.0 + g.get("thrust_pct", 0.0) / 100.0)
	s.turn_rate = float(hull["turn"]) * maxf(0.3, 1.0 + g.get("turn_pct", 0.0) / 100.0)
	s.cruise_charge = CRUISE_CHARGE_TIME * maxf(0.2, 1.0 + g.get("cruise_charge_pct", 0.0) / 100.0)
	s.damage_reduction = clampf(float(hull.get("dr", 0.0)) + g.get("damage_reduction", 0.0), 0.0, 60.0)
	s.leech = g.get("leech", 0.0)
	s.loot_find = g.get("loot_find", 0.0) + meta.get("loot_find", 0.0)
	s.credit_find = g.get("credit_find", 0.0)
	var all_dmg: float = g.get("all_damage_pct", 0.0) + meta.get("damage_pct", 0.0)

	for i in int(hull["hardpoints"]):
		var w: Item = loadout.get("weapon%d" % i)
		if w != null:
			s.weapons.append(_weapon(w, all_dmg))
	return s


static func _weapon(item: Item, all_dmg: float) -> Dictionary:
	var wb: Dictionary = item.base()["weapon"]
	var st := item.stats()
	var pellets: int = wb.get("pellets", 1)
	var mult: float = 1.0 + (st.get("damage_pct", 0.0) + all_dmg) / 100.0
	return {
		"type": wb["type"],
		"min": float(wb["dmg"][0]) * maxf(0.1, mult),
		"max": float(wb["dmg"][1]) * maxf(0.1, mult),
		"flat": {"thermal": st.get("thermal", 0.0) / pellets, "emp": st.get("emp", 0.0) / pellets,
			"kinetic": st.get("kinetic", 0.0) / pellets},
		"interval": 1.0 / (float(wb["rate"]) * (1.0 + st.get("fire_rate_pct", 0.0) / 100.0)),
		"speed": float(wb["speed"]) * (1.0 + st.get("proj_speed_pct", 0.0) / 100.0),
		"range": float(wb["range"]),
		"energy": float(wb["energy"]),
		"pellets": pellets,
		"spread": float(wb.get("spread", 0.0)),
		"homing": float(wb.get("homing", 0.0)),
		"crit_chance": st.get("crit_chance", 0.0) + 5.0,
		"crit_mult": 1.5 + st.get("crit_mult", 0.0) / 100.0,
		"color": wb["color"],
	}


## Expected damage per second of one weapon (used by tooltips and tests).
static func weapon_dps(w: Dictionary) -> float:
	var flat: Dictionary = w["flat"]
	var per_hit: float = (float(w["min"]) + float(w["max"])) * 0.5 + flat["thermal"] + flat["emp"] + flat["kinetic"]
	var crit: float = 1.0 + float(w["crit_chance"]) / 100.0 * (float(w["crit_mult"]) - 1.0)
	return per_hit * int(w["pellets"]) * crit / float(w["interval"])
