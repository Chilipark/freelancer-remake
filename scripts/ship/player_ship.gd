class_name PlayerShip
extends Ship
## The player's ship: Freelancer controls. Mouse flight steers toward the
## cursor, guns aim at the cursor within their gimbal, W/S set throttle,
## Shift+W or C toggles cruise, Tab is afterburner, A/D strafe.

signal interact_pressed
signal tractor_pressed

const AIM_ASSIST_DEG := 3.5

var camera: Camera3D
var mouse_flight := true
var controls_enabled := true
var aim_point := Vector3.ZERO
var lead_point := Vector3.ZERO
var has_lead := false


func _ready() -> void:
	faction = "player"
	display_name = "You"


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or not alive:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_W and event.shift_pressed:
			toggle_cruise()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("cruise"):
		toggle_cruise()
	elif event.is_action_pressed("mouse_flight"):
		mouse_flight = not mouse_flight
	elif event.is_action_pressed("target_next"):
		cycle_target()
	elif event.is_action_pressed("interact"):
		interact_pressed.emit()
	elif event.is_action_pressed("tractor"):
		tractor_pressed.emit()
	elif event.is_action_pressed("full_stop"):
		flight.throttle = 0.0
		flight.set_cruise(false)


func toggle_cruise() -> void:
	if not flight.cruise_active and is_jammed():
		Run.message.emit("Cruise jammed! Destroy the jammer or get out of its field.", Color(1, 0.3, 0.35))
		return
	flight.set_cruise(not flight.cruise_active)
	if flight.cruise_active:
		flight.throttle = 1.0


func think(dt: float) -> void:
	steer = Vector3.ZERO
	strafe = Vector2.ZERO
	wants_afterburner = false
	if not controls_enabled:
		steer.z = level_roll()
		return

	if Input.is_action_pressed("throttle_up") and not Input.is_key_pressed(KEY_SHIFT):
		flight.throttle = minf(1.0, flight.throttle + dt * 0.9)
	if Input.is_action_pressed("throttle_down"):
		flight.throttle = maxf(-1.0, flight.throttle - dt * 0.9)
		if flight.cruise_active:
			flight.set_cruise(false)
	strafe.x = Input.get_axis("strafe_left", "strafe_right")
	wants_afterburner = Input.is_action_pressed("afterburner")
	if wants_afterburner and flight.cruise_active:
		flight.set_cruise(false)

	if mouse_flight and camera:
		var vp := get_viewport()
		var size := vp.get_visible_rect().size
		var off := (vp.get_mouse_position() - size * 0.5) / (minf(size.x, size.y) * 0.42)
		if off.length() < 0.06:
			off = Vector2.ZERO
		off = off.limit_length(1.0)
		steer.x = -off.y
		steer.y = -off.x

	var roll_in := Input.get_axis("roll_right", "roll_left")
	steer.z = roll_in if absf(roll_in) > 0.0 else level_roll()

	_update_aim()
	if Input.is_action_pressed("fire"):
		if target == null or not target.alive:
			pick_nearest_target()
		if fire(aim_point) and flight.cruise_active:
			flight.set_cruise(false)


func _update_aim() -> void:
	if camera == null:
		aim_point = global_position + forward() * 500.0
		return
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var dist := 500.0
	has_lead = false
	if target and is_instance_valid(target) and target.alive:
		dist = global_position.distance_to(target.global_position)
		lead_point = compute_lead(target)
		has_lead = true
		var to_lead := (lead_point - origin).normalized()
		if dir.angle_to(to_lead) < deg_to_rad(AIM_ASSIST_DEG):
			aim_point = lead_point
			return
	aim_point = origin + dir * maxf(dist, 50.0)


## Where to shoot so a projectile meets `t` (first-order intercept).
func compute_lead(t: Ship) -> Vector3:
	var speed := 600.0
	if not stats.weapons.is_empty():
		speed = float(stats.weapons[0]["speed"])
	var rel_pos := t.global_position - global_position
	var rel_vel := t.flight.velocity - flight.velocity
	var time := rel_pos.length() / speed
	for i in 3:
		time = (rel_pos + rel_vel * time).length() / speed
	return t.global_position + rel_vel * time


func is_jammed() -> bool:
	return world != null and world.has_method("is_jammed") and world.is_jammed(global_position)


func hostiles() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("ships"):
		var s := n as Ship
		if s and s.alive and s.faction == "enemy":
			out.append(s)
	return out


func pick_nearest_target() -> void:
	var best: Ship = null
	var best_d := 2500.0
	for s in hostiles():
		var d := global_position.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	target = best


func cycle_target() -> void:
	var list := hostiles()
	if list.is_empty():
		target = null
		return
	list.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	var idx := list.find(target)
	target = list[(idx + 1) % list.size()]
