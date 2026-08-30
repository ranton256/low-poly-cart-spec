# The race state machine — the design document's Race Start Sequence and Game
# State Machine feature, plus the port decisions in godot/race-state:
# tick-derived countdown, GO! on tick 240, failure as terminal LOADING.
#
#   godot --headless -s tests/race_state_test.gd
#
# EXPECTED TIMINGS COME FROM THE DESIGN DOCUMENT: countdownStep is 1.0 s
# (60 ticks), READY shows immediately, GO! lands 4.0 s — exactly 240 ticks —
# after STARTING begins. "4.0 s, not 5.0 s": the document warns about the
# off-by-one-step reading twice, so tick 240 is asserted exactly, not with the
# ± 6 tick acceptance slack.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const RaceState := preload("res://scripts/core/race_state.gd")
const Sim := preload("res://scripts/core/sim.gd")
const Tuning := preload("res://scripts/core/tuning.gd")
const InputState := preload("res://scripts/core/input_state.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")

const GO_TICK := 240  # 4 × countdownStep × 60, quoted from the document


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _make_race() -> RefCounted:
	var race: RefCounted = RaceState.new()
	race.countdown_step_ticks = 60
	return race


## A minimal racing-capable sim with the SHIPPED tuning, no props, no kart box.
func _make_sim() -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.tuning = TuningLoader.load_tuning()
	sim.input = InputState.new()
	return sim


func _init() -> void:
	_test_boots_in_loading_with_nothing_available()
	_test_transitions_taken_once_each()
	_test_countdown_indices_at_step_boundaries()
	_test_go_lands_on_tick_240_exactly()
	_test_failure_is_terminal_loading()
	_test_sim_freezes_kart_during_starting()
	_test_held_input_acts_on_first_racing_tick()
	_test_race_state_in_the_summary()
	RVTest.finish(
		self, "race state: states, countdown, freeze, failure, summary ok", "race check(s)"
	)


# The "Presenting a loading state" scenario stays with the visual register —
# the indicator's on-screen presence is the claim; this covers the state half.
func _test_boots_in_loading_with_nothing_available() -> void:
	var race: RefCounted = _make_race()
	_check(race.state == RaceState.LOADING, "the machine boots in LOADING")
	for _i in range(200):
		race.advance()
	_check(race.state == RaceState.LOADING, "LOADING never advances on ticks alone")
	_check(race.countdown_index() == -1, "no countdown is running in LOADING")


# @covers Race Start Sequence and Game State Machine / Enumerating the game states
# The claim text must match the design document verbatim and does not fit in
# the line limit, so the limit yields for exactly these two lines.
# gdlint: disable=max-line-length
# @covers
#   Session Bootstrap and Asset Normalisation / Completing bootstrap and handing off to the start sequence


func _test_transitions_taken_once_each() -> void:
	# gdlint: enable=max-line-length — the verbatim claim above is the only
	# line the limit yields for; the checker's block parser reads comments up
	# to the function line, so the directive lives here.
	var race: RefCounted = _make_race()
	race.mark_world_ready()
	_check(race.state == RaceState.STARTING, "world-ready hands off to STARTING automatically")
	race.mark_world_ready()
	_check(
		race.state == RaceState.STARTING and race.ticks_in_state == 0,
		"a second world-ready is a no-op; the transition is taken once"
	)
	for _i in range(GO_TICK):
		race.advance()
	_check(race.state == RaceState.RACING, "STARTING hands off to RACING")
	for _i in range(10000):
		race.advance()
	_check(race.state == RaceState.RACING, "there is no path out of RACING")


# @covers Race Start Sequence and Game State Machine / Running the countdown
func _test_countdown_indices_at_step_boundaries() -> void:
	var race: RefCounted = _make_race()
	race.mark_world_ready()
	_check(race.countdown_index() == 0, "READY shows immediately, before any tick")
	var expected: Array = [[0, 0], [59, 0], [60, 1], [120, 2], [180, 3], [239, 3]]
	for pair: Array in expected:
		var race2: RefCounted = _make_race()
		race2.mark_world_ready()
		for _i in range(int(pair[0])):
			race2.advance()
		_check(
			race2.countdown_index() == int(pair[1]),
			"tick %d shows countdown index %d" % [int(pair[0]), int(pair[1])]
		)


# @covers Race Start Sequence and Game State Machine / Releasing control on the GO frame
func _test_go_lands_on_tick_240_exactly() -> void:
	var race: RefCounted = _make_race()
	race.mark_world_ready()
	for _i in range(GO_TICK - 1):
		race.advance()
	_check(race.state == RaceState.STARTING, "tick 239 is still STARTING — 4.0 s, not sooner")
	race.advance()
	_check(race.state == RaceState.RACING, "tick 240 is RACING — 4.0 s, not 5.0")
	_check(race.ticks_in_state == 0, "the racing clock zeroes on the GO! tick")


# @covers Session Bootstrap and Asset Normalisation / Failing to load an asset
func _test_failure_is_terminal_loading() -> void:
	var race: RefCounted = _make_race()
	race.fail_load("synthetic: model missing")
	_check(race.state == RaceState.LOADING, "a failed load stays in LOADING")
	_check(race.error_message != "", "the failure carries a visible message")
	race.mark_world_ready()
	for _i in range(GO_TICK * 2):
		race.advance()
	_check(
		race.state == RaceState.LOADING,
		"a failed LOADING is terminal — no countdown into a broken world"
	)


# @covers Race Start Sequence and Game State Machine / Freezing the kart during the countdown
# @covers Frame Loop and Render Pipeline / Suspending the simulation outside the racing state
func _test_sim_freezes_kart_during_starting() -> void:
	var sim: RefCounted = _make_sim()
	sim.race.mark_world_ready()
	sim.input.forward = true
	sim.input.left = true
	for _i in range(GO_TICK - 1):
		sim.step()
	_check(sim.velocity == 0.0, "held drive input does not accelerate a STARTING kart")
	_check(
		sim.yaw == 0.0 and sim.pos_x == 0.0 and sim.pos_z == 0.0,
		"the kart does not move or rotate before GO!"
	)
	_check(sim.ticks == GO_TICK - 1, "the simulation clock still advances while frozen")


# (The freeze scenario is claimed once, on the test above.)
func _test_held_input_acts_on_first_racing_tick() -> void:
	var sim: RefCounted = _make_sim()
	sim.race.mark_world_ready()
	sim.input.forward = true
	for _i in range(GO_TICK):
		sim.step()
	_check(sim.race.state == RaceState.RACING, "tick 240 is the first racing tick")
	_check(sim.velocity > 0.0, "a key held through GO! takes effect on that very tick")


func _test_race_state_in_the_summary() -> void:
	var a: RefCounted = _make_sim()
	var b: RefCounted = _make_sim()
	for s: RefCounted in [a, b]:
		s.race.mark_world_ready()
	for _i in range(GO_TICK + 30):
		a.step()
		b.step()
	_check(a.stats_line() == b.stats_line(), "two identical runs agree through the countdown")
	_check("state=" in a.stats_line(), "the summary carries the race state")
