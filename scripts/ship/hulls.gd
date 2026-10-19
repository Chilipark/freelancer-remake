class_name Hulls
extends RefCounted
## Player ship types. Unlocked in the Hangar with salvage.

const LIST := [
	{"id": "kestrel", "name": "Kestrel", "desc": "Balanced light fighter. Two hardpoints.",
		"hull": 220.0, "power": 100.0, "power_regen": 30.0, "speed": 80.0, "turn": 1.8,
		"hardpoints": 2, "dr": 0.0, "cost": 0, "color": Color(0.75, 0.78, 0.85),
		"start": ["laser1", "laser1", "shield1", "engine1", "armor1", "core1"]},
	{"id": "warden", "name": "Warden", "desc": "Heavy gunboat. Tough and slow, built-in 6% damage reduction.",
		"hull": 360.0, "power": 120.0, "power_regen": 32.0, "speed": 66.0, "turn": 1.35,
		"hardpoints": 2, "dr": 6.0, "cost": 400, "color": Color(0.55, 0.62, 0.5),
		"start": ["mass1", "pulse1", "shield1", "engine1", "armor1", "core1"]},
	{"id": "marauder", "name": "Marauder", "desc": "Glass cannon. Fast, fragile, three hardpoints.",
		"hull": 160.0, "power": 140.0, "power_regen": 40.0, "speed": 92.0, "turn": 2.05,
		"hardpoints": 3, "dr": 0.0, "cost": 650, "color": Color(0.7, 0.3, 0.28),
		"start": ["laser1", "pulse1", "scatter1", "shield1", "engine1", "armor1", "core1"]},
]


static func get_hull(id: String) -> Dictionary:
	for h in LIST:
		if h["id"] == id:
			return h
	return LIST[0]
