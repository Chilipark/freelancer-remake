class_name ShipMesh
extends RefCounted
## Builds ship models out of primitive shapes. The ship faces -Z.

## Returns a Node3D model and stores hardpoint/engine positions in its meta.
static func build(style: String, color: Color, engine_color: Color = Color(0.4, 0.7, 1.0)) -> Node3D:
	var root := Node3D.new()
	var hull := FX.mat(color, 0.0, 0.6, 0.45)
	var dark := FX.mat(color.darkened(0.55), 0.0, 0.5, 0.6)
	var glass := FX.mat(Color(0.2, 0.5, 0.8), 0.6, 0.2, 0.1)
	var glow := FX.glow_mat(engine_color, 5.0)
	var hardpoints: Array = []
	var engines: Array = []

	match style:
		"heavy":
			root.add_child(FX.mesh_node(FX.box(Vector3(3.2, 1.8, 7.0)), hull))
			root.add_child(FX.mesh_node(FX.box(Vector3(7.5, 0.5, 3.0)), dark, Vector3(0, 0, 1.0)))
			root.add_child(FX.mesh_node(FX.box(Vector3(1.6, 0.9, 2.0)), glass, Vector3(0, 1.1, -1.8)))
			root.add_child(FX.mesh_node(FX.box(Vector3(1.0, 1.0, 3.5)), dark, Vector3(-3.5, 0, 0.5)))
			root.add_child(FX.mesh_node(FX.box(Vector3(1.0, 1.0, 3.5)), dark, Vector3(3.5, 0, 0.5)))
			hardpoints = [Vector3(-3.5, 0, -1.5), Vector3(3.5, 0, -1.5), Vector3(0, -1.0, -3.6)]
			engines = [Vector3(-1.0, 0, 3.6), Vector3(1.0, 0, 3.6)]
		"raider":
			root.add_child(FX.mesh_node(FX.cylinder(0.2, 1.1, 6.0, 8), hull, Vector3.ZERO, Vector3.ONE, Vector3(-PI / 2, 0, 0)))
			root.add_child(FX.mesh_node(FX.box(Vector3(6.0, 0.25, 1.6)), dark, Vector3(0, 0, 1.4), Vector3.ONE, Vector3(0, 0, 0)))
			root.add_child(FX.mesh_node(FX.box(Vector3(0.25, 2.0, 1.4)), dark, Vector3(0, 0.9, 2.0)))
			root.add_child(FX.mesh_node(FX.sphere(0.55, 10), glass, Vector3(0, 0.45, -0.8), Vector3(1, 0.7, 1.6)))
			hardpoints = [Vector3(-2.6, 0, 0.6), Vector3(2.6, 0, 0.6), Vector3(0, -0.6, -2.4)]
			engines = [Vector3(0, 0, 3.0)]
		"boss":
			root.add_child(FX.mesh_node(FX.box(Vector3(10, 5, 34)), hull))
			root.add_child(FX.mesh_node(FX.box(Vector3(26, 2, 10)), dark, Vector3(0, 0, 6)))
			root.add_child(FX.mesh_node(FX.box(Vector3(6, 4, 8)), dark, Vector3(0, 4, 8)))
			root.add_child(FX.mesh_node(FX.box(Vector3(3, 1.5, 3)), glass, Vector3(0, 6.5, 6)))
			root.add_child(FX.mesh_node(FX.cylinder(2.5, 3.5, 6, 12), dark, Vector3(-12, 0, 6), Vector3.ONE, Vector3(PI / 2, 0, 0)))
			root.add_child(FX.mesh_node(FX.cylinder(2.5, 3.5, 6, 12), dark, Vector3(12, 0, 6), Vector3.ONE, Vector3(PI / 2, 0, 0)))
			hardpoints = [Vector3(-12, 0, -2), Vector3(12, 0, -2), Vector3(0, 3, -16), Vector3(-5, -2.5, -14), Vector3(5, -2.5, -14)]
			engines = [Vector3(-12, 0, 9.5), Vector3(12, 0, 9.5), Vector3(0, 0, 17.5)]
		"jammer":
			var red := FX.glow_mat(Color(1.0, 0.15, 0.2), 5.0)
			root.add_child(FX.mesh_node(FX.sphere(5.0, 16), red))
			root.add_child(FX.mesh_node(FX.torus(7.0, 9.0, 24), dark))
			for axis in [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]:
				root.add_child(FX.mesh_node(FX.box(axis * 26.0 + (Vector3.ONE - axis) * 1.6), hull))
				root.add_child(FX.mesh_node(FX.sphere(1.6, 8), red, axis * 13.5))
				root.add_child(FX.mesh_node(FX.sphere(1.6, 8), red, -axis * 13.5))
			engines = []
		"freighter":
			root.add_child(FX.mesh_node(FX.box(Vector3(4, 4, 16)), hull))
			for i in 3:
				root.add_child(FX.mesh_node(FX.box(Vector3(5, 5, 3.5)), dark, Vector3(0, 0, -4 + i * 4.5)))
			root.add_child(FX.mesh_node(FX.box(Vector3(2, 1.4, 2.5)), glass, Vector3(0, 2.6, -6.5)))
			hardpoints = [Vector3(0, 2.5, -8)]
			engines = [Vector3(-1.2, 0, 8.2), Vector3(1.2, 0, 8.2)]
		_:  # "fighter"
			root.add_child(FX.mesh_node(FX.box(Vector3(1.4, 0.9, 5.5)), hull))
			root.add_child(FX.mesh_node(FX.box(Vector3(1.0, 0.6, 1.8)), hull, Vector3(0, 0, -3.4), Vector3(0.8, 0.8, 1)))
			root.add_child(FX.mesh_node(FX.sphere(0.5, 12), glass, Vector3(0, 0.55, -1.2), Vector3(1, 0.8, 1.8)))
			root.add_child(FX.mesh_node(FX.box(Vector3(6.2, 0.18, 2.0)), dark, Vector3(0, -0.1, 0.9)))
			root.add_child(FX.mesh_node(FX.box(Vector3(0.3, 1.0, 1.6)), dark, Vector3(-3.0, 0.4, 1.2)))
			root.add_child(FX.mesh_node(FX.box(Vector3(0.3, 1.0, 1.6)), dark, Vector3(3.0, 0.4, 1.2)))
			root.add_child(FX.mesh_node(FX.box(Vector3(0.25, 1.1, 1.4)), dark, Vector3(0, 0.8, 2.2)))
			hardpoints = [Vector3(-1.9, -0.2, -0.6), Vector3(1.9, -0.2, -0.6), Vector3(0, -0.6, -2.6)]
			engines = [Vector3(-0.45, 0, 2.85), Vector3(0.45, 0, 2.85)]

	for e in engines:
		var size := 0.45 if style == "fighter" or style == "raider" else 1.2
		if style == "boss":
			size = 2.5
		var g := FX.mesh_node(FX.sphere(size, 10), glow, e, Vector3(1, 1, 1.6))
		g.name = "EngineGlow"
		root.add_child(g)
	root.set_meta("hardpoints", hardpoints)
	root.set_meta("engines", engines)
	return root
