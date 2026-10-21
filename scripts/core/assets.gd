class_name Assets
extends RefCounted
## Loads optional art and sound from res://assets/. Everything here is a
## drop-in: if a file is missing the game falls back to its built-in shapes,
## so you can swap any model or sound by replacing the file with the same name.
##
##   assets/ships/<name>.glb + <name>.json   ship models (+ size and engine data)
##   assets/models/<name>.glb                props, asteroids
##   assets/sounds/<name>.ogg                sound effects

const SHIP_DIR := "res://assets/ships/"
const MODEL_DIR := "res://assets/models/"
const SOUND_DIR := "res://assets/sounds/"

static var _scenes: Dictionary = {}
static var _meta: Dictionary = {}
static var _meshes: Dictionary = {}
static var _sounds: Dictionary = {}


static func _scene(path: String) -> PackedScene:
	if _scenes.has(path):
		return _scenes[path]
	var s: PackedScene = null
	if ResourceLoader.exists(path):
		s = load(path) as PackedScene
	_scenes[path] = s
	return s


static func ship_meta(name: String) -> Dictionary:
	if _meta.has(name):
		return _meta[name]
	var d: Dictionary = {}
	var path := SHIP_DIR + name + ".json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			d = parsed
	_meta[name] = d
	return d


## A ship model scaled to `length` metres, facing -Z, with "hardpoints" and
## "engines" meta like ShipMesh.build. Returns null if the model is missing.
static func ship(name: String, length: float, engine_color: Color) -> Node3D:
	var scene := _scene(SHIP_DIR + name + ".glb")
	var meta := ship_meta(name)
	if scene == null or meta.is_empty():
		return null
	var size := Vector3(meta["size"][0], meta["size"][1], meta["size"][2])
	var s := length / maxf(0.1, size.z)
	var root := Node3D.new()
	var inst := scene.instantiate() as Node3D
	inst.rotation.y = PI          # Shipyard exports nose toward +Z
	inst.scale = Vector3.ONE * s
	root.add_child(inst)
	var w := size.x * s
	var h := size.y * s
	var l := size.z * s
	var hardpoints: Array = [Vector3(-w * 0.28, -h * 0.1, -l * 0.3), Vector3(w * 0.28, -h * 0.1, -l * 0.3),
		Vector3(0, -h * 0.25, -l * 0.42)]
	if l > 40.0:   # capital ships: batteries along the hull
		hardpoints.append_array([Vector3(-w * 0.4, h * 0.2, -l * 0.1), Vector3(w * 0.4, h * 0.2, -l * 0.1)])
	var engines: Array = []
	var glow := FX.glow_mat(engine_color, 5.0)
	for e in meta.get("engines", []):
		# Rotated 180° about Y: x and z flip.
		var p := Vector3(-float(e["x"]), float(e["y"]), -float(e["z"])) * s
		engines.append(p)
		var r := maxf(0.2, float(e.get("r", 0.5)) * s * 0.45)
		var g := FX.mesh_node(FX.sphere(r, 10), glow, p + Vector3(0, 0, r * 0.6), Vector3(1, 1, 1.6))
		g.name = "EngineGlow%d" % engines.size()
		root.add_child(g)
	root.set_meta("hardpoints", hardpoints)
	root.set_meta("engines", engines)
	return root


static func model(name: String) -> Node3D:
	var scene := _scene(MODEL_DIR + name + ".glb")
	return scene.instantiate() as Node3D if scene else null


## First mesh in a model plus the scale that makes it 2 units across
## (radius 1), for MultiMesh asteroid fields. [] if missing.
static func unit_mesh(name: String) -> Array:
	if _meshes.has(name):
		return _meshes[name]
	var out: Array = []
	var inst := model(name)
	if inst:
		var mi := _find_mesh(inst)
		if mi and mi.mesh:
			var aabb := mi.mesh.get_aabb()
			var longest := maxf(0.01, aabb.get_longest_axis_size())
			out = [mi.mesh, 2.0 / longest, aabb.get_center()]
		inst.free()
	_meshes[name] = out
	return out


static func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := _find_mesh(c)
		if m:
			return m
	return null


static func sound(name: String) -> AudioStream:
	if _sounds.has(name):
		return _sounds[name]
	var path := SOUND_DIR + name + ".ogg"
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_sounds[name] = s
	return s
