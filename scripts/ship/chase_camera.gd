class_name ChaseCamera
extends Camera3D
## Freelancer-style chase camera: sits behind the ship and lags behind its
## rotation, so the ship swings across the screen when you turn hard.

var target: Ship
var offset := Vector3(0, 5.5, 21.0)
var rotation_lag := 5.0
var _basis := Basis.IDENTITY
var _ready_once := false


func _ready() -> void:
	process_priority = 100   # after the ships have moved
	far = 40000.0
	near = 0.5
	fov = 70.0


func _process(dt: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var t := target.global_transform
	if not _ready_once:
		_basis = t.basis
		_ready_once = true
	_basis = _basis.slerp(t.basis.orthonormalized(), 1.0 - exp(-rotation_lag * dt)).orthonormalized()
	var pos := t.origin + _basis * offset
	global_transform = Transform3D(_basis, pos)
	rotate_object_local(Vector3.RIGHT, -0.08)
	var cruising := target.flight.is_cruising()
	fov = lerpf(fov, 82.0 if cruising else 70.0, 1.0 - exp(-2.0 * dt))


func snap() -> void:
	_ready_once = false
