## The director: loads the mall, runs the story, scripted scares, lighting, audio, saves and menus.
extends Node3D

const MALL := "res://scenes/mall.tscn"
const PLAYER := "res://scenes/player.tscn"
const C := 2.0

var mall: Node3D
var nav: NavigationRegion3D
var player: Player
var iris: Iris
var ui: CanvasLayer
var env: Environment
var post: ShaderMaterial

var state = "title"      # title, intro, play, dead, end
var paused = false
var reading = ""
var nav_ready = false

# story state
var pre_power = true
var cut_t = -1.0
var power = false
var chase = false
var restful = false
var dale_found = false
var gate_raising = false
var gate_open = false
var read_dale = false
var left_office = false
var fuses_installed = false
var blackout = 0.0
var blackout_t = 8.0
var fuses = 0
var notes_read = {}
var phone_line = 0
var low_hint = false
var checkpoint = {}
var ev = {"done": {}, "active": "", "t": 0.0, "wait": 0.0, "balcony_n": 0, "arcade_t": 0.0}

# runtime handles
var items: Array = []
var hall_lights: Array = []
var emergency: Array = []
var shop_lights: Array = []
var signs: Array = []
var cams: Array = []
var puddles: Array = []
var mats = {}             # imported materials we animate (panels, screens, pumpkins, neon...)
var loops = {}
var focus: Interactable = null
var pa_busy_until = 0.0
var pa_t = 70.0
var decoy_t = 18.0
var hb_t = 0.0
var drip_t = 2.0
var phone_t = 45.0
var dead_t = 0.0
var dead_cut = false
var dead_dir = Vector3.FORWARD
var tts_voice = ""
var hide_tunnel = 0.0

func _ready() -> void:
	mall = (load(MALL) as PackedScene).instantiate(); add_child(mall)
	nav = mall.get_node("Navigation")
	player = (load(PLAYER) as PackedScene).instantiate() as Player; add_child(player)
	ui = load("res://scripts/ui.gd").new(); add_child(ui)
	post = ui.post.material
	_setup_environment()
	_collect()
	var ir = Node3D.new(); ir.set_script(load("res://scripts/iris.gd")); iris = ir as Iris
	iris.set("game", self); iris.set("player", player); iris.set("camera", player.camera)
	add_child(iris)
	iris.connect("killed_player", _die)
	_place_player(mall.get_node("Markers/Spawn"))
	iris.global_position = (mall.get_node("Markers/IrisStart") as Node3D).global_position
	loops.drone = Sfx.loop("drone_loop", -10); loops.tension = Sfx.loop("tension_loop", -80)
	loops.hum = Sfx.loop("hum_loop", -80); loops.muzak = Sfx.loop("muzak_loop", -80)
	_connect_ui()
	if Session.night == 2: _setup_night2()

	var gate = mall.get_node("Navigation/Structure/GateShutter") as Node3D
	gate.position.y = 3.6
	_apply_settings()
	var tvs = DisplayServer.tts_get_voices_for_language("en")
	if tvs.size() > 0: tts_voice = tvs[0]
	for v in DisplayServer.tts_get_voices():
		if String(v.get("name", "")).to_lower().contains("zira") or String(v.get("name", "")).to_lower().contains("female"): tts_voice = v.id
	ui.continue_btn.visible = not Session.load_save().is_empty()
	ui.night2_btn.visible = Session.night == 1 and Session.night2_unlocked()
	if "--playtest" in OS.get_cmdline_user_args():
		var pt = Node.new(); pt.set_script(load("res://tools/playtest.gd")); add_child(pt)
	if "--autotest" in OS.get_cmdline_user_args():
		var t = Node.new(); t.set_script(load("res://tools/autotest.gd")); add_child(t)
	nav.bake_finished.connect(_on_baked)
	nav.bake_navigation_mesh(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_baked() -> void:
	nav_ready = true
	ui.load_label.text = ""

# ---------------------------------------------------------------- setup
func _setup_environment() -> void:
	var we = WorldEnvironment.new(); env = Environment.new(); we.environment = env; add_child(we)
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.008, 0.008, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("1a1f2c"); env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.tonemap_exposure = 1.0
	env.fog_enabled = true; env.fog_light_color = Color(0.02, 0.02, 0.025); env.fog_density = 0.035; env.fog_sky_affect = 0.0
	env.volumetric_fog_density = 0.012; env.volumetric_fog_albedo = Color(0.8, 0.8, 0.85); env.volumetric_fog_length = 40
	env.glow_enabled = true; env.glow_intensity = 0.6; env.glow_bloom = 0.05
	env.ssao_enabled = true; env.ssao_radius = 1.2; env.ssao_intensity = 2.0

func _collect() -> void:
	for n in get_tree().get_nodes_in_group("interactable"): items.append(n)
	for n in get_tree().get_nodes_in_group("hall_light"): hall_lights.append(n)
	for n in get_tree().get_nodes_in_group("emergency_light"): emergency.append(n)
	for n in get_tree().get_nodes_in_group("shop_light"): shop_lights.append(n)
	for n in get_tree().get_nodes_in_group("sign"): signs.append(n)
	for n in get_tree().get_nodes_in_group("puddle"): puddles.append(n)
	for n in get_tree().get_nodes_in_group("security_camera"):
		var h = n.find_child("head", true, false); if h: cams.append(h)
	for mi in mall.find_children("*", "MeshInstance3D", true, false):
		var m = mi as MeshInstance3D
		if m.mesh == null: continue
		if m.mesh is PrimitiveMesh and (m.mesh as PrimitiveMesh).material and (m.mesh as PrimitiveMesh).material.resource_name == "hall_neon":
			mats["hall_neon"] = (m.mesh as PrimitiveMesh).material
		for i in m.mesh.get_surface_count():
			var mat = m.mesh.surface_get_material(i) as StandardMaterial3D
			if mat == null: continue
			var nm = mat.resource_name
			if nm in ["light_panel", "screen", "pumpkin", "balcony_neon", "tree_bulbs", "vending_glow", "camera_led", "fuse_glow", "note", "breaker_lights", "skylight", "hall_neon"]:
				if not mats.has(nm): mats[nm] = mat

func _connect_ui() -> void:
	ui.new_game.connect(func(): _start(false))
	ui.continue_game.connect(func(): _start(true))
	ui.night2.connect(func(): Session.night = 2; Session.pending_save = {}; get_tree().reload_current_scene())
	ui.resume.connect(_resume)
	ui.load_checkpoint.connect(func(): get_tree().reload_current_scene())
	ui.quit_to_title.connect(func(): get_tree().reload_current_scene())
	ui.retry.connect(_respawn)
	ui.play_again.connect(func(): Session.night = 1 if Session.night == 1 else 2; get_tree().reload_current_scene())
	ui.settings_changed.connect(_apply_settings)

func _apply_settings() -> void:
	env.tonemap_exposure = float(Session.settings.bright)
	env.volumetric_fog_enabled = bool(Session.settings.vfog)
	if state != "dead": player.camera.fov = float(Session.settings.fov)
	player.drain_mult = float(Session.diff().drain)
	ui.diff_label.text = String(Session.settings.diff).to_upper()

func _place_player(m: Node3D) -> void:
	player.global_position = Vector3(m.global_position.x, 0.05, m.global_position.z)
	player.yaw = m.global_rotation.y; player.pitch = 0.0

# ---------------------------------------------------------------- start / continue
func _start(cont: bool) -> void:
	if not nav_ready: ui.toast("Still loading the mall…", 1.5); return
	ui.title.visible = false
	var sv = Session.load_save() if cont else {}
	if not cont: Session.clear_save()
	if cont and not sv.is_empty():
		if int(sv.get("night", 1)) != Session.night:
			Session.night = int(sv.night); Session.pending_save = sv; get_tree().reload_current_scene(); return
		_apply_save(sv); _begin_play(); return
	state = "intro"
	ui.play_intro(Notes.INTRO[Session.night])
	await get_tree().create_timer(10.2).timeout
	_begin_play()
	loops.hum.volume_db = -26
	if Session.night == 2:
		ui.set_objective("Find Dale. HALVORSEN & CO., east end of the mall")
		await get_tree().create_timer(2.5).timeout
		pa("Welcome back to the Halvorsen Galleria. We knew you would come back.")
		return
	ui.set_objective("Clock in at the SECURITY office, north-west corner")
	loops.muzak.volume_db = -14
	await get_tree().create_timer(2.5).timeout
	pa("Good evening. The Halvorsen Galleria is now closed. Thank you for shopping with us.")

func _begin_play() -> void:
	state = "play"; ui.hud.visible = true; ui.fade.modulate.a = 1.0
	create_tween().tween_property(ui.fade, "modulate:a", 0.0, 1.6)
	player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _ready_deferred_save() -> void:
	if not Session.pending_save.is_empty():
		var sv = Session.pending_save; Session.pending_save = {}
		ui.title.visible = false; _apply_save(sv); _begin_play()

# ---------------------------------------------------------------- input
func _input(e: InputEvent) -> void:
	# grab the mouse again whenever you click the game while it's free (alt-tab, focus loss)
	if state == "play" and not paused and reading == "" and e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "play" and not paused and reading == "": _toggle_pause()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		if state == "play" and reading == "": _toggle_pause()
		elif reading != "": _close_note()
		return
	if state != "play" or paused: return
	if e.is_action_pressed("interact"):
		if reading != "": _close_note()
		else: _interact()
	if e.is_action_pressed("flashlight") and reading == "": player.toggle_flash()

func _toggle_pause() -> void:
	paused = not paused
	ui.pause_menu.visible = paused
	get_tree().paused = false
	player.controls_enabled = not paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED

func _resume() -> void:
	if paused: _toggle_pause()
	ui.settings_panel.visible = false

# ---------------------------------------------------------------- main loop
func _process(dt: float) -> void:
	if not Session.pending_save.is_empty() and nav_ready: _ready_deferred_save()
	if state == "play" and not paused and reading == "":
		if player.hidden_in == null and Input.is_action_just_pressed("interact") == false: pass
		iris.think(dt)
		if iris.anim_speed > 0.0: pass
		_update_decoys(dt); _update_decor(dt); _update_events(dt); _update_opening(dt); _update_interact()
		_check_exit()
	elif state == "dead":
		_update_death(dt)
	if state in ["play", "dead"]: _update_world(dt)
	ui.battery_bar.value = player.battery; ui.stamina_bar.value = player.stamina
	ui.breath_box.visible = player.hidden_in != null; ui.breath_bar.value = player.breath
	hide_tunnel = lerp(hide_tunnel, 1.0 if player.hidden_in else 0.0, min(1.0, dt * 4))
	post.set_shader_parameter("hide_tunnel", hide_tunnel)

func power_lit() -> bool: return (power or pre_power) and blackout <= 0.0
func aggression() -> int: return fuses + (1 if fuses_installed else 0) + (1 if power else 0)

func line_of_sight(from: Vector3, to: Vector3) -> bool:
	var q = PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

# ---------------------------------------------------------------- lighting & ambience
func _update_world(dt: float) -> void:
	if power and not restful:
		var gap = randf_range(3, 6) if chase else (randf_range(6, 11) if Session.night == 2 else randf_range(6, 13))
		var ln = randf_range(0.8, 1.5) if chase else (randf_range(2, 3.5) if Session.night == 2 else randf_range(1.1, 2.0))
		if blackout > 0.0:
			blackout -= dt
			if blackout <= 0.0: blackout_t = gap; Sfx.play("buzz", -14)
		else:
			blackout_t -= dt
			if blackout_t <= 0.0: blackout = ln; Sfx.play("buzz", -10)
	var lit = power_lit()
	for l in hall_lights:
		var v = 2.6 if lit else 0.0
		if lit and l.get_meta("flicker", false) and randf() < 0.06: v *= randf() * 0.3
		(l as OmniLight3D).light_energy = v
	env.ambient_light_energy = 0.9 if lit else 0.25
	for l in shop_lights: (l as OmniLight3D).light_energy = 0.7 if lit else 0.0
	_set_emit("light_panel", 1.6 if lit else 0.0)
	_set_emit("screen", (2.0 + randf() * 3.0 if randf() > 0.3 else 0.0) if ev.arcade_t > 0.0 else (0.9 if lit else 0.12) * randf_range(0.85, 1.15))
	_set_emit("balcony_neon", 2.2 if lit else 0.06)
	_set_emit("hall_neon", (2.2 if lit else 0.06) * (0.2 if randf() < 0.02 else 1.0))
	_set_emit("vending_glow", 1.5 if lit else 0.05)
	_set_emit("pumpkin", randf_range(0.7, 1.05))
	_set_emit("tree_bulbs", 1.6 if fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.5 else 0.2)
	_set_emit("fuse_glow", 0.8 + 0.6 * sin(Time.get_ticks_msec() / 250.0))
	_set_emit("note", 0.1 + 0.08 * sin(Time.get_ticks_msec() / 330.0))
	_set_emit("camera_led", 3.0 if fmod(Time.get_ticks_msec() / 1000.0, 1.4) < 0.15 else 0.3)
	for s in signs:
		var base: float = s.get_meta("base", 1.0)
		var on = base if lit else 0.07
		if s.get_meta("flicker", false) and randf() < 0.04: on *= 0.1
		(s as Label3D).modulate.a = on
	for l in emergency: (l as OmniLight3D).light_energy = 0.8 * (0.75 + 0.25 * sin(Time.get_ticks_msec() / 476.0))
	loops.hum.volume_db = -26.0 if lit else -80.0
	# tension + heartbeat
	var t: float = iris.tension
	loops.tension.volume_db = linear_to_db(max(0.0001, t * 0.5))
	post.set_shader_parameter("red", 1.0 if state == "dead" else t * 0.35)
	hb_t -= dt
	if t > 0.3 and hb_t <= 0.0: Sfx.play("heartbeat", linear_to_db(0.25 + t * 0.5)); hb_t = 1.15 - t * 0.6
	if read_dale and state == "play":
		pa_t -= dt
		if pa_t <= 0.0: pa_t = randf_range(80, 140); pa(Notes.AMBIENT_PA.pick_random())

func _set_emit(nm: String, v: float) -> void:
	if mats.has(nm): (mats[nm] as StandardMaterial3D).emission_energy_multiplier = v

# ---------------------------------------------------------------- PA announcements (text-to-speech)
func pa(text: String, then: Callable = Callable()) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	var start: float = max(now, pa_busy_until)
	var dur = 1.6 + text.length() * 0.075
	pa_busy_until = start + dur + 1.5
	await get_tree().create_timer(start - now + 0.01).timeout
	Sfx.play("chime", -6)
	await get_tree().create_timer(1.5).timeout
	ui.say(text, dur, "PUBLIC ADDRESS")
	if tts_voice != "": DisplayServer.tts_speak(text, tts_voice, 85, 0.45, 0.8)
	if then.is_valid():
		await get_tree().create_timer(dur).timeout
		then.call()

func whisper(text: String) -> void:
	if tts_voice != "": DisplayServer.tts_speak(text, tts_voice, 45, 1.8, 0.6)
	Sfx.play("whisper_air", -12)

# ---------------------------------------------------------------- interaction
func _visible_item(it: Interactable) -> bool:
	if it.taken: return false
	if it.night != 0 and it.night != Session.night: return false
	if it.kind == "phone" and it.ring_time <= 0.0: return false
	if it.kind == "pedestal" and not (Session.night == 1 and power and not restful and _all_notes()): return false
	if it.kind == "gate" and (gate_open or gate_raising or pre_power): return false
	return true

func _all_notes() -> bool:
	for k in Notes.NIGHT1:
		if not notes_read.has(k): return false
	return true

func _update_interact() -> void:
	focus = null
	if player.hidden_in: ui.set_prompt(""); return
	var cam = player.camera; var fwd = -cam.global_transform.basis.z; var best = 1e9
	for it in items:
		if not _visible_item(it): continue
		var p: Vector3 = it.global_position + (Vector3(0, 1.2, 0) if it.kind in ["breaker", "phone"] else Vector3.ZERO)
		var d = cam.global_position.distance_to(p)
		if d > it.reach: continue
		if (p - cam.global_position).normalized().dot(fwd) < (0.5 if it.kind == "gate" else 0.75): continue
		if d < best: best = d; focus = it
	var lab = ""
	if focus:
		match focus.kind:
			"note": lab = "[E] Read"
			"fuse": lab = "[E] Take fuse"
			"battery": lab = "[E] Take batteries"
			"breaker": lab = "Breaker: ON" if power else "[E] Breaker panel"
			"gate": lab = "[E] Main gate"
			"phone": lab = "[E] Answer the phone"
			"hide": lab = "[E] Hide"
			"pedestal": lab = "[E] Leave her letters on the pedestal"
	ui.set_prompt(lab)

func _interact() -> void:
	if player.hidden_in: player.leave_hide(); return
	if focus == null: return
	var it = focus
	match it.kind:
		"note": _open_note(it.note_id)
		"hide": player.enter_hide(it)
		"pedestal": _lay_to_rest()
		"phone": _answer_phone(it)
		"battery":
			it.take(); player.battery = min(1.0, player.battery + 0.35); Sfx.play("pickup", -6); ui.toast("Batteries")
		"fuse": _take_fuse(it)
		"breaker":
			if power: return
			if fuses < 3: ui.toast("The breaker is missing fuses (%d/3)" % fuses); return
			_power_up()
		"gate":
			if NIGHT_2_LOCK(): ui.toast("Not without Dale."); return
			if not power: ui.toast("Locked. No power to the shutter motor."); return
			_open_gate()

func NIGHT_2_LOCK() -> bool: return Session.night == 2 and not dale_found

func _take_fuse(it: Interactable) -> void:
	it.take(); fuses += 1; Sfx.play("pickup", -6); ui.fuse_label.text = "FUSES %d/3" % fuses
	if it.store_kind == "arcade": ev.arcade_t = 2.6; Sfx.play("chip", -6); player.shake = 0.3
	ui.toast("Fuse %d / 3" % fuses)
	ui.set_objective("Find fuses for the MAINTENANCE breaker (%d/3)" % fuses if fuses < 3 else "Install the fuses in the MAINTENANCE breaker, south hall")
	if fuses == 1: pa("Iris Halvorsen, please return to the atrium window. Your father is waiting.")
	if fuses == 2: pa("Shoppers are reminded that the Galleria never really closes. Not for family.")
	if fuses == 3: pa("Security to maintenance. Security to maintenance. She is right behind you.", func():
		if state == "play" and not iris.seen: iris.teleport_hidden(4.5, 7, true); iris.mode = "hunt"; iris.mode_t = 12; Sfx.play("creak", -4))
	_save()

func _open_note(id: String) -> void:
	var n: Array = Notes.ALL[id]
	reading = id; notes_read[id] = true; Sfx.play("paper", -8)
	ui.show_note(n[0], n[1]); ui.set_prompt("")
	if id == "dale1" and not read_dale:
		read_dale = true
		ui.set_objective("Find 3 fuses hidden in the shops (0/3) and restore power in MAINTENANCE")

func _close_note() -> void:
	var id = reading; reading = ""; ui.hide_note(); Sfx.play("paper", -8)
	match id:
		"dale1", "rule2": _save()
		"dale3": _night2_escape()
		"lumen":
			if not ev.done.has("lumen"):
				ev.done.lumen = true
				var st = mall.get_node("Stores/display")
				for m in get_tree().get_nodes_in_group("mannequin"):
					var p: Vector3 = m.global_position
					var gx = int(p.x / C); var gy = int(p.z / C)
					if gx >= st.get_meta("x0") and gx <= st.get_meta("x1") and gy >= st.get_meta("y0") and gy <= st.get_meta("y1"):
						var d = player.global_position - p; m.rotation.y = atan2(d.x, d.z); m.random_pose(["tilt", "point", "reach"])
				Sfx.play("creak", -2); get_tree().create_timer(0.14).timeout.connect(func(): Sfx.play("creak", -4, 0.9))
		"dale2":
			if not ev.done.has("hands"):
				ev.done.hands = true; mall.get_node("Events/Hands").visible = true
				var pane: Vector3 = mall.get_node("Events/Hands").get_child(0).global_position
				for i in 3: get_tree().create_timer(i * 0.38).timeout.connect(func(): Sfx.play_at("thunk", pane, 0))
				get_tree().create_timer(1.3).timeout.connect(func(): whisper("let me out"))

func _answer_phone(it: Interactable) -> void:
	it.ring_time = 0.0
	var line: String = Notes.PHONE_LINES[min(phone_line, Notes.PHONE_LINES.size() - 1)]
	phone_line += 1
	Sfx.play("static_blast", -14)
	ui.say(line, 2.5 + line.length() * 0.08, "PAYPHONE")
	if tts_voice != "": DisplayServer.tts_speak(line, tts_voice, 60, 1.7, 0.72)
	if phone_line == Notes.PHONE_LINES.size():
		await get_tree().create_timer(3.5).timeout
		if state == "play" and iris.active: iris.teleport_hidden(5, 8, true); iris.mode = "hunt"; iris.mode_t = 12

# ---------------------------------------------------------------- the power, the gate, the endings
func _power_up() -> void:
	fuses_installed = true; power = true; chase = true; Sfx.play("power_up", 0); player.shake = 0.5
	if mats.has("breaker_lights"): (mats.breaker_lights as StandardMaterial3D).emission = Color(0.19, 1, 0.25)
	ui.set_objective("Get to the MAIN GATE — or bring her letters to the ATRIUM WINDOW" if _all_notes() else "Get to the MAIN GATE — west entrance")
	ui.toast("POWER RESTORED", 3)
	blackout_t = 5
	pa("Thank you for shopping at the Halvorsen Galleria. The doors are now open. Please... stay.")
	iris.mode = "hunt"; iris.mode_t = 999; iris.appear_t = 6
	_save()

func _open_gate() -> void:
	if gate_raising or gate_open: return
	gate_raising = true; Sfx.play("shutter", 0)
	if not restful:
		get_tree().create_timer(3.2).timeout.connect(func(): Sfx.play("shutter", 0))
		get_tree().create_timer(6.4).timeout.connect(func(): Sfx.play("shutter", 0))
		ui.toast("The shutter motor grinds... hold her off!", 3); ui.set_objective("Hold her off until the shutter is up")
		iris.mode = "hunt"; iris.mode_t = 999; iris.appear_t = 2
	var gate = mall.get_node("Navigation/Structure/GateShutter") as Node3D
	var tw = create_tween(); tw.tween_property(gate, "position:y", 3.6, 3.2 if restful else 9.0)
	tw.tween_callback(func():
		gate_open = true; gate_raising = false
		(gate.get_node("Collision") as StaticBody3D).collision_layer = 0
		ui.set_objective("Go home." if restful else "GO. NOW."))

func _check_exit() -> void:
	if gate_open and player.global_position.x < 2 * C - 0.3:
		_end_game("night2" if Session.night == 2 else ("rest" if restful else "dale"))

func _lay_to_rest() -> void:
	restful = true; chase = false; blackout = 0.0
	iris.active = false; iris.visible = false
	var g = mall.get_node("Events/Ghost") as Node3D; var top = mall.get_node("Markers/PedestalTop") as Node3D
	g.global_position = top.global_position; g.rotation.y = top.rotation.y; g.set_pose("idle"); g.visible = true
	Sfx.play("musicbox_loop", -8, 0.6)
	get_tree().create_timer(1.4).timeout.connect(func(): whisper("thank you. closing time."))
	ui.set_objective("Go home. The main gate is open."); ui.toast("She is home.", 3)
	_open_gate(); _save()

func _end_game(kind: String) -> void:
	if state == "end": return
	state = "end"; player.controls_enabled = false; ui.hud.visible = false
	DisplayServer.tts_stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Session.night == 1: Session.unlock_night2()
	Session.clear_save()
	var tw = create_tween(); tw.tween_property(ui.fade, "modulate:a", 1.0, 2.5)
	await tw.finished
	var e: Array = Notes.ENDINGS[kind]
	ui.show_ending(e[0], e[1])

# ---------------------------------------------------------------- Night 2
func _setup_night2() -> void:
	for it in items:
		if it.night == 1: it.take()
	pre_power = false; cut_t = 99.0; power = true; read_dale = true; left_office = true; blackout_t = 12.0
	player.flash_on = true
	var grille = mall.get_node("Navigation/Structure/Grille") as Node3D
	grille.visible = false; (grille.get_node("Collision") as StaticBody3D).collision_layer = 0
	iris.active = true; iris.scripted = 3; iris.mode = "lurk"; iris.mode_t = 20; iris.appear_t = 30
	iris.global_position = (mall.get_node("Markers/IrisStartNight2") as Node3D).global_position; iris.visible = true
	ui.fuse_label.visible = false

func _night2_escape() -> void:
	if dale_found: return
	dale_found = true; power = false; blackout = 0.0; chase = true; Sfx.play("power_down", 0)
	gate_open = true; (mall.get_node("Navigation/Structure/GateShutter/Collision") as StaticBody3D).collision_layer = 0
	ui.set_objective("RUN. Main gate, west entrance.")
	pa("Attention. The guard on duty is leaving. Please... do not let them leave.")
	await get_tree().create_timer(2.5).timeout
	if state == "play": iris.teleport_hidden(7, 12, true); iris.mode = "hunt"; iris.mode_t = 999; iris.appear_t = 6
	_save()

# ---------------------------------------------------------------- the opening: a lit mall, until you clock in
func _update_opening(dt: float) -> void:
	if not pre_power: return
	var p = player.global_position
	if cut_t < 0.0 and p.x > 4.0 and p.x < 16.0 and p.z > 2.0 and p.z < 12.0: cut_t = 0.0
	if cut_t < 0.0: return
	cut_t += dt; var t = cut_t
	blackout = 1.0 if ((t > 0.8 and t < 0.95) or (t > 1.3 and t < 1.42) or (t > 1.75 and t < 1.8)) else 0.0
	if not ev.done.has("cut_buzz") and t > 0.8: ev.done.cut_buzz = true; Sfx.play("buzz", -4)
	if t < 2.3: return
	pre_power = false; blackout = 0.0; player.shake = 0.5
	Sfx.play("power_down", 0); Sfx.play("tape_stop", -10)
	create_tween().tween_property(loops.muzak, "volume_db", -80.0, 0.6)
	var gate = mall.get_node("Navigation/Structure/GateShutter") as Node3D
	create_tween().tween_property(gate, "position:y", 0.0, 0.38).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	for i in 5:
		get_tree().create_timer([0.25, 0.7, 1.15, 1.7, 2.3][i]).timeout.connect(func():
			Sfx.play_at("thunk", player.global_position + Vector3(randf_range(-20, 20), 2, randf_range(-20, 20)), -i * 2.0))
	await get_tree().create_timer(3.2).timeout
	if state != "play": return
	player.flash_on = true; Sfx.play("click", -10)
	ui.toast("[F] Flashlight", 2.5); ui.set_objective("Check the security desk")

# ---------------------------------------------------------------- scripted scares
func _update_events(dt: float) -> void:
	var p = player.global_position
	var px = int(p.x / C); var py = int(p.z / C)
	var fwd = -player.camera.global_transform.basis.z
	if not left_office and read_dale and py >= 8:
		left_office = true; iris.active = true; iris.scripted = 1; iris.script_t = 0
	# 1) the lamp corridor: lights clunk on one by one... and someone is at the end
	if not ev.done.has("lamps") and ev.active == "" and fuses >= 1 and not power and py >= 20 and py <= 23 and px >= 17 and px <= 20 and fwd.x > 0.6:
		ev.done.lamps = true; ev.active = "lamps"; ev.t = 0.0; ev.step = 0
		iris.mode = "lurk"; iris.mode_t = 12; iris.grace_t = 10; iris.appear_t = max(iris.appear_t, 14)
		if iris.active and not iris.seen: iris.teleport_hidden(22, 45, false)
		var sh = mall.get_node("Events/Shade") as Node3D; sh.visible = true; sh.set_pose("tilt")
		env.fog_density = 0.015
	if ev.active == "lamps":
		ev.t += dt; var t: float = ev.t
		while ev.step < 5 and t > 0.8 + ev.step * 0.75:
			_lamp(ev.step, true); Sfx.play_at("thunk", (mall.get_node("Events/LampCorridor/Lamp%d" % ev.step) as Node3D).global_position, -4); ev.step += 1
		if ev.step == 5 and not ev.done.has("lamps_sting") and t > 4.0:
			ev.done.lamps_sting = true; Sfx.play("stinger", -2); mall.get_node("Events/Shade").set_pose("reach")
		if t > 5.6 and not ev.done.has("lamps_pop"):
			ev.done.lamps_pop = true; for i in 5: _lamp(i, false)
			Sfx.play("pop", -2)
		if t > 6.6 and t < 7.6:
			var on = randf() < 0.45
			for i in 5: _lamp(i, on)
			mall.get_node("Events/Shade").visible = false
		if t >= 7.6:
			for i in 5: _lamp(i, false)
			ev.active = ""; env.fog_density = 0.035
	# 2) footsteps following you; they stop the moment you turn around
	if fuses >= 2: ev.wait += dt
	if not ev.done.has("steps") and ev.active == "" and ev.wait > 18.0 and py >= 8 and py <= 23:
		ev.done.steps = true; ev.active = "steps"; ev.t = 0.0; ev.n = 0; ev.yaw0 = player.yaw
	if ev.active == "steps":
		ev.t += dt
		if abs(wrapf(player.yaw - ev.yaw0, -PI, PI)) > 1.4: ev.active = ""
		elif ev.t > 0.6:
			ev.t = 0.0; ev.n += 1
			Sfx.play_at("clack_%d" % (ev.n % 3), p - fwd * (5.0 - ev.n * 0.3) + Vector3(0, 0.2, 0), -14 + ev.n * 1.5)
			if ev.n >= 10: ev.active = ""; whisper("closing time")
	# 3) first blackout after the power returns: it's standing right in front of you
	if power and blackout > 0.0 and not ev.done.has("blackfig"):
		var s = iris.ambush_spot(4.5, 8)
		if s != null:
			ev.done.blackfig = true; ev.blackfig = true
			var sh = mall.get_node("Events/Shade") as Node3D
			sh.global_position = s; var d = p - (s as Vector3); sh.rotation.y = atan2(d.x, d.z); sh.set_pose("face"); sh.visible = true
			Sfx.play("stinger", -6)
	if ev.get("blackfig", false) and blackout <= 0.0:
		ev.blackfig = false; mall.get_node("Events/Shade").visible = false
	# 4) the girl in the red dress on the balcony (once per fuse)
	if Session.night == 1 and ev.active == "" and not restful and fuses > ev.balcony_n and px >= 13 and px <= 30 and py >= 12 and py <= 19:
		ev.balcony_n = fuses; ev.active = "balcony"; ev.t = 0.0; ev.seen_g = false
		var g = mall.get_node("Events/Ghost") as Node3D
		var gz = 22.8 if p.z > 32 else 41.2; var gx: float = clamp(p.x + randf_range(-6, 6), 28, 60)
		g.global_position = Vector3(gx, 4.35, gz); var dd = p - g.global_position; g.rotation.y = atan2(dd.x, dd.z)
		g.random_pose(["idle", "tilt", "point"]); g.visible = true
	if ev.active == "balcony":
		ev.t += dt
		var g = mall.get_node("Events/Ghost") as Node3D
		var hp = g.global_position + Vector3(0, 1.5, 0)
		var in_view = player.camera.is_position_in_frustum(hp) and (hp - player.camera.global_position).normalized().dot(fwd) > 0.85
		if in_view and not ev.seen_g: ev.seen_g = true; Sfx.play("stinger", -8)
		if (ev.seen_g and not in_view) or ev.t > 30.0:
			g.visible = false; ev.active = ""
			if ev.seen_g: Sfx.play("creak", -10)
	if ev.arcade_t > 0.0: ev.arcade_t -= dt

func _lamp(i: int, on: bool) -> void:
	var l = mall.get_node("Events/LampCorridor/Lamp%d" % i) as OmniLight3D
	l.light_energy = 2.2 if on else 0.0
	((l.get_node("Panel") as MeshInstance3D).material_override as StandardMaterial3D).emission_energy_multiplier = 2.2 if on else 0.0

# ---------------------------------------------------------------- living decor
func _update_decoys(dt: float) -> void:
	decoy_t -= dt
	if decoy_t > 0.0 or not read_dale: return
	decoy_t = randf_range(10, 22)
	var near: Array = []
	for m in get_tree().get_nodes_in_group("mannequin"):
		if not m.visible or m.get_parent().name == "Events": continue
		if m.global_position.distance_to(player.global_position) < 14.0 and not iris.is_seen_at(m.global_position): near.append(m)
	if near.is_empty(): return
	var m: Node3D = near.pick_random()
	var d = player.global_position - m.global_position
	m.rotation.y = atan2(d.x, d.z); m.random_pose(["tilt", "point", "idle", "peek"])
	Sfx.play_at("creak", m.global_position, -14)
	if Session.diff().decoys_walk and d.length() > 2.5:   # Nightmare: some of them are a little closer each time
		m.global_position += Vector3(d.x, 0, d.z).normalized() * 0.7

func _update_decor(dt: float) -> void:
	for h in cams:
		var hp: Vector3 = h.global_position; var d = player.global_position - hp
		var want = atan2(d.x, d.z)
		h.rotation.y = lerp_angle(h.rotation.y, want - h.get_parent().global_rotation.y, min(1.0, dt * 1.2))
		h.rotation.x = -atan2(hp.y - 1.6, Vector2(d.x, d.z).length())
	drip_t -= dt
	if drip_t <= 0.0:
		drip_t = randf_range(0.6, 2.2)
		for pd in puddles:
			if pd.global_position.distance_to(player.global_position) < 12.0:
				Sfx.play_at("drip", pd.global_position + Vector3(0, 0.1, 0), -10, randf_range(0.9, 1.1), 14); break
	if read_dale and phone_line < Notes.PHONE_LINES.size():
		phone_t -= dt
		var phones = items.filter(func(i): return i.kind == "phone")
		if phone_t <= 0.0 and phones.all(func(i): return i.ring_time <= 0.0):
			phones.pick_random().ring_time = 24.0; phone_t = randf_range(70, 120)
		for ph in phones:
			if ph.ring_time <= 0.0: continue
			var before: float = ph.ring_time; ph.ring_time -= dt
			if fmod(before, 4.0) < fmod(ph.ring_time, 4.0) or before == 24.0: Sfx.play_at("phone_ring", ph.global_position + Vector3(0, 1.5, 0), -2, 1.0, 50)

# ---------------------------------------------------------------- death & respawn
func _die() -> void:
	if state != "play": return
	state = "dead"; dead_t = 0.0; dead_cut = false
	player.controls_enabled = false
	if player.hidden_in: player.leave_hide(true)
	DisplayServer.tts_stop()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), -80)
	var js = AudioStreamPlayer.new(); js.stream = Sfx.stream("jumpscare"); js.bus = "Master"; js.volume_db = 2; add_child(js); js.play(); js.finished.connect(js.queue_free)
	dead_dir = -player.camera.global_transform.basis.z; dead_dir.y = 0; dead_dir = dead_dir.normalized()
	iris.visible = true; iris.freeze_anim(true)
	if iris.face: iris.face.visible = true
	ui.hud.visible = false
	ui.flash_white.modulate.a = 1.0; create_tween().tween_property(ui.flash_white, "modulate:a", 0.0, 0.05)
	player.flash.position = Vector3(0, 0.05, 0)

func _update_death(dt: float) -> void:
	dead_t += dt
	var cam = player.camera
	if dead_t < 1.45:
		var k: float = min(1.0, dead_t / 0.1)
		var dist = 1.6 - (1.6 - 0.75) * (1.0 - pow(1.0 - k, 3))
		iris.global_position = player.global_position + dead_dir * dist
		iris.face_player()
		iris.random_frame(); iris.freeze_anim(true); iris.arms_up()
		var h: Vector3 = iris.head_world()
		iris.global_position.y += clamp(1.62 - h.y, -0.2, 0.4)
		h = iris.head_world() + Vector3(0, 0.04, 0)
		var s = 0.06 * 2.5
		cam.global_position = player.global_position + Vector3(randf_range(-1, 1) * s, 1.62 + randf_range(-1, 1) * s, randf_range(-1, 1) * s)
		cam.look_at(h + Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), 0), Vector3.UP)
		cam.rotation.z += randf_range(-0.2, 0.2)
		cam.fov = float(Session.settings.fov) - 20.0 * k + randf_range(-3, 3)
		var on = int(dead_t * 22.0) % 2 == 0
		player.flash.light_energy = 1.2 if on else 0.1
		post.set_shader_parameter("glitch", 1 if randf() < 0.25 else (2 if randf() < 0.15 else 3))
		post.set_shader_parameter("glitch_bright", randf_range(1.2, 2.0))
	elif not dead_cut:
		dead_cut = true; post.set_shader_parameter("glitch", 0)
		ui.fade.modulate.a = 1.0
		var sb = AudioStreamPlayer.new(); sb.stream = Sfx.stream("static_blast"); sb.bus = "Master"; add_child(sb); sb.play(); sb.finished.connect(sb.queue_free)
	if dead_t > 2.1 and not ui.death.visible:
		ui.death.visible = true; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _respawn() -> void:
	ui.death.visible = false; ui.hud.visible = true
	player.flash.position = Vector3(0.2, -0.18, 0.05)
	player.camera.transform = Transform3D(); player.camera.fov = float(Session.settings.fov)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), 0)
	iris.reset_after_death()
	var cp: Node3D = mall.get_node("Markers/Spawn" if Session.night == 2 else "Markers/Respawn")
	if not checkpoint.is_empty(): player.global_position = Vector3(checkpoint.x, 0.05, checkpoint.z); player.yaw = checkpoint.yaw
	else: _place_player(cp)
	player.pitch = 0.0; player.stamina = 1.0; player.flash_on = true; player.battery = max(player.battery, 0.3)
	if not iris.teleport_hidden(22, 60, true): iris.place((mall.get_node("Markers/IrisStart") as Node3D).global_position)
	iris.travel = 0; iris.mode = "lurk"; iris.mode_t = 10; iris.appear_t = 25; iris.grace_t = 4
	state = "play"; player.controls_enabled = true
	create_tween().tween_property(ui.fade, "modulate:a", 0.0, 1.6)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ---------------------------------------------------------------- checkpoints
func _save() -> void:
	if pre_power or state == "dead" or player.hidden_in: return
	checkpoint = {"x": player.global_position.x, "z": player.global_position.z, "yaw": player.yaw}
	var taken: Array = []
	for it in items:
		if it.taken and it.night != (1 if Session.night == 2 else 2): taken.append(String(mall.get_path_to(it)))
	Session.save_game({"v": 1, "night": Session.night, "diff": Session.settings.diff, "pos": checkpoint, "fuses": fuses, "battery": player.battery,
		"taken": taken, "notes": notes_read.keys(), "phone_line": phone_line, "ev": ev.done, "balcony_n": ev.balcony_n, "objective": ui.objective.text,
		"flags": {"read_dale": read_dale, "left_office": left_office, "power": power, "fuses_installed": fuses_installed, "chase": chase, "restful": restful, "dale_found": dale_found, "gate_open": gate_open}})
	get_tree().create_timer(2.6).timeout.connect(func(): ui.toast("Checkpoint", 1.4))

func _apply_save(sv: Dictionary) -> void:
	pre_power = false; cut_t = 99.0
	var f: Dictionary = sv.flags
	read_dale = f.read_dale; left_office = f.left_office; power = f.power; fuses_installed = f.fuses_installed
	chase = f.chase; restful = f.restful; dale_found = f.dale_found; gate_open = f.gate_open
	for path in sv.taken:
		var it = mall.get_node_or_null(NodePath(path)) as Interactable
		if it: it.take()
	fuses = int(sv.fuses); ui.fuse_label.text = "FUSES %d/3" % fuses
	for k in sv.notes: notes_read[k] = true
	phone_line = int(sv.get("phone_line", 0))
	for k in sv.get("ev", {}): ev.done[k] = sv.ev[k]
	ev.balcony_n = int(sv.get("balcony_n", 0))
	if ev.done.has("hands"): mall.get_node("Events/Hands").visible = true
	player.battery = float(sv.battery); player.flash_on = true
	var gate = mall.get_node("Navigation/Structure/GateShutter") as Node3D
	gate.position.y = 3.6 if gate_open else 0.0
	if gate_open: (gate.get_node("Collision") as StaticBody3D).collision_layer = 0
	if power and mats.has("breaker_lights"): (mats.breaker_lights as StandardMaterial3D).emission = Color(0.19, 1, 0.25)
	if restful: _lay_to_rest_visual()
	checkpoint = sv.pos
	player.global_position = Vector3(float(sv.pos.x), 0.05, float(sv.pos.z)); player.yaw = float(sv.pos.yaw)
	ui.set_objective(String(sv.get("objective", "")))
	iris.active = read_dale and left_office and not restful; iris.scripted = 3; iris.grace_t = 5
	if iris.active and not iris.teleport_hidden(22, 60, true): iris.place((mall.get_node("Markers/IrisStart") as Node3D).global_position)
	iris.mode = "hunt" if chase else "lurk"; iris.mode_t = 999.0 if chase else 10.0; iris.appear_t = 20
	if Session.night == 2: player.flash_on = true

func _lay_to_rest_visual() -> void:
	iris.active = false; iris.visible = false
	var g = mall.get_node("Events/Ghost") as Node3D; var top = mall.get_node("Markers/PedestalTop") as Node3D
	g.global_position = top.global_position; g.rotation.y = top.rotation.y; g.visible = true
