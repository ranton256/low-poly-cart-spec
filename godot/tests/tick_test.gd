# The kart tick — the design document's Kart Driving Physics feature.
#
#   godot --headless -s tests/tick_test.gd
#
# EXPECTED TIMINGS COME FROM THE DESIGN DOCUMENT, never from running this
# implementation and recording what it did. An expectation produced from the
# code under test agrees with it by construction and verifies nothing. The
# three timings below are quoted from the Acceptance Checklist, items 4 and 5,
# with the tolerances it states.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const Sim := preload("res://scripts/core/sim.gd")
const Tuning := preload("res://scripts/core/tuning.gd")
const InputState := preload("res://scripts/core/input_state.gd")

# --- Acceptance Checklist item 4, quoted ---
const DIAL_NINE_TENTHS := 103
const DIAL_NINE_TENTHS_SECONDS := 0.94
const DIAL_STEADY := 115
const DIAL_STEADY_SECONDS := 2.60
const COAST_BELOW_THRESHOLD_SECONDS := 1.21
const TIMING_TOLERANCE := 0.05

# Curve tests must finish before the kart reaches the world boundary, or the
# bounce reverses the velocity they are measuring. At steady speed the kart
# covers the 90 wu to the limit in ~469 ticks, and the dial reaches its steady
# value at 156, so 300 is comfortably past steady state and comfortably inside
# the field. Boundary behaviour is boundary_test.gd's subject, not this file's.
const SETTLE_TICKS := 300


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_test_spin_up_reaches_nine_tenths_on_time()
	_test_dial_settles_and_stays()
	_test_coast_falls_below_threshold_on_time()
	_test_steady_speed_is_below_the_clamp()
	_test_reverse_is_half()
	_test_no_steering_at_rest()
	_test_no_steering_below_the_threshold()
	_test_steering_reads_pre_friction_velocity()
	_test_steering_reverses_in_reverse()
	_test_turn_rate_independent_of_speed()
	_test_travel_matches_heading()
	_test_input_combinations()
	RVTest.finish(self, "tick: order, curve, steering, heading, input", "tick check(s)")


## The design document's tuning, built directly — no file, no engine.
func _tuning() -> RefCounted:
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
	return t


func _sim() -> RefCounted:
	var s := Sim.new()
	s.tuning = _tuning()
	s.input = InputState.new()
	return s


## Ticks until the dial first reads at least `target`, or -1.
func _ticks_until_dial(s: RefCounted, target: int, limit: int) -> int:
	for n in range(1, limit + 1):
		s.step()
		if s.speedo_readout() >= target:
			return n
	return -1


func _within(actual: float, expected: float, tol: float) -> bool:
	return absf(actual - expected) <= tol


func _test_spin_up_reaches_nine_tenths_on_time() -> void:
	var s := _sim()
	s.input.forward = true
	var n := _ticks_until_dial(s, DIAL_NINE_TENTHS, 6000)
	_check(n > 0, "dial reaches %d at all" % DIAL_NINE_TENTHS)
	var seconds: float = float(n) / float(s.TICKS_PER_SECOND)
	_check(
		_within(seconds, DIAL_NINE_TENTHS_SECONDS, TIMING_TOLERANCE),
		(
			"dial %d first at %.4f s, want %.2f +/- %.2f (acceptance 4)"
			% [DIAL_NINE_TENTHS, seconds, DIAL_NINE_TENTHS_SECONDS, TIMING_TOLERANCE]
		)
	)


func _test_dial_settles_and_stays() -> void:
	var s := _sim()
	s.input.forward = true
	var n := _ticks_until_dial(s, DIAL_STEADY, 6000)
	_check(n > 0, "dial reaches %d at all" % DIAL_STEADY)
	var seconds: float = float(n) / float(s.TICKS_PER_SECOND)
	_check(
		_within(seconds, DIAL_STEADY_SECONDS, TIMING_TOLERANCE),
		(
			"dial %d first at %.4f s, want %.2f +/- %.2f (acceptance 4)"
			% [DIAL_STEADY, seconds, DIAL_STEADY_SECONDS, TIMING_TOLERANCE]
		)
	)
	# and stays there — never exceeds it, for as long as the road is clear
	var left_steady := false
	for _i in range(SETTLE_TICKS):
		s.step()
		if s.speedo_readout() != DIAL_STEADY:
			left_steady = true
			break
	_check(not left_steady, "dial stays at %d and never exceeds it" % DIAL_STEADY)


func _test_coast_falls_below_threshold_on_time() -> void:
	var s := _sim()
	s.input.forward = true
	# reach steady state first
	for _i in range(SETTLE_TICKS):
		s.step()
	s.input.clear()
	var n := 0
	for i in range(1, 6001):
		s.step()
		if absf(s.velocity) < s.tuning.steer_threshold:
			n = i
			break
	_check(n > 0, "coasting falls below the steering threshold")
	var seconds: float = float(n) / float(s.TICKS_PER_SECOND)
	_check(
		_within(seconds, COAST_BELOW_THRESHOLD_SECONDS, TIMING_TOLERANCE),
		(
			"coast below threshold at %.4f s, want %.2f +/- %.2f (acceptance 4)"
			% [seconds, COAST_BELOW_THRESHOLD_SECONDS, TIMING_TOLERANCE]
		)
	)
	# asymptotic, never snapping to a halt
	_check(absf(s.velocity) > 0.0, "velocity approaches zero without reaching it")


## Friction is applied AFTER the clamp, so the achievable speed is below it.
## This is why the dial tops out short of its nominal maximum.
func _test_steady_speed_is_below_the_clamp() -> void:
	var s := _sim()
	s.input.forward = true
	for _i in range(SETTLE_TICKS):
		s.step()
	_check(absf(s.velocity) < s.tuning.max_speed, "steady speed is below the clamp")
	_check(s.speedo_readout() < int(s.tuning.speedo_max), "dial tops out below its nominal maximum")


func _test_reverse_is_half() -> void:
	var forward_sim := _sim()
	forward_sim.input.forward = true
	for _i in range(SETTLE_TICKS):
		forward_sim.step()
	var reverse_sim := _sim()
	reverse_sim.input.reverse = true
	for _i in range(SETTLE_TICKS):
		reverse_sim.step()
	var ratio: float = absf(reverse_sim.velocity) / absf(forward_sim.velocity)
	_check(
		absf(ratio - reverse_sim.tuning.reverse_factor) < 0.001,
		"reverse settles at reverseFactor of forward (got %.4f)" % ratio
	)


func _test_no_steering_at_rest() -> void:
	var s := _sim()
	s.input.left = true
	var before: float = s.yaw
	for _i in range(600):
		s.step()
	_check(s.yaw == before, "a stationary kart cannot be turned (acceptance 5)")


## The one above passes for the wrong reason on its own: at rest the velocity is
## exactly zero, so sign(v) is zero and the yaw delta vanishes whether or not a
## threshold exists. Deleting the threshold entirely left the whole suite green.
## This is the case that actually tests it — moving, but at or below the
## threshold, which the design document specifies as "steerThreshold or less".
func _test_no_steering_below_the_threshold() -> void:
	var s := _sim()
	var threshold: float = s.tuning.steer_threshold
	s.input.left = true
	s.velocity = threshold * 0.5  # moving, but under the threshold
	var before: float = s.yaw
	s.step()
	_check(s.yaw == before, "a kart moving below the threshold does not steer (acceptance 5)")

	# and exactly AT the threshold is also refused — the document says "or less"
	var at := _sim()
	at.input.left = true
	at.velocity = at.tuning.steer_threshold
	var at_before: float = at.yaw
	at.step()
	_check(at.yaw == at_before, "a kart exactly at the threshold does not steer")


## Discriminates the stage order the design document bolds: the steering test
## reads the POST-CLAMP, PRE-FRICTION velocity. This velocity is above the
## threshold before friction and below it after, so it must steer — and would
## not if stage 3 ran after stage 4. Moving stage 3 after stage 4 otherwise
## leaves the whole suite green.
func _test_steering_reads_pre_friction_velocity() -> void:
	var s := _sim()
	var threshold: float = s.tuning.steer_threshold
	var friction: float = s.tuning.friction
	var band_velocity: float = threshold / friction * 0.98  # in (threshold, threshold/friction)
	_check(band_velocity > threshold, "the probe velocity is above the threshold before friction")
	_check(band_velocity * friction < threshold, "and below it after friction")

	s.input.left = true
	s.velocity = band_velocity
	var before: float = s.yaw
	s.step()
	_check(
		s.yaw != before,
		"steering is tested before friction is applied, not after (design document tick order)"
	)


func _test_steering_reverses_in_reverse() -> void:
	var fwd := _sim()
	fwd.input.forward = true
	fwd.input.left = true
	for _i in range(120):
		fwd.step()
	var rev := _sim()
	rev.input.reverse = true
	rev.input.left = true
	for _i in range(120):
		rev.step()
	_check(fwd.yaw > 0.0, "left while moving forward turns one way")
	_check(rev.yaw < 0.0, "the same input in reverse turns the other (acceptance 5)")


func _test_turn_rate_independent_of_speed() -> void:
	var slow := _sim()
	slow.input.forward = true
	slow.step()
	slow.step()
	var fast := _sim()
	fast.input.forward = true
	for _i in range(SETTLE_TICKS):
		fast.step()
	# both now steer for one tick, at very different speeds
	slow.input.left = true
	fast.input.left = true
	var slow_before: float = slow.yaw
	var fast_before: float = fast.yaw
	slow.step()
	fast.step()
	var slow_delta: float = slow.yaw - slow_before
	var fast_delta: float = fast.yaw - fast_before
	_check(
		absf(slow.velocity) < absf(fast.velocity) * 0.5,
		"the two sims really are at different speeds"
	)
	_check(
		absf(slow_delta - fast_delta) < 1e-12,
		"turn rate is constant above the threshold (%.9f vs %.9f)" % [slow_delta, fast_delta]
	)


## Travel is along the heading at every angle, with no lateral component.
func _test_travel_matches_heading() -> void:
	for step_index in range(16):
		var heading := TAU * float(step_index) / 16.0
		var s := _sim()
		s.yaw = heading
		s.velocity = 0.1
		var before_x: float = s.pos_x
		var before_z: float = s.pos_z
		s._stage_5_integrate()
		var moved_x: float = s.pos_x - before_x
		var moved_z: float = s.pos_z - before_z
		var expected_x := sin(heading) * 0.1
		var expected_z := cos(heading) * 0.1
		_check(
			absf(moved_x - expected_x) < 1e-12 and absf(moved_z - expected_z) < 1e-12,
			"heading %.3f rad displaces along its own axis" % heading
		)
	# reverse travels backwards along the same heading, without turning
	var r := _sim()
	r.yaw = 0.0
	r.velocity = -0.1
	r._stage_5_integrate()
	_check(
		r.pos_z < 0.0 and r.yaw == 0.0,
		"negative velocity moves opposite the facing, heading unchanged"
	)


func _test_input_combinations() -> void:
	# opposing drive inputs cancel, leaving only friction
	var both := _sim()
	both.input.forward = true
	both.input.reverse = true
	both.velocity = 0.1
	both.step()
	_check(
		absf(both.velocity - 0.1 * both.tuning.friction) < 1e-12,
		"forward and reverse cancel, leaving friction"
	)
	# combined drive and steer both apply in one tick
	var combo := _sim()
	combo.input.forward = true
	combo.input.left = true
	combo.velocity = 0.1
	var yaw_before: float = combo.yaw
	combo.step()
	_check(
		combo.velocity != 0.1 and combo.yaw != yaw_before,
		"acceleration and rotation both apply in one tick"
	)
	# held input persists until cleared
	var held := _sim()
	held.input.forward = true
	for _i in range(10):
		held.step()
	var moving: float = absf(held.velocity)
	held.input.clear()
	held.step()
	_check(
		moving > 0.0 and absf(held.velocity) < moving,
		"held input persists, and clearing it leaves only friction"
	)
