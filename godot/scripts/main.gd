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
const Scatter := preload("res://scripts/core/scatter.gd")
const RaceState := preload("res://scripts/core/race_state.gd")

## Actions declared in project.godot's InputMap, mapped to the core's held-state
## fields. The design document's control table also binds Reset Kart and Save
## Layout, whose EFFECTS arrive in M7 — they are bound here and deliberately do
## nothing, which the register entry for "Mapping the control scheme" records.
## The seed this session's field is generated from.
##
## Fixed rather than drawn from the clock: a field nobody can reproduce is a field
## nobody can report a bug about. Regenerate World advances it, so the player gets
## a new arrangement while every one of them stays nameable.
const STARTING_SEED := 20260829

## The camera shake's seed. A SEPARATE stream and a different value from
## STARTING_SEED: the shudder must not depend on how many props were scattered,
## and it must not reset when the player regenerates the world. Same value would
## have worked and read as though the two were one thing.
const SHAKE_SEED := 704221

## The pre-race inspection pose — the design document's approximate (0, 5, −10),
## stated in its own world frame, looking toward the origin.
const INSPECT_POSITION := Vector3(0, 5, -10)

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

## The scattered field. The generator lives in the core; this holds what it
## produced, in the order it produced it.
var scatter: RefCounted = null
var field_seed: int = STARTING_SEED

var _art: RefCounted = null

var _steps: int = 0
var _frames: int = 0
var _begin_frame_calls: int = 0
var _camera_steps: int = 0
var _jolts: int = 0

## The kart view, found in the scene rather than constructed here: the root owns
## the simulation, not the presentation. It is optional so a headless suite can
## drive the root with no view attached.
@onready var kart: Node3D = get_node_or_null("Kart") as Node3D

## The node the chase camera is applied to. Optional for the same reason the kart
## view is: a headless suite drives the root with neither attached.
@onready var chase_camera: Camera3D = get_node_or_null("ChaseCamera") as Camera3D

## The props. Optional like the other views, so a headless suite can drive the
## root without one.
@onready var props: Node3D = get_node_or_null("PropField") as Node3D

## The start-sequence overlay. Optional like the other views.
@onready var overlay: CanvasLayer = get_node_or_null("Overlay") as CanvasLayer

## The minimap inset. Optional like the other views.
@onready var minimap: SubViewportContainer = get_node_or_null("Minimap") as SubViewportContainer


## The render-scale cap (Limiting render resolution on high-density displays):
## a device pixel ratio above 2 is clamped to exactly 2 — the game never
## renders at full native density of very dense displays.
static func capped_scale(device_pixel_ratio: float) -> float:
	return minf(device_pixel_ratio, 2.0)


func _ready() -> void:
	var tuning: RefCounted = TuningLoader.load_tuning()
	# DPI cap, applied to the real window from the real screen's ratio.
	var window := get_window()
	if window != null:
		window.content_scale_factor = capped_scale(DisplayServer.screen_get_scale())
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
	camera.seed_shake(SHAKE_SEED)
	if kart != null:
		# What the kart's hit volume is recomputed from each tick. The correction
		# is included because the volume follows the model's transform, and the
		# model is rotated a quarter turn from the simulation's forward.
		sim.kart_normalised = kart.normalised()
		sim.kart_yaw_offset = kart.yaw_correction()
	_art = ArtTuning.load_art()
	scatter = Scatter.new()
	scatter.tuning = tuning
	# Bootstrap verdict (godot/race-state): success hands off to the countdown
	# automatically; failure is a terminal LOADING with a visible message —
	# never a countdown into a broken world. The underlying error has already
	# been logged by the loader that hit it.
	if _generate_field(field_seed):
		sim.race.mark_world_ready()
	else:
		sim.race.fail_load("Could not load the game's models — see the log")
	if minimap != null and _art != null:
		# Markers join the world this node roots; the chase camera must not
		# see their layer (godot/minimap — masked, never moved or toggled).
		minimap.configure(_art, self)
		if chase_camera != null:
			chase_camera.cull_mask &= ~(1 << 1)


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
	# ONLY WHILE RACING ("Suspending the simulation outside the racing state"):
	# before the race starts the chase camera does not engage — the view holds
	# the fixed inspection pose — so stepping it here would ease it toward a
	# kart it is not yet following.
	if sim.race.is_racing():
		camera.step(sim.pos_x, sim.pos_z, sim.yaw, sim.speed_ratio())
		# AFTER the camera's own step, so the displacement survives into the
		# following ticks instead of being eased away by the step that produced
		# it. The easing absorbs it from here with no separate decay.
		if sim.last_hit != null:
			camera.jolt()
			_jolts += 1
		_camera_steps += 1
	_steps += 1


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
		if sim.race.is_racing():
			chase_camera.apply(camera, _art.num("nearClip"), _art.num("farClip"))
		else:
			# "Viewing the kart before the start": a fixed inspection pose
			# behind and above the start line, looking at the origin. The chase
			# camera engages on the first RACING frame.
			chase_camera.look_at_from_position(INSPECT_POSITION, Vector3.ZERO)
	if overlay != null:
		overlay.draw_from(sim, _art)
	if minimap != null:
		minimap.draw_from(sim)


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


## How many collisions have jolted the camera. Exists for the same reason
## camera_steps() does: "the running game jolts on a collision" is otherwise
## invisible from outside, and deleting the call left the whole suite green.
func jolts() -> int:
	return _jolts


## How far the current frame sits between the last step and the next, 0..1.
##
## The engine's own fraction, which is meaningful precisely because the engine
## owns the loop that produced the steps. The view draws at this; nothing else
## reads it.
func interpolation_fraction() -> float:
	return Engine.get_physics_interpolation_fraction()


## Scatter a field and hand it to the view.
##
## The design document's regeneration scenario requires the kart's position,
## heading, velocity and the running clock be left untouched — which is why
## nothing here touches the simulation. Regenerating is a world operation, not a
## reset.
## Returns whether the world is ready to race in. A headless root with no
## PropField has nothing to load and succeeds; a field whose models cannot be
## loaded fails, and the caller turns that into the terminal LOADING error.
func _generate_field(seed_value: int) -> bool:
	if props == null:
		return true
	if props.authored_boxes().is_empty() and not props.load_assets():
		push_error("main: could not load the prop models; the field is empty")
		return false
	build_field(scatter.generate(seed_value, props.authored_boxes()))
	print("world: seed %d — %s" % [seed_value, scatter.shortfall_report()])
	return true


## Instantiate a field and hand it to the simulation, in registration order.
##
## ONE PLACE, because the two halves must not drift: a build that draws props the
## simulation does not know about is a field the kart drives through. Review
## deleted the second line and every collision test stayed green, so
## driver_test.gd now asserts this wiring against the running scene, and
## tools/collision_capture.gd stages its arrangements THROUGH this method rather
## than repeating it — a capture that wires its own props would show a collision
## in a build that has none.
func build_field(placements: Array) -> void:
	if props == null:
		return
	props.build(placements)
	# In registration order, which is what collision resolves by.
	sim.props = props.collision_props()


## Regenerate World. The design document gives this action no required binding and
## leaves the exposure to the port; project.godot binds it and check_settings.py
## pins it.
func regenerate_world() -> void:
	field_seed += 1
	_generate_field(field_seed)


func _read_input() -> void:
	for action in DRIVE_ACTIONS:
		input.set(DRIVE_ACTIONS[action], Input.is_action_pressed(action))
	# Edge-triggered, not held: one press is one new world.
	if Input.is_action_just_pressed("regenerate_world"):
		regenerate_world()


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
