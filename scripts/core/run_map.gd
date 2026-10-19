class_name RunMap
extends RefCounted
## The run's sector graph: layers of sectors joined by jump gates, like the
## map in Slay the Spire / FTL. Each sector links to 1-3 sectors in the next
## layer, and the last layer is the boss.

const DEPTH := 15
const TYPES := ["combat", "elite", "station", "event"]
const TYPE_NAMES := {
	"start": "Departure", "combat": "Hostile Sector", "elite": "Elite Sector",
	"station": "Trade Station", "event": "Unknown Signal", "boss": "Warlord's Bastion",
}
const TYPE_COLORS := {
	"start": Color(0.6, 0.8, 1.0), "combat": Color(1.0, 0.45, 0.35), "elite": Color(1.0, 0.75, 0.2),
	"station": Color(0.4, 1.0, 0.55), "event": Color(0.75, 0.55, 1.0), "boss": Color(1.0, 0.2, 0.2),
}
const SECTOR_WORDS_A := ["Tau", "Sigma", "Omicron", "Kappa", "Rho", "Zeta", "Theta", "Epsilon", "Lambda", "Psi", "Iota", "Delta"]
const SECTOR_WORDS_B := ["Reach", "Expanse", "Drift", "Hollow", "Verge", "Rift", "Shoals", "Gulf", "Crossing", "Wastes", "Deep", "Nebula"]

## Each node: {id, depth, lane, type, level, next: Array[int], seed, name}
var nodes: Array = []


static func level_for_depth(depth: int) -> int:
	return 1 + int(round(depth * 1.8))


func generate(rng: RandomNumberGenerator) -> void:
	nodes.clear()
	var layers: Array = []
	for d in DEPTH:
		var count := 1
		if d == 1:
			count = rng.randi_range(2, 3)   # the start sector has at most 3 gates
		elif d > 0 and d < DEPTH - 1:
			count = rng.randi_range(2, 4)
		var layer: Array = []
		for lane in count:
			var n := {
				"id": nodes.size(), "depth": d, "lane": lane, "lanes": count,
				"type": _pick_type(d, rng), "level": level_for_depth(d), "next": [],
				"seed": rng.randi(),
				"name": "%s %s" % [SECTOR_WORDS_A[rng.randi_range(0, SECTOR_WORDS_A.size() - 1)],
					SECTOR_WORDS_B[rng.randi_range(0, SECTOR_WORDS_B.size() - 1)]],
			}
			nodes.append(n)
			layer.append(n)
		layers.append(layer)

	# Guarantee a station choice before the mid-point and before the boss.
	for d in [6, DEPTH - 2]:
		var layer: Array = layers[d]
		if not layer.any(func(n): return n["type"] == "station"):
			layer[rng.randi_range(0, layer.size() - 1)]["type"] = "station"

	# Connect layers: map lanes proportionally, plus some extra branches.
	for d in DEPTH - 1:
		var a: Array = layers[d]
		var b: Array = layers[d + 1]
		for n in a:
			var pos: float = (float(n["lane"]) + 0.5) / a.size()
			var main := clampi(int(pos * b.size()), 0, b.size() - 1)
			_link(n, b[main])
			if b.size() > 1 and n["next"].size() < 2 and rng.randf() < 0.55:
				var other := clampi(main + (1 if rng.randf() < 0.5 else -1), 0, b.size() - 1)
				_link(n, b[other])
		for m in b:
			var has_in := a.any(func(n): return m["id"] in n["next"])
			if not has_in:
				# Link from the nearest sector in the previous layer that has room.
				var pos2: float = (float(m["lane"]) + 0.5) / b.size()
				var best: Dictionary = {}
				var best_d := INF
				for n in a:
					var gap := absf((float(n["lane"]) + 0.5) / a.size() - pos2)
					if n["next"].size() < 3 and gap < best_d:
						best_d = gap
						best = n
				_link(best if not best.is_empty() else a[0], m)
	for layer in layers:
		for n in layer:
			n["next"].sort()


func _link(from: Dictionary, to: Dictionary) -> void:
	if not (to["id"] in from["next"]):
		from["next"].append(to["id"])


func _pick_type(depth: int, rng: RandomNumberGenerator) -> String:
	if depth == 0:
		return "start"
	if depth == DEPTH - 1:
		return "boss"
	var r := rng.randf()
	if depth <= 2:
		return "combat" if r < 0.65 else "event"
	if r < 0.45:
		return "combat"
	if r < 0.63:
		return "elite"
	if r < 0.78:
		return "station"
	return "event"


func node_at(id: int) -> Dictionary:
	return nodes[id]


func start_id() -> int:
	return 0
