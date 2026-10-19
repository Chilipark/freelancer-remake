class_name EndScreen
extends Control
## Shown when the run ends, in death or victory.

signal done

var won := false
var earned := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var m := UITheme.modal("", 620, 380)
	add_child(m[0])
	var vb: VBoxContainer = m[1]
	vb.add_child(UITheme.label("VICTORY" if won else "SHIP DESTROYED", 44,
		Color(1, 0.85, 0.3) if won else Color(1, 0.35, 0.3), HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(UITheme.label("You escaped the Warlord's Bastion!" if won else "Your run ends in %s." % Run.current_node()["name"],
		18, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(HSeparator.new())
	for l in [
		"Sectors reached: %d / %d" % [Run.depth() + 1, RunMap.DEPTH],
		"Pirates destroyed: %d   (elites %d, bosses %d)" % [Run.kills, Run.elites_killed, Run.bosses_killed],
		"Credits held: %d" % Run.credits,
	]:
		vb.add_child(UITheme.label(l, 17, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(HSeparator.new())
	vb.add_child(UITheme.label("+%d salvage  (total %d)" % [earned, Meta.salvage], 24, Color(1, 0.85, 0.4), HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(UITheme.label("Spend salvage in the Hangar on permanent upgrades and new ships.", 14, Color(0.6, 0.65, 0.7), HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(UITheme.button("Return to Hangar", func(): done.emit()))
