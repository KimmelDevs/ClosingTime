## Screenshot tour for development. Run:  Godot --path godot -- --autotest
## Saves PNGs into godot/screenshots/ and quits.
extends Node

var game

func _ready() -> void:
	game = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	_run()

func shot(name: String) -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://screenshots/%s.png" % name))
	print("shot ", name)

func go(pos: Vector3, yaw: float, pitch := 0.0) -> void:
	game.player.global_position = pos; game.player.yaw = yaw; game.player.pitch = pitch

func _run() -> void:
	while not game.nav_ready: await get_tree().process_frame
	await shot("00_title")
	game.ui.title.visible = false
	game._begin_play(); game.ui.fade.modulate.a = 0.0
	game.loops.muzak.volume_db = -14
	go(Vector3(7.5, 0.05, 32), 0); await shot("01_spawn_lit")
	go(Vector3(30, 0.05, 30), -PI / 2 - 0.3, 0.3); await shot("02_atrium_lit")
	go(Vector3(9, 0.05, 9), 0); await shot("03_office_lit")
	game.pre_power = false; game.player.flash_on = true
	await shot("04_office_dark")
	go(Vector3(20, 0.05, 18), -PI / 2); await shot("05_hall_dark")
	go(Vector3(30, 0.05, 30), -PI / 2 - 0.3, 0.35); await shot("06_atrium_dark")
	game.iris.active = true; game.iris.scripted = 3; game.iris.mode = "lurk"; game.iris.mode_t = 999; game.iris.appear_t = 999
	game.iris.place(Vector3(34, 0, 30)); game.iris.random_frame()
	go(Vector3(28, 0.05, 30), -PI / 2); await shot("07_iris_beam")
	go(Vector3(90, 0.05, 32), -PI / 2); await shot("08_dept_store")
	game.power = true; go(Vector3(60, 0.05, 44), PI * 0.8); await shot("09_power_on")
	game.power = false
	go(Vector3(28, 0.05, 30), -PI / 2); game.iris.place(Vector3(31, 0, 30)); game._die(); await shot("10_jumpscare")
	get_tree().quit()
