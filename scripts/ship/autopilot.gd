class_name Autopilot
extends RefCounted
## Freelancer-style "Goto" autopilot. Plans the quickest route to a sector
## over the trade lane network (or straight there under cruise if that's
## faster), then flies it: cruise to each lane's entry ring, ride the lane,
## repeat, and finally cruise into the destination sector.
##
## It hands control back when you touch the flight controls, take fire, get
## jammed, or a lane trip is cut short (ambush or jammer).

const CRUISE_SPEED := 300.0
const LANE_OVERHEAD := 15.0      # seconds lost lining up / spooling a lane
const ARRIVE_RADIUS := 900.0
const RING_RADIUS := 180.0
const CRUISE_MIN_DIST := 2500.0
const CRUISE_DROP_DIST := 1200.0

var galaxy: Galaxy
var active := false
var target_id := -1
## Each leg: {"pos": Vector3 (absolute), "radius": float, "lane": int (-1 = none), "t": float, "sign": int}
var legs: Array = []
var leg := 0


## Lane cost in seconds, or INF for lanes we know are jammed.
func _lane_cost(i: int) -> float:
	var L: Dictionary = galaxy.lanes[i]
	if float(L["jam_t"]) >= 0.0:
		var site: Dictionary = galaxy.sites[int(L["jam_site"])]
		var known: bool = site.get("known", false) or site["loaded"] != null
		if known and not (0 in site["state"]["dead"]):
			return INF
	return float(L["length"]) / Galaxy.LANE_SPEED + LANE_OVERHEAD


## Dijkstra from the player's position. Returns the legs to fly, or [] if
## the target can't be reached.
func plan(to_id: int) -> Array:
	var map := galaxy.map
	var pabs := galaxy.player_abs()
	var n_count := map.nodes.size()
	var cost: Array = []
	var prev: Array = []          # [previous node id or -1 for "start", lane index or -1]
	var done: Array = []
	for n in map.nodes:
		cost.append(pabs.distance_to(n["pos"]) / CRUISE_SPEED)
		prev.append([-1, -1])
		done.append(false)
	var adj: Array = []
	for i in n_count:
		adj.append([])
	for i in galaxy.lanes.size():
		var L: Dictionary = galaxy.lanes[i]
		adj[int(L["a"])].append([int(L["b"]), i])
		adj[int(L["b"])].append([int(L["a"]), i])
	for _iter in n_count:
		var u := -1
		for i in n_count:
			if not done[i] and (u < 0 or cost[i] < cost[u]):
				u = i
		if u < 0 or cost[u] == INF:
			break
		done[u] = true
		for e in adj[u]:
			var c: float = _lane_cost(e[1])
			if c == INF:
				continue
			var v: int = e[0]
			if cost[u] + c < cost[v]:
				cost[v] = cost[u] + c
				prev[v] = [u, e[1]]
	# Walk back from the target to list the lanes used.
	var hops: Array = []   # [from_node, lane]
	var cur := to_id
	var guard := 0
	while prev[cur][0] >= 0 and guard < n_count:
		hops.push_front([prev[cur][0], prev[cur][1]])
		cur = prev[cur][0]
		guard += 1
	var out: Array = []
	for h in hops:
		var L: Dictionary = galaxy.lanes[int(h[1])]
		var sgn := 1 if int(L["a"]) == int(h[0]) else -1
		var t := 0.0 if sgn > 0 else float(L["length"])
		out.append({"pos": L["start"] + L["dir"] * t, "radius": RING_RADIUS, "lane": int(h[1]), "t": t, "sign": sgn})
	out.append({"pos": map.node_at(to_id)["pos"], "radius": ARRIVE_RADIUS, "lane": -1, "t": 0.0, "sign": 0})
	return out


## Lanes the current route uses (for drawing it on the nav map).
func route_lanes() -> Array:
	var out: Array = []
	if not active:
		return out
	for i in range(leg, legs.size()):
		if int(legs[i]["lane"]) >= 0:
			out.append(int(legs[i]["lane"]))
	return out


func engage(to_id: int) -> bool:
	if to_id < 0:
		Run.message.emit("Set a waypoint on the nav map (M) first.", Color(1, 0.8, 0.4))
		return false
	if galaxy.player.is_jammed():
		Run.message.emit("Autopilot unavailable: jammed.", Color(1, 0.3, 0.35))
		return false
	legs = plan(to_id)
	if legs.is_empty():
		return false
	if galaxy.player_abs().distance_to(legs[-1]["pos"]) < ARRIVE_RADIUS:
		Run.message.emit("Already there.", Color(0.7, 0.85, 1))
		return false
	target_id = to_id
	leg = 0
	active = true
	var lanes_used := legs.size() - 1
	Run.message.emit("Autopilot engaged: %s (%d lane%s)" % [galaxy.map.node_at(to_id)["name"],
		lanes_used, "" if lanes_used == 1 else "s"], Color(0.6, 0.9, 1))
	return true


func cancel(reason: String = "") -> void:
	if not active:
		return
	active = false
	legs = []
	if reason != "":
		Run.message.emit("Autopilot disengaged: " + reason, Color(1, 0.75, 0.4))


func current_leg() -> Dictionary:
	if not active or leg >= legs.size():
		return {}
	return legs[leg]


## What the HUD shows.
func status_text() -> String:
	var l := current_leg()
	if l.is_empty():
		return ""
	var dest: String = galaxy.map.node_at(target_id)["name"]
	if int(l["lane"]) >= 0:
		var L: Dictionary = galaxy.lanes[int(l["lane"])]
		var to_name: String = L["name_b"] if int(l["sign"]) > 0 else L["name_a"]
		return "AUTOPILOT → %s · leg %d/%d: lane to %s" % [dest, leg + 1, legs.size(), to_name]
	return "AUTOPILOT → %s · leg %d/%d: final approach" % [dest, leg + 1, legs.size()]


## Called by the Galaxy when a lane trip ends.
func on_lane_ended(reason: String) -> void:
	if not active:
		return
	if reason == "arrived":
		leg += 1
	else:
		cancel("lane trip interrupted")


## Flies the current leg. Called from PlayerShip.think while engaged.
func drive(p: PlayerShip, _dt: float) -> void:
	var l := current_leg()
	if l.is_empty():
		cancel()
		return
	if p.is_jammed():
		p.flight.set_cruise(false)
		cancel("jammed!")
		return
	var target := galaxy.to_local_pos(l["pos"])
	var to := target - p.position
	var dist := to.length()
	if dist < float(l["radius"]):
		if int(l["lane"]) >= 0:
			galaxy.start_trip(int(l["lane"]), float(l["t"]), int(l["sign"]))
			if galaxy.trip.is_empty():
				cancel("lane blocked")
		else:
			p.flight.set_cruise(false)
			p.flight.throttle = 0.3
			Run.message.emit("Autopilot: arrived at %s." % galaxy.map.node_at(target_id)["name"], Color(0.6, 0.9, 1))
			active = false
		return
	p.steer = p.steer_toward(to)
	p.steer.z = p.level_roll()
	var facing := p.forward().angle_to(to) < deg_to_rad(15.0)
	if p.flight.cruise_active:
		if dist < CRUISE_DROP_DIST or not facing and p.forward().angle_to(to) > deg_to_rad(45.0):
			p.flight.set_cruise(false)
	elif facing and dist > CRUISE_MIN_DIST:
		p.flight.set_cruise(true)
	if not p.flight.cruise_active:
		# Slow down for the final few hundred metres so we don't overshoot.
		p.flight.throttle = clampf(dist / 600.0, 0.25, 1.0)
