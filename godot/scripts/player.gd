## First-person guard: walk/run, flashlight with a draining battery and a loud wind-up crank,
## hiding spots with breath-holding. The Game node drives story; this script only moves and looks.
extends CharacterBody3D
class_name Player

signal step(volume: float)

const WALK := 2.7
const BACK := 2.0
const RUN := 4.9

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var flash: SpotLight3D = $Head/Camera/Flashlight
@onready var bounce: OmniLight3D = $Head/Camera/Bounce

var yaw = 0.0
var pitch = 0.0
var stamina = 1.0
var exhausted = false
var sprinting = false
var battery = 1.0
var flash_on = false
var cranking = false
var flicker_t = 0.0        # >0 = the flashlight is cutting out
var shake = 0.0
var noise = 0.0            # 1 = loud (running / cranking / gasping); she hears it
var controls_enabled = false
var drain_mult = 1.0

# hiding
var hidden_in: Interactable = null
var breath = 1.0
var holding = false
var _gasped = false
var _breath_t = 0.0

var _step_acc = 0.0
var _bob = 0.0
var _crank_t = 0.0
var _foot = 1

func _ready() -> void:
	flash.light_energy = 0.0

# _input (not _unhandled_input) so no GUI element can swallow mouse-look
func _input(e: InputEvent) -> void:
	if not controls_enabled: return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var k = 0.0022 * float(Session.settings.sens)
		var rel: Vector2 = e.screen_relative   # raw screen pixels: same feel at any window size
		yaw -= rel.x * k
		pitch = clamp(pitch - rel.y * k * (-1.0 if Session.settings.invert else 1.0), -1.35, 1.35)

func flash_active() -> bool:
	return flash_on and battery > 0.0 and flicker_t <= 0.0 and not cranking and hidden_in == null

func toggle_flash() -> void:
	if hidden_in: return
	flash_on = not flash_on
	Sfx.play("click", -12)

func _physics_process(dt: float) -> void:
	if not controls_enabled:
		_apply_view(0.0); return
	# controller look
	var look = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	yaw -= look.x * 2.6 * dt * float(Session.settings.sens)
	pitch = clamp(pitch - look.y * 2.0 * dt * float(Session.settings.sens) * (-1.0 if Session.settings.invert else 1.0), -1.35, 1.35)
	if hidden_in: _hidden(dt); return

	var mv = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	cranking = Input.is_action_pressed("crank")
	if cranking:
		mv = Vector2.ZERO
		battery = min(1.0, battery + 0.075 * dt); noise = 1.0
		_crank_t -= dt
		if _crank_t <= 0.0: _crank_t = 0.09; Sfx.play("ratchet", -8, randf_range(0.9, 1.1))
	var moving = mv.length() > 0.05
	if stamina <= 0.02: exhausted = true
	if exhausted and stamina > 0.35: exhausted = false
	sprinting = Input.is_action_pressed("sprint") and moving and mv.y > 0.0 and not exhausted
	stamina = clamp(stamina + (-0.22 if sprinting else 0.13) * dt, 0.0, 1.0)
	var speed = RUN if sprinting else (BACK if mv.y < 0.0 else WALK)
	var dir = (Basis(Vector3.UP, yaw) * Vector3(mv.x, 0, -mv.y))
	if dir.length() > 1.0: dir = dir.normalized()
	var before = global_position
	velocity.x = dir.x * speed; velocity.z = dir.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * dt
	move_and_slide()
	var moved = Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_step_acc += moved; _bob += moved * (2.2 if sprinting else 2.6)
	if _step_acc > (0.95 if sprinting else 0.72):
		_step_acc = 0.0; _foot = -_foot
		Sfx.play("step_%d" % (randi() % 4), -4.0 if sprinting else -9.0, randf_range(0.92, 1.08))
		step.emit(0.5 if sprinting else 0.3)
	if sprinting: noise = 1.0
	noise = max(0.0, noise - dt * 0.5)
	if flash_on and not cranking: battery = max(0.0, battery - dt / 220.0 * drain_mult)
	_apply_view(_bob if moving else 0.0)
	_apply_flash(dt)

func _apply_view(bob_phase: float) -> void:
	var bob = sin(bob_phase) * (0.05 if sprinting else 0.03) if bob_phase != 0.0 else 0.0
	head.position = Vector3(0, 1.62 + bob, 0)
	if shake > 0.0:
		head.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.05
		shake = max(0.0, shake - get_physics_process_delta_time() * 2.0)
	rotation.y = yaw
	head.rotation = Vector3(pitch, 0, (sin(Time.get_ticks_msec() / 45.0) * 0.01) if cranking else 0.0)

func _apply_flash(dt: float) -> void:
	var e = 0.0
	if flash_on and battery > 0.0 and not cranking:
		e = 6.0 * (0.35 + 0.65 * min(1.0, battery / 0.3))
		if battery < 0.2 and randf() < 0.04: e *= randf() * 0.3
	if flicker_t > 0.0:
		flicker_t -= dt
		e = e * 0.4 if (flicker_t > 0.55 and randf() < 0.5) else 0.0
	flash.light_energy = e
	bounce.light_energy = 0.12 * e / 6.0

# ---------------------------------------------------------------- hiding
func enter_hide(spot: Interactable) -> void:
	hidden_in = spot; breath = 1.0; flash_on = false
	var s = spot.spot()
	yaw = s.global_rotation.y; pitch = 0.0
	Sfx.play("cloth", -10)

func leave_hide(silent := false) -> void:
	if hidden_in == null: return
	var ex = hidden_in.exit_point()
	hidden_in = null; holding = false
	global_position = Vector3(ex.global_position.x, 0.05, ex.global_position.z)
	head.position = Vector3(0, 1.62, 0)
	if not silent: Sfx.play("cloth", -10)

func _hidden(dt: float) -> void:
	var s = hidden_in.spot()
	holding = Input.is_action_pressed("hold_breath") and breath > 0.0
	if holding: breath = max(0.0, breath - dt / 7.0)
	else: breath = min(1.0, breath + dt / 4.0)
	if breath <= 0.0 and not _gasped:
		_gasped = true; noise = 1.0; Sfx.play("gasp", 0)
	if breath > 0.3: _gasped = false
	_breath_t -= dt
	if not holding and _breath_t <= 0.0:
		_breath_t = 1.7; Sfx.play("breath", -14)
	var dy = wrapf(yaw - s.global_rotation.y, -PI, PI)
	yaw = s.global_rotation.y + clamp(dy, -0.9, 0.9)
	pitch = clamp(pitch, -0.5, 0.4)
	velocity = Vector3.ZERO
	# eyes at the spot; body parked under it so distance checks see you there
	global_position = Vector3(s.global_position.x, 0.05, s.global_position.z)
	rotation.y = yaw
	head.position = Vector3(0, s.global_position.y + (0.0 if holding else sin(Time.get_ticks_msec() / 600.0) * 0.006), 0)
	head.rotation = Vector3(pitch, 0, 0)
	flash.light_energy = 0.0; bounce.light_energy = 0.0
