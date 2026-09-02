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
const LayoutIO := preload("res://scripts/world/layout_io.gd")

## The seed the AUTHORING scatter starts from — tools and suites only. The game
## itself boots the shipped circuit (below) and never scatters, so this is the
## seed content was authored from rather than the seed the player plays:
## tools/author_first_light.gd restates it, and the same field is what
## regenerate_world() produces for the tools and suites that still want one.
##
## Fixed rather than drawn from the clock: a field nobody can reproduce is a
## field nobody can report a bug about.
const STARTING_SEED := 20260829

## The boot world's file, overridable for suites — the LPC_LAYOUT_FILE
## tradition, but a SEPARATE variable from it on purpose: LPC_LAYOUT_FILE
## redirects Save/Load Layout, and several suites point it at a scratch file
## before the scene is even instantiated. Sharing one variable would make those
## suites boot into whatever that scratch file last held.
const CIRCUIT_FILE_ENV := "LPC_CIRCUIT_FILE"

## The camera shake's seed. A SEPARATE stream and a different value from
## STARTING_SEED: the shudder must not depend on how many props were scattered,
## and it must not reset when the player regenerates the world. Same value would
## have worked and read as though the two were one thing.
const SHAKE_SEED := 704221

## The pre-race inspection pose — the design document's approximate (0, 5, −10),
## stated in its own world frame, looking toward the origin.
const INSPECT_POSITION := Vector3(0, 5, -10)

## Actions declared in project.godot's InputMap, mapped to the core's held-state
## fields. The other bound actions — Reset Kart, Save/Load Layout, and the
## `regenerate` action the design document renamed to Restart Circuit — are read
## edge-triggered in _read_input().
const DRIVE_ACTIONS := {
	"accelerate": "forward",
	"reverse": "reverse",
	"steer_left": "left",
	"steer_right": "right",
}

## The LPC_SMOKE drive (§14 phase 2) mirrors tests/lap_gate_test.gd's
## LAP_PHASES — the suite proves that table banks; the smoke must not import
## test code into the shipped binary, so the table is restated here with its
## source named. Neither copy is hand-written: both are baked from the shipped
## circuit by tools/author_first_light.gd, which prints them together.
const SMOKE_PHASES: Array = [
	[true, false, false, 116],
	[true, true, false, 28],
	[true, false, true, 3],
	[true, false, false, 89],
	[true, true, false, 1],
	[true, false, false, 8],
	[true, true, false, 31],
	[true, false, true, 2],
	[true, false, false, 34],
	[true, false, true, 1],
	[true, false, false, 131],
	[true, true, false, 28],
	[true, false, false, 11],
	[true, false, true, 1],
	[true, false, false, 114],
	[true, false, true, 1],
	[true, true, false, 12],
	[true, false, true, 2],
	[true, false, false, 123],
	[true, true, false, 1],
	[true, false, false, 19],
	[true, true, false, 31],
	[true, false, false, 56],
	[true, true, false, 1],
	[true, false, false, 42],
	[true, true, false, 42],
	[true, false, true, 2],
	[true, false, false, 38],
	[true, false, true, 1],
	[true, false, false, 14],
	[true, false, true, 29],
	[true, true, false, 3],
	[true, false, true, 1],
	[true, false, false, 9],
	[true, false, true, 1],
	[true, false, false, 49],
]
const SMOKE_ACTIONS: Array = ["accelerate", "steer_left", "steer_right"]
const SMOKE_BOOT_DEADLINE_TICKS := 600
const SMOKE_BANK_DEADLINE_TICKS := 2000

var sim: RefCounted = null
var input: RefCounted = null

## The chase camera's state. In the core because it is a fixed-step recurrence
## whose specified properties are numbers — see scripts/core/chase_camera.gd.
var camera: RefCounted = null

## The scattered field. The generator lives in the core; this holds what it
## produced, in the order it produced it. The AUTHORING path only — the game
## boots the circuit below.
var scatter: RefCounted = null
var field_seed: int = STARTING_SEED

## The circuit this session is playing, as it was loaded: the props in file
## order beside the gates. Held because Restart Circuit rebuilds THIS
## arrangement — "the same authored arrangement, not a fresh scatter".
var loaded_circuit: RefCounted = null

var _art: RefCounted = null

## The live tuning surface (Runtime Tuning): data/tuning.json's mtime,
## polled once a second on the SIMULATION clock; a change re-applies the
## table into the same shared tuning object, in force next tick. A file, not
## a panel — §7 bans player-facing instrumentation, and nothing draws this.
var _tuning_mtime: int = 0
var _tuning_poll_tick: int = 0

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

## The gate furniture. Optional like the other views — a headless suite drives
## the root with none of them attached.
@onready var gates: Node3D = get_node_or_null("Gates") as Node3D


## The render-scale cap (Limiting render resolution on high-density displays).
## The knob that governs the RENDER SURFACE is the viewport's 3D scale — the
## first draft capped content_scale_factor, which scales the 2D canvas and
## leaves the 3D target at native density (M6 Critic finding 2). Effective
## render density = device pixel ratio × this factor, capped at exactly 2.
static func capped_3d_scale(device_pixel_ratio: float) -> float:
	return minf(1.0, 2.0 / maxf(device_pixel_ratio, 1.0))


func _ready() -> void:
	var tuning: RefCounted = TuningLoader.load_tuning()
	# DPI cap, applied to the real render surface from the real screen's ratio.
	var viewport := get_viewport()
	if viewport != null:
		viewport.scaling_3d_scale = capped_3d_scale(DisplayServer.screen_get_scale())
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
	# been logged by the loader that hit it. The world built here is the SHIPPED
	# CIRCUIT (Session Bootstrap, as amended), not a seeded scatter.
	if _build_circuit_world():
		sim.race.mark_world_ready()
	else:
		sim.race.fail_load("Could not load the circuit — see the log")
	if gates != null and _art != null:
		gates.configure(_art, self)
	if minimap != null and _art != null:
		# Markers join the world this node roots; the chase camera must not
		# see their layer (godot/minimap — masked, never moved or toggled).
		minimap.configure(_art, self)
		if chase_camera != null:
			chase_camera.cull_mask &= ~(1 << 1)
	if OS.get_environment("LPC_SMOKE") == "1":
		_run_smoke()


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
	_poll_tuning()
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
			# And it must be the camera the game RENDERS through, pre-race
			# included: the world scene's placeholder ships current=true (for
			# its own standalone captures) and carries no marker mask — left
			# in charge, it showed the minimap disc floating over the kart
			# through the whole countdown (checklist item 9, found by the M8
			# grazing-angle capture).
			chase_camera.current = true
	if gates != null:
		gates.draw_from(sim)
	if overlay != null:
		# The camera is handed in for the off-screen gate chevron, which is the
		# projection of a world point — the overlay reads it, never moves it.
		overlay.draw_from(sim, _art, chase_camera)
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


## The live tuning watch. Reads the FILE's mtime once a second of sim time;
## on change, re-applies the table into the shared object every consumer
## already holds — the next tick simply reads new numbers. The kart's state
## and the clock are untouched by the application itself.
func _poll_tuning() -> void:
	_tuning_poll_tick += 1
	if _tuning_poll_tick < Sim.TICKS_PER_SECOND:
		return
	_tuning_poll_tick = 0
	var path := ProjectSettings.globalize_path(TuningLoader.TUNING_PATH)
	var mtime := FileAccess.get_modified_time(path)
	if _tuning_mtime == 0:
		_tuning_mtime = mtime
		return
	if mtime == _tuning_mtime:
		return
	_tuning_mtime = mtime
	apply_tuning_file()


## Re-parse the tuning file into the SHARED object. Callable by suites, which
## must not write repo files; the watch above calls it on a real edit.
func apply_tuning_file() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TuningLoader.TUNING_PATH))
	if not (parsed is Dictionary):
		push_error("tuning: live reload failed — the file is not a JSON object")
		return false
	sim.tuning.apply_table(parsed)
	print("tuning: live table applied; in force next tick")
	return true


## The boot world: the shipped circuit, through the ordinary layout import.
##
## Returns whether the world is ready to race in. A headless root with no
## PropField has nothing to build and succeeds; models that cannot be loaded, a
## missing file, a malformed one, and a GATELESS one all fail, and the caller
## turns that into the terminal LOADING error.
func _build_circuit_world() -> bool:
	if props == null:
		return true
	if props.authored_boxes().is_empty() and not props.load_assets():
		push_error("main: could not load the prop models; the field is empty")
		return false
	var path: String = circuit_path()
	var loaded: RefCounted = LayoutIO.import_layout(path, props.authored_boxes())
	if not loaded.ok:
		push_error("main: the shipped circuit at %s did not load" % path)
		return false
	loaded_circuit = loaded
	build_field(loaded.placements)
	sim.arm_circuit(loaded.circuit)
	print(
		(
			"world: circuit %s — %d props, %d gates from %s"
			% [
				loaded.circuit.circuit_name,
				loaded.placements.size(),
				loaded.circuit.gate_count(),
				path
			]
		)
	)
	return true


## Where the boot world is read from: the committed circuit, or the override a
## suite sets to boot a different — or a deliberately broken — file.
static func circuit_path() -> String:
	var override := OS.get_environment(CIRCUIT_FILE_ENV)
	return override if override != "" else LayoutIO.SHIPPED_CIRCUIT_PATH


## Scatter a fresh field and hand it to the view — THE AUTHORING PATH, and no
## longer bound to any player action (godot/world-scatter, as amended). Circuits
## are authored from a scatter, so the tools and the suites still need it; the
## player's `G` is Restart Circuit below.
##
## The design document's regeneration scenario requires the kart's position,
## heading, velocity and the running clock be left untouched — which is why
## nothing here touches the simulation. Regenerating is a world operation, not a
## reset.
func _generate_field(seed_value: int) -> bool:
	if props == null:
		return true
	if props.authored_boxes().is_empty() and not props.load_assets():
		push_error("main: could not load the prop models; the field is empty")
		return false
	build_field(scatter.generate(seed_value, props.authored_boxes()))
	print("world: seed %d — %s" % [seed_value, scatter.shortfall_report()])
	return true


## Restart Circuit — the `regenerate` binding's new behaviour (Procedural World
## Generation / Restarting the circuit). The world half is here: every prop is
## released and the LOADED arrangement rebuilt, never a fresh scatter. The
## attempt half is the core's, in one call, so the two cannot drift apart.
##
## Instant and total for the attempt, and nothing else: the race state never
## leaves RACING, there is no fresh countdown, and the session's per-circuit
## best is untouched.
func restart_circuit() -> void:
	if loaded_circuit != null:
		build_field(loaded_circuit.placements)
	sim.restart_circuit()


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


## Save Layout (P): the current field to indented JSON, in registration
## order, delivered per A2. The loaded circuit rides along, so a version-2 file
## saves back as a version-2 file. Callable directly by suites.
func save_layout() -> bool:
	if props == null:
		return false
	return LayoutIO.export_layout(
		props, props.authored_boxes(), LayoutIO.layout_path(), sim.circuit
	)


## Load Layout (L): validate first, then rebuild through the same path
## regeneration uses — release-first, registered in file order (A3). A
## refused file changes nothing. A version-2 file also ARMS its circuit, which
## is the only way a circuit exists until the boot swap ships one.
func load_layout() -> bool:
	if props == null:
		return false
	var loaded: RefCounted = LayoutIO.import_layout(LayoutIO.layout_path(), props.authored_boxes())
	if not loaded.ok:
		return false
	loaded_circuit = loaded
	build_field(loaded.placements)
	sim.arm_circuit(loaded.circuit)
	print("layout: restored %d props from %s" % [loaded.placements.size(), LayoutIO.layout_path()])
	return true


## The authoring scatter, one seed on. NOT bound to a player action since the
## GDD's Restart Circuit rename — kept for the tools and suites that author and
## check the scatter rules (godot/world-scatter's "regenerated through the
## authoring path" scenarios).
func regenerate_world() -> void:
	field_seed += 1
	_generate_field(field_seed)


func _read_input() -> void:
	for action in DRIVE_ACTIONS:
		input.set(DRIVE_ACTIONS[action], Input.is_action_pressed(action))
	# Edge-triggered, not held: one press is one fresh attempt. The action keeps
	# its name and its `G` binding — the GDD renamed the ACTION, not the port's
	# InputMap entry, which check_settings.py pins by exact text.
	if Input.is_action_just_pressed("regenerate_world") and sim.race.is_racing():
		restart_circuit()
	if Input.is_action_just_pressed("reset_kart") and sim.race.is_racing():
		sim.reset_kart()
	if Input.is_action_just_pressed("save_layout"):
		save_layout()
	if Input.is_action_just_pressed("load_layout"):
		load_layout()


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


## §14 phase 2, executable: LPC_SMOKE=1 makes the SHIPPED artifact prove
## "boots to countdown, drives, banks a lap, exits clean" by itself — boot
## unaided, control on GO, the lap drive through the real input path, exit 0
## only on a banked lap. LPC_SMOKE_SHOT names a PNG to write just after the
## bank, so every smoked target leaves a capture. Unset, none of this exists.
##
## The drive mirrors tests/lap_gate_test.gd's LAP_PHASES — the suite proves
## that table banks; the smoke must not import test code into the shipped
## binary, so the table is restated above with its source named. Both copies
## are baked from the shipped circuit by tools/author_first_light.gd.
func _run_smoke() -> void:
	var waited := 0
	while not sim.race.is_racing():
		await get_tree().physics_frame
		waited += 1
		if waited > SMOKE_BOOT_DEADLINE_TICKS:
			_smoke_fail("never reached RACING within %d ticks" % SMOKE_BOOT_DEADLINE_TICKS)
			return
	print("smoke: countdown handed over control at tick %d" % sim.ticks)

	var start: int = sim.ticks
	var phase_index := 0
	var phase_start: int = start
	while not sim.lap.banked_this_tick:
		if sim.ticks - start > SMOKE_BANK_DEADLINE_TICKS:
			_smoke_fail("drove %d ticks without banking a lap" % (sim.ticks - start))
			return
		var phase: Array = SMOKE_PHASES[phase_index % SMOKE_PHASES.size()]
		if sim.ticks >= phase_start + int(phase[3]):
			phase_start += int(phase[3])
			phase_index += 1
			phase = SMOKE_PHASES[phase_index % SMOKE_PHASES.size()]
		for i in range(SMOKE_ACTIONS.size()):
			if phase[i]:
				Input.action_press(SMOKE_ACTIONS[i])
			else:
				Input.action_release(SMOKE_ACTIONS[i])
		await get_tree().physics_frame
	for action: String in SMOKE_ACTIONS:
		Input.action_release(action)
	print(
		(
			"smoke: banked a %.2f s lap at tick %d; drives, banks, and the clock ran"
			% [sim.lap.banked_seconds, sim.ticks]
		)
	)

	var shot: String = OS.get_environment("LPC_SMOKE_SHOT")
	if shot != "":
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		if image == null or image.save_png(shot) != OK:
			_smoke_fail("could not write the smoke capture to %s" % shot)
			return
		print("smoke: capture written to %s" % shot)
	print("smoke: clean exit")
	get_tree().quit(0)


func _smoke_fail(reason: String) -> void:
	printerr("smoke: FAILED — %s" % reason)
	get_tree().quit(1)
