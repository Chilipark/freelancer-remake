class_name LootGenerator
extends RefCounted
## Item generation following Diablo's rules (DevilutionX Source/items.cpp),
## with Diablo 2's rare tier added on top:
##
## 1. Unique check (CheckUnique): d100 <= uper, where uper is 1 for normal
##    enemies, 5 for elites and 15 for bosses. Boss drops get +4 item level.
## 2. Magic check (GetItemBLevel): d100 <= 10 or d100 <= item level, or
##    always when `onlygood` (bosses, vendors).
## 3. Magic items roll affixes from [ilvl/2, ilvl] (capped at 25), prefix
##    1 in 4, suffix 2 in 3, at least one (GetItemPowerPrefixAndSuffix).
## 4. Diablo 2 rare: some magic rolls are upgraded to rare, 3-6 affixes,
##    up to 3 prefixes and 3 suffixes, no repeated stat, random name.
## Loot find ("magic find") boosts the unique, magic and rare chances with
## diminishing returns, as in Diablo 2.

enum Source { NORMAL, ELITE, BOSS, VENDOR, CACHE }

const UPER := {Source.NORMAL: 1, Source.ELITE: 5, Source.BOSS: 15, Source.VENDOR: 0, Source.CACHE: 3}


static func generate(level: int, source: int, rng: RandomNumberGenerator,
		loot_find: float = 0.0, slot: String = "") -> Item:
	var item := Item.new()
	var onlygood := source == Source.BOSS or source == Source.VENDOR or source == Source.ELITE
	var ilvl := level + (4 if source == Source.BOSS else 0)
	item.ilvl = maxi(1, ilvl)
	var base := ItemBases.random_base(item.ilvl, rng, slot)
	item.base_id = base["id"]

	# Diablo 2 style diminishing magic find for uniques/rares.
	var mf_unique := 1.0 + (loot_find * 250.0) / (loot_find + 250.0) / 100.0
	var mf_magic := 1.0 + loot_find / 100.0

	# 1. Unique.
	var uper: float = UPER[source] * mf_unique
	if uper > 0 and rng.randi_range(1, 100) <= int(ceil(uper)):
		var pool := []
		for u in Uniques.candidates(item.ilvl):
			if slot == "" or ItemBases.get_base(u["base"])["slot"] == slot:
				pool.append(u)
		if not pool.is_empty():
			var u: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
			item.base_id = u["base"]
			item.rarity = Item.Rarity.UNIQUE
			item.unique_id = u["id"]
			for k in u["stats"]:
				item.affixes.append({"name": "", "stat": k, "value": float(u["stats"][k]), "prefix": true})
			return item

	# 2. Magic check.
	var magic := onlygood \
		or rng.randi_range(1, 100) <= int(10 * mf_magic) \
		or rng.randi_range(1, 100) <= int(item.ilvl * mf_magic)
	if not magic:
		return item

	var minlvl := mini(item.ilvl / 2, 25)
	var maxlvl := item.ilvl
	if source == Source.VENDOR:
		minlvl = maxlvl / 2

	# 4. Rare upgrade (chance grows with item level and loot find).
	var rare_chance := (8.0 + item.ilvl * 0.8) * mf_unique
	if source == Source.BOSS:
		rare_chance += 25.0
	elif source == Source.ELITE:
		rare_chance += 12.0
	if rng.randf() * 100.0 < rare_chance:
		_roll_rare(item, minlvl, maxlvl, onlygood, rng)
	else:
		_roll_magic(item, minlvl, maxlvl, onlygood, rng)
	return item


static func _roll_magic(item: Item, minlvl: int, maxlvl: int, onlygood: bool, rng: RandomNumberGenerator) -> void:
	item.rarity = Item.Rarity.MAGIC
	var slot := item.slot()
	var want_prefix := rng.randi_range(0, 3) == 0
	var want_suffix := rng.randi_range(0, 2) != 0
	if not want_prefix and not want_suffix:
		if rng.randi_range(0, 1) == 0:
			want_prefix = true
		else:
			want_suffix = true
	# Diablo: 2 in 3 magic items may only roll good affixes even off normal drops.
	var good := onlygood or rng.randi_range(0, 2) != 0
	if want_prefix:
		var p := Affixes.select(Affixes.PREFIXES, slot, minlvl, maxlvl, good, rng)
		if not p.is_empty():
			item.affixes.append(_make(p, true, rng))
	if want_suffix:
		var s := Affixes.select(Affixes.SUFFIXES, slot, minlvl, maxlvl, good, rng)
		if not s.is_empty():
			item.affixes.append(_make(s, false, rng))
	if item.affixes.is_empty():
		# Nothing fit the [ilvl/2, ilvl] window for this slot: widen it rather
		# than handing out a plain item from a magic roll.
		var table: Array = Affixes.SUFFIXES if rng.randi_range(0, 1) == 0 else Affixes.PREFIXES
		var a := Affixes.select(table, slot, 0, maxlvl, good, rng)
		if a.is_empty():
			table = Affixes.PREFIXES if table == Affixes.SUFFIXES else Affixes.SUFFIXES
			a = Affixes.select(table, slot, 0, maxlvl, good, rng)
		if a.is_empty():
			item.rarity = Item.Rarity.NORMAL
		else:
			item.affixes.append(_make(a, table == Affixes.PREFIXES, rng))


static func _roll_rare(item: Item, minlvl: int, maxlvl: int, _onlygood: bool, rng: RandomNumberGenerator) -> void:
	item.rarity = Item.Rarity.RARE
	var slot := item.slot()
	var count := rng.randi_range(3, 6)
	var prefixes := 0
	var suffixes := 0
	var used: Array = []
	for i in count:
		var as_prefix := rng.randi_range(0, 1) == 0
		if prefixes >= 3:
			as_prefix = false
		if suffixes >= 3:
			as_prefix = true
		var table: Array = Affixes.PREFIXES if as_prefix else Affixes.SUFFIXES
		# Rares draw from the full range up to the item level (no cursed affixes).
		var a := Affixes.select(table, slot, 0, maxlvl, true, rng, used)
		if a.is_empty() and (prefixes if not as_prefix else suffixes) < 3:
			as_prefix = not as_prefix
			table = Affixes.PREFIXES if as_prefix else Affixes.SUFFIXES
			a = Affixes.select(table, slot, 0, maxlvl, true, rng, used)
		if a.is_empty():
			continue
		used.append(a["stat"])
		item.affixes.append(_make(a, as_prefix, rng))
		if as_prefix:
			prefixes += 1
		else:
			suffixes += 1
	item.rare_name = Uniques.RARE_FIRST[rng.randi_range(0, Uniques.RARE_FIRST.size() - 1)] + " " \
		+ Uniques.RARE_SECOND[rng.randi_range(0, Uniques.RARE_SECOND.size() - 1)]
	if item.affixes.size() < 2:
		item.affixes.clear()
		_roll_magic(item, minlvl, maxlvl, true, rng)


static func _make(a: Dictionary, prefix: bool, rng: RandomNumberGenerator) -> Dictionary:
	return {"name": a["name"], "stat": a["stat"], "value": Affixes.roll_value(a, rng), "prefix": prefix}


## A plain starting item of the given base.
static func make_normal(base_id: String, ilvl: int = 1) -> Item:
	var item := Item.new()
	item.base_id = base_id
	item.ilvl = ilvl
	return item
