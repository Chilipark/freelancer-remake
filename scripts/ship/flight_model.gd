class_name FlightModel
extends RefCounted
## Freelancer-style flight, after the decomp's CEEngine / CSteering:
## engine force fights linear drag, so speed eases toward throttle * top
## speed and sideways drift bleeds off. Steering torque fights angular drag
## the same way. Cruise charges for a few seconds, then pushes toward 300 m/s.
## Integration is exact for constant input, so it doesn't depend on frame rate.

const LINEAR_DRAG := 1.1         # 1/s, how fast velocity settles
const CRUISE_DRAG := 0.55        # gentler pull toward cruise speed
const ANGULAR_DRAG := 5.0        # 1/s, how fast turning settles
const REVERSE_FRACTION := 0.4    # Freelancer reverse_fraction
const STRAFE_FRACTION := 0.6
const AFTERBURNER_MULT := 1.9

var velocity := Vector3.ZERO
var ang_vel := Vector3.ZERO      # local radians/s: x pitch, y yaw, z roll
var throttle := 0.0              # -1..1
var afterburner := false
var cruise_active := false
var cruise_elapsed := 0.0

var top_speed := 80.0
var turn_rate := 1.8
var cruise_charge := ShipStats.CRUISE_CHARGE_TIME


func configure(stats: ShipStats) -> void:
	top_speed = stats.top_speed
	turn_rate = stats.turn_rate
	cruise_charge = stats.cruise_charge


func set_cruise(on: bool) -> void:
	if on == cruise_active:
		return
	cruise_active = on
	cruise_elapsed = 0.0


func is_cruising() -> bool:
	return cruise_active and cruise_elapsed >= cruise_charge


func cruise_progress() -> float:
	if not cruise_active:
		return 0.0
	return clampf(cruise_elapsed / maxf(0.01, cruise_charge), 0.0, 1.0)


## Advances the ship one step. `steer` is (pitch, yaw, roll) in -1..1,
## `strafe` is (right, up) in -1..1. Returns the new transform.
func step(xf: Transform3D, dt: float, steer: Vector3, strafe: Vector2) -> Transform3D:
	var b := xf.basis.orthonormalized()
	var fwd := -b.z
	var target_vel: Vector3
	var drag := LINEAR_DRAG

	if cruise_active:
		cruise_elapsed += dt
	if is_cruising():
		target_vel = fwd * ShipStats.CRUISE_SPEED
		drag = CRUISE_DRAG
	else:
		var t := throttle
		if cruise_active:
			t = 1.0   # charging cruise runs the engine at full
		var engine := top_speed * (t if t >= 0.0 else t * REVERSE_FRACTION)
		if afterburner:
			engine = top_speed * AFTERBURNER_MULT
		target_vel = fwd * engine
		target_vel += b.x * strafe.x * top_speed * STRAFE_FRACTION
		target_vel += b.y * strafe.y * top_speed * STRAFE_FRACTION

	var k := exp(-drag * dt)
	velocity = target_vel + (velocity - target_vel) * k

	var turn := turn_rate * (0.6 if is_cruising() else 1.0)
	var target_ang := Vector3(steer.x * turn, steer.y * turn, steer.z * turn * 1.4)
	ang_vel = target_ang + (ang_vel - target_ang) * exp(-ANGULAR_DRAG * dt)

	var rot := Basis(Vector3.RIGHT, ang_vel.x * dt) * Basis(Vector3.UP, ang_vel.y * dt) \
		* Basis(Vector3.BACK, ang_vel.z * dt)
	return Transform3D((b * rot).orthonormalized(), xf.origin + velocity * dt)


func speed() -> float:
	return velocity.length()
