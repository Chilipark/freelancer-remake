class_name InputSetup
extends RefCounted
## Registers the game's input actions in code (Freelancer-like defaults).

const KEYS := {
	"throttle_up": [KEY_W],
	"throttle_down": [KEY_S],
	"strafe_left": [KEY_A],
	"strafe_right": [KEY_D],
	"roll_left": [KEY_Q],
	"roll_right": [KEY_E],
	"afterburner": [KEY_TAB],
	"cruise": [KEY_C],
	"mouse_flight": [KEY_SPACE],
	"tractor": [KEY_T],
	"interact": [KEY_F],
	"target_next": [KEY_R],
	"inventory": [KEY_I],
	"map": [KEY_M],
	"pause": [KEY_ESCAPE],
	"full_stop": [KEY_BACKSPACE],
	"autopilot": [KEY_G],
	"journal": [KEY_J],
}


static func ensure() -> void:
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", mb)
