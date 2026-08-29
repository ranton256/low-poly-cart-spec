# Smoke suite — proves the harness works and guards the RNG and the tick
# contract. Its sim-dependent checks were rewritten by add-simulation-tick-core
# when the skeleton's 2D placeholder was replaced by the real simulation; the
# effects-channel shape went with it, because this game publishes no effects
# from the core yet. Behaviour lives in tick_test.gd, boundary_test.gd and
# determinism_test.gd; this file stays deliberately thin.
#
#   godot --headless -s tests/smoke_test.gd
extends SceneTree

# preload, NOT class_name — global class names come from a cache the editor
# writes, so on a fresh clone `godot -s` cannot see them. See GOTCHAS.md.
const RVTest := preload("res://tests/harness.gd")
const Rng := preload("res://scripts/core/rng.gd")
const Sim := preload("res://scripts/core/sim.gd")
const Tuning := preload("res://scripts/core/tuning.gd")
const InputState := preload("res://scripts/core/input_state.gd")


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_test_rng_is_reproducible()
	_test_tick_is_fixed_rate()
	_test_run_is_deterministic()
	RVTest.finish(self, "smoke: rng, fixed tick rate, determinism ok", "smoke check(s)")


## SHAPE 1 — a seeded generator must replay exactly.
func _test_rng_is_reproducible() -> void:
	Rng.seed_rng(12345)
	var first: Array[int] = []
	for i in range(8):
		first.append(Rng.next_uint32())

	Rng.seed_rng(12345)
	for i in range(8):
		_check(Rng.next_uint32() == first[i], "rng draw %d differs on replay" % i)

	Rng.seed_rng(999)
	var diverged := false
	for i in range(8):
		if Rng.next_uint32() != first[i]:
			diverged = true
	_check(diverged, "a different seed must produce a different sequence")

	Rng.seed_rng(7)
	for i in range(200):
		var roll := Rng.between(3, 9)
		_check(roll >= 3 and roll <= 9, "between(3,9) returned %d" % roll)


## SHAPE 2 — the tick is a fixed step, not wall-clock. 60 steps is one second,
## on any machine, under any load, and elapsed time comes from the tick count.
func _test_tick_is_fixed_rate() -> void:
	var sim := _sim()
	for _i in range(60):
		sim.step()
	RVTest.close(sim.elapsed_seconds(), 1.0, 0.000001, "60 ticks is one second of sim time")
	_check(sim.ticks == 60, "the tick counter is the clock")

	# and movement follows from it: held input from rest travels a positive
	# distance along +Z, the design document's world forward.
	var mover := _sim()
	mover.input.forward = true
	for _i in range(60):
		mover.step()
	_check(mover.pos_z > 0.0, "one second of held input travels forward along +Z")
	_check(absf(mover.pos_x) < 1e-12, "and does not drift sideways")


## SHAPE 3 — same inputs, same run. Compare a one-line summary rather than
## object graphs. determinism_test.gd covers this at length; this is the smoke.
func _test_run_is_deterministic() -> void:
	var summaries: Array[String] = []
	for _attempt in range(2):
		Rng.seed_rng(4242)
		var sim := _sim()
		for tick in range(300):
			sim.input.left = tick % 120 < 60
			sim.input.right = not sim.input.left
			sim.input.forward = true
			sim.step()
		summaries.append(sim.stats_line())
	_check(
		summaries[0] == summaries[1], "runs diverged:\n  %s\n  %s" % [summaries[0], summaries[1]]
	)


## The design document's tuning, supplied directly — no file, no engine.
func _sim() -> RefCounted:
	var t := Tuning.new()
	t.accel = 0.008
	t.max_speed = 0.2
	t.reverse_factor = 0.5
	t.friction = 0.96
	t.turn_rate = 0.04
	t.steer_threshold = 0.01
	t.bounce_factor = -0.3
	t.drivable_extent = 90.0
	t.speedo_max = 120.0
	var s := Sim.new()
	s.tuning = t
	s.input = InputState.new()
	return s
