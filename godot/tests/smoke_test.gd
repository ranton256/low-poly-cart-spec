# Smoke suite — proves the harness works and demonstrates the four assertion
# shapes you will reuse constantly. Delete these once you have real suites, or
# keep them: they also guard the RNG and the sim's tick contract.
#
#   godot --headless -s tests/smoke_test.gd
extends SceneTree

# preload, NOT class_name — global class names come from a cache the editor
# writes, so on a fresh clone `godot -s` cannot see them. See GOTCHAS.md.
const RVTest := preload("res://tests/harness.gd")
const Rng := preload("res://scripts/core/rng.gd")
const Sim := preload("res://scripts/core/sim.gd")


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_test_rng_is_reproducible()
	_test_tick_is_fixed_rate()
	_test_run_is_deterministic()
	_test_effects_are_published_as_data()
	RVTest.finish(self, "smoke: rng, tick rate, determinism, event channel ok", "smoke check(s)")


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
## on any machine, under any load.
func _test_tick_is_fixed_rate() -> void:
	var sim := Sim.new()
	sim.setup()
	for i in range(60):
		sim.step()
	RVTest.close(sim.time_ms, 1000.0, 0.1, "60 ticks is one second of sim time")

	# and movement follows from it: one second of held input travels SPEED px
	var mover := Sim.new()
	mover.setup()
	var start_x: float = mover.px
	mover.in_right = true
	for i in range(60):
		mover.step()
	RVTest.close(mover.px - start_x, Sim.SPEED, 1.0, "one second of input travel")


## SHAPE 3 — same seed, same inputs, same run. Compare a one-line summary
## rather than object graphs.
func _test_run_is_deterministic() -> void:
	var summaries: Array[String] = []
	for attempt in range(2):
		Rng.seed_rng(4242)
		var sim := Sim.new()
		sim.setup()
		for tick in range(300):
			sim.in_left = tick % 120 < 60
			sim.in_right = not sim.in_left
			sim.step()
			sim.events.clear()
		summaries.append(sim.stats_line())
	_check(
		summaries[0] == summaries[1], "runs diverged:\n  %s\n  %s" % [summaries[0], summaries[1]]
	)


## SHAPE 4 — effects are data the view drains, so they can be asserted with no
## audio device. The NEGATIVE case matters as much as the positive one.
func _test_effects_are_published_as_data() -> void:
	var sim := Sim.new()
	sim.setup()

	sim.in_left = true
	var bumped := false
	for i in range(300):  # long enough to reach the left wall
		sim.step()
		for e in sim.events:
			if e.get("type", "") == "sfx" and e["id"] == "bump":
				bumped = true
		sim.events.clear()
	_check(bumped, "hitting a wall publishes a 'bump' effect")

	var quiet := Sim.new()
	quiet.setup()
	quiet.step()
	_check(quiet.events.is_empty(), "an idle tick publishes nothing")
