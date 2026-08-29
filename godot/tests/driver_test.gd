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

var _root: Node3D = null


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	await process_frame
	_root = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	get_root().add_child(_root)
	await process_frame

	await _test_stepping_tracks_the_fixed_rate_callback()
	_test_the_view_never_writes_back()
	_test_the_game_looks_through_the_specified_camera()
	await _test_the_running_game_collides_and_jolts()

	get_root().remove_child(_root)
	_root.free()
	_root = null
	RVTest.finish(
		self, "driver: one step per fixed callback, view reads only, props wired", "driver check(s)"
	)


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
