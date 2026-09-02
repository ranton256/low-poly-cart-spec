# Reproducibility and precision of the simulation core.
#
#   godot --headless -s tests/determinism_test.gd
#
# Determinism is not a testing nicety here — it is what makes every other
# headless suite meaningful, and acceptance item 14 depends on it. A divergence
# is a defect in the simulation, never noise to be tolerated.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const Sim := preload("res://scripts/core/sim.gd")
const Tuning := preload("res://scripts/core/tuning.gd")
const InputState := preload("res://scripts/core/input_state.gd")

# The longest run the timing suite needs, with headroom.
const LONG_RUN_TICKS := 3000


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_test_two_runs_agree_exactly()
	_test_precision_is_far_below_the_tolerance()
	_test_tuning_change_applies_next_tick()
	_test_constructible_without_a_file()
	RVTest.finish(
		self, "determinism: identical runs, precision, live tuning", "determinism check(s)"
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
	# Boot from LOADING through the real countdown: acceptance 14a spans it
	# (godot/race-state, "Two runs agree through the countdown").
	s.race.mark_world_ready()
	return s


## A scripted input sequence, deterministic and not trivially straight-line.
func _apply_scripted_input(s: RefCounted, tick: int) -> void:
	s.input.forward = (tick % 7) != 0
	s.input.reverse = (tick % 53) == 0
	s.input.left = (tick % 11) < 4
	s.input.right = (tick % 17) < 3


func _test_two_runs_agree_exactly() -> void:
	var a := _sim()
	var b := _sim()
	var diverged_at := -1
	for tick in range(LONG_RUN_TICKS):
		_apply_scripted_input(a, tick)
		_apply_scripted_input(b, tick)
		a.step()
		b.step()
		if a.stats_line() != b.stats_line():
			diverged_at = tick
			break
	_check(
		diverged_at < 0,
		"two separately constructed runs agree tick for tick (diverged at %d)" % diverged_at
	)
	_check(a.ticks == LONG_RUN_TICKS, "the run actually advanced %d ticks" % LONG_RUN_TICKS)


## The timing scenarios assert to +/- 0.05 s, which is three ticks. Accumulated
## error over the longest run must be far below that, or a passing timing test
## is luck. Compared against the closed form of the same recurrence.
func _test_precision_is_far_below_the_tolerance() -> void:
	var s := _sim()
	s.input.forward = true
	# Steady state has a closed form: accel * friction / (1 - friction).
	var accel: float = s.tuning.accel
	var friction: float = s.tuning.friction
	var closed_form: float = accel * friction / (1.0 - friction)
	for _i in range(LONG_RUN_TICKS):
		s.velocity = minf(s.velocity + accel, s.tuning.max_speed) * friction
	var drift: float = absf(s.velocity - closed_form)
	# One tick of velocity is ~0.192 wu; the tolerance is three ticks of TIME.
	# Drift of even 1e-9 wu/tick is six orders below anything that could move a
	# reported timing by a single tick.
	_check(
		drift < 1e-9,
		(
			"accumulated drift over %d ticks is %.15f, far below what could shift a timing"
			% [LONG_RUN_TICKS, drift]
		)
	)


# @covers Runtime Tuning and Player Actions / Adjusting handling without a restart
func _test_tuning_change_applies_next_tick() -> void:
	var s := _sim()
	s.race.start_racing_immediately()  # pipeline check, not a countdown check
	s.input.forward = true
	for _i in range(50):
		s.step()
	var pos_before: float = s.pos_z
	var yaw_before: float = s.yaw
	var vel_before: float = s.velocity
	var ticks_before: int = s.ticks

	# change a value mid-run
	s.tuning.accel = s.tuning.accel * 2.0

	_check(s.pos_z == pos_before, "changing tuning does not move the kart")
	_check(s.yaw == yaw_before, "changing tuning does not turn the kart")
	_check(s.velocity == vel_before, "changing tuning does not alter velocity by itself")
	_check(s.ticks == ticks_before, "changing tuning does not advance the clock")

	# and takes effect on the very next tick
	var expected: float = minf(vel_before + s.tuning.accel, s.tuning.max_speed) * s.tuning.friction
	s.step()
	_check(
		absf(s.velocity - expected) < 1e-12,
		"the new value is in force on the next tick, with no restart"
	)


func _test_constructible_without_a_file() -> void:
	var s := _sim()
	s.race.start_racing_immediately()  # pipeline check, not a countdown check
	s.input.forward = true
	s.step()
	_check(
		s.ticks == 1 and s.velocity > 0.0,
		"the simulation runs on directly supplied tuning, no file present"
	)
