# The composition root: the one place that owns a simulation and advances it.
#
# THE ONLY CALLER OF Sim.step(). That is a requirement, not a convention — see
# openspec/changes/add-kart-view-orientation-and-input/specs/godot/simulation-driver/.
# If a second caller appears, "how many times has the world advanced" stops having
# one answer, and every timing figure in the design document stops meaning anything.
#
# It lives on main.tscn rather than on world.tscn deliberately (design D1): the
# world scene has a committed requirement that it renders with nothing stepping,
# and that requirement is what lets it be captured on its own.
#
# GODOT'S FIXED-RATE LOOP IS THE ACCUMULATOR (design D2a). _physics_process runs
# at the rate project.godot pins, running as many times per rendered frame as the
# elapsed time buys and carrying the remainder itself — which is exactly what the
# design document's Reference Tick section asks a port to do. This project pins
# physics_ticks_per_second and physics_jitter_fix so that loop is authoritative;
# building a second accumulator on top would make those pins decorative and put
# two fixed-step loops in a project whose determinism story rests on there being
# one.
extends Node3D

const Sim := preload("res://scripts/core/sim.gd")
const InputState := preload("res://scripts/core/input_state.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")
const ChaseCamera := preload("res://scripts/core/chase_camera.gd")
const ArtTuning := preload("res://scripts/art_tuning.gd")

## Actions declared in project.godot's InputMap, mapped to the core's held-state
## fields. The design document's control table also binds Reset Kart and Save
## Layout, whose EFFECTS arrive in M7 — they are bound here and deliberately do
## nothing, which the register entry for "Mapping the control scheme" records.
const DRIVE_ACTIONS := {
	"accelerate": "forward",
	"reverse": "reverse",
	"steer_left": "left",
	"steer_right": "right",
}

var sim: RefCounted = null
var input: RefCounted = null

## The chase camera's state. In the core because it is a fixed-step recurrence
## whose specified properties are numbers — see scripts/core/chase_camera.gd.
var camera: RefCounted = null

var _art: RefCounted = null

var _steps: int = 0
var _frames: int = 0
var _begin_frame_calls: int = 0
var _camera_steps: int = 0

## The kart view, found in the scene rather than constructed here: the root owns
## the simulation, not the presentation. It is optional so a headless suite can
## drive the root with no view attached.
@onready var kart: Node3D = get_node_or_null("Kart") as Node3D

## The node the chase camera is applied to. Optional for the same reason the kart
## view is: a headless suite drives the root with neither attached.
@onready var chase_camera: Camera3D = get_node_or_null("ChaseCamera") as Camera3D


func _ready() -> void:
	var tuning: RefCounted = TuningLoader.load_tuning()
	if tuning == null:
		# The loader has already named what is missing. Refusing to run is the
		# point: a simulation with a defaulted accel produces a kart that will
		# not move, which is a far more confusing symptom than a named failure.
		push_error("main: no tuning; the game will not start")
		get_tree().quit(1)
		return
	sim = Sim.new()
	input = InputState.new()
	sim.tuning = tuning
	sim.input = input
	camera = ChaseCamera.new()
	camera.tuning = tuning
	_art = ArtTuning.load_art()


## Exactly one step. Never a loop: the loop is Godot's, and duplicating it here is
## what design D2a rejected.
func _physics_process(_delta: float) -> void:
	if sim == null:
		return
	_read_input()
	# The view is told where the kart WAS before the step, so it has both ends of
	# the interval it draws between. Ordering matters: after the step, "previous"
	# would be the current state and the interpolation would be a no-op that looks
	# almost right.
	if kart != null:
		kart.remember(sim)
	sim.step()
	# ONCE PER TICK, immediately after the simulation advances — ambiguity A10.
	# Never in _process: the design document states the easing per tick, and per
	# frame the time constant becomes 0.4 s at 30 fps and 0.083 s at 144 fps
	# against a stated 0.2 s.
	camera.step(sim.pos_x, sim.pos_z, sim.yaw, sim.speed_ratio())
	_steps += 1
	_camera_steps += 1


## Once per rendered frame. This advances NOTHING — the count below exists so a
## test can assert that, since "the per-frame callback does not step" is the half
## of the contract that a passing game would never reveal on its own.
func _process(_delta: float) -> void:
	if sim == null:
		return
	sim.begin_frame()
	_begin_frame_calls += 1
	_frames += 1
	if kart != null:
		kart.draw_from(sim, interpolation_fraction())
	if chase_camera != null and _art != null:
		chase_camera.apply(camera, _art.num("nearClip"), _art.num("farClip"))


func steps() -> int:
	return _steps


func frames() -> int:
	return _frames


func begin_frame_calls() -> int:
	return _begin_frame_calls


## Asserted against steps() by driver_test: the camera must advance exactly with
## the simulation, which is what "per tick" means in practice.
func camera_steps() -> int:
	return _camera_steps


## How far the current frame sits between the last step and the next, 0..1.
##
## The engine's own fraction, which is meaningful precisely because the engine
## owns the loop that produced the steps. The view draws at this; nothing else
## reads it.
func interpolation_fraction() -> float:
	return Engine.get_physics_interpolation_fraction()


func _read_input() -> void:
	for action in DRIVE_ACTIONS:
		input.set(DRIVE_ACTIONS[action], Input.is_action_pressed(action))


## Every held input is released when the window loses focus.
##
## The design document requires it so the kart coasts rather than driving away
## unattended. The core has no notion of focus — that is an engine concern — so
## the observation lives here and the effect is the core's own clear(), which M1
## built and nothing called until now.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if input != null:
			input.clear()
