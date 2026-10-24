## Iris: runs at you only while your flashlight beam is off her, freezes mid-sprint in the beam,
## teleports when unseen, and leaps when she gets close in the dark. Uses the baked navmesh.
extends Node3D
class_name Iris

signal killed_player
signal spotted(distance: float)

const MODEL := "res://models/iris_running.fbx"
const HEIGHT := 1.8

var game                    # the Game node (state, player, helpers)
var player: Player
var camera: Camera3D

var active = false
var mode = "lurk"
var mode_t = 10.0
var appear_t = 30.0
var travel = 0.0
var pose_changed = false
var sting_cd = 0.0
var step_acc = 0.0
var grace_t = 0.0
var scripted = 0          # 1 waiting for first sighting, 2 staged in view, 3 normal
var script_t = 0.0
var script_seen = false
var seen = false
var tension = 0.0
var lunge = {}
var search_t = 0.0
var hear_t = 0.0
var anim_speed = 0.0

var model: Node3D
var anim: AnimationPlayer
var anim_name = ""
var skeleton: Skeleton3D
var head_bone = -1
var arms: Array = []
var face: Node3D
var music_box: AudioStreamPlayer3D
var _path = PackedVector3Array()
var _path_i = 0
var _repath_t = 0.0
var _sk_scale = 1.0

func _ready() -> void:
	model = (load(MODEL) as PackedScene).instantiate()
	add_child(model)
	# porcelain skin over the whole body
	var porcelain = StandardMaterial3D.new(); porcelain.albedo_color = Color("d9d3c9"); porcelain.roughness = 0.22
	var aabb = AABB(); var first = true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = porcelain
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		aabb = b if first else aabb.merge(b); first = false
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_sk_scale = _mesh_scale()
	var s = HEIGHT / max(0.01, aabb.size.y * _sk_scale)
	model.scale = Vector3.ONE * s
	anim = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	# pick the real run cycle (skip the importer's RESET track)
	var best_len = 0.0
	for n in anim.get_animation_list():
		var l = anim.get_animation(n).length
		if n != "RESET" and l > best_len: best_len = l; anim_name = n
	if anim.has_animation("mixamo_com"): anim_name = "mixamo_com"   # Mixamo's clip; "Take 001" is the bind pose
	print("iris anims: ", anim.get_animation_list(), " using ", anim_name)
	if anim_name != "":
		var a = anim.get_animation(anim_name)
		a.loop_mode = Animation.LOOP_LINEAR
		_strip_root_motion(a)
		anim.play(anim_name); anim.speed_scale = 0.0
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i).ends_with("Head"): head_bone = i
	for side in ["Left", "Right"]:
		var a = _bone(side + "Arm"); var f = _bone(side + "ForeArm"); var h = _bone(side + "Hand")
		if a >= 0 and f >= 0 and h >= 0: arms.append([a, f, h, 1.0 if side == "Left" else -1.0])
	_build_face()
	music_box = Sfx.loop_at("musicbox_loop", self, -6.0, 30.0)
	music_box.position = Vector3(0, 1.4, 0)
	visible = false

func _mesh_scale() -> float:
	# skinned meshes report their bind-pose size in skeleton space; account for the importer's scale
	var t = skeleton.global_transform if skeleton.is_inside_tree() else skeleton.transform
	return t.basis.get_scale().y

func _bone(suffix: String) -> int:
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i).ends_with(suffix) and not skeleton.get_bone_name(i).ends_with("Up" + suffix): return i
	return -1

func _strip_root_motion(a: Animation) -> void:
	for t in a.get_track_count():
		if a.track_get_type(t) == Animation.TYPE_POSITION_3D and String(a.track_get_path(t)).ends_with("Hips"):
			if a.track_get_key_count(t) == 0: continue
			var first: Vector3 = a.track_get_key_value(t, 0)
			for k in a.track_get_key_count(t):
				var v: Vector3 = a.track_get_key_value(t, k)
				a.track_set_key_value(t, k, Vector3(first.x, v.y, first.z))

func _build_face() -> void:
	# hollow eye sockets and a stretched mouth on a bone attachment; shown only during the kill
	if head_bone < 0: return
	var att = BoneAttachment3D.new(); att.bone_idx = head_bone
	skeleton.add_child(att)
	face = Node3D.new(); att.add_child(face)
	var hole = StandardMaterial3D.new(); hole.albedo_color = Color.BLACK; hole.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rest = skeleton.get_bone_global_rest(head_bone)
	var world_scale = model.scale.x * _sk_scale
	# offset in model space (model faces +Z), converted into the head bone's frame
	var want = rest.origin + Vector3(0, 0.09, 0.118) / world_scale
	var local = rest.affine_inverse() * want
	face.position = local
	face.basis = rest.basis.inverse().orthonormalized()
	face.scale = Vector3.ONE / world_scale
	for e in [[Vector3(-0.033, 0.004, 0), 0.25, 1.0], [Vector3(0.035, -0.004, 0), -0.15, 0.85]]:
		var m = MeshInstance3D.new(); var sm = SphereMesh.new(); sm.radius = 1; sm.height = 2; m.mesh = sm; m.material_override = hole
		m.position = e[0]; m.rotation.z = e[1]; m.scale = Vector3(0.012, 0.03, 0.012) * e[2]
		face.add_child(m)
	var mouth = MeshInstance3D.new(); var ms = SphereMesh.new(); ms.radius = 1; ms.height = 2; mouth.mesh = ms; mouth.material_override = hole
	mouth.position = Vector3(0.004, -0.075, -0.01); mouth.rotation.z = 0.06; mouth.scale = Vector3(0.017, 0.085, 0.012)
	face.add_child(mouth)
	face.visible = false

# ---------------------------------------------------------------- posing
func random_frame() -> void:
	if anim_name == "": return
	anim.seek(randf() * anim.get_animation(anim_name).length, true)

func head_world() -> Vector3:
	if head_bone < 0: return global_position + Vector3(0, 1.6, 0)
	return skeleton.global_transform * skeleton.get_bone_global_pose(head_bone).origin

func arms_up() -> void:
	# both arms thrown straight up over the head, reaching slightly forward
	var fwd = global_transform.basis.z.normalized()
	var left = global_transform.basis.x.normalized()
	var inv = skeleton.global_transform.basis.inverse()
	for a in arms:
		var dir: Vector3 = (fwd * 0.45 + left * a[3] * 0.22 + Vector3.UP).normalized()
		var d_sk: Vector3 = (inv * dir).normalized()
		_aim(a[0], a[1], d_sk); _aim(a[1], a[2], d_sk)

func _aim(b: int, child: int, dir: Vector3) -> void:
	var gp = skeleton.get_bone_global_pose(b); var cp = skeleton.get_bone_global_pose(child)
	var cur = (cp.origin - gp.origin).normalized()
	if cur.length() < 0.5: return
	var q = Quaternion(cur, dir)
	var new_basis = Basis(q) * gp.basis.orthonormalized()
	var parent = skeleton.get_bone_parent(b)
	var pb = skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	skeleton.set_bone_pose_rotation(b, (pb.inverse() * new_basis).get_rotation_quaternion())

func freeze_anim(on: bool) -> void:
	if on: anim.pause()
	elif anim_name != "": anim.play(anim_name)

# ---------------------------------------------------------------- visibility
func seen_point(pt: Vector3) -> bool:
	if not player.flash_active(): return false
	var from = camera.global_position
	var to = pt - from; var dist = to.length()
	if dist > 26.0: return false
	var cos_a = to.normalized().dot(-camera.global_transform.basis.z)
	if cos_a < 0.87: return false
	if not camera.is_position_in_frustum(pt): return false
	return game.line_of_sight(from, pt)

func is_seen_at(p: Vector3) -> bool:
	return seen_point(p + Vector3(0, 1.55, 0)) or seen_point(p + Vector3(0, 0.95, 0)) or seen_point(p + Vector3(0, 0.3, 0))

# ---------------------------------------------------------------- movement on the navmesh
func nav_map() -> RID: return get_world_3d().navigation_map

func step_toward(target: Vector3, speed: float, dt: float) -> float:
	_repath_t -= dt
	if _repath_t <= 0.0 or _path_i >= _path.size():
		_repath_t = 0.3
		_path = NavigationServer3D.map_get_path(nav_map(), global_position, target, true)
		_path_i = 1
	if _path_i >= _path.size(): return 0.0
	var next = _path[_path_i]; next.y = 0.0
	var here = Vector3(global_position.x, 0, global_position.z)
	var d = here.distance_to(next)
	if d < 0.3:
		_path_i += 1; return 0.0
	var st: float = min(d, speed * dt)
	global_position = Vector3(global_position.x, 0, global_position.z) + (next - here) / d * st
	return st

func place(p: Vector3) -> void:
	global_position = Vector3(p.x, 0, p.z); visible = true; travel = 99.0; face_player()
	_path = PackedVector3Array()

func face_player() -> void:
	var d = player.global_position - global_position
	rotation.y = atan2(d.x, d.z)

func teleport_hidden(min_d: float, max_d: float, prefer_behind: bool) -> bool:
	var best = Vector3.INF; var best_score = -1e9
	var fwd = -camera.global_transform.basis.z
	for i in 160:
		var c = NavigationServer3D.map_get_random_point(nav_map(), 1, false)
		var dv = c - player.global_position; dv.y = 0
		var d = dv.length()
		if d < min_d or d > max_d: continue
		if is_seen_at(c): continue
		var path = NavigationServer3D.map_get_path(nav_map(), c, player.global_position, true)
		if path.size() < 2 or path[path.size() - 1].distance_to(player.global_position) > 2.5: continue
		var score = randf() * 3.0
		if prefer_behind: score -= dv.normalized().dot(fwd) * 4.0
		if score > best_score: best_score = score; best = c
	if best == Vector3.INF: return false
	place(best); random_frame(); pose_changed = true
	return true

func ambush_spot(min_d: float, max_d: float) -> Variant:
	var f = -camera.global_transform.basis.z; f.y = 0
	if f.length() < 0.3: return null
	f = f.normalized()
	var d = max_d
	while d >= min_d:
		var p = player.global_position + f * d; p.y = 0
		var q = NavigationServer3D.map_get_closest_point(nav_map(), p)
		if q.distance_to(p) < 0.6 and game.line_of_sight(camera.global_position, p + Vector3(0, 1.2, 0)): return q
		d -= 0.5
	return null

func ambush() -> bool:
	var s = ambush_spot(5, 9)
	if s == null: return false
	player.flicker_t = 0.75; Sfx.play("buzz", -8)
	place(s); random_frame()
	mode = "hunt"; mode_t = 6
	return true

func appear() -> void:
	var a: int = game.aggression()
	appear_t = (randf_range(6, 10) if game.chase else max(12.0, 44.0 - a * 7.0) + randf_range(0, 10)) * float(Session.diff().appear)
	if player.flash_active() and randf() < 0.4 and ambush(): return
	if teleport_hidden(7, 15, true): mode = "hunt"; mode_t = 10 + a * 4

# ---------------------------------------------------------------- the brain (called by Game every frame)
func think(dt: float) -> void:
	if not active:
		tension = 0.0; _music(dt, false); return
	if scripted == 1:
		script_t += dt
		var s = ambush_spot(9, 15)
		if s != null and script_t > 0.6:
			player.flicker_t = 0.6; Sfx.play("buzz", -8); place(s); random_frame()
			scripted = 2; script_t = 0; script_seen = false; mode = "lurk"; mode_t = 999; grace_t = 999
		elif script_t > 7:
			scripted = 3; teleport_hidden(14, 30, true); mode = "lurk"; mode_t = 14; appear_t = 22; grace_t = 0
		_music(dt, true); return
	if not lunge.is_empty():
		_lunge(dt); return
	var to = player.global_position - global_position; to.y = 0
	var d = to.length()
	sting_cd -= dt; grace_t -= dt
	# Night 2: while the lights are on, nothing moves
	var now_seen: bool = (Session.night == 2 and game.power_lit()) or is_seen_at(global_position)
	if now_seen:
		if travel > 1.2 and sting_cd <= 0.0 and d < 15.0:
			Sfx.play("stinger", 0.0 if d < 6 else (-5.0 if d < 10 else -10.0)); sting_cd = 5.0
			player.shake = 0.6 if d < 6 else 0.2
			spotted.emit(d)
		travel = 0.0; pose_changed = false; anim_speed = 0.0
		if scripted == 2: script_seen = true
	else:
		if scripted == 2: script_t += dt
		if scripted == 2 and (script_seen or script_t > 9.0):
			scripted = 3; player.flicker_t = 0.2
			teleport_hidden(16, 32, true); travel = 0; mode = "lurk"; mode_t = 12; appear_t = 20; grace_t = 0
			game.pa("Attention shoppers. The Halvorsen Galleria is now closed. Please make your way... to the nearest display.")
			return
		face_player()
		if not pose_changed: random_frame(); pose_changed = true
		anim_speed = 0.0
		if player.hidden_in and mode == "hunt" and d < 2.6:
			_search_hidden(dt)
		elif mode == "hunt":
			var speed: float = (2.3 + game.aggression() * 0.5 + (1.2 if game.blackout > 0 else 0.0) + (0.6 if game.chase else 0.0)) * float(Session.diff().speed)
			var target: Vector3 = player.global_position
			var st = step_toward(target, speed, dt) if d > 2.2 else _straight(target, speed, dt)
			anim_speed = speed / 3.2 if st > 0.0 else 0.0
			travel += st; step_acc += st
			if step_acc > 0.7 and d < 18.0:
				step_acc = 0.0; Sfx.play_at("clack_%d" % (randi() % 3), global_position, -6, randf_range(0.9, 1.1))
				if randf() < 0.15: Sfx.play_at("creak", global_position, -10)
		if player.hidden_in == null and mode == "hunt" and d < float(Session.diff().lunge) and grace_t <= 0.0 and game.line_of_sight(global_position + Vector3(0, 1.2, 0), player.global_position + Vector3(0, 1.2, 0)):
			lunge = {"t": 0.0, "from": global_position}
			Sfx.play("stinger", 0); Sfx.play_at("clack_0", global_position, 0)
			return
		if player.hidden_in == null and d < 0.95 and grace_t <= 0.0:
			killed_player.emit(); return
	seen = now_seen
	anim.speed_scale = anim_speed
	if player.noise > 0.5 and d < 22.0 and mode == "lurk": mode = "hunt"; mode_t = 8 + game.aggression() * 3
	mode_t -= dt
	if mode_t <= 0.0:
		var a: int = game.aggression()
		if mode == "hunt": mode = "lurk"; mode_t = max(4.0, 16.0 - a * 3.0) + randf_range(0, 6)
		else: mode = "hunt"; mode_t = 14 + a * 4 + randf_range(0, 6)
	appear_t -= dt
	if appear_t <= 0.0 and not now_seen: appear()
	if d > 34.0 and not now_seen and mode == "hunt": teleport_hidden(10, 20, true)
	tension = clamp(1.0 - d / 14.0, 0.0, 1.0) * (1.0 if mode == "hunt" else 0.6)
	_music(dt, true)

func _straight(target: Vector3, speed: float, dt: float) -> float:
	var here = Vector3(global_position.x, 0, global_position.z); var t = Vector3(target.x, 0, target.z)
	var d = here.distance_to(t); if d < 0.01: return 0.0
	var st: float = min(d, speed * dt)
	global_position = here + (t - here) / d * st
	return st

func _search_hidden(dt: float) -> void:
	# she reaches your hiding place and stands there, listening
	search_t += dt; face_player()
	if player.holding: hear_t = max(0.0, hear_t - dt * 0.8)
	else: hear_t += dt
	if hear_t > 1.1:
		search_t = 0; hear_t = 0; player.leave_hide(true); killed_player.emit(); return
	if search_t > 7.0:
		search_t = 0; hear_t = 0; teleport_hidden(18, 35, false); mode = "lurk"; mode_t = 12

func _lunge(dt: float) -> void:
	# mid-leap: committed, the beam can't stop her now
	lunge.t += dt
	var k: float = min(1.0, lunge.t / 0.42)
	var from: Vector3 = lunge.from
	var p = from.lerp(player.global_position, k)
	global_position = Vector3(p.x, sin(PI * min(1.0, k * 1.15)) * 0.7, p.z)
	face_player(); rotation.x = 0.3 * k
	freeze_anim(true); arms_up()
	tension = 1.0
	if k >= 1.0:
		lunge = {}; rotation.x = 0; killed_player.emit()

func reset_after_death() -> void:
	lunge = {}; rotation.x = 0; global_position.y = 0; freeze_anim(false); anim.speed_scale = 0
	if face: face.visible = false

func _music(dt: float, on: bool) -> void:
	# the wind-up music box: slows and flattens when your beam freezes her
	var target = 0.25 if seen else (1.15 if mode == "hunt" else 0.8)
	music_box.pitch_scale = lerp(music_box.pitch_scale, target, min(1.0, dt * (1.6 if seen else 0.7)))
	music_box.volume_db = -4.0 if (on and visible) else -80.0
