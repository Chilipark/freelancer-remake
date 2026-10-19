class_name LootPickup
extends Node3D
## A floating cargo pod with a Diablo-style coloured light beam.
## Credits are collected on contact; items need the tractor beam (T)
## or flying right next to them.

const COLLECT_RANGE := 22.0
const TRACTOR_SPEED := 160.0

var item: Item
var credits := 0
var tractored := false
var drift := Vector3.ZERO
var _spin := Vector3.ZERO


func _ready() -> void:
	add_to_group("loot")
	var col := Color(1.0, 0.85, 0.3) if item == null else item.color()
	if item == null:
		add_child(FX.mesh_node(FX.sphere(1.6, 8), FX.glow_mat(col, 4.0)))
	else:
		add_child(FX.mesh_node(FX.box(Vector3(3, 2, 4)), FX.mat(col.darkened(0.3), 0.6, 0.5, 0.4)))
		# Light beam, taller for better items.
		var h := 30.0 + item.rarity * 25.0
		add_child(FX.mesh_node(FX.cylinder(0.6, 0.6, h, 6), FX.glow_mat(col, 3.0, 0.45), Vector3(0, h * 0.5, 0)))
		var label := Label3D.new()
		label.text = item.display_name()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.25
		label.font_size = 40
		label.outline_size = 10
		label.modulate = col
		label.position = Vector3(0, h + 6.0, 0)
		label.no_depth_test = true
		add_child(label)
	_spin = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.6


func _process(dt: float) -> void:
	position += drift * dt
	drift *= exp(-0.8 * dt)
	if get_child_count() > 0:
		get_child(0).rotation += _spin * dt


## Moves toward the player when tractored. Returns true once in range.
func pull_toward(pos: Vector3, dt: float) -> bool:
	var to := pos - global_position
	if to.length() < COLLECT_RANGE:
		return true
	if tractored:
		global_position += to.normalized() * minf(to.length(), TRACTOR_SPEED * dt)
	return false
