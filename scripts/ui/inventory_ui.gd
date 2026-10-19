class_name InventoryUI
extends Control
## Ship loadout and cargo hold. When docked it also shows the station's
## shop: sell cargo, buy items and repair the hull.

signal closed
signal jettison(item: Item)

var station: Station
var tooltip: ItemTooltip
var _body: HBoxContainer
var _title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var m := UITheme.modal("", 1180, 660)
	var root: Control = m[0]
	var vb: VBoxContainer = m[1]
	add_child(root)
	_title = UITheme.label("", 26, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(_title)
	vb.add_child(HSeparator.new())
	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_body)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(bottom)
	bottom.add_child(UITheme.label("Left-click: equip / unequip / buy    Right-click: %s" % ("sell" if station else "jettison"), 14, Color(0.6, 0.65, 0.7)))
	bottom.add_child(UITheme.button("Close", func(): closed.emit(), 140))
	tooltip = ItemTooltip.new()
	add_child(tooltip)
	Run.loadout_changed.connect(refresh)
	Run.credits_changed.connect(refresh)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		closed.emit()


func refresh() -> void:
	if _body == null:
		return
	tooltip.hide_item()
	for c in _body.get_children():
		c.queue_free()
	_title.text = (station.station_name if station else "Ship & Cargo") + "      ·      %d credits" % Run.credits
	_body.add_child(_equipped_column())
	_body.add_child(VSeparator.new())
	_body.add_child(_cargo_column())
	if station:
		_body.add_child(VSeparator.new())
		_body.add_child(_shop_column())


func _equipped_column() -> Control:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = 340
	vb.add_child(UITheme.label("%s — Loadout" % Run.hull_def["name"], 20, UITheme.ACCENT))
	var keys: Array = []
	for i in int(Run.hull_def["hardpoints"]):
		keys.append("weapon%d" % i)
	keys.append_array(["shield", "engine", "armor", "core"])
	for k in keys:
		var item: Item = Run.loadout.get(k)
		var slot_name: String = "Hardpoint %d" % (int(k.substr(6)) + 1) if k.begins_with("weapon") else ItemBases.SLOT_NAMES[k]
		vb.add_child(UITheme.label(slot_name, 13, Color(0.55, 0.6, 0.65)))
		if item:
			var b := _item_button(item)
			b.pressed.connect(func(): Run.unequip(k))
			vb.add_child(b)
		else:
			var b := Button.new()
			b.text = "(empty)"
			b.disabled = true
			vb.add_child(b)
	vb.add_child(HSeparator.new())
	var s := Run.stats
	var dps := 0.0
	for w in s.weapons:
		dps += ShipStats.weapon_dps(w)
	var lines := [
		"Hull %d / %d   Shield %d" % [int(Run.hull), int(s.max_hull), int(s.max_shield)],
		"Weapon DPS ≈ %d   Damage Reduction %d%%" % [int(dps), int(s.damage_reduction)],
		"Speed %d m/s   Turn %.2f   Power %d (+%d/s)" % [int(s.top_speed), s.turn_rate, int(s.max_power), int(s.power_regen)],
		"Loot Find +%d%%   Credit Find +%d%%" % [int(s.loot_find), int(s.credit_find)],
	]
	if s.leech > 0.0 or s.hull_regen > 0.0:
		lines.append("Leech %.1f%%   Hull Repair %.1f/s" % [s.leech, s.hull_regen])
	for l in lines:
		vb.add_child(UITheme.label(l, 14))
	return vb


func _cargo_column() -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(UITheme.label("Cargo Hold  (%d / %d)" % [Run.cargo.size(), Run.CARGO_SIZE], 20, UITheme.ACCENT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2 if station else 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for item in Run.cargo.duplicate():
		var b := _item_button(item, "Sells for %d credits" % item.value() if station else "")
		b.custom_minimum_size.x = 250
		b.gui_input.connect(func(ev): _cargo_click(ev, item))
		grid.add_child(b)
	if Run.cargo.is_empty():
		vb.add_child(UITheme.label("Empty. Destroy pirates and tractor in their loot with T.", 14, Color(0.55, 0.6, 0.65)))
	return vb


func _shop_column() -> Control:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = 300
	vb.add_child(UITheme.label("Equipment Dealer", 20, UITheme.ACCENT))
	for item in station.stock.duplicate():
		var price := Station.buy_price(item)
		var b := _item_button(item, "Price: %d credits" % price)
		b.disabled = Run.credits < price
		b.pressed.connect(func(): _buy(item, price))
		vb.add_child(b)
	vb.add_child(HSeparator.new())
	var missing := Run.stats.max_hull - Run.hull
	var cost := int(ceil(missing * 0.6))
	var repair := UITheme.button("Repair hull (%d credits)" % cost if missing > 0.5 else "Hull fully repaired", func(): _repair(cost))
	repair.disabled = missing <= 0.5 or Run.credits < cost
	vb.add_child(repair)
	return vb


func _item_button(item: Item, extra: String = "") -> Button:
	var b := Button.new()
	b.text = item.display_name()
	b.add_theme_color_override("font_color", item.color())
	b.add_theme_color_override("font_hover_color", item.color().lightened(0.3))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.mouse_entered.connect(func(): tooltip.show_item(item, _equipped_for(item), extra))
	b.mouse_exited.connect(func(): tooltip.hide_item())
	return b


func _equipped_for(item: Item) -> Item:
	var keys := Run.slots_for(item)
	for k in keys:
		var e: Item = Run.loadout.get(k)
		if e != null and e != item:
			return e
	return null


func _cargo_click(ev: InputEvent, item: Item) -> void:
	if not (ev is InputEventMouseButton and ev.pressed):
		return
	if ev.button_index == MOUSE_BUTTON_LEFT:
		Run.equip(item)
	elif ev.button_index == MOUSE_BUTTON_RIGHT:
		if station:
			Run.sell(item)
		else:
			Run.cargo.erase(item)
			jettison.emit(item)
			refresh()


func _buy(item: Item, price: int) -> void:
	if Run.credits < price or Run.cargo.size() >= Run.CARGO_SIZE:
		return
	station.stock.erase(item)
	Run.credits -= price
	Run.cargo.append(item)
	Run.credits_changed.emit()


func _repair(cost: int) -> void:
	if Run.credits < cost:
		return
	Run.credits -= cost
	Run.hull = Run.stats.max_hull
	Run.credits_changed.emit()
