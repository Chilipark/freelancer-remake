class_name Item
extends RefCounted
## One piece of ship equipment.

enum Rarity { NORMAL, MAGIC, RARE, UNIQUE }

const RARITY_NAMES := ["Normal", "Magic", "Rare", "Unique"]
## Diablo 2 item colours: white, blue, yellow, gold.
const RARITY_COLORS := [
	Color(0.92, 0.92, 0.92), Color(0.42, 0.52, 1.0), Color(1.0, 1.0, 0.4), Color(0.78, 0.66, 0.38),
]

var base_id: String = ""
var rarity: int = Rarity.NORMAL
var ilvl: int = 1
## Each affix: {"name": String, "stat": String, "value": float, "prefix": bool}
var affixes: Array = []
var unique_id: String = ""
var rare_name: String = ""


func base() -> Dictionary:
	return ItemBases.get_base(base_id)


func slot() -> String:
	return base()["slot"]


func color() -> Color:
	return RARITY_COLORS[rarity]


func is_weapon() -> bool:
	return slot() == "weapon"


func display_name() -> String:
	var base_name: String = base()["name"]
	match rarity:
		Rarity.UNIQUE:
			return Uniques.get_unique(unique_id).get("name", base_name)
		Rarity.RARE:
			return rare_name
		Rarity.MAGIC:
			var pre := ""
			var suf := ""
			for a in affixes:
				if a["prefix"]:
					pre = a["name"] + " "
				else:
					suf = " " + a["name"]
			return pre + base_name + suf
	return base_name


## Base stats plus every affix, summed by stat key.
func stats() -> Dictionary:
	var out: Dictionary = {}
	var b := base()
	for k in b.get("stats", {}):
		out[k] = float(b["stats"][k])
	for a in affixes:
		out[a["stat"]] = float(out.get(a["stat"], 0.0)) + float(a["value"])
	return out


## Sale value in credits. Affixes add to it like Diablo's item pricing.
func value() -> int:
	var v: float = float(base()["value"])
	var mult := 1.0
	match rarity:
		Rarity.MAGIC: mult = 1.6
		Rarity.RARE: mult = 2.6
		Rarity.UNIQUE: mult = 4.0
	v *= mult
	v += affixes.size() * 12.0 * (1.0 + ilvl / 10.0)
	return int(v)


## Lines for a Diablo-style tooltip: [text, color].
func tooltip_lines() -> Array:
	var lines: Array = []
	var b := base()
	lines.append([display_name(), color()])
	if rarity == Rarity.RARE or rarity == Rarity.UNIQUE:
		lines.append([b["name"], color()])
	lines.append([ItemBases.SLOT_NAMES[b["slot"]] + "  ·  Item Level " + str(ilvl), Color(0.6, 0.6, 0.65)])
	if b.has("weapon"):
		var w: Dictionary = b["weapon"]
		var pellets: int = w.get("pellets", 1)
		var dmg := "%d-%d %s Damage" % [w["dmg"][0], w["dmg"][1], String(w["type"]).capitalize()]
		if pellets > 1:
			dmg += " x%d" % pellets
		lines.append([dmg, Color.WHITE])
		lines.append(["%.1f Shots per Second · %d m Range" % [w["rate"], int(w["range"])], Color.WHITE])
		if w.has("homing"):
			lines.append(["Homing", Color.WHITE])
	for k in b.get("stats", {}):
		var v: float = b["stats"][k]
		if v != 0.0:
			lines.append([Stats.describe(k, v), Color.WHITE])
	var magic_col: Color = RARITY_COLORS[Rarity.MAGIC]
	for a in affixes:
		var bad: bool = float(a["value"]) < 0.0 and not String(a["stat"]).ends_with("_delay_pct") and a["stat"] != "cruise_charge_pct"
		lines.append([Stats.describe(a["stat"], a["value"]), Color(1, 0.35, 0.35) if bad else magic_col])
	lines.append(["Sell value: %d credits" % value(), Color(0.85, 0.75, 0.4)])
	return lines


func to_dict() -> Dictionary:
	return {"base": base_id, "rarity": rarity, "ilvl": ilvl, "affixes": affixes,
		"unique": unique_id, "rare_name": rare_name}


static func from_dict(d: Dictionary) -> Item:
	var it := Item.new()
	it.base_id = d["base"]
	it.rarity = int(d["rarity"])
	it.ilvl = int(d["ilvl"])
	it.affixes = d.get("affixes", [])
	it.unique_id = d.get("unique", "")
	it.rare_name = d.get("rare_name", "")
	return it
