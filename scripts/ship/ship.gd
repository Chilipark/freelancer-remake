class_name Ship
extends Node3D
## Shared ship logic for the player and enemies: flight, power, shields,
## hull, weapons and taking damage.

signal died(ship: Ship)
signal damaged(ship: Ship, amount: float)

## How each damage type hits shields and hull.
const SHIELD_MULT := {"kinetic": 0.6, "thermal": 1.0, "emp": 2.0}
const HULL_MULT := {"kinetic": 1.25, "thermal": 1.0, "emp": 0.4}
const AFTERBURNER_DRAIN := 35.0
const GIMBAL_DEG := 22.0         # how far guns can swivel toward the aim point

var faction := "enemy"
var display_name := "Ship"
var level := 1
var rank := "normal"             # normal / elite / boss
var stats: ShipStats
var flight := FlightModel.new()
var hull := 100.0
var shield := 0.0
var power := 100.0
var shield_timer := 0.0
var radius := 4.0
var alive := true
var target: Ship
var world: Node3D                # where projectiles and effects are spawned
var model: Node3D
var hardpoints: Array = []
var cooldowns: Array = []
var steer := Vector3.ZERO
var strafe := Vector2.ZERO
var wants_afterburner := false
var rng := RandomNumberGenerator.new()


func setup_ship(ship_stats: ShipStats, style: String, color: Color, engine_color: Color, ship_radius: float) -> void:
	stats = ship_stats
	flight.configure(stats)
	hull = stats.max_hull
	shield = stats.max_shield
	power = stats.max_power
	radius = ship_radius
	if model:
		model.queue_free()
	model = ShipMesh.build(style, color, engine_color)
	add_child(model)
	hardpoints = model.get_meta("hardpoints")
	cooldowns.clear()
	for i in stats.weapons.size():
		cooldowns.append(rng.randf_range(0.0, 0.3))
	add_to_group("ships")


func apply_stats(ship_stats: ShipStats) -> void:
	stats = ship_stats
	flight.configure(stats)
	hull = minf(hull, stats.max_hull)
	shield = minf(shield, stats.max_shield)
	power = minf(power, stats.max_power)
	while cooldowns.size() < stats.weapons.size():
		cooldowns.append(0.0)


func _process(dt: float) -> void:
	if not alive:
		return
	think(dt)
	var burning := wants_afterburner and power > 5.0 and not flight.cruise_active
	flight.afterburner = burning
	global_transform = flight.step(global_transform, dt, steer, strafe)
	_regen(dt, burning)
	for i in cooldowns.size():
		cooldowns[i] = maxf(0.0, cooldowns[i] - dt)
	_update_engine_glow()


## Overridden by player input / AI to set steer, strafe, throttle and fire.
func think(_dt: float) -> void:
	pass


func _regen(dt: float, burning: bool) -> void:
	var p := stats.power_regen
	if burning:
		p -= AFTERBURNER_DRAIN
	power = clampf(power + p * dt, 0.0, stats.max_power)
	if shield_timer > 0.0:
		shield_timer -= dt
	elif stats.max_shield > 0.0:
		shield = minf(stats.max_shield, shield + stats.shield_regen * dt)
	if stats.hull_regen > 0.0:
		hull = minf(stats.max_hull, hull + stats.hull_regen * dt)


func _update_engine_glow() -> void:
	if model == null:
		return
	var s := flight.speed() / maxf(1.0, stats.top_speed)
	var glow_len := 1.0 + clampf(s, 0.0, 4.0) * 0.8
	for c in model.get_children():
		if c.name.begins_with("EngineGlow"):
			c.scale.z = glow_len * 1.6


func forward() -> Vector3:
	return -global_transform.basis.z


## Fires every ready weapon toward `aim_point`. Returns true if anything fired.
func fire(aim_point: Vector3) -> bool:
	if flight.cruise_active or world == null:
		return false
	var fired := false
	for i in stats.weapons.size():
		var w: Dictionary = stats.weapons[i]
		if cooldowns[i] > 0.0 or power < float(w["energy"]):
			continue
		var hp: Vector3 = hardpoints[i % hardpoints.size()] if not hardpoints.is_empty() else Vector3.ZERO
		var origin := global_transform * hp
		if global_position.distance_to(aim_point) > float(w["range"]) * 1.5:
			continue
		var dir := (aim_point - origin).normalized()
		# Guns only swivel within their gimbal; otherwise they fire straight ahead.
		if dir.angle_to(forward()) > deg_to_rad(GIMBAL_DEG):
			dir = forward()
		cooldowns[i] = float(w["interval"])
		power -= float(w["energy"])
		for p in int(w["pellets"]):
			var d := dir
			if float(w["spread"]) > 0.0:
				var sp := deg_to_rad(float(w["spread"]))
				d = (d.rotated(global_transform.basis.x, rng.randf_range(-sp, sp))
					.rotated(global_transform.basis.y, rng.randf_range(-sp, sp))).normalized()
			_spawn_projectile(w, origin, d)
		fired = true
	return fired


func _spawn_projectile(w: Dictionary, origin: Vector3, dir: Vector3) -> void:
	var dmg: Dictionary = {"kinetic": 0.0, "thermal": 0.0, "emp": 0.0}
	dmg[w["type"]] = rng.randf_range(float(w["min"]), float(w["max"]))
	var flat: Dictionary = w["flat"]
	for k in flat:
		dmg[k] += float(flat[k])
	var crit := rng.randf() * 100.0 < float(w["crit_chance"])
	if crit:
		for k in dmg:
			dmg[k] *= float(w["crit_mult"])
	var proj := Projectile.new()
	proj.setup(self, origin, dir * float(w["speed"]) + flight.velocity, dmg, float(w["range"]),
		w["color"], float(w["homing"]), target, crit)
	world.add_child(proj)


## Applies a hit. Returns the damage actually dealt to shield + hull.
func take_damage(dmg: Dictionary, attacker: Ship = null) -> float:
	if not alive:
		return 0.0
	var vs_shield := 0.0
	for k in dmg:
		vs_shield += float(dmg[k]) * SHIELD_MULT[k]
	var dealt := 0.0
	var hull_fraction := 1.0
	if shield > 0.0 and vs_shield > 0.0:
		if shield >= vs_shield:
			shield -= vs_shield
			dealt = vs_shield
			hull_fraction = 0.0
		else:
			hull_fraction = 1.0 - shield / vs_shield
			dealt = shield
			shield = 0.0
	if hull_fraction > 0.0:
		var vs_hull := 0.0
		for k in dmg:
			vs_hull += float(dmg[k]) * HULL_MULT[k]
		vs_hull *= hull_fraction * (1.0 - stats.damage_reduction / 100.0)
		hull -= vs_hull
		dealt += vs_hull
	shield_timer = stats.shield_delay
	if flight.cruise_active and faction == "player":
		flight.set_cruise(false)   # getting shot drops you out of cruise
	if attacker and attacker.alive and attacker.stats.leech > 0.0:
		attacker.hull = minf(attacker.stats.max_hull, attacker.hull + dealt * attacker.stats.leech / 100.0)
	damaged.emit(self, dealt)
	if hull <= 0.0:
		_die()
	return dealt


func _die() -> void:
	if not alive:
		return
	alive = false
	hull = 0.0
	if world:
		FX.explosion(world, global_position, radius)
	died.emit(self)
	remove_from_group("ships")
	if faction == "player":
		visible = false   # the game world still needs the player node
	else:
		queue_free()


## Steering input that turns the ship toward `world_dir`. Used by AI and autopilot.
func steer_toward(world_dir: Vector3) -> Vector3:
	var local := global_transform.basis.inverse() * world_dir.normalized()
	# local -Z is forward. Yaw from x, pitch from y.
	var yaw := atan2(-local.x, -local.z)
	var pitch := atan2(local.y, Vector2(local.x, local.z).length())
	return Vector3(clampf(pitch * 2.5, -1, 1), clampf(yaw * 2.5, -1, 1), 0.0)


## Roll input that keeps the ship's top facing world up (Freelancer auto-level).
func level_roll() -> float:
	var b := global_transform.basis
	var fwd := -b.z
	if absf(fwd.dot(Vector3.UP)) > 0.9:
		return 0.0
	var want_up := (Vector3.UP - fwd * fwd.dot(Vector3.UP)).normalized()
	var err := b.y.signed_angle_to(want_up, fwd)
	return clampf(-err * 1.5, -1, 1)
