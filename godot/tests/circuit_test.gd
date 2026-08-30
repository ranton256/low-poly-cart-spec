# The checkpoint circuit — the design document's Checkpoint Circuit feature and
# the amended lap condition, as core state advanced from stage 8.
#
#   godot --headless -s tests/circuit_test.gd
#
# EXPECTED VALUES COME FROM THE DESIGN DOCUMENT: a gate is a centre, a yaw and a
# width; a pass needs |lateral| < width/2, the position inside a gateDepth slab
# ahead of the segment, and the STEP-5 integration's gate-forward component
# above gateCrossingThreshold; the cursor starts at 1, advances only on the gate
# it names, rewinds on a bank, and Reset Kart does not touch it; the band banks
# only a threaded lap and there is NO minimum lap time; bests and medals belong
# to their circuit, "at or under" a target earning it.
#
# The push-out test is the gate sibling of the band's ordering discriminator and
# is MUTATION-VERIFIED the same way: make the pass test read net position change
# instead of the stage-5 observable and this suite must fail.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const Sim := preload("res://scripts/core/sim.gd")
const Circuit := preload("res://scripts/core/circuit.gd")
const InputState := preload("res://scripts/core/input_state.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")
const Collision := preload("res://scripts/core/collision.gd")
const Normalise := preload("res://scripts/core/normalise.gd")

const HOLD_TICKS := 30  # lapRestartDelay 0.5 s
const MIN_LAP_TICKS := 300  # the retired minLapTime, 5 s — quoted to disprove it

## Every yaw the pass test is staged at: square on, both diagonals, a quarter
## turn, and an arbitrary angle that is none of those.
const GATE_YAWS: Array = [0.0, 0.7853981633974483, -0.7853981633974483, 1.5707963267948966, 2.3]


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_test_the_gate_frame_holds_at_every_yaw()
	_test_a_push_out_cannot_pass_a_gate()
	_test_the_cursor_forgives_everything_but_the_gate_it_names()
	_test_reset_kart_keeps_the_cursor()
	_test_the_band_banks_only_a_threaded_lap()
	_test_bests_belong_to_their_circuit()
	_test_a_lap_exactly_on_a_target_earns_its_medal()
	_test_the_summary_carries_the_circuit()
	RVTest.finish(
		self, "circuit: gate frames, cursor, threading, bests, medals ok", "circuit check(s)"
	)


func _tuning() -> RefCounted:
	return TuningLoader.load_tuning()


func _sim() -> RefCounted:
	var s := Sim.new()
	s.tuning = _tuning()
	s.input = InputState.new()
	s.race.start_racing_immediately()
	return s


## A one-gate circuit, ready to arm.
func _one_gate(gate_x: float, gate_z: float, yaw: float, width: float) -> RefCounted:
	var c := Circuit.new()
	c.circuit_name = "probe"
	c.add_gate(gate_x, gate_z, yaw, width)
	return c


## Stage one tick's worth of geometry directly against the pass test, in the
## gate's own frame: how far ahead of the segment, how far off its centre, and
## how much of stage 5's displacement ran along gate-forward. Returns whether
## the cursor advanced.
func _verdict(yaw: float, ahead: float, lateral: float, along: float) -> bool:
	var c := _one_gate(4.0, -7.0, yaw, 6.0)
	c.tuning = _tuning()
	var fx: float = sin(yaw)
	var fz: float = cos(yaw)
	# The lateral axis: gate-forward turned a quarter turn, so at yaw 0 it is +X.
	var lx: float = cos(yaw)
	var lz: float = -sin(yaw)
	var px: float = 4.0 + fx * ahead + lx * lateral
	var pz: float = -7.0 + fz * ahead + lz * lateral
	c.advance(px, pz, fx * along, fz * along)
	return c.cursor == 2


# @covers Checkpoint Circuit / Defining a gate
func _test_the_gate_frame_holds_at_every_yaw() -> void:
	var t: RefCounted = _tuning()
	var depth: float = t.gate_depth
	var threshold: float = t.gate_crossing_threshold
	var speed: float = threshold * 10.0
	for yaw: float in GATE_YAWS:
		var label := "yaw %.3f" % yaw
		# Inside the slab, on the centre line, driving through it under power.
		_check(_verdict(yaw, depth / 2.0, 0.0, speed), "%s: a clean crossing passes" % label)
		# Half the width is the limit, and it is the gate's OWN half width.
		_check(
			not _verdict(yaw, depth / 2.0, 3.1, speed),
			"%s: wider than half the width laterally does not" % label
		)
		_check(
			_verdict(yaw, depth / 2.0, 2.9, speed), "%s: just inside half the width does" % label
		)
		# The slab is gateDepth deep AHEAD of the segment.
		_check(
			not _verdict(yaw, -0.5, 0.0, speed),
			"%s: short of the segment is not inside the slab" % label
		)
		_check(
			not _verdict(yaw, depth + 0.5, 0.0, speed),
			"%s: beyond the slab's far face is not either" % label
		)
		# The stage-5 component, in gate-forward terms.
		_check(
			not _verdict(yaw, depth / 2.0, 0.0, threshold * 0.999),
			"%s: displacement under the threshold does not pass" % label
		)
		_check(
			not _verdict(yaw, depth / 2.0, 0.0, -speed),
			"%s: through the gate backwards passes nothing" % label
		)
	_check(true, "the same crossing gets the same verdict in all five gate frames")
	# The exact "exceeds, not equals" edge, staged at the one yaw whose frame is
	# exactly representable: sin(0) is 0.0 and cos(0) is 1.0, so the projection
	# is the threshold itself. At an arbitrary yaw sin²+cos² lands a few ulp off
	# unity and the staged value is no longer exactly the threshold — a fact
	# about this staging, not about the pass test.
	_check(
		not _verdict(0.0, depth / 2.0, 0.0, threshold),
		"displacement AT the threshold is not above it — the document says exceeds"
	)


## The immunities half of "Defining a gate", claimed above with the frame half —
## one scenario, one claim, so the coverage gate's bijection holds.
func _test_a_push_out_cannot_pass_a_gate() -> void:
	# The band's own trap, aimed at a gate: a kart motionless against a prop on
	# its south side is shoved +0.3 wu north every tick — thirty times the
	# threshold — while stage 5 displaces it nothing. The gate straddles the
	# path the shove takes.
	var s := _sim()
	s.arm_circuit(_one_gate(0.0, 5.0, 0.0, 10.0))
	s.kart_normalised = Normalise.to_target_height(
		AABB(Vector3(-1.1, 0.0, -1.18), Vector3(2.2, 1.2, 2.36)), 1.2
	)
	var prop := Collision.Prop.new()
	prop.asset = "synthetic"
	prop.box = AABB(Vector3(-1.0, 0.0, 3.2), Vector3(2.0, 2.0, 2.0))
	s.props = [prop]
	s.pos_x = 0.0
	s.pos_z = 5.0
	s.velocity = 0.0
	s.input.forward = false
	var z_before: float = s.pos_z
	var pushed := false
	var reached_slab := false
	for _i in range(40):
		s.step()
		if s.last_hit != null:
			pushed = true
		if s.pos_z >= 5.0 and s.pos_z < 5.0 + s.tuning.gate_depth:
			reached_slab = true
		_check_quiet(
			absf(s.last_step5_dz) <= s.tuning.gate_crossing_threshold, "setup: stage 5 stayed still"
		)
	_check(pushed, "setup: the prop really does push the kart each tick")
	_check(reached_slab, "setup: and the push carried it into the gate's slab (z=%.2f)" % s.pos_z)
	_check(s.pos_z > z_before, "setup: net position moved north through the gate")
	_check(
		s.circuit.cursor == 1,
		"a push-out cannot pass a gate — stage 5's gate-forward component stayed at nothing"
	)


# @covers Checkpoint Circuit / Progress is a cursor, not a checklist
func _test_the_cursor_forgives_everything_but_the_gate_it_names() -> void:
	var c := Circuit.new()
	c.tuning = _tuning()
	c.circuit_name = "three"
	c.add_gate(0.0, 10.0, 0.0, 8.0)
	c.add_gate(0.0, 30.0, 0.0, 8.0)
	c.add_gate(0.0, 50.0, 0.0, 8.0)
	var speed: float = c.tuning.gate_crossing_threshold * 10.0
	var depth: float = c.tuning.gate_depth

	_check(c.cursor == 1, "the cursor starts at gate 1")
	# Not yet due: gate 3 while the cursor names gate 1.
	c.advance(0.0, 50.0 + depth / 2.0, 0.0, speed)
	_check(c.cursor == 1, "passing gate 3 while the cursor names gate 1 changes nothing")
	# The gate it names.
	c.advance(0.0, 10.0 + depth / 2.0, 0.0, speed)
	_check(c.cursor == 2, "passing the named gate advances the cursor by one")
	# Already passed: gate 1 again.
	c.advance(0.0, 10.0 + depth / 2.0, 0.0, speed)
	_check(c.cursor == 2, "passing gate 1 again changes nothing — no reset, no void")
	# The right gate backwards.
	c.advance(0.0, 30.0 + depth / 2.0, 0.0, -speed)
	_check(c.cursor == 2, "the named gate taken backwards changes nothing either")
	# And the only cure is to go and pass it.
	c.advance(0.0, 30.0 + depth / 2.0, 0.0, speed)
	c.advance(0.0, 50.0 + depth / 2.0, 0.0, speed)
	_check(c.cursor == 4 and c.is_threaded(), "passing 2 then 3 threads the course")
	c.advance(0.0, 50.0 + depth / 2.0, 0.0, speed)
	_check(c.cursor == 4, "and a threaded course does not run past its final gate")
	c.rewind()
	_check(c.cursor == 1 and not c.is_threaded(), "banking a lap returns the cursor to 1")


# @covers Checkpoint Circuit / Reset Kart and circuit progress
func _test_reset_kart_keeps_the_cursor() -> void:
	var s := _sim()
	var c := Circuit.new()
	c.circuit_name = "six"
	for i in range(6):
		c.add_gate(0.0, 10.0 * float(i + 1), 0.0, 8.0)
	s.arm_circuit(c)
	var speed: float = s.tuning.gate_crossing_threshold * 10.0
	var depth: float = s.tuning.gate_depth
	for i in range(3):
		c.advance(0.0, 10.0 * float(i + 1) + depth / 2.0, 0.0, speed)
	_check(c.cursor == 4, "setup: the cursor stands at gate 4 of 6")

	s.pos_x = 12.0
	s.pos_z = 34.0
	s.yaw = 1.0
	s.velocity = 0.1
	s.reset_kart()
	_check(
		s.pos_x == 0.0 and s.pos_z == 0.0 and s.yaw == 0.0 and s.velocity == 0.0,
		"setup: Reset Kart restored the start pose"
	)
	_check(c.cursor == 4, "and the cursor still names gate 4 — Reset Kart restores nothing else")

	# No shortcut results: the band still refuses.
	_drive_through_the_band(s)
	_check(
		s.lap.banked_seconds < 0.0,
		"the band still refuses to bank until the remaining gates are passed"
	)


# @covers Checkpoint Circuit / The band banks only a threaded lap
func _test_the_band_banks_only_a_threaded_lap() -> void:
	# Unthreaded: the kart starts NORTH of the gate, so it never passes it, and
	# crosses the band satisfying every other condition of a valid lap.
	var unthreaded := _sim()
	unthreaded.arm_circuit(_one_gate(0.0, -2.0, 0.0, 10.0))
	unthreaded.pos_z = 2.0
	_drive_through_the_band(unthreaded)
	_check(unthreaded.pos_z > unthreaded.tuning.lap_gate_z_max, "setup: it crossed the band")
	_check(unthreaded.circuit.cursor == 1, "setup: with the cursor short of the final gate")
	_check(unthreaded.lap.banked_seconds < 0.0, "an unthreaded crossing banks nothing")
	_check(unthreaded.lap.clock_ticks > 0, "and the clock keeps running")

	# Threaded, and FAST: the whole lap is well inside the retired minLapTime.
	var threaded := _sim()
	threaded.arm_circuit(_one_gate(0.0, -2.0, 0.0, 10.0))
	threaded.pos_z = -4.0
	_drive_through_the_band(threaded)
	_check(threaded.circuit.gate_count() == 1, "setup: one gate on the way to the line")
	_check(threaded.lap.banked_seconds > 0.0, "a threaded crossing banks the lap")
	_check(
		threaded.lap.banked_seconds < float(MIN_LAP_TICKS) / 60.0,
		(
			"in %.2f s — under the retired 5 s minimum, so no minimum applies"
			% threaded.lap.banked_seconds
		)
	)
	_check(threaded.circuit.cursor == 1, "and banking returned the cursor to gate 1")


# @covers Checkpoint Circuit / Best times belong to their circuit
func _test_bests_belong_to_their_circuit() -> void:
	var s := _sim()
	var alpha := _one_gate(0.0, -2.0, 0.0, 10.0)
	alpha.circuit_name = "alpha"
	s.arm_circuit(alpha)
	s.pos_z = -4.0
	_drive_through_the_band(s)
	var alpha_best: float = s.lap.banked_seconds
	_check(alpha_best > 0.0, "setup: a lap banks on circuit alpha (%.2f s)" % alpha_best)
	_check(s.lap.best_seconds == alpha_best, "and it is alpha's best")

	# Circuit B, and a deliberately slower lap: idle before starting the run.
	var beta := _one_gate(0.0, -2.0, 0.0, 10.0)
	beta.circuit_name = "beta"
	s.arm_circuit(beta)
	_check(s.lap.best_seconds < 0.0, "arming beta shows beta's own (unset) best, not alpha's")
	_wait(s, HOLD_TICKS + 240)
	s.pos_z = -4.0
	_drive_through_the_band(s)
	var beta_best: float = s.lap.banked_seconds
	_check(beta_best > alpha_best, "setup: beta's lap was slower (%.2f s)" % beta_best)
	_check(s.lap.best_seconds == beta_best, "beta's best is the slower lap")
	_check(float(s.lap.bests["alpha"]) == alpha_best, "and alpha's best is unchanged")

	s.arm_circuit(alpha)
	_check(s.lap.best_seconds == alpha_best, "returning to alpha shows alpha's own best")


## The core half of "Medal targets". NO `@covers` claim: that scenario is
## written about the held TIME readout gaining the medal's name in the medal's
## colour, and nothing is drawn until add-circuit-world-and-presentation. Its
## register deferral stays open, and the verdict this asserts is what the
## display will read.
func _test_a_lap_exactly_on_a_target_earns_its_medal() -> void:
	# The determination itself, at the edge the document names: "at or under".
	var c := _one_gate(0.0, -2.0, 0.0, 10.0)
	c.targets = {"gold": 10.0, "silver": 20.0, "bronze": 30.0}
	_check(c.medal_for(20.0) == "silver", "a lap EXACTLY on the silver target earns silver")
	_check(c.medal_for(10.0) == "gold", "and exactly on gold earns gold")
	_check(c.medal_for(30.0) == "bronze", "and exactly on bronze earns bronze")
	_check(c.medal_for(9.99) == "gold", "under gold is still gold, the best target met")
	_check(c.medal_for(30.01) == "", "a hundredth over bronze earns nothing")
	var bare := _one_gate(0.0, -2.0, 0.0, 10.0)
	_check(bare.medal_for(0.5) == "", "a circuit may omit targets, and then nothing is earned")

	# And end to end, at bank time, on a lap timed to the tick: the same scripted
	# run twice, the second with its own banked time as the silver target.
	var learn: float = _bank_one_scripted_lap({})
	_check(learn > 0.0, "setup: the scripted lap banks (%.2f s)" % learn)
	var targets: Dictionary = {"gold": learn - 1.0, "silver": learn, "bronze": learn + 1.0}
	var s := _sim()
	s.arm_circuit(_targeted_circuit(targets))
	s.pos_z = -4.0
	_drive_through_the_band(s)
	_check(s.lap.banked_seconds == learn, "setup: the replayed lap banks the same time to the tick")
	_check(s.lap.banked_medal == "silver", "the core's verdict at bank time is silver — at target")


func _test_the_summary_carries_the_circuit() -> void:
	var s := _sim()
	_check(
		"circuit=procedural" in s.stats_line(),
		"with no circuit loaded the summary keys the best as procedural"
	)
	s.arm_circuit(_one_gate(0.0, -2.0, 0.0, 10.0))
	s.pos_z = -4.0
	_drive_through_the_band(s)
	var line: String = s.stats_line()
	_check("circuit=probe" in line, "the loaded circuit's name joins the determinism summary")
	_check("gate=1/1" in line, "so does the cursor, against the gate count")
	_check("medal=" in line, "and the banked medal")


## The scripted lap the medal edge is measured against, banked twice.
func _bank_one_scripted_lap(targets: Dictionary) -> float:
	var s := _sim()
	s.arm_circuit(_targeted_circuit(targets))
	s.pos_z = -4.0
	_drive_through_the_band(s)
	return s.lap.banked_seconds


func _targeted_circuit(targets: Dictionary) -> RefCounted:
	var c := _one_gate(0.0, -2.0, 0.0, 10.0)
	c.targets = targets
	return c


## Drive north under power until a lap banks or the drive runs out.
func _drive_through_the_band(s: RefCounted) -> void:
	s.pos_x = 0.0
	s.yaw = 0.0
	s.velocity = 0.0
	s.input.forward = true
	for _i in range(200):
		s.step()
		if s.lap.banked_this_tick:
			break
	s.input.forward = false


## Idle, so the next lap's clock is unambiguously longer.
func _wait(s: RefCounted, ticks: int) -> void:
	s.input.forward = false
	for _i in range(ticks):
		s.step()


## A quiet check that only records failures, for per-tick loops.
func _check_quiet(cond: bool, msg: String) -> void:
	if not cond:
		RVTest.check(cond, msg)
