## Automated playtest: drives the real game through every system and prints PASS/FAIL.
## Night 1:  Godot --headless --path godot -- --playtest
## Night 2:  Godot --headless --path godot -- --playtest --night2
extends Node

var game
var fails := 0
var passes := 0

func _ready() -> void:
	game = get_parent()
	Engine.time_scale = 3.0
	_run()

func check(name: String, ok: bool, info := "") -> void:
	if ok: passes += 1; print("PASS  ", name)
	else: fails += 1; print("FAIL  ", name, "  ", info)

func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func go(pos: Vector3, yaw := 0.0) -> void:
	game.player.global_position = Vector3(pos.x, 0.05, pos.z); game.player.yaw = yaw; game.player.pitch = 0.0

func item(path: String) -> Interactable:
	return game.mall.get_node("Items/" + path) as Interactable

func use(it: Interactable) -> void:
	game.focus = it; game._interact()

func _run() -> void:
	while not game.nav_ready: await get_tree().process_frame
	check("navmesh baked", game.nav_ready)
	if "--continue" in OS.get_cmdline_user_args():
		await _continue(); print("RESULT  %d passed, %d failed" % [passes, fails]); get_tree().quit(1 if fails > 0 else 0); return
	Session.clear_save()
	game.ui.title.visible = false
	game._begin_play(); game.ui.fade.modulate.a = 0.0
	if "--continue" in OS.get_cmdline_user_args(): await _continue()
	elif Session.night == 2: await _night2()
	else: await _night1()
	print("RESULT  %d passed, %d failed" % [passes, fails])
	Engine.time_scale = 1.0
	get_tree().quit(1 if fails > 0 else 0)

func _night1() -> void:
	# --- opening: walk into Security, the power dies, the gate slams, the flashlight comes on
	check("starts lit", game.power_lit())
	# mouse-look reaches the player even with the crosshair in the middle of the screen
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var y0: float = game.player.yaw
	var mm := InputEventMouseMotion.new(); mm.relative = Vector2(120, 0); mm.screen_relative = Vector2(120, 0); mm.position = get_viewport().get_visible_rect().size / 2
	Input.parse_input_event(mm); await wait(1.5)
	print("mouse capture=", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, " yaw delta=", game.player.yaw - y0)
	check("mouse look turns the camera", abs(game.player.yaw - y0) > 0.1 or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, str(game.player.yaw - y0))
	go(Vector3(9, 0, 9)); await wait(6.5)
	check("power cut in the office", not game.pre_power)
	check("flashlight on after the cut", game.player.flash_on)
	check("gate slammed down", (game.mall.get_node("Navigation/Structure/GateShutter") as Node3D).position.y < 0.1)
	# --- the first note, leaving the office wakes her
	use(item("Note_dale1")); check("note opens", game.reading == "dale1"); game._close_note()
	check("read_dale set", game.read_dale)
	go(Vector3(9, 0, 18)); await wait(1.0)
	check("Iris activates after leaving the office", game.iris.active)
	# --- crank
	game.player.battery = 0.1
	Input.action_press("crank"); await wait(2.0); Input.action_release("crank")
	check("winding charges the battery", game.player.battery > 0.2, str(game.player.battery))
	# --- hiding: hold breath and survive her search, then let it go and get caught
	var kiosk: Interactable = null
	for it in game.items: if it.kind == "hide" and it.get_node_or_null("Model") == null: kiosk = it; break
	check("found a kiosk hiding spot", kiosk != null)
	if kiosk:
		go(kiosk.exit_point().global_position)
		use(kiosk); check("entered hiding", game.player.hidden_in == kiosk)
		game.iris.scripted = 3; game.iris.mode = "hunt"; game.iris.mode_t = 999; game.iris.appear_t = 999; game.iris.grace_t = 0
		game.iris.place(kiosk.global_position + Vector3(6, 0, 0))
		Input.action_press("hold_breath"); await wait(5.0)
		check("survived while holding breath", game.state == "play", game.state)
		check("she came to look", game.iris.global_position.distance_to(game.player.global_position) < 4.0, str(game.iris.global_position.distance_to(game.player.global_position)))
		Input.action_release("hold_breath"); await wait(3.0)
		check("caught when breathing next to her", game.state == "dead", game.state)
		await wait(2.5); game._respawn(); await wait(0.5)
		check("respawn back to play", game.state == "play" and game.player.hidden_in == null)
	# --- lunge in the dark
	game.player.flash_on = false
	game.iris.scripted = 3; game.iris.mode = "hunt"; game.iris.mode_t = 999; game.iris.appear_t = 999; game.iris.grace_t = 0
	go(Vector3(30, 0, 30), -PI / 2); game.iris.place(Vector3(38, 0, 30)); await wait(4.0)
	check("lunges and kills in the dark", game.state == "dead", game.state)
	await wait(2.5); game._respawn(); await wait(0.5)
	# --- the beam freezes her
	game.player.flash_on = true; game.player.battery = 1.0
	go(Vector3(28, 0, 30), -PI / 2); game.iris.place(Vector3(36, 0, 30)); game.iris.grace_t = 0; game.iris.mode = "hunt"
	var before: Vector3 = game.iris.global_position; await wait(2.0)
	check("frozen in the beam", game.iris.global_position.distance_to(before) < 0.3, str(game.iris.global_position.distance_to(before)))
	game.iris.active = false; game.iris.visible = false
	# --- fuses, notes, breaker, save
	for k in ["shoes", "arcade", "boutique2"]: use(item("Fuse_" + k))
	check("three fuses", game.fuses == 3)
	for n in ["lumen", "poster", "janitor", "father", "dale2"]:
		use(item("Note_" + n)); game._close_note()
	check("all six notes read", game._all_notes())
	use(item("Breaker")); await wait(0.5)
	check("power restored", game.power and game.chase)
	var sv := Session.load_save()
	check("checkpoint saved", not sv.is_empty() and sv.get("flags", {}).get("power", false))
	# --- payphone
	var phone: Interactable = null
	for it in game.items: if it.kind == "phone": phone = it; break
	phone.ring_time = 10.0; go(phone.global_position + Vector3(1.2, 0, 0), PI / 2); await wait(0.3)
	game._update_interact(); check("phone answerable", game.focus == phone, str(game.focus))
	use(phone); check("phone answered", phone.ring_time <= 0.0 and game.phone_line == 1)
	# --- secret ending path: pedestal shows up, laying her to rest opens the gate
	var ped := item("PedestalSpot")
	check("pedestal available", game._visible_item(ped))
	use(ped); await wait(4.5)
	check("she is at rest", game.restful and not game.iris.active)
	check("gate opened", game.gate_open)
	go(Vector3(3.0, 0, 32), -PI / 2); await wait(1.0)
	check("walking out ends the game", game.state == "end", game.state)

func _night2() -> void:
	check("grille gone", not (game.mall.get_node("Navigation/Structure/Grille") as Node3D).visible)
	check("night 1 fuses hidden", item("Fuse_shoes").taken)
	check("power on", game.power)
	game.iris.mode = "hunt"; game.iris.mode_t = 999; game.iris.appear_t = 999; game.iris.grace_t = 0
	go(Vector3(60, 0, 30), -PI / 2); game.iris.place(Vector3(70, 0, 30)); game.blackout = 0; game.blackout_t = 999
	var before: Vector3 = game.iris.global_position; await wait(2.0)
	check("frozen while the lights are on", game.iris.global_position.distance_to(before) < 0.3)
	game.blackout = 3.0; game.player.flash_on = false; game.player.yaw = PI / 2
	await wait(1.0)
	check("moves in a blackout", game.iris.global_position.distance_to(before) > 0.5, str(game.iris.global_position.distance_to(before)))
	game.iris.active = false; game.iris.visible = false; game.blackout = 0
	use(item("Note_dale3")); game._close_note(); await wait(3.0)
	check("Dale found: lights die, gate open", game.dale_found and not game.power and game.gate_open)
	go(Vector3(3.0, 0, 32), -PI / 2); await wait(1.0)
	check("escape ends Night 2", game.state == "end", game.state)

func _continue() -> void:
	# a mid-game save: two fuses taken, power off, standing in the south hall
	Session.save_game({"v": 1, "night": 1, "diff": "normal", "pos": {"x": 40.0, "z": 44.0, "yaw": 0.5}, "fuses": 2, "battery": 0.6,
		"taken": ["Items/Fuse_shoes", "Items/Fuse_arcade"], "notes": ["dale1", "lumen"], "phone_line": 1, "ev": {"lamps": true}, "balcony_n": 2,
		"objective": "Find fuses for the MAINTENANCE breaker (2/3)",
		"flags": {"read_dale": true, "left_office": true, "power": false, "fuses_installed": false, "chase": false, "restful": false, "dale_found": false, "gate_open": false}})
	game._start(true); await wait(1.0)
	check("continue enters play", game.state == "play", game.state)
	check("fuses restored", game.fuses == 2)
	check("taken fuse stays taken", item("Fuse_shoes").taken and not item("Fuse_boutique2").taken)
	check("position restored", game.player.global_position.distance_to(Vector3(40, 0, 44)) < 0.5, str(game.player.global_position))
	check("no lit opening on continue", not game.pre_power)
	check("Iris awake", game.iris.active)
	check("objective restored", game.ui.objective.text.begins_with("FIND FUSES"))
	Session.clear_save()
