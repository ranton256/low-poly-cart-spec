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

	get_root().remove_child(_root)
	_root.free()
	_root = null
	RVTest.finish(self, "driver: one step per fixed callback, view reads only", "driver check(s)")


func _test_stepping_tracks_the_fixed_rate_callback() -> void:
	var physics_before: int = Engine.get_physics_frames()
	var steps_before: int = _root.steps()
	var begins_before: int = _root.begin_frame_calls()
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
