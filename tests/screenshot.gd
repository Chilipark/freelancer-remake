extends SceneTree
## Renders a few in-game screenshots (needs a display, e.g. xvfb-run):
##   godot --path . --script res://tests/screenshot.gd -- <out_dir>

func _initialize() -> void:
	_run.call_deferred()


func _snap(path: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	InputSetup.ensure()
	root.get_node("Meta").save_path = "user://shot_meta.cfg"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	await _snap(out + "/menu.png")
	main.start_run("kestrel")
	var world = main._screen
	for i in 60:
		await process_frame
	var p = world.player
	p.controls_enabled = false
	p.flight.throttle = 0.6
	p.target = null
	for e in get_nodes_in_group("ships"):
		if e != p:
			p.target = e
			break
	if p.target:
		p.look_at(p.target.global_position, Vector3.UP)
		p.global_position = p.target.global_position + Vector3(0, 20, 220)
		p.look_at(p.target.global_position, Vector3.UP)
		world.camera.snap()
	for i in 20:
		await process_frame
	p.fire(p.target.global_position if p.target else p.global_position - p.global_transform.basis.z * 300)
	for i in 6:
		await process_frame
	await _snap(out + "/flight.png")
	# Drop some loot and show it.
	var run = root.get_node("Run")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for src in [0, 1, 2, 2, 3]:
		world.sector.spawn_item(p.global_position + p.forward() * 120 + Vector3(rng.randf_range(-40, 40), 0, 0), LootGenerator.generate(12, src, rng, 100.0))
	for i in 30:
		await process_frame
	await _snap(out + "/loot.png")
	for i in 6:
		run.cargo.append(LootGenerator.generate(14, LootGenerator.Source.ELITE, rng, 100.0))
	world._open_inventory(null)
	for i in 5:
		await process_frame
	var inv = world.modal
	var tip: ItemTooltip = inv.tooltip
	tip.show_item(run.cargo[0], run.loadout.get("weapon0") if run.cargo[0].is_weapon() else run.loadout.get(run.cargo[0].slot()))
	tip.global_position = Vector2(820, 120)
	await _snap(out + "/inventory.png")
	world._close_modal()
	world._open_map()
	await _snap(out + "/map.png")
	world._close_modal()
	# A gate.
	var gate = get_nodes_in_group("gates").filter(func(g): return not g.used)[0]
	p.global_position = gate.global_transform * Vector3(0, 30, 420)
	p.look_at(gate.global_position, Vector3.UP)
	world.camera.snap()
	for i in 10:
		await process_frame
	await _snap(out + "/gate.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_meta.cfg"))
	quit()
