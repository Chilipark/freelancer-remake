class_name EventUI
extends Control
## FTL-style event dialog: story text and choices, then the outcome.

signal chosen(index: int)
signal closed

var event_def: Dictionary = {}
var level := 1
var _vb: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var m := UITheme.modal(String(event_def["title"]), 720, 360)
	add_child(m[0])
	_vb = m[1]
	var text := UITheme.label(String(event_def["text"]), 18)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 680
	_vb.add_child(text)
	_vb.add_child(HSeparator.new())
	for i in event_def["choices"].size():
		var idx: int = i
		_vb.add_child(UITheme.button("%d. %s" % [i + 1, SectorEvents.choice_label(event_def, i, level)], func(): chosen.emit(idx)))


func show_result(text: String) -> void:
	for c in _vb.get_children():
		if c is Button:
			c.queue_free()
	var l := UITheme.label(text, 18, Color(1, 0.9, 0.6))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 680
	_vb.add_child(l)
	_vb.add_child(UITheme.button("Continue", func(): closed.emit()))
