extends SceneTree
## Renders a few in-game screenshots (needs a display, e.g. xvfb-run):
##   godot --path . --rendering-method gl_compatibility --script res://tests/screenshot.gd -- <out_dir>

func _initialize() -> void:
	_run.call_deferred()


func _snap(path: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	InputSetup.ensure()
	root.get_node("Meta").save_path = "user://shot_meta.cfg"
	var run = root.get_node("Run")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)
	main.start_run("kestrel")
	var world = main._screen
	await _frames(30)
	var galaxy = world.galaxy
	var p = world.player
	p.controls_enabled = false
	# Look down a trade lane from just before its first ring.
	var L: Dictionary = galaxy.lanes[0]
	var dir: Vector3 = L["dir"]
	var side: Vector3 = dir.cross(Vector3.UP).normalized()
	var pos: Vector3 = L["start"] - dir * 350.0 + side * 60.0 + Vector3(0, 25, 0)
	p.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), galaxy.to_local_pos(pos))
	p.flight.velocity = Vector3.ZERO
	p.flight.throttle = 0.0
	world.camera.snap()
	await _frames(20)
	await _snap(out + "/lane.png")
	# Ride the lane.
	galaxy.start_trip(0, 0.0, 1)
	galaxy.trip["stop_t"] = L["length"]
	galaxy.trip["speed"] = 2200.0
	await _frames(40)
	await _snap(out + "/lane_ride.png")
	galaxy._end_trip("ambush")
	await _frames(40)
	var target = null
	for n in get_nodes_in_group("jammers"):
		target = n
	if target:
		p.target = target
		p.look_at(target.position, Vector3.UP)
		world.camera.snap()
	await _frames(20)
	await _snap(out + "/ambush.png")
	run.waypoint = run.map.nodes[-1]["id"]
	world._open_map()
	await _snap(out + "/navmap.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_meta.cfg"))
	quit()
