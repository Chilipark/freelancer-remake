class_name Station
extends Node3D
## A trade station. Fly close and press F to dock.

const DOCK_RANGE := 260.0

var station_name := "Station"
var stock: Array = []


func _ready() -> void:
	add_to_group("stations")
	add_to_group("obstacles")
	set_meta("radius", 70.0)
	var hull := FX.mat(Color(0.62, 0.64, 0.68), 0.0, 0.7, 0.35)
	var dark := FX.mat(Color(0.3, 0.32, 0.36), 0.0, 0.6, 0.5)
	var lights := FX.glow_mat(Color(0.5, 1.0, 0.6), 4.0)
	add_child(FX.mesh_node(FX.cylinder(22, 22, 120, 20), hull))
	add_child(FX.mesh_node(FX.torus(90, 104, 64), dark, Vector3.ZERO, Vector3.ONE))
	for i in 4:
		var a := i * PI / 2.0
		add_child(FX.mesh_node(FX.box(Vector3(70, 6, 6)), dark, Vector3(cos(a), 0, sin(a)) * 55.0, Vector3.ONE, Vector3(0, -a, 0)))
	add_child(FX.mesh_node(FX.sphere(34, 20), hull, Vector3(0, 60, 0), Vector3(1, 0.6, 1)))
	add_child(FX.mesh_node(FX.cylinder(4, 4, 70, 8), dark, Vector3(0, 110, 0)))
	for i in 12:
		var a := i * TAU / 12.0
		add_child(FX.mesh_node(FX.sphere(2.2, 8), lights, Vector3(cos(a) * 104, 0, sin(a) * 104)))
	# Kenney satellite dishes and turrets, if the models are present.
	for i in 2:
		var dish := Assets.model("satellitedish-large")
		if dish:
			dish.scale = Vector3.ONE * 22.0
			dish.position = Vector3(0, 95, 0) if i == 0 else Vector3(0, -62, 0)
			dish.rotation = Vector3(0 if i == 0 else PI, 0, 0)
			add_child(dish)
	for i in 4:
		var turret := Assets.model("turret-double")
		if turret:
			var a := i * PI / 2.0 + PI / 4.0
			turret.scale = Vector3.ONE * 10.0
			turret.position = Vector3(cos(a) * 97.0, 6.0, sin(a) * 97.0)
			add_child(turret)
	var label := Label3D.new()
	label.text = station_name + "\n[F] Dock"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.6
	label.font_size = 48
	label.outline_size = 12
	label.modulate = Color(0.5, 1.0, 0.6)
	label.position = Vector3(0, 170, 0)
	label.no_depth_test = true
	add_child(label)
	var light := OmniLight3D.new()
	light.light_color = Color(0.8, 0.95, 1.0)
	light.light_energy = 4.0
	light.omni_range = 500.0
	light.position = Vector3(0, 30, 0)
	add_child(light)


func _process(dt: float) -> void:
	rotate_y(dt * 0.05)


## Vendor stock, like Diablo's Griswold: magic-only items around the sector level.
func generate_stock(level: int, rng: RandomNumberGenerator) -> void:
	stock.clear()
	for i in 8:
		stock.append(LootGenerator.generate(level, LootGenerator.Source.VENDOR, rng))


static func buy_price(item: Item) -> int:
	return item.value() * 3
