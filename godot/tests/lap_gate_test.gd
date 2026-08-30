# The lap gate and timing — the design document's Lap Detection and Best-Time
# Tracking feature, plus the port decisions in godot/lap-timing: the crossing
# test reads stage 5's own +Z displacement, the lap clock is its own counter,
# best state is session state.
#
#   godot --headless -s tests/lap_gate_test.gd
#
# EXPECTED VALUES COME FROM THE DESIGN DOCUMENT: the band Z ∈ (4, 6), |X| < 5;
# lapRestartDelay 0.5 s; bestFlashDuration 1 s; the threshold 0.01 wu of
# stage-5 +Z displacement. The two traps its own paragraph names — the push-out
# and driving-forward-heading-south — get their own tests.
#
# THERE IS NO MINIMUM LAP TIME any more: the ordered gates are the farming
# defence, and `minLapTime` went with add-circuit-world-and-presentation. The
# rejection cases below therefore run on a simulation with NO circuit armed, on
# purpose — with no threading condition in play, the only thing that can refuse
# a crossing is the condition each case is about. The threaded half is here too:
# the scripted drive now threads the SHIPPED circuit's six gates on its way to
# the line, which is what keeps tools/lap_capture.gd, tools/refresh_probe.gd and
# main.gd's LPC_SMOKE banking the same lap on the same tick as before.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const LayoutIO := preload("res://scripts/world/layout_io.gd")
const Sim := preload("res://scripts/core/sim.gd")
const InputState := preload("res://scripts/core/input_state.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")
const Collision := preload("res://scripts/core/collision.gd")
const Normalise := preload("res://scripts/core/normalise.gd")

## Long enough that two banked laps are unmistakably different times. NOT a
## minimum — none exists.
const CLOCK_RUN_TICKS := 300
const HOLD_TICKS := 30  # lapRestartDelay 0.5 s
const FLASH_TICKS := 60  # bestFlashDuration 1 s

## The scripted lap tools/lap_capture.gd replays for M4's visual proof: north
## through the band (unthreaded — nothing banks), a left u-turn (drifting east
## of the band's X window), south past the band outside that window, a second
## left u-turn curling back west to the line, then north through the band under
## power with every gate of the shipped circuit passed in order. The shipped
## circuit's gates were AUTHORED ON THIS TRAJECTORY (tools/author_first_light.gd)
## precisely so this table still banks, at the same tick, unmodified.
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


## Run the clock on with the kart parked somewhere harmless.
func _run_the_clock(s: RefCounted) -> void:
	for _i in range(CLOCK_RUN_TICKS + 1):
		s.step()


func _drive_ticks(s: RefCounted, forward: bool, left: bool, right: bool, ticks: int) -> void:
	s.input.forward = forward
	s.input.left = left
	s.input.right = right
	for _i in range(ticks):
		s.step()


func _init() -> void:
	_test_scripted_lap_banks()
	_test_an_unthreaded_crossing_is_rejected()
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
	var circuit: RefCounted = LayoutIO.read_circuit(LayoutIO.SHIPPED_CIRCUIT_PATH)
	_check(circuit != null and circuit.has_gates(), "setup: the shipped circuit's course loaded")
	s.arm_circuit(circuit)
	var threaded_at := -1
	for phase: Array in LAP_PHASES:
		if s.lap.banked_seconds >= 0.0:
			break
		s.input.forward = phase[0]
		s.input.left = phase[1]
		s.input.right = phase[2]
		for _i in range(int(phase[3])):
			s.step()
			if threaded_at < 0 and s.circuit.is_threaded():
				threaded_at = s.ticks
			if s.lap.banked_this_tick:
				break
	_check(
		s.lap.banked_seconds > 0.0, "the scripted drive banks a lap (%.2f s)" % s.lap.banked_seconds
	)
	_check(
		threaded_at > 0 and threaded_at < s.ticks,
		"having threaded all %d gates first, at tick %d" % [circuit.gate_count(), threaded_at]
	)
	_check(s.lap.best_seconds == s.lap.banked_seconds, "the first lap is the session best")
	_check(s.circuit.cursor == 1, "and banking returned the cursor to gate 1")


# @covers Lap Detection and Best-Time Tracking / Rejecting a crossing
func _test_an_unthreaded_crossing_is_rejected() -> void:
	var s := _sim()
	s.arm_circuit(LayoutIO.read_circuit(LayoutIO.SHIPPED_CIRCUIT_PATH))
	# Straight north from the start: the kart crosses the band having passed no
	# gate at all, and must not bank — however long the clock has run.
	_drive_ticks(s, true, false, false, 60)
	_check(s.pos_z > 6.0, "the kart has driven through the band (z=%.1f)" % s.pos_z)
	_check(s.circuit.cursor == 1, "with the cursor still naming gate 1")
	_check(s.lap.banked_seconds < 0.0, "an unthreaded crossing banks nothing")
	# And again with a long clock behind it, so nothing about the refusal is
	# about being early: the retired minimum is not quietly still in there.
	_run_the_clock(s)
	s.pos_x = 0.0
	s.pos_z = -3.0
	s.yaw = 0.0
	s.velocity = 0.0
	_drive_ticks(s, true, false, false, 90)
	_check(s.pos_z > 6.0, "the kart crossed the band a second time (z=%.1f)" % s.pos_z)
	_check(
		s.lap.banked_seconds < 0.0 and s.lap.clock_seconds() > 5.0,
		(
			"still nothing, %.2f s into the attempt — the line alone is never enough"
			% s.lap.clock_seconds()
		)
	)


func _test_wrong_way_is_rejected() -> void:
	var s := _sim()
	_run_the_clock(s)
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
	_run_the_clock(s)
	s.pos_z = 2.0
	s.pos_x = 6.0  # |X| >= 5: around the band, not through it
	_drive_ticks(s, true, false, false, 60)
	_check(s.pos_z > 6.0, "the kart passed the plane z=5 (z=%.1f)" % s.pos_z)
	_check(s.lap.banked_seconds < 0.0, "outside the band: passing at |X| >= 5 banks nothing")


func _test_push_out_cannot_bank() -> void:
	var s := _sim()
	_run_the_clock(s)
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
	# Second lap, necessarily slower: the clock runs well past the first lap's
	# time before the kart crosses again.
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
	_run_the_clock(s)
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
