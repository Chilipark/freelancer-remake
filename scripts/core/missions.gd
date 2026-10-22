class_name Missions
extends RefCounted
## The main story chain and station contracts. The game reports what happens
## (kills, lanes, docking, sectors entered...) through `on_event`, and this
## class advances objectives and pays out rewards.

signal changed

const STORY_TITLE := "The Gatebreaker Core"
const STORY := """Three days ago the research cruiser Meridian was torn apart by Warlord Kazrak's raiders. You pulled its black-box core from the wreck before they could.

The core holds the firing codes for Kazrak's "Gatebreaker", a device built to collapse the only jump gate out of this system and trap everyone inside it with him. The Navy fleet is waiting on the other side of that gate, at the far eastern edge of the system.

Get the core through the gate. Kazrak knows you have it, and every pirate between here and his Bastion will be hunting you."""

## Main story steps. Completing a later step skips any earlier ones.
const MAIN_STEPS := [
	{"id": "raiders", "text": "Destroy the raiders hunting you"},
	{"id": "lane", "text": "Fly through a trade lane ring to head east"},
	{"id": "contact", "text": "Dock at %s to meet your Navy contact"},
	{"id": "bastion", "text": "Reach the Warlord's Bastion in the far east"},
	{"id": "boss", "text": "Destroy Kazrak's dreadnought"},
	{"id": "escape", "text": "Escape through the jump gate"},
]
const MAX_CONTRACTS := 3
const ACE_A := ["Red", "One-Eye", "Black", "Mad", "Iron", "Grinning", "Silent", "Rust"]
const ACE_B := ["Vash", "Morrow", "Kestle", "Drask", "Juno", "Hask", "Tarrow", "Ilse"]

var map: RunMap
## Callable(lane_index) -> bool, set by the galaxy: true if that lane's jammer is dead.
var jam_cleared: Callable
var rng := RandomNumberGenerator.new()
var main_step := 0
var contact_node := -1
var boss_node := -1
## Accepted contracts: {id, type, title, desc, target, level, credits, done, spawned, lane, from}
var contracts: Array = []
var completed_contracts := 0
var _next_id := 1
## Station node id -> offered contracts.
var boards: Dictionary = {}


func setup(run_map: RunMap, seed_value: int) -> void:
	map = run_map
	rng.seed = seed_value
	main_step = 0
	contracts.clear()
	boards.clear()
	completed_contracts = 0
	for n in map.nodes:
		if n["type"] == "boss":
			boss_node = int(n["id"])
	# The contact waits at the mid-way station (the map guarantees one).
	var best_d := 999
	for n in map.nodes:
		if n["type"] == "station" and absi(int(n["depth"]) - 6) < best_d:
			best_d = absi(int(n["depth"]) - 6)
			contact_node = int(n["id"])


# --- Main story ----------------------------------------------------------------

func main_text() -> String:
	if main_step >= MAIN_STEPS.size():
		return "Deliver the core: complete!"
	var t: String = MAIN_STEPS[main_step]["text"]
	if MAIN_STEPS[main_step]["id"] == "contact":
		t = t % map.node_at(contact_node)["name"]
	return t


## Map node the current main objective points at, or -1.
func main_target() -> int:
	if main_step >= MAIN_STEPS.size():
		return -1
	match String(MAIN_STEPS[main_step]["id"]):
		"contact":
			return contact_node
		"bastion", "boss", "escape":
			return boss_node
	return -1


func _complete_main(step_id: String) -> void:
	var idx := -1
	for i in MAIN_STEPS.size():
		if MAIN_STEPS[i]["id"] == step_id:
			idx = i
	if idx < main_step:
		return
	main_step = idx + 1
	Run.message.emit("Objective complete: " + _step_done_text(step_id), Color(1, 0.85, 0.3))
	match step_id:
		"raiders":
			Run.add_credits(50)
		"contact":
			# The contact patches you up and hands over something useful.
			Run.hull = Run.stats.max_hull
			Run.add_credits(250 + map.node_at(contact_node)["level"] * 20)
			var gift := LootGenerator.generate(int(map.node_at(contact_node)["level"]) + 2, LootGenerator.Source.BOSS, rng)
			Run.add_to_cargo(gift)
			Run.message.emit("Commander Hale: \"Good work getting this far. Take this, and keep moving east.\"", Color(0.6, 0.9, 1))
	if main_step < MAIN_STEPS.size():
		Run.message.emit("New objective: " + main_text(), Color(1, 0.85, 0.3))
	_auto_waypoint()
	changed.emit()


func _step_done_text(step_id: String) -> String:
	match step_id:
		"raiders": return "raiders destroyed"
		"lane": return "on your way east"
		"contact": return "core verified by the Navy"
		"bastion": return "Bastion reached"
		"boss": return "Kazrak is dead"
		"escape": return "you made it out"
	return step_id


## Points the waypoint at the main objective unless the player picked their own.
func _auto_waypoint() -> void:
	var t := main_target()
	if t >= 0 and (Run.waypoint < 0 or Run.waypoint == contact_node or Run.waypoint == boss_node):
		Run.waypoint = t


# --- Contracts -------------------------------------------------------------------

## Offers on a station's mission board (generated once per station).
func board(station_node: int) -> Array:
	if boards.has(station_node):
		return boards[station_node]
	var here: Dictionary = map.node_at(station_node)
	var d: int = here["depth"]
	var offers: Array = []
	var kinds := ["bounty", "jammer", "delivery", "signal"]
	kinds.shuffle()
	for kind in kinds:
		var c := _make_contract(kind, here)
		if not c.is_empty():
			offers.append(c)
		if offers.size() >= 3:
			break
	boards[station_node] = offers
	return offers


func _nodes_near(depth: int, types: Array, exclude: int) -> Array:
	var out: Array = []
	for n in map.nodes:
		var nd: int = n["depth"]
		if nd >= depth - 1 and nd <= depth + 3 and n["type"] in types and int(n["id"]) != exclude:
			out.append(n)
	return out


func _make_contract(kind: String, here: Dictionary) -> Dictionary:
	var d: int = here["depth"]
	var c := {"id": _next_id, "type": kind, "from": int(here["id"]), "done": false, "spawned": false, "lane": -1}
	match kind:
		"bounty":
			var cands := _nodes_near(d, ["combat", "elite", "event", "station"], int(here["id"]))
			if cands.is_empty():
				return {}
			var t: Dictionary = cands[rng.randi_range(0, cands.size() - 1)]
			var ace := "%s %s" % [ACE_A[rng.randi_range(0, ACE_A.size() - 1)], ACE_B[rng.randi_range(0, ACE_B.size() - 1)]]
			c["title"] = "Bounty: %s" % ace
			c["ace"] = ace
			c["desc"] = "The pirate ace %s has been spotted in %s. Destroy their ship." % [ace, t["name"]]
			c["target"] = int(t["id"])
			c["level"] = int(t["level"]) + 1
			c["credits"] = 150 + int(t["level"]) * 40
		"jammer":
			var best := -1
			for i in map.lanes.size():
				var L: Dictionary = map.lanes[i]
				var a: Dictionary = map.node_at(L["a"])
				var cleared: bool = jam_cleared.is_valid() and jam_cleared.call(i)
				if float(L["jam"]) >= 0.0 and absi(int(a["depth"]) - d) <= 3 and not cleared:
					best = i
					break
			if best < 0:
				return {}
			var L2: Dictionary = map.lanes[best]
			var na: Dictionary = map.node_at(L2["a"])
			var nb: Dictionary = map.node_at(L2["b"])
			c["title"] = "Clear the %s lane" % nb["name"]
			c["desc"] = "Pirates have jammed the trade lane from %s to %s. Destroy their jammer." % [na["name"], nb["name"]]
			c["target"] = int(L2["a"])
			c["lane"] = best
			c["level"] = int(na["level"])
			c["credits"] = 140 + int(na["level"]) * 35
		"delivery":
			var cands2 := _nodes_near(d, ["station"], int(here["id"]))
			if cands2.is_empty():
				return {}
			var t2: Dictionary = cands2[rng.randi_range(0, cands2.size() - 1)]
			var cargo: String = ["medical supplies", "reactor parts", "sealed diplomatic pouches", "refugee manifests", "coolant cells"][rng.randi_range(0, 4)]
			c["title"] = "Deliver %s" % cargo
			c["desc"] = "Carry %s to %s. Dock there to deliver." % [cargo, t2["name"]]
			c["target"] = int(t2["id"])
			c["level"] = int(t2["level"])
			c["credits"] = 100 + absi(int(t2["depth"]) - d) * 60 + int(t2["level"]) * 15
		"signal":
			var cands3 := _nodes_near(d, ["event"], int(here["id"]))
			if cands3.is_empty():
				return {}
			var t3: Dictionary = cands3[rng.randi_range(0, cands3.size() - 1)]
			c["title"] = "Investigate %s" % t3["name"]
			c["desc"] = "Navy listening posts picked up a strange signal in %s. Go and find out what it is." % t3["name"]
			c["target"] = int(t3["id"])
			c["level"] = int(t3["level"])
			c["credits"] = 90 + int(t3["level"]) * 25
	_next_id += 1
	return c


func can_accept() -> bool:
	return contracts.size() < MAX_CONTRACTS


func accept(c: Dictionary) -> bool:
	if not can_accept() or c in contracts:
		return false
	for b in boards.values():
		b.erase(c)
	contracts.append(c)
	Run.message.emit("Contract accepted: " + String(c["title"]), Color(0.6, 0.9, 1))
	changed.emit()
	return true


func abandon(c: Dictionary) -> void:
	contracts.erase(c)
	changed.emit()


func _finish_contract(c: Dictionary) -> void:
	if c["done"]:
		return
	c["done"] = true
	contracts.erase(c)
	completed_contracts += 1
	Run.add_credits(int(c["credits"]))
	var item := LootGenerator.generate(int(c["level"]), LootGenerator.Source.ELITE, rng, Run.stats.loot_find)
	Run.add_to_cargo(item)
	Run.message.emit("Contract complete: %s  (+%d credits)" % [c["title"], c["credits"]], Color(1, 0.85, 0.3))
	if Run.waypoint == int(c["target"]):
		Run.waypoint = -1
		_auto_waypoint()
	changed.emit()


## Bounty contracts whose ace should appear in this sector right now.
func bounties_at(node_id: int) -> Array:
	return contracts.filter(func(c): return c["type"] == "bounty" and int(c["target"]) == node_id and not c["done"] and not c["spawned"])


# --- Events from the game ---------------------------------------------------------

## kind: "raiders_cleared", "lane", "enter" {node}, "dock" {node}, "boss",
## "escape", "signal" {node}, "jammer" {lane}, "kill" {contract}
func on_event(kind: String, data: Dictionary = {}) -> void:
	match kind:
		"raiders_cleared":
			_complete_main("raiders")
		"lane":
			_complete_main("lane")
		"enter":
			if int(data["node"]) == boss_node:
				_complete_main("bastion")
		"dock":
			if int(data["node"]) == contact_node:
				_complete_main("contact")
			for c in contracts.duplicate():
				if c["type"] == "delivery" and int(c["target"]) == int(data["node"]):
					_finish_contract(c)
		"boss":
			_complete_main("boss")
		"escape":
			_complete_main("escape")
		"signal":
			for c in contracts.duplicate():
				if c["type"] == "signal" and int(c["target"]) == int(data["node"]):
					_finish_contract(c)
		"jammer":
			for c in contracts.duplicate():
				if c["type"] == "jammer" and int(c["lane"]) == int(data["lane"]):
					_finish_contract(c)
		"kill":
			for c in contracts.duplicate():
				if int(c["id"]) == int(data.get("contract", -1)):
					_finish_contract(c)
