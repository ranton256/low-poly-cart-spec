# Acceptance item 14a — the simulation is indifferent to how ticks are batched.
#
#   godot --headless -s tests/replay_test.gd
#
# Item 14 is stated in frames per second, but what a frame rate DOES to a
# fixed-step simulation is change how many ticks a frame consumes: two at 30 fps,
# one at 60, and at 144 most frames consume none while some consume one. So
# batching is the property under test, and it needs no frame loop at all. The
# real loop at real refresh rates is 14b, at M8.
#
# determinism_test.gd proves two runs of the SAME driver agree. That says nothing
# about batching, which is exactly what a frame loop varies.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const Sim := preload("res://scripts/core/sim.gd")
const Tuning := preload("res://scripts/core/tuning.gd")
const InputState := preload("res://scripts/core/input_state.gd")

# The 60 seconds acceptance item 14 names.
const REPLAY_TICKS := 3600


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_test_batching_does_not_change_the_outcome()
	_test_the_sequence_is_not_straight_line()
	RVTest.finish(
		self, "replay: batching-independent over %d ticks" % REPLAY_TICKS, "replay check(s)"
	)


func _tuning() -> RefCounted:
	var t := Tuning.new()
	t.accel = 0.01
	t.max_speed = 0.25
	t.reverse_factor = 0.5
	t.friction = 0.96
	t.turn_rate = 0.05
	t.steer_threshold = 0.0125
	t.steer_ease_seconds = 0.12
	t.bounce_factor = -0.3
	t.drivable_extent = 90.0
	t.speedo_max = 120.0
	return t


func _sim() -> RefCounted:
	var s := Sim.new()
	s.tuning = _tuning()
	s.input = InputState.new()
	# Boot from LOADING through the real countdown: batch-independence must
	# hold across the frozen prefix too (godot/race-state).
	s.race.mark_world_ready()
	return s


## Turns, reverses and releases input rather than only accelerating. A
## straight-line run is nearly symmetric under batching and would pass against a
## broken implementation.
func _apply_input(s: RefCounted, tick: int) -> void:
	s.input.forward = (tick % 97) > 12
	s.input.reverse = (tick % 313) < 24
	s.input.left = (tick % 71) < 26
	s.input.right = (tick % 53) < 17


## The tick groupings a frame loop produces at three display rates. A frame
## consuming zero ticks is the 144 fps case and must be a no-op, not a skip.
func _batches(pattern: Array, total: int) -> Array:
	var out: Array = []
	var i := 0
	var done := 0
	while done < total:
		var n: int = pattern[i % pattern.size()]
		n = mini(n, total - done)
		out.append(n)
		done += n
		i += 1
		if n == 0 and i > total * 4:
			break
	return out


func _run(pattern: Array) -> RefCounted:
	var s := _sim()
	var tick := 0
	for batch in _batches(pattern, REPLAY_TICKS):
		# Once per frame, as a composition root would — including frames that
		# consume no ticks. This is the seam through which batching is visible
		# to the simulation at all.
		s.begin_frame()
		for _i in range(batch):
			_apply_input(s, tick)
			s.step()
			tick += 1
	return s


func _test_batching_does_not_change_the_outcome() -> void:
	var one_at_a_time := _run([1])  # a 60 Hz display: one tick per frame
	var thirty := _run([2])  # 30 fps: two ticks per frame
	var one_forty_four := _run([0, 1, 1])  # 144 fps: most frames advance nothing

	_check(
		one_at_a_time.ticks == REPLAY_TICKS, "the reference run advanced %d ticks" % REPLAY_TICKS
	)
	_check(thirty.ticks == REPLAY_TICKS, "the 30 fps batching advanced the same number of ticks")
	_check(
		one_forty_four.ticks == REPLAY_TICKS,
		"the 144 fps batching advanced the same number of ticks"
	)

	var reference: String = one_at_a_time.stats_line()
	_check(
		thirty.stats_line() == reference,
		(
			"30 fps batching agrees exactly\n    got  %s\n    want %s"
			% [thirty.stats_line(), reference]
		)
	)
	_check(
		one_forty_four.stats_line() == reference,
		(
			"144 fps batching agrees exactly\n    got  %s\n    want %s"
			% [one_forty_four.stats_line(), reference]
		)
	)


## Guards the guard: if the scripted sequence never turned or reversed, the three
## runs would agree for a reason that has nothing to do with the simulation.
func _test_the_sequence_is_not_straight_line() -> void:
	var s := _sim()
	var turned := false
	var reversed_travel := false
	var coasted := false
	for tick in range(REPLAY_TICKS):
		_apply_input(s, tick)
		s.step()
		if s.yaw != 0.0:
			turned = true
		if s.velocity < 0.0:
			reversed_travel = true
		if not s.input.forward and not s.input.reverse:
			coasted = true
	_check(turned, "the sequence turns the kart")
	_check(reversed_travel, "the sequence drives it backwards at some point")
	_check(coasted, "the sequence releases all drive input at some point")
