class_name Sfx
extends RefCounted
## Fire-and-forget sound effects. Picks a random variant from a list, limits
## how often the same sound can start, and frees the player when it ends.

const SETS := {
	"laser": ["laserSmall_000", "laserSmall_001", "laserSmall_002"],
	"pulse": ["laserRetro_000", "laserRetro_002"],
	"mass": ["laserLarge_000", "laserLarge_001"],
	"missile": ["thrusterFire_000"],
	"explosion": ["explosionCrunch_000", "explosionCrunch_001", "explosionCrunch_002"],
	"big_explosion": ["lowFrequency_explosion_000", "lowFrequency_explosion_001"],
	"hit_hull": ["impactMetal_000", "impactMetal_001", "impactMetal_002"],
	"hit_shield": ["forceField_000", "forceField_001", "forceField_002"],
	"dock": ["doorOpen_000"],
	"undock": ["doorClose_000"],
	"lane": ["spaceEngineLarge_001"],
	"pickup": ["computerNoise_000"],
	"ui": ["computerNoise_002"],
}
const MIN_GAP := 0.045           # seconds between starts of the same set

static var enabled := true
static var _last: Dictionary = {}


static func _pick(set_name: String) -> AudioStream:
	var list: Array = SETS.get(set_name, [set_name])
	return Assets.sound(list[randi() % list.size()])


static func _throttled(set_name: String) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(set_name, -10.0)) < MIN_GAP:
		return true
	_last[set_name] = now
	return false


## Positional sound in the 3D world.
static func play_at(parent: Node, set_name: String, pos: Vector3, volume_db: float = -6.0, pitch_jitter: float = 0.08) -> void:
	if not enabled or parent == null or not parent.is_inside_tree() or _throttled(set_name):
		return
	var stream := _pick(set_name)
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.unit_size = 80.0
	p.max_distance = 3000.0
	p.position = pos
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Non-positional sound (UI, the player's own events).
static func play(parent: Node, set_name: String, volume_db: float = -6.0) -> void:
	if not enabled or parent == null or not parent.is_inside_tree() or _throttled(set_name):
		return
	var stream := _pick(set_name)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## A looping sound on its own player (engine hum). Returns null if missing.
static func make_loop(name: String, volume_db: float) -> AudioStreamPlayer:
	var s := Assets.sound(name)
	if s == null:
		return null
	if s is AudioStreamOggVorbis:
		s = s.duplicate()
		(s as AudioStreamOggVorbis).loop = true
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	return p
