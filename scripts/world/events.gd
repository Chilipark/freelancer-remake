class_name SectorEvents
extends RefCounted
## FTL-style sector events. Each has text and choices; `resolve` applies the
## outcome through the game world (`ctx`) and returns the result text.
##
## ctx must provide: spawn_pirates(count, rank), drop_loot(source, count),
## add_credits(amount), damage_player(fraction), add_buff(stat, value),
## spend_credits(amount) -> bool, level() -> int, rng() -> RandomNumberGenerator

const LIST := [
	{"id": "derelict", "title": "Derelict Freighter", "model": "freighter",
		"text": "A gutted freighter drifts silently, its cargo bay torn open. Something might still be aboard. Or someone.",
		"choices": ["Board and search the wreck", "Leave it be"]},
	{"id": "distress", "title": "Distress Call", "model": "freighter",
		"text": "\"Mayday! Pirates are boarding us, any pilot please respond!\" A merchant hauler is limping through the sector.",
		"choices": ["Fight off the pirates", "Ignore the call"]},
	{"id": "mining", "title": "Rich Asteroid Field", "model": "rocks",
		"text": "Your scanner lights up: the rocks here are veined with platinum. Mining them fast would be lucrative, and dangerous.",
		"choices": ["Mine aggressively", "Survey carefully", "Move on"]},
	{"id": "anomaly", "title": "Strange Anomaly", "model": "anomaly",
		"text": "A shimmering rift hangs in space, pulsing with light. Your instruments can't make sense of it.",
		"choices": ["Fly into the rift", "Scan it from a distance"]},
	{"id": "cache", "title": "Smuggler's Cache", "model": "crate",
		"text": "A locked smuggler's container, transponder still pinging. The lock wants a credit transfer. Or a few rounds of ammunition.",
		"choices": ["Pay to unlock it", "Shoot it open", "Leave it"]},
	{"id": "graveyard", "title": "Ship Graveyard", "model": "rocks",
		"text": "Wrecks of a fleet battle fill the sector. Salvage is everywhere, but so are the scavengers who claim it.",
		"choices": ["Salvage the wrecks", "Pass through quietly"]},
]


static func pick(rng: RandomNumberGenerator) -> Dictionary:
	return LIST[rng.randi_range(0, LIST.size() - 1)]


static func cache_price(level: int) -> int:
	return 60 + level * 25


static func choice_label(ev: Dictionary, i: int, level: int) -> String:
	var s: String = ev["choices"][i]
	if ev["id"] == "cache" and i == 0:
		s += " (%d credits)" % cache_price(level)
	return s


static func resolve(ev: Dictionary, choice: int, ctx) -> String:
	var rng: RandomNumberGenerator = ctx.rng()
	var lvl: int = ctx.level()
	match ev["id"]:
		"derelict":
			if choice == 1:
				return "You leave the wreck to its ghosts."
			if rng.randf() < 0.6:
				ctx.drop_loot(LootGenerator.Source.CACHE, rng.randi_range(1, 2))
				ctx.add_credits(20 + lvl * 8)
				return "Your crew finds sealed crates still intact. Loot ejected!"
			ctx.spawn_pirates(3, "normal")
			ctx.drop_loot(LootGenerator.Source.CACHE, 1)
			return "It's a trap! Pirates power up from behind the wreck!"
		"distress":
			if choice == 1:
				return "The calls fade into static behind you."
			ctx.spawn_pirates(2 + lvl / 6, "normal")
			ctx.spawn_pirates(1, "elite" if lvl >= 8 else "normal")
			ctx.add_credits(40 + lvl * 15)
			ctx.drop_loot(LootGenerator.Source.ELITE, 1)
			return "\"Thank you, pilot! Take this for your trouble.\" The pirates turn on you!"
		"mining":
			if choice == 0:
				ctx.damage_player(rng.randf_range(0.1, 0.25))
				ctx.add_credits(rng.randi_range(80, 160) + lvl * 20)
				return "Rocks scrape your hull as you strip the field. The ore sells well."
			if choice == 1:
				ctx.add_credits(rng.randi_range(30, 60) + lvl * 8)
				return "A careful survey yields a modest haul."
			return "You leave the rocks for someone else."
		"anomaly":
			if choice == 1:
				ctx.add_credits(25 + lvl * 5)
				return "The scan data will fetch a fair price with researchers."
			var roll := rng.randf()
			if roll < 0.25:
				ctx.add_buff("all_damage_pct", 15.0)
				return "Energy surges through your weapons. +15% damage for the rest of the run!"
			if roll < 0.5:
				ctx.add_buff("max_hull_pct", 15.0)
				return "Your hull plating fuses stronger. +15% hull for the rest of the run!"
			if roll < 0.7:
				ctx.add_buff("loot_find", 30.0)
				return "Your scanners are rewired by the rift. +30% loot find for the rest of the run!"
			ctx.damage_player(0.3)
			return "The rift tears at your ship! Heavy hull damage."
		"cache":
			if choice == 0:
				if ctx.spend_credits(cache_price(lvl)):
					ctx.drop_loot(LootGenerator.Source.BOSS, 1)
					return "The lock clicks open. Premium goods inside!"
				return "You can't afford it."
			if choice == 1:
				if rng.randf() < 0.5:
					ctx.drop_loot(LootGenerator.Source.NORMAL, 1)
					return "The container cracks open. Some of it survived."
				return "The container explodes. Nothing salvageable."
			return "You leave the cache."
		"graveyard":
			if choice == 1:
				return "You slip through the wreckage unnoticed."
			ctx.drop_loot(LootGenerator.Source.CACHE, 2)
			ctx.spawn_pirates(2 + lvl / 5, "normal")
			return "You haul in salvage, and the scavengers come for you!"
	return ""
