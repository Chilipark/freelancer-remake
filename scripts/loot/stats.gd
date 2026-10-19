class_name Stats
extends RefCounted
## Stat keys used by items, affixes and ships, and how to show them.

## Stats on a weapon item that only affect that weapon (Diablo 2 "local" mods).
const LOCAL_WEAPON := [
	"damage_pct", "thermal", "emp", "kinetic", "fire_rate_pct",
	"proj_speed_pct", "crit_chance", "crit_mult",
]

## Format strings, "%s" gets the value.
const FORMAT := {
	"damage_pct": "%s%% Enhanced Damage",
	"thermal": "Adds %s Thermal Damage",
	"emp": "Adds %s EMP Damage",
	"kinetic": "Adds %s Kinetic Damage",
	"fire_rate_pct": "%s%% Increased Fire Rate",
	"proj_speed_pct": "%s%% Projectile Speed",
	"crit_chance": "%s%% Critical Hit Chance",
	"crit_mult": "%s%% Critical Damage",
	"max_hull": "%s Hull",
	"max_hull_pct": "%s%% Hull",
	"hull_regen": "Repairs %s Hull per Second",
	"max_shield": "%s Shield Capacity",
	"shield_regen_pct": "%s%% Shield Recharge Rate",
	"shield_delay_pct": "%s%% Shield Recharge Delay",
	"max_power": "%s Power Capacity",
	"power_regen_pct": "%s%% Power Regeneration",
	"thrust_pct": "%s%% Engine Thrust",
	"turn_pct": "%s%% Turn Rate",
	"cruise_charge_pct": "%s%% Cruise Charge Time",
	"damage_reduction": "Damage Reduced by %s%%",
	"leech": "%s%% of Damage Repairs Hull",
	"loot_find": "%s%% Better Chance of Finding Loot",
	"credit_find": "%s%% Extra Credits from Enemies",
	"all_damage_pct": "%s%% Damage to All Weapons",
}


static func describe(stat: String, value: float) -> String:
	var fmt: String = FORMAT.get(stat, stat + " %s")
	var shown := _num(value)
	# Signed stats read "+20%" / "-10%"; flat "Adds" damage stays unsigned.
	if not fmt.begins_with("Adds") and not fmt.begins_with("Repairs") and not fmt.begins_with("Damage Reduced"):
		shown = ("+" if value >= 0.0 else "") + shown
	return fmt % shown


static func _num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return "%.1f" % v
