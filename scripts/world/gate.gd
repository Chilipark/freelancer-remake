class_name JumpGate
extends Node3D
## A jump gate ring. Flying through the middle jumps to `target_id`.

signal entered(gate: JumpGate)

const RING_RADIUS := 45.0

var target_id := -1
var label_text := ""
var color := Color(0.5, 0.8, 1.0)
var used := false
var _player_side := 0.0


func setup(node: Dictionary) -> void:
	target_id = node["id"]
	color = RunMap.TYPE_COLORS[node["type"]]
	label_text = "%s\n%s · Level %d" % [node["name"], RunMap.TYPE_NAMES[node["type"]], node["level"]]
	if node["type"] == "event":
		label_text = "%s\n??? · Level %d" % [node["name"], node["level"]]


func _ready() -> void:
	add_to_group("gates")
	var frame := FX.mat(Color(0.35, 0.37, 0.42), 0.0, 0.7, 0.4)
	add_child(FX.mesh_node(FX.torus(RING_RADIUS, RING_RADIUS + 7.0, 48), frame, Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0)))
	add_child(FX.mesh_node(FX.torus(RING_RADIUS - 2.0, RING_RADIUS, 48), FX.glow_mat(color, 3.0), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0)))
	var field := FX.mesh_node(FX.cylinder(RING_RADIUS - 2.0, RING_RADIUS - 2.0, 0.5, 32), FX.glow_mat(color, 1.2, 0.12), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0))
	add_child(field)
	for i in 4:
		var a := i * PI / 2.0 + PI / 4.0
		add_child(FX.mesh_node(FX.box(Vector3(10, 10, 14)), frame, Vector3(cos(a), sin(a), 0) * (RING_RADIUS + 6.0)))
		add_child(FX.mesh_node(FX.sphere(2.0, 8), FX.glow_mat(color, 5.0), Vector3(cos(a), sin(a), 0) * (RING_RADIUS + 6.0) + Vector3(0, 0, -7.5)))
	var label := Label3D.new()
	label.text = label_text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.5
	label.font_size = 48
	label.outline_size = 12
	label.modulate = color
	label.position = Vector3(0, RING_RADIUS + 30.0, 0)
	label.no_depth_test = true
	label.fixed_size = false
	add_child(label)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0
	light.omni_range = 220.0
	add_child(light)


## Called by the sector each frame with the player's position.
func check_player(pos: Vector3) -> void:
	if used:
		return
	var local := to_local(pos)
	var side := signf(local.z)
	var inside := Vector2(local.x, local.y).length() < RING_RADIUS - 3.0
	if inside and absf(local.z) < 30.0 and _player_side != 0.0 and side != _player_side:
		used = true
		entered.emit(self)
	if absf(local.z) < 200.0:
		_player_side = side if side != 0.0 else _player_side
	else:
		_player_side = 0.0
