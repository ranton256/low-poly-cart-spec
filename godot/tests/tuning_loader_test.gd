# The shipped tuning table, end to end.
#
#   godot --headless -s tests/tuning_loader_test.gd
#
# WHY THIS EXISTS SEPARATELY. Every other suite builds a Tuning from inline
# literals, which is what keeps them independent of the real table — a good
# property for testing the curve, and a hole on its own: retune tuning.json and
# they would all still pass while the shipped game violated acceptance item 4.
#
# This suite closes that loop. It loads the real file through the real loader
# and asserts the design document's three timings against it, so a typo in a
# JSON key or a drifted value fails here rather than in a playtest.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const Loader := preload("res://scripts/tuning_loader.gd")
const Sim := preload("res://scripts/core/sim.gd")
const InputState := preload("res://scripts/core/input_state.gd")

# Acceptance Checklist item 4, quoted from the design document.
const DIAL_NINE_TENTHS := 103
const DIAL_NINE_TENTHS_SECONDS := 0.94
const DIAL_STEADY := 115
const DIAL_STEADY_SECONDS := 2.60
const COAST_BELOW_THRESHOLD_SECONDS := 1.21
const TIMING_TOLERANCE := 0.05
const SETTLE_TICKS := 300


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_test_the_real_table_loads_completely()
	_test_the_real_table_produces_the_acceptance_timings()
	_test_the_real_table_carries_the_asset_target_heights()
	_test_a_malformed_table_is_refused()
	RVTest.finish(self, "tuning loader: real table meets acceptance item 4", "loader check(s)")


func _test_the_real_table_loads_completely() -> void:
	var t: RefCounted = Loader.load_tuning()
	_check(t != null, "the shipped tuning.json loads")
	if t == null:
		return
	var missing: PackedStringArray = t.missing_fields()
	_check(
		missing.is_empty(),
		"every field the simulation needs is present (missing: %s)" % ", ".join(missing)
	)


## The whole point of the file: the SHIPPED numbers, not inline ones, must
## produce the design document's curve.
func _test_the_real_table_produces_the_acceptance_timings() -> void:
	var tuning: RefCounted = Loader.load_tuning()
	if tuning == null:
		_check(false, "cannot check timings without the tuning table")
		return

	var spin := Sim.new()
	spin.tuning = tuning
	spin.input = InputState.new()
	spin.race.start_racing_immediately()  # timing suite: skip the countdown
	spin.input.forward = true
	var t103 := -1
	var t115 := -1
	for n in range(1, 6001):
		spin.step()
		if t103 < 0 and spin.speedo_readout() >= DIAL_NINE_TENTHS:
			t103 = n
		if t115 < 0 and spin.speedo_readout() >= DIAL_STEADY:
			t115 = n
			break
	_check(t103 > 0 and t115 > 0, "the shipped table reaches both dial values")

	var s103: float = float(t103) / float(spin.TICKS_PER_SECOND)
	var s115: float = float(t115) / float(spin.TICKS_PER_SECOND)
	_check(
		absf(s103 - DIAL_NINE_TENTHS_SECONDS) <= TIMING_TOLERANCE,
		(
			"shipped table: dial %d at %.4f s, want %.2f +/- %.2f"
			% [DIAL_NINE_TENTHS, s103, DIAL_NINE_TENTHS_SECONDS, TIMING_TOLERANCE]
		)
	)
	_check(
		absf(s115 - DIAL_STEADY_SECONDS) <= TIMING_TOLERANCE,
		(
			"shipped table: dial %d at %.4f s, want %.2f +/- %.2f"
			% [DIAL_STEADY, s115, DIAL_STEADY_SECONDS, TIMING_TOLERANCE]
		)
	)

	var coast := Sim.new()
	coast.tuning = tuning
	coast.input = InputState.new()
	coast.race.start_racing_immediately()  # timing suite: skip the countdown
	coast.input.forward = true
	for _i in range(SETTLE_TICKS):
		coast.step()
	coast.input.clear()
	var tc := -1
	for n in range(1, 6001):
		coast.step()
		if absf(coast.velocity) < coast.tuning.steer_threshold:
			tc = n
			break
	_check(tc > 0, "the shipped table coasts below the steering threshold")
	var sc: float = float(tc) / float(coast.TICKS_PER_SECOND)
	_check(
		absf(sc - COAST_BELOW_THRESHOLD_SECONDS) <= TIMING_TOLERANCE,
		(
			"shipped table: coast below threshold at %.4f s, want %.2f +/- %.2f"
			% [sc, COAST_BELOW_THRESHOLD_SECONDS, TIMING_TOLERANCE]
		)
	)


## The §3 target heights reach the simulation through the same loader, so the
## shipped values are asserted rather than only gated as text.
func _test_the_real_table_carries_the_asset_target_heights() -> void:
	var tuning: RefCounted = Loader.load_tuning()
	if tuning == null:
		_check(false, "cannot check target heights without the tuning table")
		return
	var expected := {
		"kart": 1.2,
		"tree": 4.0,
		"rock": 1.5,
		"cone": 0.8,
		"crate": 1.0,
		"tires": 1.2,
		"cottage": 3.0
	}
	for asset in expected:
		var got: float = tuning.target_height(asset)
		_check(
			absf(got - float(expected[asset])) < 0.000001,
			"%s target height is %.2f (got %.4f)" % [asset, expected[asset], got]
		)
	_check(tuning.target_height("nonexistent") == 0.0, "an unknown asset yields zero, not a guess")


## A missing key must be refused by name, not surface later as a kart that will
## not move.
func _test_a_malformed_table_is_refused() -> void:
	var missing_path := "res://tests/does_not_exist.json"
	_check(Loader.load_tuning(missing_path) == null, "a missing file is refused")
