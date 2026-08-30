# The lap gate and timing — the design document's Lap Detection and Best-Time
# Tracking feature, plus the port decisions in godot/lap-timing: the crossing
# test reads stage 5's own +Z displacement, the lap clock is its own counter,
# best state is session state.
#
#   godot --headless -s tests/lap_gate_test.gd
#
# EXPECTED VALUES COME FROM THE DESIGN DOCUMENT: the band Z ∈ (4, 6), |X| < 5;
# minLapTime 5 s; lapRestartDelay 0.5 s; bestFlashDuration 1 s; the threshold
# 0.01 wu of stage-5 +Z displacement. The two traps its own paragraph names —
# the push-out and driving-forward-heading-south — get their own tests.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const Sim := preload("res://scripts/core/sim.gd")
const InputState := preload("res://scripts/core/input_state.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")
const Collision := preload("res://scripts/core/collision.gd")
const Normalise := preload("res://scripts/core/normalise.gd")

const MIN_LAP_TICKS := 300  # minLapTime 5 s, quoted
const HOLD_TICKS := 30  # lapRestartDelay 0.5 s
const FLASH_TICKS := 60  # bestFlashDuration 1 s

## The scripted lap tools/lap_capture.gd replays for M4's visual proof: north
## through the band (too soon — rejected), a left u-turn (drifting east of the
## band's X window), south past the band outside that window, a second left
## u-turn curling back west to the line, then north through the band under
## power with the clock long past minLapTime.
## [forward, left, right, ticks]
const LAP_PHASES: Array = [
	[true, false, false, 340],
	[true, true, false, 79],
	[true, false, false, 350],
	[true, true, false, 79],
	[true, false, false, 200],
]


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _sim() -> RefCounted:
	var s := Sim.new()
	s.tuning = TuningLoader.load_tuning()
	s.input = InputState.new()
	s.race.start_racing_immediately()
	return s


## Run the clock past minLapTime with the kart parked somewhere harmless.
func _mature_clock(s: RefCounted) -> void:
	for _i in range(MIN_LAP_TICKS + 1):
		s.step()


func _drive_ticks(s: RefCounted, forward: bool, left: bool, right: bool, ticks: int) -> void:
	s.input.forward = forward
	s.input.left = left
	s.input.right = right
	for _i in range(ticks):
		s.step()


func _init() -> void:
	_test_scripted_lap_banks()
	_test_too_soon_is_rejected()
	_test_wrong_way_is_rejected()
	_test_outside_the_band_is_rejected()
	_test_push_out_cannot_bank()
	_test_hold_window_and_restart()
	_test_best_updates_and_flashes()
	_test_slower_lap_keeps_the_best()
	RVTest.finish(self, "lap gate: crossing, rejections, hold, best, flash ok", "lap check(s)")


# @covers Lap Detection and Best-Time Tracking / Completing a valid lap
func _test_scripted_lap_banks() -> void:
	var s := _sim()
	for phase: Array in LAP_PHASES:
		if s.lap.banked_seconds >= 0.0:
			break
		_drive_ticks(s, phase[0], phase[1], phase[2], int(phase[3]))
	_check(s.lap.banked_seconds > 0.0, "the scripted drive banks a lap")
	_check(
		s.lap.banked_seconds >= 5.0,
		"and not before minLapTime (banked %.2f s)" % s.lap.banked_seconds
	)
	_check(s.lap.best_seconds == s.lap.banked_seconds, "the first lap is the session best")


# @covers Lap Detection and Best-Time Tracking / Rejecting a crossing
func _test_too_soon_is_rejected() -> void:
	var s := _sim()
	# Straight north from the start: the kart crosses the band well inside the
	# first five seconds and must not bank.
	_drive_ticks(s, true, false, false, MIN_LAP_TICKS - 1)
	_check(s.pos_z > 6.0, "the kart has driven through the band (z=%.1f)" % s.pos_z)
	_check(s.lap.banked_seconds < 0.0, "too soon: no lap is banked before minLapTime")


func _test_wrong_way_is_rejected() -> void:
	var s := _sim()
	_mature_clock(s)
	# Facing south, north of the band, driving forward under power: the scalar
	# velocity is positive, stage 5's +Z displacement is negative.
	s.yaw = PI
	s.pos_z = 8.0
	s.pos_x = 0.0
	_drive_ticks(s, true, false, false, 60)
	_check(s.pos_z < 4.0, "the kart drove south through the band (z=%.1f)" % s.pos_z)
	_check(s.lap.banked_seconds < 0.0, "wrong way: driving forward heading south banks nothing")


func _test_outside_the_band_is_rejected() -> void:
	var s := _sim()
	_mature_clock(s)
	s.pos_z = 2.0
	s.pos_x = 6.0  # |X| >= 5: around the band, not through it
	_drive_ticks(s, true, false, false, 60)
	_check(s.pos_z > 6.0, "the kart passed the plane z=5 (z=%.1f)" % s.pos_z)
	_check(s.lap.banked_seconds < 0.0, "outside the band: passing at |X| >= 5 banks nothing")


func _test_push_out_cannot_bank() -> void:
	var s := _sim()
	_mature_clock(s)
	# The document's own trap: a kart motionless in the band against a prop on
	# its south side is shoved +0.3 wu north every tick — thirty times the
	# threshold — while stage 5 displaces it nothing. A synthetic kart box, so
	# the geometry is exact.
	s.kart_normalised = Normalise.to_target_height(
		AABB(Vector3(-1.1, 0.0, -1.18), Vector3(2.2, 1.2, 2.36)), 1.2
	)
	var prop := Collision.Prop.new()
	prop.asset = "synthetic"
	prop.box = AABB(Vector3(-1.0, 0.0, 3.2), Vector3(2.0, 2.0, 2.0))
	s.props = [prop]
	s.pos_z = 5.0
	s.pos_x = 0.0
	s.velocity = 0.0
	s.input.forward = false
	var z_before: float = s.pos_z
	var pushed := false
	for _i in range(40):
		s.step()
		if s.last_hit != null:
			pushed = true
	_check(pushed, "setup: the prop really does push the kart each tick")
	_check(s.pos_z > z_before, "and the push moved it north through the band's plane")
	_check(s.lap.banked_seconds < 0.0, "a push-out alone cannot bank a lap (stage 5 moved nothing)")


# @covers Lap Detection and Best-Time Tracking / Restarting the clock after a lap
func _test_hold_window_and_restart() -> void:
	var s := _sim()
	_bank_a_lap(s)
	var banked: float = s.lap.banked_seconds
	_check(s.lap.hold_ticks == HOLD_TICKS, "the hold window arms at lapRestartDelay")
	var x_before: float = s.pos_x
	var v_before: float = s.velocity
	s.input.forward = false
	for _i in range(HOLD_TICKS - 1):
		s.step()
		_check_quiet(s.lap.display_seconds() == banked, "held display")
	_check(true, "the display holds the banked time through the hold window")
	s.step()
	s.step()
	_check(s.lap.hold_ticks == 0 and s.lap.clock_seconds() < 0.1, "then the clock restarts from 0")
	_check(
		s.pos_x == x_before and absf(s.velocity - v_before * pow(0.96, HOLD_TICKS + 1)) < 0.05,
		"the kart itself was never touched — only the clock paused"
	)


# @covers Lap Detection and Best-Time Tracking / Setting a new best time
# @covers Heads-Up Display / Running the race timer
func _test_best_updates_and_flashes() -> void:
	var s := _sim()
	_bank_a_lap(s)
	_check(s.lap.best_flash_ticks > 0, "the first best arms the green flash")
	_check(
		s.lap.best_flash_ticks <= FLASH_TICKS,
		"for bestFlashDuration (%d ticks armed)" % s.lap.best_flash_ticks
	)
	for _i in range(FLASH_TICKS + 2):
		s.step()
	_check(s.lap.best_flash_ticks == 0, "and the flash expires on the simulation clock")
	# The running clock: continuous while racing, held only during the hold —
	# the readout is this value formatted to two decimals (overlay assertions
	# in driver_test.gd read the label itself).
	var t0: float = s.lap.clock_seconds()
	for _i in range(60):
		s.step()
	_check(
		absf(s.lap.clock_seconds() - t0 - 1.0) < 0.001,
		"the lap clock runs on ticks, one second per sixty"
	)


# @covers Lap Detection and Best-Time Tracking / Recording a lap slower than the best
func _test_slower_lap_keeps_the_best() -> void:
	var s := _sim()
	_bank_a_lap(s)
	var best: float = s.lap.best_seconds
	for _i in range(FLASH_TICKS + 2):
		s.step()
	# Second lap, necessarily slower: the clock must mature past minLapTime
	# again, and we let it run well past the first lap's time before crossing.
	_recross(s, int(best * 60.0) + 240)
	_check(s.lap.banked_seconds > best, "the second lap was slower (%.2f)" % s.lap.banked_seconds)
	_check(s.lap.best_seconds == best, "the best readout is unchanged")
	_check(s.lap.best_flash_ticks == 0, "and no flash arms")
	_check(s.lap.hold_ticks > 0, "but the lap still counted: the clock is in its hold")


## Park south of the band until the clock matures, then drive north through
## it, stopping the drive on the bank tick so the hold window is untouched.
func _bank_a_lap(s: RefCounted) -> void:
	s.pos_z = -3.0
	s.pos_x = 0.0
	s.yaw = 0.0
	_mature_clock(s)
	s.input.forward = true
	for _i in range(120):
		s.step()
		if s.lap.banked_this_tick:
			break
	_check(s.lap.banked_seconds >= 0.0, "setup: the maturity drive banked a lap")
	s.input.forward = false


## After a bank, wait out the hold, mature the new clock, and cross again.
func _recross(s: RefCounted, extra_wait_ticks: int) -> void:
	for _i in range(HOLD_TICKS + extra_wait_ticks):
		s.step()
	s.pos_z = -3.0
	s.pos_x = 0.0
	s.yaw = 0.0
	s.velocity = 0.0
	s.input.forward = true
	for _i in range(120):
		s.step()
		if s.lap.banked_this_tick:
			break
	s.input.forward = false


## A quiet check that only records failures, for per-tick loops.
func _check_quiet(cond: bool, msg: String) -> void:
	if not cond:
		RVTest.check(cond, msg)
