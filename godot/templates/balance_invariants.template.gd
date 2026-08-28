# TEMPLATE — design intent as assertions over DATA, not over code.
#
# This is the highest-value suite in the kit and the least obvious. It does not
# test that functions work; it tests that the game's tuning data still says what
# the designer meant. A generous-looking number change that quietly lets the
# player finish the upgrade tree at level 5 fails here, immediately, with a
# message naming the level.
#
# Write these the moment a tuning intent becomes a sentence someone could say
# out loud: "difficulty never dips", "the kit completes late, not early",
# "no boss is a damage sponge".
extends SceneTree

const RVTest := preload("res://tests/harness.gd")


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_test_monotonic_difficulty()
	_test_bounded_pressure()
	_test_economy_curve()
	RVTest.finish(self, "balance: <what was checked> ok", "balance invariant(s)")


## SHAPE 1 — monotonic escalation.
## Derive a difficulty scalar per level from the data (spawn rate x enemy HP,
## incoming damage per second, whatever your game's pressure actually is) and
## assert it never decreases. Use a small epsilon: equal is fine, dipping is not.
func _test_monotonic_difficulty() -> void:
	var previous := 0.0
	for level in range(1, 2):  # TODO: your level count
		var pressure := 0.0   # TODO: compute from your level data
		_check(pressure >= previous - 1e-9,
			"difficulty dips at level %d (%.3f < %.3f)" % [level, pressure, previous])
		previous = pressure


## SHAPE 2 — bounded, and zero where it should be.
## Monotonic alone permits runaway. Assert an upper bound too, and assert the
## tutorial level is actually gentle — an intro that quietly armed itself is a
## classic regression that no crash test catches.
func _test_bounded_pressure() -> void:
	pass  # TODO


## SHAPE 3 — simulate the economy at a player-skill parameter.
## Model a player who collects some fraction of what drops, walk the campaign,
## buy what they can afford, and assert where they end up. Two runs — a
## realistic collector and a near-perfect one — bracket the curve:
##
##   realistic:     owns most of the kit by the end, never goes negative
##   near-perfect:  completes the kit, but NOT before level N, and does not
##                  finish drowning in unspent currency
##
## The "not before level N" assertion is the one that catches over-generous
## tuning, and it is the one nobody writes unprompted.
func _test_economy_curve() -> void:
	pass  # TODO


## Worked example: tests/balance_test.gd in the project this kit came from.
