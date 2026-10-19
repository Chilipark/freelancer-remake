class_name RunMap
extends RefCounted
## The run's sector graph, laid out in one open-world system. Sectors sit in
## layers left to right (like Slay the Spire / FTL), each linked to 1-3
## sectors in the next layer by a Freelancer trade lane. You can fly anywhere
## under your own power; lanes are just much faster. Some lanes are jammed.

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
const SPACING := 32000.0        # metres between layers (x axis)
const SPREAD := 40000.0         # metres between sectors in a layer (z axis)
const SECTOR_WORDS_A := ["Tau", "Sigma", "Omicron", "Kappa", "Rho", "Zeta", "Theta", "Epsilon", "Lambda", "Psi", "Iota", "Delta"]
const SECTOR_WORDS_B := ["Reach", "Expanse", "Drift", "Hollow", "Verge", "Rift", "Shoals", "Gulf", "Crossing", "Wastes", "Deep", "Nebula"]

## Each node: {id, depth, lane, type, level, next: Array[int], seed, name, pos: Vector3}
var nodes: Array = []
## Each lane: {a: int, b: int, jam: float} — jam is where along the lane
## (0..1) a pirate jammer sits, or -1 for a clear lane.
var lanes: Array = []


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
			var nm := ""
			for attempt in 50:
				nm = "%s %s" % [SECTOR_WORDS_A[rng.randi_range(0, SECTOR_WORDS_A.size() - 1)],
					SECTOR_WORDS_B[rng.randi_range(0, SECTOR_WORDS_B.size() - 1)]]
				if not nodes.any(func(o): return o["name"] == nm):
					break
			var n := {
				"id": nodes.size(), "depth": d, "lane": lane, "lanes": count,
				"type": _pick_type(d, rng), "level": level_for_depth(d), "next": [],
				"seed": rng.randi(),
				"name": nm,
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

	# Place sectors in space.
	for n in nodes:
		var d: int = n["depth"]
		var jitter := d > 0 and d < DEPTH - 1
		n["pos"] = Vector3(
			d * SPACING + (rng.randf_range(-3000, 3000) if jitter else 0.0),
			rng.randf_range(-1200, 1200) if jitter else 0.0,
			(float(n["lane"]) - (float(n["lanes"]) - 1.0) * 0.5) * SPREAD + (rng.randf_range(-4000, 4000) if jitter else 0.0))

	# One trade lane per link. Deeper lanes are more likely to be jammed.
	lanes.clear()
	for n in nodes:
		for nid in n["next"]:
			var jam := -1.0
			if int(n["depth"]) >= 2 and rng.randf() < 0.12 + int(n["depth"]) * 0.015:
				jam = rng.randf_range(0.3, 0.7)
			lanes.append({"a": n["id"], "b": nid, "jam": jam})


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


## Enemy level for a point in space, by how far along the run it is.
static func level_at(pos: Vector3) -> int:
	return level_for_depth(clampi(int(round(pos.x / SPACING)), 0, DEPTH - 1))


func nearest_node(pos: Vector3) -> Dictionary:
	var best: Dictionary = nodes[0]
	var best_d := INF
	for n in nodes:
		var d: float = pos.distance_to(n["pos"])
		if d < best_d:
			best_d = d
			best = n
	return best


func node_at(id: int) -> Dictionary:
	return nodes[id]


func start_id() -> int:
	return 0
