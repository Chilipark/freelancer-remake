class_name FX
extends RefCounted
## Shared materials and simple effects built from primitives (no art assets).

static var _mats: Dictionary = {}


static func mat(color: Color, emission: float = 0.0, metallic: float = 0.4, rough: float = 0.5) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), emission, metallic, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


static func glow_mat(color: Color, energy: float = 3.0, alpha: float = 1.0) -> StandardMaterial3D:
	var key := "glow|%s|%.2f|%.2f" % [color.to_html(), energy, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


static func mesh_node(mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO,
		scale: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.scale = scale
	mi.rotation = rot
	return mi


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func sphere(radius: float, segments: int = 16) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = maxi(4, segments / 2)
	return m


static func cylinder(top: float, bottom: float, height: float, segments: int = 12) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	return m


static func torus(inner: float, outer: float, rings: int = 48) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = rings
	m.ring_segments = 12
	return m


## An expanding, fading glow ball. Used for hits and explosions.
static func flash(parent: Node, pos: Vector3, color: Color, size: float, duration: float = 0.35) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := mesh_node(sphere(1.0, 10), glow_mat(color, 4.0, 0.8), pos, Vector3.ONE * size * 0.3)
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * size, duration).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "transparency", 1.0, duration)
	tw.tween_callback(mi.queue_free)


static func explosion(parent: Node, pos: Vector3, size: float) -> void:
	flash(parent, pos, Color(1.0, 0.6, 0.2), size * 2.2, 0.7)
	flash(parent, pos, Color(1.0, 0.95, 0.7), size * 1.1, 0.35)
	if parent == null or not parent.is_inside_tree():
		return
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 6.0
	light.omni_range = size * 8.0
	light.position = pos
	parent.add_child(light)
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.8)
	tw.tween_callback(light.queue_free)
