# The composition root drives the simulation, and only it does.
#
#   godot --headless -s tests/driver_test.gd
#
# WHAT THIS DOES NOT TEST, stated because it would be easy to assume otherwise:
# the fixed-step accumulator is GODOT'S (design D2a), so its correctness — whole
# steps, remainder carried, more steps on a slow frame — is the engine's and a
# suite driving synthetic elapsed times here would be testing Godot. What IS
# ours, and is tested below, is that we step exactly once per fixed-rate callback
# and never in the per-frame one, so the step count remains a function of elapsed
# time alone. The rate those two files agree on is pinned by check_settings.py.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const RaceState := preload("res://scripts/core/race_state.gd")
const ArtTuning := preload("res://scripts/art_tuning.gd")
const MainScene := preload("res://scenes/main.tscn")

var _root: Node3D = null


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	await process_frame
	_root = MainScene.instantiate() as Node3D
	get_root().add_child(_root)
	await process_frame

	await _test_boots_into_the_countdown_and_suspends()
	# From here the suite studies the racing pipeline; the countdown itself is
	# race_state_test's subject (race-state seam).
	_root.sim.race.start_racing_immediately()
	await _test_go_lingers_green_then_resets()
	await _test_stepping_tracks_the_fixed_rate_callback()
	_test_the_view_never_writes_back()
	_test_the_game_looks_through_the_specified_camera()
	await _test_the_frame_orders_physics_then_camera_then_minimap()
	await _test_the_readouts_derive_from_the_lap_counters()
	await _test_the_running_game_collides_and_jolts()
	await _test_a_failed_load_halts_the_real_boot()

	get_root().remove_child(_root)
	_root.free()
	_root = null
	RVTest.finish(
		self, "driver: one step per fixed callback, view reads only, props wired", "driver check(s)"
	)


## The shipped boot: straight into the countdown, with the simulation stepping,
## the chase camera suspended, and the camera holding the inspection pose.
# @covers Race Start Sequence and Game State Machine / Viewing the kart before the start
func _test_boots_into_the_countdown_and_suspends() -> void:
	var sim: RefCounted = _root.sim
	_check(
		sim.race.state == RaceState.STARTING,
		"the game boots into the countdown with no interaction and no configuration"
	)
	var camera_before: int = _root.camera_steps()
	var steps_before: int = _root.steps()
	for _i in range(6):
		await process_frame
	_check(_root.steps() > steps_before, "the simulation still steps outside RACING (A4)")
	_check(
		_root.camera_steps() == camera_before,
		"the chase camera does not run before RACING (suspension)"
	)
	var cam: Camera3D = _root.chase_camera
	if cam != null:
		_check(
			cam.global_position.distance_to(Vector3(0, 5, -10)) < 0.01,
			"the camera holds the fixed inspection pose behind and above the kart"
		)
		var toward_origin := (Vector3.ZERO - cam.global_position).normalized()
		_check((-cam.global_basis.z).angle_to(toward_origin) < 0.01, "looking toward the origin")
	var countdown: Label = _root.overlay.get_node("Countdown") as Label
	_check(countdown.visible, "the countdown overlay is on screen during STARTING")
	_check(
		countdown.text in ["READY", "3", "2", "1"],
		"showing a countdown glyph (%s)" % countdown.text
	)
	var art: RefCounted = ArtTuning.load_art()
	_check(
		countdown.label_settings.font_color.is_equal_approx(art.colour("countdownTextColour")),
		"in white — the preceding frames are never green"
	)


## The frame's ordering, observed from outside: physics first, then the
## camera from the kart's post-physics transform, then the minimap re-centred
## on the post-physics position. The camera-advances-with-the-step half is the
## stepping test above; this reads the two consumers against the stepped state.
# @covers Frame Loop and Render Pipeline / Ordering the work within a frame
func _test_the_frame_orders_physics_then_camera_then_minimap() -> void:
	for _i in range(20):
		Input.action_press("accelerate")
		await physics_frame
	Input.action_release("accelerate")
	await process_frame
	RVTest.close(
		_root.camera.aim_x,
		_root.sim.pos_x + _root.sim.forward_x() * _root.sim.tuning.aim_ahead,
		0.5,
		"the chase camera aims from the POST-physics transform"
	)
	var minimap_cam: Camera3D = _root.get_node("Minimap/Viewport/Camera") as Camera3D
	RVTest.close(
		minimap_cam.global_position.z,
		_root.sim.pos_z,
		0.5,
		"the minimap is re-centred on the post-physics position"
	)


## The GO! overlay through the running scene: green through the goLinger
## window, then hidden with its colour reset to white for the next use.
func _test_go_lingers_green_then_resets() -> void:
	var countdown: Label = _root.overlay.get_node("Countdown") as Label
	var art: RefCounted = ArtTuning.load_art()
	await process_frame
	_check(countdown.visible and countdown.text == "GO!", "GO! shows on the handover")
	_check(
		countdown.label_settings.font_color.is_equal_approx(art.colour("countdownGoColour")),
		"in the specified green"
	)
	for _i in range(35):  # goLinger is 30 ticks
		await physics_frame
	await process_frame
	_check(not countdown.visible, "after goLinger the overlay hides")
	_check(
		countdown.label_settings.font_color.is_equal_approx(art.colour("countdownTextColour")),
		"and resets its colour to white for the next use"
	)


## The broken-model boot through the REAL driver, via the LPC_FAIL_LOADS seam:
## terminal LOADING and the visible error. The logged-cause clause is carried
## by prop_field's push_error before every false return — it prints in this
## suite's own stderr when the seam trips.
func _test_a_failed_load_halts_the_real_boot() -> void:
	OS.set_environment("LPC_FAIL_LOADS", "1")
	var broken: Node3D = MainScene.instantiate() as Node3D
	get_root().add_child(broken)
	await process_frame
	await process_frame
	_check(broken.sim.race.state == RaceState.LOADING, "the failed boot stays in LOADING")
	_check(broken.sim.race.error_message != "", "with the error recorded for the view")
	var loading: Label = broken.overlay.get_node("Loading") as Label
	_check(
		loading.visible and loading.text == broken.sim.race.error_message,
		"and the loading indicator replaced by the visible error"
	)
	for _i in range(30):
		await physics_frame
	_check(broken.sim.race.state == RaceState.LOADING, "terminally — no countdown follows")
	OS.set_environment("LPC_FAIL_LOADS", "")
	get_root().remove_child(broken)
	broken.free()


## THE CHANGE'S HEADLINE DELIVERABLE, AND NOTHING GUARDED IT.
##
## add-chase-camera exists to retire the placeholder viewpoint that
## add-world-presentation-layer shipped. Review deleted the ChaseCamera node from
## main.tscn — putting the running game back on the placeholder — and the whole
## standing suite stayed green, because the root reads the node with
## get_node_or_null and skips it when absent.
##
## This is also the change's own spec scenario "The running game uses the
## specified camera, not the placeholder", which had no test.
func _test_the_game_looks_through_the_specified_camera() -> void:
	var camera: Camera3D = _root.chase_camera
	_check(camera != null, "the running scene has a chase camera at all")
	if camera == null:
		return
	_check(camera.current, "and the game looks through it, not through the placeholder")

	# The placeholder is still in world.tscn, deliberately — world.tscn must stay
	# capturable on its own. What must NOT happen is the game rendering through
	# it, and "current" is the only thing that decides which camera wins.
	var placeholder: Camera3D = _root.get_node_or_null("World/PlaceholderCamera") as Camera3D
	_check(placeholder != null, "the world scene keeps its placeholder for its own captures")
	if placeholder != null:
		_check(
			not placeholder.current,
			"but the placeholder is not the active camera in the running game"
		)

	# The view applies the camera and computes none of it — the other spec
	# scenario with no test. If these disagree, something between the core and the
	# screen is doing arithmetic it should not.
	_check(
		absf(camera.fov - _root.camera.fov) < 1e-4,
		(
			"the view's field of view is the core camera's, unmodified (%f vs %f)"
			% [camera.fov, _root.camera.fov]
		)
	)
	var applied := camera.global_position
	var computed := Vector3(_root.camera.pos_x, _root.camera.pos_y, _root.camera.pos_z)
	_check(
		applied.distance_to(computed) < 1e-3,
		"and its position is the core camera's, unmodified (%v vs %v)" % [applied, computed]
	)


func _test_stepping_tracks_the_fixed_rate_callback() -> void:
	var physics_before: int = Engine.get_physics_frames()
	var steps_before: int = _root.steps()
	var begins_before: int = _root.begin_frame_calls()
	var camera_before: int = _root.camera_steps()
	for _i in range(12):
		await process_frame

	var physics_ran: int = Engine.get_physics_frames() - physics_before
	var stepped: int = _root.steps() - steps_before
	var begun: int = _root.begin_frame_calls() - begins_before

	_check(stepped > 0, "the simulation advanced at all (%d steps)" % stepped)
	# EXACTLY one per callback. More would mean a second caller; fewer would mean
	# a frame silently skipped, which is how a race clock drifts.
	_check(
		stepped == physics_ran,
		(
			"exactly one step per fixed-rate callback (%d steps for %d callbacks)"
			% [stepped, physics_ran]
		)
	)
	_check(begun > 0, "the per-frame entry point was called (%d times)" % begun)

	# THE CAMERA ADVANCES WITH THE SIMULATION, not with the frame. This is the
	# half of ambiguity A10's resolution that camera_test.gd cannot carry: its
	# tick-grouping check drives the camera itself, so it proves the property
	# holds when stepped per tick and says nothing about whether the running game
	# does. This does.
	var camera_stepped: int = _root.camera_steps() - camera_before
	_check(
		camera_stepped == stepped,
		(
			"the chase camera advances exactly once per simulation step (%d vs %d)"
			% [camera_stepped, stepped]
		)
	)
	# The per-frame callback advances NOTHING. If it stepped too, the step count
	# would exceed the callback count and the simulation would run at display rate.
	_check(
		stepped <= physics_ran,
		(
			"the per-frame callback advances the simulation none (%d steps, %d callbacks)"
			% [stepped, physics_ran]
		)
	)


## The view draws between states; it must not write one back. Reading the
## simulation after frames have been drawn must give the STEPPED value, and an
## interpolated position is never a stepped one except at the instant a step
## lands.
func _test_the_view_never_writes_back() -> void:
	var sim: RefCounted = _root.sim
	var kart: Node3D = _root.kart
	_check(kart != null, "the scene has a kart view")
	if kart == null:
		return
	sim.pos_x = 12.5
	sim.pos_z = -3.25
	kart.draw_from(sim, 0.5)
	_check(
		is_equal_approx(sim.pos_x, 12.5) and is_equal_approx(sim.pos_z, -3.25),
		"drawing the kart leaves the simulation's own position untouched"
	)


## The TIME and BEST readouts, through the running scene: pure consumers of
## the lap module's counters — set the counters, read the labels.
# @covers Heads-Up Display / Displaying an unset best time
# @covers Lap Detection and Best-Time Tracking / Persisting the best time for the session
func _test_the_readouts_derive_from_the_lap_counters() -> void:
	var overlay: CanvasLayer = _root.overlay
	_check(overlay != null, "the running scene has the overlay")
	if overlay == null:
		return
	var art: RefCounted = ArtTuning.load_art()
	var time_label: Label = overlay.get_node("TimeValue") as Label
	var best_label: Label = overlay.get_node("BestValue") as Label
	await process_frame
	await process_frame
	_check(time_label.visible and best_label.visible, "TIME and BEST show while racing")
	_check(best_label.text == "--.--", "an unset best shows the placeholder, %s" % best_label.text)

	# Two decimal places, from the running clock.
	var shown: float = float(time_label.text)
	_check(
		time_label.text.match("*.??") and absf(shown - _root.sim.lap.display_seconds()) < 0.2,
		"TIME shows the lap clock to two decimals (%s)" % time_label.text
	)

	# The hold: set the counters, and the label must follow — no state of its own.
	var lap: RefCounted = _root.sim.lap
	lap.banked_seconds = 12.34
	lap.best_seconds = 12.34
	lap.best_flash_ticks = 240
	lap.hold_ticks = 240
	await process_frame
	_check(
		time_label.text == "12.34", "during the hold TIME is the banked time (%s)" % time_label.text
	)
	_check(best_label.text == "12.34", "and BEST shows the banked best (%s)" % best_label.text)
	_check(
		best_label.label_settings.font_color.is_equal_approx(art.colour("bestFlashColour")),
		"a fresh best flashes in the data layer's green"
	)
	# Session persistence: regeneration must not touch the lap module.
	_root.regenerate_world()
	_check(lap.best_seconds == 12.34, "the best survives a world regeneration")
	lap.hold_ticks = 0
	lap.best_flash_ticks = 0
	lap.banked_seconds = -1.0
	lap.best_seconds = -1.0
	await process_frame
	_check(
		best_label.label_settings.font_color.is_equal_approx(art.colour("bestTextColour")),
		"and the flash returns to the yellow base"
	)


## THE WIRING BETWEEN THE FIELD AND THE SIMULATION, WHICH NOTHING GUARDED.
##
## Same shape as the deleted ChaseCamera above, and found the same way: review
## deleted the line handing the scattered props to the simulation and every one of
## the sixteen suites stayed green — including the whole of collision_test.gd,
## which builds its own props and never loads a scene. The shipped game would have
## had no collision at all. The capture tool did not cover it either, because it
## used to wire sim.props itself; it now goes through main.gd's build_field().
##
## Two halves, because deleting either one leaves a game that looks right:
## the props reaching the tick, and a resolved collision reaching the camera.
func _test_the_running_game_collides_and_jolts() -> void:
	var sim: RefCounted = _root.sim
	var field: Node3D = _root.props
	_check(field != null, "the running scene has a prop field")
	if field == null:
		return

	_check(field.prop_count() > 0, "the field was populated (%d props)" % field.prop_count())
	_check(
		sim.props.size() == field.prop_count(),
		(
			"every prop the view drew reached the simulation (%d vs %d)"
			% [sim.props.size(), field.prop_count()]
		)
	)
	# IN REGISTRATION ORDER, which is what collision resolves by — asserted
	# element by element rather than by counting, because a reordered array has
	# the same size and collides differently.
	var ordered := true
	for i in range(mini(sim.props.size(), field.prop_count())):
		if (sim.props[i] as RefCounted).asset != (field.records[i] as RefCounted).asset:
			ordered = false
	_check(ordered, "and in the order the view holds them, prop for prop")

	# Regeneration must re-wire, not leave the simulation colliding with the
	# previous field.
	_root.regenerate_world()
	_check(
		sim.props.size() == field.prop_count() and field.prop_count() > 0,
		(
			"regenerating the world re-wires the simulation (%d vs %d)"
			% [sim.props.size(), field.prop_count()]
		)
	)

	# Now drive the RUNNING GAME onto a prop and let its own physics callback run.
	var target: RefCounted = sim.props[0]
	sim.pos_x = target.centre_x() + 0.2
	sim.pos_z = target.centre_z() + 0.2
	sim.velocity = 0.0
	var jolts_before: int = _root.jolts()
	var collided := false
	for _i in range(4):
		await physics_frame
		if sim.last_hit != null:
			collided = true
	_check(collided, "a kart standing on a prop collides in the running game")
	_check(
		_root.jolts() > jolts_before,
		"and the collision jolts the camera (%d jolts, was %d)" % [_root.jolts(), jolts_before]
	)
