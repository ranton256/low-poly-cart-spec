# The steering ease-in — the design document's "Steering eases in rather than
# stepping" scenario, and the amended "Steering while rolling".
#
#   godot --headless -s tests/steer_test.gd
#
# WHY A SUITE OF ITS OWN. tick_test.gd owns the eight-stage tick and the
# acceptance curve; this owns one property of stage 3, at tick resolution.
# The ramp is five claims and each needs its own hold history — linear climb,
# reset on release, reset on reversal, an exact peak, and the threshold gate
# holding at every ease value — and folding five hold histories into the tick
# suite would bury the acceptance timings it exists to state.
#
# EXPECTED VALUES COME FROM THE DESIGN DOCUMENT: `steerEaseSeconds` is 0.12 s,
# which at the 60 Hz reference tick is 7.2 ticks, so the ramp is
# `min(1, held_ticks / 7.2)` and the eighth consecutive held tick is the first
# at full `turnRate`. The tuning below is the document's amended Physics table
# transcribed, exactly as every other core suite transcribes it.
#
# THE THRESHOLD EDGE, decided here and asserted below. The document says the
# ease "never gates the threshold rule" — below `steerThreshold` there is no
# steering, ramped or otherwise — but it does not say whether a below-threshold
# tick ADVANCES the ramp. This port rules that the counter counts HELD TICKS,
# not steering ticks: the ramp models the player's hand on the key, not the
# kart's speed, and the alternative would make the onset jerk again exactly
# where the kart crosses the threshold under acceleration — the moment the
# feature exists to smooth. Asserted by _test_the_ramp_counts_held_ticks.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const Sim := preload("res://scripts/core/sim.gd")
const Tuning := preload("res://scripts/core/tuning.gd")
const InputState := preload("res://scripts/core/input_state.gd")

## steerEaseSeconds (0.12 s) at the 60 Hz reference tick.
const RAMP_TICKS := 7.2
## The first tick at which held_ticks / RAMP_TICKS reaches 1.0.
const FULL_RATE_TICK := 8
## A speed comfortably above steerThreshold and below the clamp.
const ROLLING := 0.15


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_test_the_ramp_climbs_linearly()
	_test_the_peak_is_exactly_turn_rate()
	_test_releasing_resets_the_ramp()
	_test_reversing_resets_the_ramp()
	_test_no_steering_below_the_threshold_at_any_ease()
	_test_the_ramp_counts_held_ticks()
	_test_the_ease_is_in_the_reproducibility_summary()
	RVTest.finish(self, "steer: ramp, peak, resets, threshold, summary ok", "steer check(s)")


## The design document's amended Physics table, transcribed.
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


## A simulation rolling above the threshold, with no drive input: velocity is
## held by the caller so the only thing changing tick to tick is the ramp.
func _rolling() -> RefCounted:
	var s := Sim.new()
	s.tuning = _tuning()
	s.input = InputState.new()
	s.race.start_racing_immediately()
	s.velocity = ROLLING
	return s


## One tick with the given inputs held; returns the yaw change it produced.
## The velocity is restored afterwards so friction cannot walk the kart under
## the threshold mid-ramp and confound the measurement.
func _turn_of_one_tick(s: RefCounted, left: bool, right: bool) -> float:
	s.input.left = left
	s.input.right = right
	s.velocity = ROLLING
	var before: float = s.yaw
	s.step()
	return s.yaw - before


func _expected_turn(s: RefCounted, held_ticks: int, direction: float) -> float:
	return s.tuning.turn_rate * minf(1.0, float(held_ticks) / RAMP_TICKS) * direction


# @covers Kart Driving Physics / Steering eases in rather than stepping
func _test_the_ramp_climbs_linearly() -> void:
	var s := _rolling()
	var climbed := true
	var previous := 0.0
	for held in range(1, FULL_RATE_TICK + 1):
		var turned: float = _turn_of_one_tick(s, true, false)
		var want: float = _expected_turn(s, held, 1.0)
		if absf(turned - want) > 1e-12:
			_check(false, "hold tick %d turns %.12f, want %.12f" % [held, turned, want])
			climbed = false
		if held < FULL_RATE_TICK and turned <= previous:
			_check(false, "hold tick %d did not climb above tick %d" % [held, held - 1])
			climbed = false
		previous = turned
	_check(climbed, "the ramp climbs linearly, tick by tick, over steerEaseSeconds")
	# And the FIRST tick of a hold is a fraction of the rate, not all of it —
	# which is the entire complaint the ease answers. A step function passes
	# every other assertion in this file except this one and the peak's index.
	var fresh := _rolling()
	var first: float = _turn_of_one_tick(fresh, true, false)
	_check(
		first > 0.0 and first < fresh.tuning.turn_rate * 0.2,
		(
			"the onset is a ramp, not a step: tick one turns %.12f of turnRate %.12f"
			% [first, fresh.tuning.turn_rate]
		)
	)


## The amended "Steering while rolling" scenario's own claim — a settled hold
## turns by exactly `turnRate` — is claimed by tick_test.gd, which owns that
## scenario. What is here is the ramp's shape around it.
func _test_the_peak_is_exactly_turn_rate() -> void:
	var left := _rolling()
	for _i in range(FULL_RATE_TICK - 1):
		_turn_of_one_tick(left, true, false)
	var turned: float = _turn_of_one_tick(left, true, false)
	_check(
		absf(turned - left.tuning.turn_rate) < 1e-12,
		(
			"after steerEaseSeconds the rate is EXACTLY turnRate (got %.12f, want %.12f)"
			% [turned, left.tuning.turn_rate]
		)
	)
	# and it stays there, tick after tick, rather than overshooting
	var stayed := true
	for _i in range(60):
		if absf(_turn_of_one_tick(left, true, false) - left.tuning.turn_rate) > 1e-12:
			stayed = false
	_check(stayed, "and holds at turnRate thereafter — the ease saturates, it does not overshoot")

	# Right is the same magnitude the other way, ramp and peak alike.
	var right := _rolling()
	var mirrored := true
	for held in range(1, FULL_RATE_TICK + 1):
		var turn: float = _turn_of_one_tick(right, false, true)
		if absf(turn - _expected_turn(right, held, -1.0)) > 1e-12:
			mirrored = false
	_check(mirrored, "the right ramp is the left ramp negated, tick for tick")


func _test_releasing_resets_the_ramp() -> void:
	var s := _rolling()
	for _i in range(30):
		_turn_of_one_tick(s, true, false)
	_check(
		absf(_turn_of_one_tick(s, true, false) - s.tuning.turn_rate) < 1e-12,
		"setup: the hold is saturated before it is released"
	)
	var released: float = _turn_of_one_tick(s, false, false)
	_check(released == 0.0, "the released tick turns nothing at all")
	var after: float = _turn_of_one_tick(s, true, false)
	_check(
		absf(after - _expected_turn(s, 1, 1.0)) < 1e-12,
		(
			"and the next press starts the ramp again from the bottom (got %.12f, want %.12f)"
			% [after, _expected_turn(s, 1, 1.0)]
		)
	)


func _test_reversing_resets_the_ramp() -> void:
	var s := _rolling()
	for _i in range(30):
		_turn_of_one_tick(s, true, false)
	# Reversed with NO released tick between: the reversal itself is the reset,
	# which is the half a release-only implementation gets wrong.
	var reversed_turn: float = _turn_of_one_tick(s, false, true)
	_check(
		absf(reversed_turn - _expected_turn(s, 1, -1.0)) < 1e-12,
		(
			"reversing the held direction resets the ramp on that tick (got %.12f, want %.12f)"
			% [reversed_turn, _expected_turn(s, 1, -1.0)]
		)
	)
	# Both held is neither direction, and cancels like the drive inputs do —
	# so it resets too rather than freezing a saturated ramp.
	for _i in range(30):
		_turn_of_one_tick(s, false, true)
	_check(_turn_of_one_tick(s, true, true) == 0.0, "both directions held cancel and turn nothing")
	_check(
		absf(_turn_of_one_tick(s, false, true) - _expected_turn(s, 1, -1.0)) < 1e-12,
		"and the cancelled tick reset the ramp"
	)


## The ease NEVER gates the threshold rule: below `steerThreshold` there is no
## steering, at ease 0, at ease 1, and at every value between. (The scenario
## "Refusing to steer while stationary" is claimed by tick_test.gd, which owns
## the threshold itself; this is the ease's non-interaction with it.)
func _test_no_steering_below_the_threshold_at_any_ease() -> void:
	var steered_anyway := 0
	for held in range(0, FULL_RATE_TICK + 3):
		var s := _rolling()
		# Bring the ramp to `held` while rolling, then drop under the threshold.
		for _i in range(held):
			_turn_of_one_tick(s, true, false)
		s.velocity = s.tuning.steer_threshold  # "steerThreshold or less"
		s.input.left = true
		var before: float = s.yaw
		s.step()
		if s.yaw != before:
			steered_anyway += 1
		# and at rest, where sign(v) would hide a broken threshold
		s.velocity = 0.0
		before = s.yaw
		s.step()
		if s.yaw != before:
			steered_anyway += 1
	_check(
		steered_anyway == 0,
		"no steering at or below steerThreshold, at every ease value (%d breaches)" % steered_anyway
	)


## THE THRESHOLD EDGE, decided in this file's header: the ramp counts HELD
## ticks, whether or not the kart was fast enough to use them. So a direction
## held while the kart is under the threshold arrives at full rate the moment
## the kart crosses it — the onset is smoothed once, at the press, not again at
## the threshold.
func _test_the_ramp_counts_held_ticks() -> void:
	var s := _rolling()
	s.velocity = 0.0
	s.input.left = true
	for _i in range(FULL_RATE_TICK + 2):
		s.velocity = 0.0  # held below the threshold the whole time
		s.step()
	_check(s.yaw == 0.0, "setup: nothing steered while the kart was below the threshold")
	var turned: float = _turn_of_one_tick(s, true, false)
	_check(
		absf(turned - s.tuning.turn_rate) < 1e-12,
		(
			(
				"a ramp advanced below the threshold is already saturated when the kart "
				+ "crosses it (got %.12f, want %.12f)"
			)
			% [turned, s.tuning.turn_rate]
		)
	)


## The reproducibility summary carries the ease, so two runs that differ only in
## steering history differ in the string the determinism suites compare.
func _test_the_ease_is_in_the_reproducibility_summary() -> void:
	var s := _rolling()
	_check("ease=" in s.stats_line(), "the summary carries the steering ease")
	var fresh: String = s.stats_line()
	for _i in range(3):
		_turn_of_one_tick(s, true, false)
	_check(
		s.stats_line() != fresh,
		"and a mid-ramp state does not summarise identically to an unpressed one"
	)
