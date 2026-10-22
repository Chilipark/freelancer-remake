extends Node
## Root of the game: switches between the main menu and a run.

var _screen: Node


func _ready() -> void:
	InputSetup.ensure()
	show_menu()
	# "-- --autostart" skips the menu (handy for quick testing).
	if "--autostart" in OS.get_cmdline_user_args():
		start_run.call_deferred("kestrel")


func show_menu() -> void:
	_swap(MainMenu.new())
	(_screen as MainMenu).start_run.connect(start_run)


func start_run(hull_id: String) -> void:
	Run.start(hull_id)
	var world := GameWorld.new()
	_swap(world)
	world.run_ended.connect(show_menu)


func _swap(n: Node) -> void:
	get_tree().paused = false
	if _screen:
		_screen.queue_free()
	_screen = n
	add_child(n)
