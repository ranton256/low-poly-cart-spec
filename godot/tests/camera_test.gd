# The chase camera: trails, lags, settles, and widens with speed.
#
#   godot --headless -s tests/camera_test.gd
#
# Every threshold this file asserts was written down and committed BEFORE any of
# it was measured — docs/camera_thresholds.md, in its own commit. The design
# document says the camera settles "within roughly half a second", and "roughly"
# is an invitation to pick a tolerance after seeing the answer. The thresholds are
# derived from the document's own chaseSmoothing instead: a time constant of
# 0.1999 s and a settling time of 0.460 s both fall out of 0.08 per tick.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const ChaseCamera := preload("res://scripts/core/chase_camera.gd")
const Sim := preload("res://scripts/core/sim.gd")
const InputState := preload("res://scripts/core/input_state.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")

# From docs/camera_thresholds.md. Committed before measurement.
const TIME_CONSTANT_SECONDS := 0.2
const TIME_CONSTANT_TOLERANCE := 0.05  # fractional, so 5%
const SETTLE_LIMIT_SECONDS := 0.5
const SETTLED_FRACTION_OF_PEAK := 0.10
const MINIMUM_LAG_DEGREES := 5.0
const STEADY_STATE_FOV := 89.4
const FOV_TOLERANCE := 0.2

const SETTLE_TICKS := 240
## Long enough to reach steady state, which the design document puts at 2.60 s
## (156 ticks), and SHORT enough not to reach the boundary: at 0.192 wu/tick a
## longer run covers more than the drivable extent, bounces, and leaves the kart
## nearly stopped. A first version used 600 and measured a camera that never
## lagged, because the kart was barely moving.
const SPIN_UP_TICKS := 200

## The shake's seed. Any value; the tests below assert reproducibility from it,
## not the numbers it happens to produce.
const SHAKE_SEED := 704221
## How far the shudder must have decayed for "brief". One time constant is 0.2 s,
## so after three the offset is 5% of its peak — that is the document's "brief
## shudder rather than a permanent camera offset", stated as a number before it
## was measured.
const SHUDDER_TICKS := 36
const SHUDDER_RESIDUAL := 0.05


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_test_it_trails_in_the_karts_own_frame()
	_test_the_aim_is_not_smoothed()
	_test_the_aim_is_in_the_karts_frame_at_every_heading()
	_test_the_time_constant_matches_the_document()
	_test_the_lag_is_real()
	_test_it_settles_within_the_stated_time()
	_test_the_field_of_view_at_the_documents_anchors()
	_test_grouping_ticks_differently_changes_nothing()
	_test_a_jolt_is_a_shudder_not_a_permanent_offset()
	_test_a_jolt_touches_nothing_but_the_camera_position()
	_test_the_shudder_is_within_bounds_and_reproducible()
	RVTest.finish(
		self, "camera: trails, lags, settles, widens with speed, absorbs a jolt", "camera check(s)"
	)


func _sim() -> RefCounted:
	var s := Sim.new()
	s.tuning = TuningLoader.load_tuning()
	s.input = InputState.new()
	return s


func _camera(sim: RefCounted) -> RefCounted:
	var c := ChaseCamera.new()
	c.tuning = sim.tuning
	return c


# @covers Chase Camera / Trailing the kart
## Behind and above in the KART'S frame, not the world's. A camera placed behind
## in world terms would sit in the same place at every heading, so testing one
## heading proves nothing.
func _test_it_trails_in_the_karts_own_frame() -> void:
	var s := _sim()
	for i in range(8):
		var yaw: float = TAU * float(i) / 8.0
		s.yaw = yaw
		s.pos_x = 0.0
		s.pos_z = 0.0
		var c := _camera(s)
		c.step(s.pos_x, s.pos_z, s.yaw, 0.0)
		# Settled on the first tick by construction, so this is the target itself.
		var want_x: float = -s.tuning.chase_back * sin(yaw)
		var want_z: float = -s.tuning.chase_back * cos(yaw)
		_check(
			absf(c.pos_x - want_x) < 1e-9 and absf(c.pos_z - want_z) < 1e-9,
			"at yaw %.3f the camera sits chaseBack behind the kart in its own frame" % yaw
		)
		_check(absf(c.pos_y - s.tuning.chase_up) < 1e-9, "and chaseUp above it")


## The document is explicit that the aim is applied without smoothing, so the
## horizon stays locked while the position lags. Displace the kart and the aim
## must move with it on the same tick, while the position must not.
func _test_the_aim_is_not_smoothed() -> void:
	var s := _sim()
	var c := _camera(s)
	c.step(0.0, 0.0, 0.0, 0.0)
	var position_before: float = c.pos_z

	s.pos_z = 20.0
	c.step(s.pos_x, s.pos_z, s.yaw, 0.0)
	_check(
		absf(c.aim_z - (20.0 + s.tuning.aim_ahead)) < 1e-9,
		"the aim point follows the kart immediately, with no easing"
	)
	_check(
		absf(c.pos_z - position_before) > 1e-9 and absf(c.pos_z - 20.0) > 1.0,
		"while the position has only begun to move toward it"
	)


## THE AIM, AT EVERY HEADING AND ON EVERY AXIS.
##
## An earlier version of this file asserted the aim at yaw 0 only — where
## sin(yaw) is zero, so computing aim_x in the WORLD frame instead of the kart's
## passes. Review demonstrated it. That is the same failure this file warns about
## for the position three functions above ("testing one heading proves nothing"),
## and the position obeyed the rule while the aim did not.
##
## aimUp had no assertion anywhere in the repository: setting it to zero left the
## whole suite green, and the tuning-literal gate excludes it as a small integer,
## so nothing at all held a value the design document states.
func _test_the_aim_is_in_the_karts_frame_at_every_heading() -> void:
	var s := _sim()
	for i in range(8):
		var yaw: float = TAU * float(i) / 8.0
		var c := _camera(s)
		c.step(3.0, -2.0, yaw, 0.0)
		var want_x: float = 3.0 + s.tuning.aim_ahead * sin(yaw)
		var want_z: float = -2.0 + s.tuning.aim_ahead * cos(yaw)
		_check(
			absf(c.aim_x - want_x) < 1e-9 and absf(c.aim_z - want_z) < 1e-9,
			"at yaw %.3f the aim sits aimAhead ahead of the kart in its own frame" % yaw
		)
		_check(
			absf(c.aim_y - s.tuning.aim_up) < 1e-9,
			"and aimUp above it (got %.4f, want %.4f)" % [c.aim_y, s.tuning.aim_up]
		)
		# The aim is AHEAD and the camera is BEHIND: they must fall on opposite
		# sides of the kart, or the camera is looking away from where it is going.
		var ahead: float = (c.aim_x - 3.0) * sin(yaw) + (c.aim_z + 2.0) * cos(yaw)
		_check(ahead > 0.0, "the aim is ahead of the kart, not behind it")


## Measured from the decay, then compared against the DOCUMENT's stated 0.2 s —
## not against the value the recurrence obviously produces, which would be the
## test checking its own arithmetic.
func _test_the_time_constant_matches_the_document() -> void:
	var s := _sim()
	var c := _camera(s)
	c.step(0.0, 0.0, 0.0, 0.0)

	# Displace the target and watch the gap decay to 1/e.
	var target_z: float = 100.0
	var initial: float = absf(target_z - s.tuning.chase_back - c.pos_z)
	var ticks: int = 0
	for i in range(1, SETTLE_TICKS):
		c.step(0.0, target_z, 0.0, 0.0)
		var gap: float = absf(target_z - s.tuning.chase_back - c.pos_z)
		if gap <= initial / exp(1.0):
			ticks = i
			break
	var measured: float = float(ticks) / float(s.TICKS_PER_SECOND)
	var off: float = absf(measured - TIME_CONSTANT_SECONDS) / TIME_CONSTANT_SECONDS
	_check(
		ticks > 0 and off <= TIME_CONSTANT_TOLERANCE,
		(
			"time constant %.4f s is within %d%% of the document's %.1f s (off by %.1f%%)"
			% [measured, int(TIME_CONSTANT_TOLERANCE * 100.0), TIME_CONSTANT_SECONDS, off * 100.0]
		)
	)


## THE CHECK THAT STOPS "SETTLES BEHIND THE KART" BEING MET BY NEVER LEAVING.
## A camera that tracks perfectly is always settled, so it would satisfy the
## settling test trivially. Set chaseSmoothing to 1.0 and this is the check that
## fails.
func _test_the_lag_is_real() -> void:
	var s := _sim()
	var c := _camera(s)
	s.input.forward = true
	for _i in range(SPIN_UP_TICKS):
		s.step()
		c.step(s.pos_x, s.pos_z, s.yaw, s.speed_ratio())

	s.input.left = true
	var peak: float = 0.0
	for _i in range(60):
		s.step()
		c.step(s.pos_x, s.pos_z, s.yaw, s.speed_ratio())
		peak = maxf(peak, rad_to_deg(c.offset_angle_from(s.pos_x, s.pos_z, s.yaw)))
	_check(
		peak >= MINIMUM_LAG_DEGREES,
		(
			"the camera measurably lags through a turn: peak offset %.2f deg, needs %.1f"
			% [peak, MINIMUM_LAG_DEGREES]
		)
	)


# @covers Chase Camera / Lagging through a turn
## Acceptance item 8's "settles behind the kart", as a number.
func _test_it_settles_within_the_stated_time() -> void:
	var s := _sim()
	var c := _camera(s)
	s.input.forward = true
	for _i in range(SPIN_UP_TICKS):
		s.step()
		c.step(s.pos_x, s.pos_z, s.yaw, s.speed_ratio())

	s.input.left = true
	var peak: float = 0.0
	for _i in range(60):
		s.step()
		c.step(s.pos_x, s.pos_z, s.yaw, s.speed_ratio())
		peak = maxf(peak, c.offset_angle_from(s.pos_x, s.pos_z, s.yaw))

	s.input.left = false
	var settled_at: int = 0
	for i in range(1, SETTLE_TICKS):
		s.step()
		c.step(s.pos_x, s.pos_z, s.yaw, s.speed_ratio())
		if c.offset_angle_from(s.pos_x, s.pos_z, s.yaw) <= peak * SETTLED_FRACTION_OF_PEAK:
			settled_at = i
			break
	var seconds: float = float(settled_at) / float(s.TICKS_PER_SECOND)
	# Reported whether it passes or fails: a settling time nobody can see is a
	# threshold nobody can check.
	print(
		(
			"        camera settled to %d%% of a %.2f deg peak in %.3f s (limit %.3f)"
			% [
				int(SETTLED_FRACTION_OF_PEAK * 100.0),
				rad_to_deg(peak),
				seconds,
				SETTLE_LIMIT_SECONDS
			]
		)
	)
	_check(settled_at > 0, "the camera settles behind the kart at all")
	_check(
		settled_at > 0 and seconds <= SETTLE_LIMIT_SECONDS,
		"and does so within the document's half a second (%.3f s)" % seconds
	)


# @covers Chase Camera / Widening the field of view with speed
## The document's OWN anchors, not the interpolation formula. Asserting
## fov == base + ratio * (max - base) would re-implement the thing under test and
## prove only that the test can multiply.
func _test_the_field_of_view_at_the_documents_anchors() -> void:
	var s := _sim()
	var c := _camera(s)
	_check(absf(c.field_of_view(0.0) - s.tuning.fov_base) < 1e-9, "at rest the view is fovBase")

	s.input.forward = true
	for _i in range(SPIN_UP_TICKS):
		s.step()
	var steady: float = c.field_of_view(s.speed_ratio())
	_check(
		absf(steady - STEADY_STATE_FOV) <= FOV_TOLERANCE,
		(
			"at steady-state top speed the view is %.2f deg, the document says %.1f"
			% [steady, STEADY_STATE_FOV]
		)
	)
	# Monotonic, and clamped above the limit.
	var previous: float = -1.0
	for i in range(21):
		var ratio: float = float(i) / 20.0
		var value: float = c.field_of_view(ratio)
		_check(value >= previous, "the field of view never narrows as speed rises")
		previous = value
	_check(
		absf(c.field_of_view(4.0) - s.tuning.fov_max) < 1e-9,
		"a speed ratio above the limit cannot widen the view past fovMax"
	)


## A10: eased per TICK, so how the ticks are grouped into frames cannot matter.
##
## A REGRESSION GUARD, and be precise about it: with the camera stepped once per
## tick this holds by construction, exactly as replay_test.gd's batching property
## does. What it guards is a later change moving the ease into the per-frame
## callback. tests/driver_test.gd carries the other half — that the composition
## root really does step it once per tick.
func _test_grouping_ticks_differently_changes_nothing() -> void:
	var reference := _drive([1])
	for batches in [[2], [3], [0, 1, 1], [0, 0, 1, 2]]:
		var other := _drive(batches)
		_check(
			other == reference,
			"grouping ticks as %s gives the same camera state as one per frame" % [batches]
		)


## Drive a fixed manoeuvre, grouping ticks into frames by the given pattern, and
## return the final camera state as a string.
func _drive(batches: Array) -> String:
	var s := _sim()
	var c := _camera(s)
	var index: int = 0
	var ticks: int = 0
	while ticks < 900:
		var count: int = int(batches[index % batches.size()])
		index += 1
		for _t in range(count):
			s.input.forward = ticks < 600
			s.input.left = ticks >= 300 and ticks < 500
			s.step()
			c.step(s.pos_x, s.pos_z, s.yaw, s.speed_ratio())
			ticks += 1
			if ticks >= 900:
				break
	return "%.9f|%.9f|%.9f|%.6f" % [c.pos_x, c.pos_y, c.pos_z, c.fov]


func _settled_camera(sim: RefCounted) -> RefCounted:
	var c := _camera(sim)
	c.seed_shake(SHAKE_SEED)
	# Settle it so the jolt is measured against a stationary camera rather than
	# against one still flying to its first target.
	for _i in range(SETTLE_TICKS):
		c.step(sim.pos_x, sim.pos_z, sim.yaw, 0.0)
	return c


# @covers Chase Camera / Absorbing a collision jolt
## The jolt is absorbed by the EASING THAT ALREADY EXISTS, at the rate already
## measured — not by a second decay with its own time constant.
##
## Asserted two ways: the offset is gone after three time constants, and the rate
## it decays at is the same chaseSmoothing the turn lag uses. A separate decay
## added "to make the shake feel better" fails the second one.
func _test_a_jolt_is_a_shudder_not_a_permanent_offset() -> void:
	var s := _sim()
	var c := _settled_camera(s)
	var rest_x: float = c.pos_x
	var rest_y: float = c.pos_y
	var rest_z: float = c.pos_z

	c.jolt()
	var peak: float = _offset(c, rest_x, rest_y, rest_z)
	_check(peak > 0.0, "the jolt actually displaces the camera (%.4f wu)" % peak)

	# One tick of easing, and the gap must have closed by exactly chaseSmoothing.
	var before: float = _offset(c, rest_x, rest_y, rest_z)
	c.step(s.pos_x, s.pos_z, s.yaw, 0.0)
	var after: float = _offset(c, rest_x, rest_y, rest_z)
	RVTest.close(
		after / before,
		1.0 - s.tuning.chase_smoothing,
		1e-6,
		"the shudder decays at the camera's OWN easing rate, with no separate decay"
	)

	for _i in range(SHUDDER_TICKS - 1):
		c.step(s.pos_x, s.pos_z, s.yaw, 0.0)
	var residual: float = _offset(c, rest_x, rest_y, rest_z) / peak
	_check(
		residual < SHUDDER_RESIDUAL,
		(
			"after %d ticks (%.2f s) the shudder is %.1f%% of its peak — brief, not permanent"
			% [SHUDDER_TICKS, float(SHUDDER_TICKS) / 60.0, residual * 100.0]
		)
	)


func _offset(c: RefCounted, x: float, y: float, z: float) -> float:
	var dx: float = c.pos_x - x
	var dy: float = c.pos_y - y
	var dz: float = c.pos_z - z
	return sqrt(dx * dx + dy * dy + dz * dz)


## A jolt is cosmetic.
## (Claimed by the shudder test above — one claim per scenario.)
##
## It moves the camera's POSITION and nothing else: not the
## kart, and not the aim — the horizon stays level through the shudder, which is
## what separates it from the whole world lurching.
func _test_a_jolt_touches_nothing_but_the_camera_position() -> void:
	var s := _sim()
	s.input.forward = true
	for _i in range(SPIN_UP_TICKS):
		s.step()
	var c := _camera(s)
	c.seed_shake(SHAKE_SEED)
	c.step(s.pos_x, s.pos_z, s.yaw, s.speed_ratio())

	var kart_x: float = s.pos_x
	var kart_z: float = s.pos_z
	var kart_yaw: float = s.yaw
	var kart_v: float = s.velocity
	var aim_x: float = c.aim_x
	var aim_y: float = c.aim_y
	var aim_z: float = c.aim_z
	var fov: float = c.fov

	c.jolt()

	_check(s.pos_x == kart_x and s.pos_z == kart_z, "a jolt leaves the kart's position unaffected")
	_check(s.yaw == kart_yaw, "and its heading")
	_check(s.velocity == kart_v, "and its velocity")
	_check(
		c.aim_x == aim_x and c.aim_y == aim_y and c.aim_z == aim_z,
		"and the camera's aim point, so the horizon stays level"
	)
	_check(c.fov == fov, "and the field of view")


## Within the stated bounds on every axis, and reproducible from a seed.
## (Claimed by the shudder test above — one claim per scenario.)
##
## Swept over many jolts rather than one: a single draw lands inside any bound
## wide enough, and a shake that used shakeHorizontal for the vertical axis too
## would pass a one-sample check most of the time. The sweep also asserts the
## offsets are not all identical, which is what a stream that never advances would
## produce.
func _test_the_shudder_is_within_bounds_and_reproducible() -> void:
	var s := _sim()
	var first: Array = _jolt_offsets(s, 200)
	var second: Array = _jolt_offsets(s, 200)

	var largest_horizontal := 0.0
	var largest_vertical := 0.0
	var distinct := {}
	for i in range(first.size()):
		var o: Array = first[i]
		var ox: float = o[0]
		var oy: float = o[1]
		var oz: float = o[2]
		largest_horizontal = maxf(largest_horizontal, maxf(absf(ox), absf(oz)))
		largest_vertical = maxf(largest_vertical, absf(oy))
		distinct["%.17f|%.17f|%.17f" % [ox, oy, oz]] = true
		_check(
			absf(ox) <= s.tuning.shake_horizontal and absf(oz) <= s.tuning.shake_horizontal,
			"jolt %d is within +/-shakeHorizontal on X and Z (%.4f, %.4f)" % [i, ox, oz]
		)
		_check(
			absf(oy) <= s.tuning.shake_vertical,
			"jolt %d is within +/-shakeVertical (%.4f)" % [i, oy]
		)
		var twin: Array = second[i]
		_check(
			ox == twin[0] and oy == twin[1] and oz == twin[2],
			"jolt %d reproduces exactly from the same seed" % i
		)

	_check(distinct.size() > first.size() / 2, "the jolts differ from one another")
	# The bounds are USED, not merely respected: a shake of half the specified size
	# would satisfy every check above.
	_check(
		largest_horizontal > s.tuning.shake_horizontal * 0.9,
		(
			"the horizontal shake reaches its stated limit (%.4f of %.4f)"
			% [largest_horizontal, s.tuning.shake_horizontal]
		)
	)
	_check(
		largest_vertical > s.tuning.shake_vertical * 0.9,
		(
			"the vertical shake reaches its stated limit (%.4f of %.4f)"
			% [largest_vertical, s.tuning.shake_vertical]
		)
	)
	# And the two axes are not the same number: a vertical drawn from
	# shakeHorizontal would exceed shakeVertical here.
	_check(
		largest_vertical < s.tuning.shake_horizontal * 0.9,
		"the vertical limit is shakeVertical, not shakeHorizontal"
	)


## `count` jolt offsets from a freshly seeded camera, each measured against the
## camera's resting position so the easing between them cannot contaminate them.
##
## Returned as arrays of three floats, NOT as Vector3. Vector3 is 32-bit real_t in
## a standard build and these are compared against 64-bit tuning limits: 0.15
## stored as float32 is 0.150000005960…, so a draw within about 1.5e-9 of the limit
## rounds UP and fails a bound it actually respects, while an overshoot smaller
## than about 6e-9 disappears. Neither has happened; neither should be able to.
## The camera's own state is float64 and there is no reason to narrow it on the way
## into an assertion.
func _jolt_offsets(sim: RefCounted, count: int) -> Array:
	var c := _camera(sim)
	c.seed_shake(SHAKE_SEED)
	c.step(sim.pos_x, sim.pos_z, sim.yaw, 0.0)
	var rest_x: float = c.pos_x
	var rest_y: float = c.pos_y
	var rest_z: float = c.pos_z
	var offsets: Array = []
	for _i in range(count):
		c.pos_x = rest_x
		c.pos_y = rest_y
		c.pos_z = rest_z
		c.jolt()
		offsets.append([c.pos_x - rest_x, c.pos_y - rest_y, c.pos_z - rest_z])
	return offsets
