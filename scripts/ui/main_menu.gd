class_name MainMenu
extends Control
## Title screen: pick a ship, spend salvage in the Hangar, start a run.

signal start_run(hull_id: String)

var _content: VBoxContainer
var _selected := "kestrel"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.03)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_content = VBoxContainer.new()
	_content.custom_minimum_size = Vector2(760, 0)
	center.add_child(_content)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_main()


func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()


func show_main() -> void:
	_clear()
	_content.add_child(UITheme.label("STARLANE ROGUE", 54, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	_content.add_child(UITheme.label("A Freelancer-style roguelite", 18, Color(0.6, 0.7, 0.8), HORIZONTAL_ALIGNMENT_CENTER))
	_content.add_child(HSeparator.new())
	_content.add_child(UITheme.label("Salvage: %d     Runs: %d     Wins: %d     Deepest sector: %d" % [Meta.salvage, Meta.runs, Meta.wins, Meta.best_depth + 1],
		16, Color(1, 0.85, 0.4), HORIZONTAL_ALIGNMENT_CENTER))
	_content.add_child(HSeparator.new())
	_content.add_child(UITheme.label("Choose your ship", 20, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	for h in Hulls.LIST:
		var row := HBoxContainer.new()
		var unlocked: bool = h["id"] in Meta.unlocked_hulls
		var info := UITheme.label("%s — %s\nHull %d · Speed %d · Hardpoints %d" % [h["name"], h["desc"], int(h["hull"]), int(h["speed"]), h["hardpoints"]], 15,
			UITheme.TEXT if unlocked else Color(0.5, 0.5, 0.55))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		if unlocked:
			var id: String = h["id"]
			var b := UITheme.button("Selected" if _selected == id else "Select", _select.bind(id), 150)
			b.disabled = _selected == id
			row.add_child(b)
		else:
			var id2: String = h["id"]
			var ub := UITheme.button("Unlock (%d salvage)" % h["cost"], _unlock.bind(id2), 150)
			ub.disabled = Meta.salvage < int(h["cost"])
			row.add_child(ub)
		_content.add_child(row)
	_content.add_child(HSeparator.new())
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(UITheme.button("Launch", func(): start_run.emit(_selected), 200))
	buttons.add_child(UITheme.button("Hangar Upgrades", show_hangar, 200))
	buttons.add_child(UITheme.button("Controls", show_controls, 140))
	buttons.add_child(UITheme.button("Quit", func(): get_tree().quit(), 120))
	_content.add_child(buttons)


func show_hangar() -> void:
	_clear()
	_content.add_child(UITheme.label("HANGAR", 40, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	_content.add_child(UITheme.label("Salvage: %d" % Meta.salvage, 18, Color(1, 0.85, 0.4), HORIZONTAL_ALIGNMENT_CENTER))
	_content.add_child(HSeparator.new())
	for u in Meta.UPGRADES:
		var row := HBoxContainer.new()
		var id: String = u["id"]
		var lvl := Meta.level(id)
		var info := UITheme.label("%s  [%d/%d]\n%s" % [u["name"], lvl, u["max"], u["desc"]], 15)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var maxed := lvl >= int(u["max"])
		var b := UITheme.button("Maxed" if maxed else "Buy (%d)" % Meta.upgrade_cost(id), _buy.bind(id), 140)
		b.disabled = not Meta.can_upgrade(id)
		row.add_child(b)
		_content.add_child(row)
	_content.add_child(HSeparator.new())
	_content.add_child(UITheme.button("Back", show_main))


func show_controls() -> void:
	_clear()
	_content.add_child(UITheme.label("CONTROLS", 40, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var lines := [
		"Mouse — steer toward the cursor (Space toggles mouse flight)",
		"Left mouse — fire guns at the cursor (they swivel a little)",
		"W / S — throttle up / down        Backspace — full stop",
		"Shift+W or C — cruise (charges for 5 s, 300 m/s, guns offline)",
		"Tab — afterburner (drains power)        A / D — strafe        Q / E — roll",
		"R — cycle target        T — tractor beam: pull in nearby loot",
		"F — dock at a station / investigate a signal",
		"I — cargo & loadout        M — sector map        Esc — pause",
		"",
		"Fly through a jump gate to move on. Each gate shows where it leads.",
		"Loot follows Diablo rules: white, blue (magic), yellow (rare), gold (unique).",
	]
	for l in lines:
		_content.add_child(UITheme.label(l, 16))
	_content.add_child(UITheme.button("Back", show_main))


func _select(id: String) -> void:
	_selected = id
	show_main()


func _unlock(id: String) -> void:
	Meta.unlock_hull(id)
	show_main()


func _buy(id: String) -> void:
	Meta.buy_upgrade(id)
	show_hangar()
