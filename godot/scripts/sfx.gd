## Autoload: plays the WAVs in res://audio. Replace any file there to change a sound.
extends Node

var _cache := {}

func stream(sound: String, looped := false) -> AudioStream:
	var key := sound + ("#loop" if looped else "")
	if _cache.has(key): return _cache[key]
	var s := load("res://audio/%s.wav" % sound) as AudioStreamWAV
	if s == null: push_warning("missing sound " + sound); return null
	if looped:
		s = s.duplicate() as AudioStreamWAV
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD; s.loop_begin = 0
		s.loop_end = s.data.size() / (2 * (2 if s.stereo else 1))
	_cache[key] = s
	return s

## Fire-and-forget 2D sound. pan: -1 left .. 1 right.
func play(sound: String, db := 0.0, pitch := 1.0, pan := 0.0) -> void:
	var p := AudioStreamPlayer.new(); p.stream = stream(sound); p.volume_db = db; p.pitch_scale = pitch; p.bus = "SFX"
	if abs(pan) > 0.01:
		# cheap panning: route through a per-sound panner bus would be heavy; use a 3D player at the listener instead
		pass
	add_child(p); p.play(); p.finished.connect(p.queue_free)

## Positional one-shot in the 3D world.
func play_at(sound: String, pos: Vector3, db := 0.0, pitch := 1.0, max_dist := 40.0) -> void:
	var tree := get_tree()
	if tree.current_scene == null: return
	var p := AudioStreamPlayer3D.new(); p.stream = stream(sound); p.volume_db = db; p.pitch_scale = pitch; p.bus = "SFX"
	p.max_distance = max_dist; p.unit_size = 6.0
	tree.current_scene.add_child(p); p.global_position = pos; p.play(); p.finished.connect(p.queue_free)

## A looping 2D player you keep a handle to (set volume_db yourself).
func loop(sound: String, db := 0.0, parent: Node = null) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new(); p.stream = stream(sound, true); p.volume_db = db; p.bus = "SFX"
	(parent if parent else self).add_child(p); p.play()
	return p

func loop_at(sound: String, parent: Node3D, db := 0.0, max_dist := 32.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = stream(sound, true); p.volume_db = db; p.bus = "SFX"
	p.max_distance = max_dist; p.unit_size = 5.0
	parent.add_child(p); p.play()
	return p
