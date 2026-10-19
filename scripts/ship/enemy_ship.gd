class_name EnemyShip
extends Ship
## Pirate AI: patrol until the player comes close, then joust: fly in
## guns blazing, break away when too close, swing back around.
## Elites get Diablo 2-style champion modifiers; the boss gets phases.

signal spawn_escorts(boss: EnemyShip, count: int)

enum State { IDLE, ATTACK, BREAK }

## Champion modifiers, like Diablo 2's "Extra Fast", "Cursed", etc.
const MODS := {
	"fast": {"title": "the Swift", "desc": "Extra Fast"},
	"shielded": {"title": "the Warded", "desc": "Shielded"},
	"strong": {"title": "the Brutal", "desc": "Extra Strong"},
	"leech": {"title": "the Leech", "desc": "Hull Leech"},
	"volatile": {"title": "the Volatile", "desc": "Explodes on Death"},
}
const NAME_A := ["Grim", "Vex", "Mor", "Kal", "Skar", "Dra", "Zel", "Rax", "Ush", "Thal"]
const NAME_B := ["gore", "maw", "fang", "claw", "bane", "rot", "spite", "scar", "hook", "ruin"]

var state := State.IDLE
var home := Vector3.ZERO
var patrol_point := Vector3.ZERO
var aggro_range := 1000.0
var break_timer := 0.0
var break_dir := Vector3.ZERO
var aim_error := 6.0             # degrees of random aim error
var fire_interval_mult := 1.6    # AI fires slower than the gun allows
var mods: Array = []
var phase := 0
var loot_source := LootGenerator.Source.NORMAL
var credit_value := 10


## Builds a pirate ship's stats for a sector level.
static func make_stats(level: int, rank_name: String, rng: RandomNumberGenerator) -> ShipStats:
	var s := ShipStats.new()
	var scale := 1.0 + 0.36 * (level - 1)
	s.max_hull = 55.0 * scale
	s.max_shield = 25.0 * scale
	s.shield_regen = s.max_shield * 0.08
	s.max_power = 999.0
	s.power_regen = 999.0
	s.top_speed = rng.randf_range(68.0, 82.0)
	s.turn_rate = rng.randf_range(1.3, 1.6)
	var weapon_count := 1
	match rank_name:
		"elite":
			s.max_hull *= 4.0
			s.max_shield *= 3.0
			weapon_count = 2
		"boss":
			s.max_hull *= 22.0
			s.max_shield *= 14.0
			s.top_speed = 55.0
			s.turn_rate = 0.7
			weapon_count = 5
	var dmg_mult := 0.7 + 0.025 * level
	for i in weapon_count:
		var base := ItemBases.random_base(level, rng, "weapon")
		var item := LootGenerator.make_normal(base["id"], level)
		var w := ShipStats._weapon(item, 0.0)
		w["min"] = float(w["min"]) * dmg_mult
		w["max"] = float(w["max"]) * dmg_mult
		w["crit_chance"] = 0.0
		s.weapons.append(w)
	return s


func setup_enemy(lvl: int, rank_name: String, rng_seed: int) -> void:
	rng.seed = rng_seed
	level = lvl
	rank = rank_name
	faction = "enemy"
	var s := make_stats(lvl, rank_name, rng)
	var style := "raider" if rng.randf() < 0.5 else "fighter"
	var color := Color(0.55, 0.32, 0.3)
	var size := 4.0
	display_name = "Pirate " + ("Raider" if style == "raider" else "Fighter")
	match rank_name:
		"elite":
			style = "heavy"
			color = Color(0.75, 0.6, 0.25)
			size = 7.0
			loot_source = LootGenerator.Source.ELITE
			credit_value = 60
			aim_error = 4.0
			var keys := MODS.keys()
			keys.shuffle()
			mods = [keys[rng.randi_range(0, keys.size() - 1)]]
			var second: String = keys[rng.randi_range(0, keys.size() - 1)]
			if not (second in mods):
				mods.append(second)
			display_name = "%s%s %s" % [NAME_A[rng.randi_range(0, NAME_A.size() - 1)],
				NAME_B[rng.randi_range(0, NAME_B.size() - 1)], MODS[mods[0]]["title"]]
			_apply_mods(s)
		"boss":
			style = "boss"
			color = Color(0.45, 0.2, 0.22)
			size = 22.0
			loot_source = LootGenerator.Source.BOSS
			credit_value = 500
			aim_error = 3.0
			fire_interval_mult = 1.2
			aggro_range = 2500.0
			display_name = "Warlord Kazrak's Dreadnought"
		_:
			credit_value = 10 + lvl * 2
	setup_ship(s, style, color, Color(1.0, 0.45, 0.3), size)
	for i in s.weapons.size():
		s.weapons[i]["interval"] = float(s.weapons[i]["interval"]) * fire_interval_mult


func _apply_mods(s: ShipStats) -> void:
	for m in mods:
		match m:
			"fast":
				s.top_speed *= 1.35
				s.turn_rate *= 1.35
			"shielded":
				s.max_shield *= 2.0
				s.shield_regen = s.max_shield * 0.15
			"strong":
				for w in s.weapons:
					w["min"] = float(w["min"]) * 1.5
					w["max"] = float(w["max"]) * 1.5
			"leech":
				s.leech = 25.0


func mod_names() -> String:
	var out: Array = []
	for m in mods:
		out.append(MODS[m]["desc"])
	return ", ".join(out)


func _ready() -> void:
	home = global_position
	patrol_point = home


func think(dt: float) -> void:
	if target == null or not is_instance_valid(target) or not target.alive:
		target = null
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			target = players[0] as Ship
	if target == null:
		_patrol(dt)
		return

	var to := target.global_position - global_position
	var dist := to.length()
	match state:
		State.IDLE:
			_patrol(dt)
			if dist < aggro_range:
				state = State.ATTACK
		State.ATTACK:
			_attack(dist)
		State.BREAK:
			break_timer -= dt
			steer = steer_toward(break_dir)
			steer.z = level_roll()
			flight.throttle = 1.0
			wants_afterburner = rank != "boss"
			if break_timer <= 0.0:
				state = State.ATTACK
				wants_afterburner = false
	if rank == "boss":
		_boss_phases()


func _patrol(_dt: float) -> void:
	if global_position.distance_to(patrol_point) < 60.0:
		patrol_point = home + Vector3(rng.randf_range(-250, 250), rng.randf_range(-80, 80), rng.randf_range(-250, 250))
	steer = steer_toward(patrol_point - global_position)
	steer.z = level_roll()
	flight.throttle = 0.35


func _attack(dist: float) -> void:
	var lead := _lead_point()
	var err := deg_to_rad(aim_error)
	var aim := lead + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * dist * tan(err)
	steer = steer_toward(lead - global_position)
	steer.z = level_roll()
	flight.throttle = 1.0 if dist > 350.0 else 0.55
	var close := 150.0 if rank != "boss" else 0.0
	if dist < close:
		state = State.BREAK
		break_timer = rng.randf_range(1.8, 3.0)
		var away := (global_position - target.global_position).normalized()
		var side := away.cross(Vector3.UP).normalized() * rng.randf_range(-1.0, 1.0)
		break_dir = (away + side + Vector3(0, rng.randf_range(-0.4, 0.4), 0)).normalized()
		return
	var range_ok := stats.weapons.size() > 0 and dist < float(stats.weapons[0]["range"]) * 1.05
	var facing := forward().angle_to(lead - global_position) < deg_to_rad(GIMBAL_DEG if rank == "boss" else 14.0)
	if range_ok and facing:
		fire(aim)


func _lead_point() -> Vector3:
	var speed := 600.0
	if not stats.weapons.is_empty():
		speed = float(stats.weapons[0]["speed"])
	var rel_pos := target.global_position - global_position
	var time := rel_pos.length() / speed
	return target.global_position + (target.flight.velocity - flight.velocity) * time


func _boss_phases() -> void:
	var frac := hull / stats.max_hull
	if phase == 0 and frac < 0.66:
		phase = 1
		spawn_escorts.emit(self, 3)
	elif phase == 1 and frac < 0.33:
		phase = 2
		spawn_escorts.emit(self, 4)
		for w in stats.weapons:
			w["interval"] = float(w["interval"]) * 0.7


func take_damage(dmg: Dictionary, attacker: Ship = null) -> float:
	if state == State.IDLE:
		state = State.ATTACK
	return super.take_damage(dmg, attacker)


func _die() -> void:
	if "volatile" in mods and world:
		for n in get_tree().get_nodes_in_group("ships"):
			var s := n as Ship
			if s and s.faction == "player" and s.global_position.distance_to(global_position) < 120.0:
				s.take_damage({"thermal": 40.0 + level * 6.0, "kinetic": 0.0, "emp": 0.0})
		FX.flash(world, global_position, Color(1, 0.3, 0.1), 120.0, 0.8)
	super._die()
