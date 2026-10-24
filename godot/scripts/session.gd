## Autoload: settings, difficulty, input bindings, audio buses, saves and which night is running.
extends Node

const SETTINGS_PATH := "user://settings.json"
const SAVE_PATH := "user://save.json"
const UNLOCK_PATH := "user://night2.unlock"

const DIFFS := {
	"easy": {"speed": 0.8, "appear": 1.4, "drain": 0.6, "lunge": 2.4, "decoys_walk": false},
	"normal": {"speed": 1.0, "appear": 1.0, "drain": 1.0, "lunge": 3.2, "decoys_walk": false},
	"nightmare": {"speed": 1.25, "appear": 0.7, "drain": 1.4, "lunge": 3.8, "decoys_walk": true},
}

var night := 1
## Set by "Continue" on the title screen; the game applies it on start.
var pending_save: Dictionary = {}
var settings := {"sens": 1.0, "vol": 0.9, "bright": 1.0, "fov": 72.0, "invert": false, "diff": "normal", "vfog": true}

func _ready() -> void:
	load_settings()
	setup_input()
	setup_audio()

func diff() -> Dictionary:
	return DIFFS.get(settings.diff, DIFFS.normal)

# ---------------------------------------------------------------- settings
func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if data is Dictionary:
		for k in data: settings[k] = data[k]

func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(settings))
	apply_volume()

func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(max(0.0001, float(settings.vol))))

# ---------------------------------------------------------------- saves
func save_game(data: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(data))

func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH): return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	return data if data is Dictionary else {}

func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH): DirAccess.remove_absolute(SAVE_PATH)

func unlock_night2() -> void:
	var f := FileAccess.open(UNLOCK_PATH, FileAccess.WRITE)
	if f: f.store_string("1")

func night2_unlocked() -> bool:
	return FileAccess.file_exists(UNLOCK_PATH)

# ---------------------------------------------------------------- input (keyboard, mouse and controller)
func setup_input() -> void:
	_bind("move_forward", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind("move_back", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_bind("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind("look_left", [], [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_bind("look_right", [], [], [[JOY_AXIS_RIGHT_X, 1.0]])
	_bind("look_up", [], [], [[JOY_AXIS_RIGHT_Y, -1.0]])
	_bind("look_down", [], [], [[JOY_AXIS_RIGHT_Y, 1.0]])
	_bind("sprint", [KEY_SHIFT], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_bind("flashlight", [KEY_F], [JOY_BUTTON_X], [])
	_bind("interact", [KEY_E], [JOY_BUTTON_A], [], [MOUSE_BUTTON_LEFT])
	_bind("crank", [KEY_C], [JOY_BUTTON_Y], [])
	_bind("hold_breath", [KEY_SPACE], [JOY_BUTTON_B], [[JOY_AXIS_TRIGGER_LEFT, 1.0]], [MOUSE_BUTTON_RIGHT])
	_bind("pause", [KEY_ESCAPE], [JOY_BUTTON_START], [])

func _bind(action: String, keys: Array, buttons: Array, axes: Array, mouse: Array = []) -> void:
	if InputMap.has_action(action): InputMap.erase_action(action)
	InputMap.add_action(action, 0.25)
	for k in keys:
		var e := InputEventKey.new(); e.physical_keycode = k; InputMap.action_add_event(action, e)
	for b in buttons:
		var e := InputEventJoypadButton.new(); e.button_index = b; InputMap.action_add_event(action, e)
	for a in axes:
		var e := InputEventJoypadMotion.new(); e.axis = a[0]; e.axis_value = a[1]; InputMap.action_add_event(action, e)
	for m in mouse:
		var e := InputEventMouseButton.new(); e.button_index = m; InputMap.action_add_event(action, e)

# ---------------------------------------------------------------- audio buses: Master <- SFX (with mall reverb)
func setup_audio() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus(); var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "SFX"); AudioServer.set_bus_send(i, "Master")
		var rv := AudioEffectReverb.new(); rv.room_size = 0.85; rv.damping = 0.4; rv.wet = 0.28; rv.dry = 1.0; rv.spread = 1.0
		AudioServer.add_bus_effect(i, rv)
	apply_volume()
