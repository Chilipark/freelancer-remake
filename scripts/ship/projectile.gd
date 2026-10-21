class_name Projectile
extends Node3D
## A bolt, pellet or missile. Moves in a straight line (or homes in) and
## checks for hits with a swept sphere test so fast shots can't tunnel.

static var _meshes: Dictionary = {}

var shooter: Ship
var faction := ""
var velocity := Vector3.ZERO
var damage: Dictionary = {}
var life := 1.0
var homing := 0.0
var homing_target: Ship
var crit := false
var color := Color.WHITE


func setup(from: Ship, origin: Vector3, vel: Vector3, dmg: Dictionary, max_range: float,
		col: Color, homing_rate: float, tgt: Ship, is_crit: bool) -> void:
	shooter = from
	faction = from.faction
	velocity = vel
	damage = dmg
	life = max_range / maxf(1.0, vel.length()) * 1.15
	homing = homing_rate
	homing_target = tgt
	crit = is_crit
	color = col
	position = origin
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_for(homing > 0.0)
	mi.material_override = FX.glow_mat(col, 6.0 if crit else 4.0)
	if crit:
		mi.scale = Vector3(1.6, 1.6, 1.3)
	add_child(mi)


func _ready() -> void:
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT)


static func _mesh_for(missile: bool) -> Mesh:
	var key := "missile" if missile else "bolt"
	if not _meshes.has(key):
		if missile:
			_meshes[key] = FX.box(Vector3(0.5, 0.5, 2.2))
		else:
			_meshes[key] = FX.box(Vector3(0.22, 0.22, 5.0))
	return _meshes[key]


func _process(dt: float) -> void:
	life -= dt
	if life <= 0.0:
		queue_free()
		return
	if homing > 0.0 and is_instance_valid(homing_target) and homing_target.alive:
		var to := (homing_target.global_position - global_position).normalized()
		var spd := velocity.length()
		velocity = velocity.normalized().slerp(to, clampf(homing * dt, 0.0, 1.0)) * spd
		look_at(global_position + velocity, Vector3.UP if absf(to.y) < 0.99 else Vector3.RIGHT)
	var from := global_position
	var to_pos := from + velocity * dt
	for node in get_tree().get_nodes_in_group("ships"):
		var s := node as Ship
		if s == null or not s.alive or s.faction == faction:
			continue
		if _segment_hits(from, to_pos, s.global_position, s.radius):
			var hit_pos := s.global_position + (from - s.global_position).normalized() * s.radius * 0.8
			var shield_hit := s.shield > 0.0
			s.take_damage(damage, shooter if is_instance_valid(shooter) else null)
			var fx_parent := get_parent()
			FX.flash(fx_parent, hit_pos, Color(0.4, 0.7, 1.0) if shield_hit else color, 3.0 if crit else 2.0, 0.25)
			Sfx.play_at(fx_parent, "hit_shield" if shield_hit else "hit_hull", hit_pos, -12.0)
			queue_free()
			return
	for node in get_tree().get_nodes_in_group("obstacles"):
		var o := node as Node3D
		var r: float = o.get_meta("radius", 10.0)
		if _segment_hits(from, to_pos, o.global_position, r):
			FX.flash(get_parent(), from, color, 1.5, 0.2)
			queue_free()
			return
	global_position = to_pos


static func _segment_hits(a: Vector3, b: Vector3, center: Vector3, r: float) -> bool:
	var ab := b - a
	var len_sq := ab.length_squared()
	var t := 0.0
	if len_sq > 0.0001:
		t = clampf((center - a).dot(ab) / len_sq, 0.0, 1.0)
	return (a + ab * t).distance_squared_to(center) <= r * r
