# TEMPLATE — twin-sim differential: prove a feature consumes no randomness.
#
# The trick: run the SAME seed twice, once with the feature and once without,
# and assert the RNG state is identical afterwards. If the feature drew even one
# number, the streams diverge and every later roll in the game shifts.
#
# Why you need it: once a seeded run is a regression tool — a bot that must
# reach victory, captures that must reproduce — the DRAW ORDER becomes part of
# the contract. Adding "one small random choice" at spawn time silently
# invalidates every recorded seed. This test makes that visible the moment it
# happens instead of three commits later when the bot mysteriously dies.
#
# It also documents the rule for the next person: authored content must not
# perturb the stream.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_test_feature_is_rng_free()
	_test_run_is_reproducible()
	RVTest.finish(self, "rng: draw-order contract holds", "rng check(s)")


## Twin sims, same seed, feature off vs on.
func _test_feature_is_rng_free() -> void:
	# TODO: replace MyRng/MySim with your own
	# MyRng.seed_rng(777)
	# var plain := MySim.new(); plain.setup(...)
	# for i in range(90): plain.step()
	# var state_without := MyRng.state
	#
	# MyRng.seed_rng(777)
	# var featured := MySim.new(); featured.setup(...)
	# featured.scripted_events = [...]        # the feature under test
	# for i in range(90): featured.step()
	#
	# _check(MyRng.state == state_without,
	#     "scripted spawns consume no RNG (stream diverged)")
	pass


## Same seed twice must produce the same run. A one-line state summary is enough
## and is far easier to diff than comparing object graphs.
func _test_run_is_reproducible() -> void:
	# var runs: Array[String] = []
	# for attempt in range(2):
	#     MyRng.seed_rng(9090)
	#     var sim := MySim.new(); sim.setup(...)
	#     for i in range(600): sim.step()
	#     runs.append(sim.stats_line())
	# _check(runs[0] == runs[1], "runs are deterministic")
	pass


## Draw-order rules worth asserting once you depend on seeds:
##
##   - a per-tick roll must happen even when its result cannot matter, so the
##     draw COUNT does not depend on game state
##   - derive extra outcomes from a roll you already made rather than drawing
##     again (e.g. drop rarity from the same number that decided the drop)
##   - authored/scripted content uses fixed values, never rolls
##   - cosmetic randomness (screen shake, view-only jitter) draws from a
##     DIFFERENT generator, so it can never perturb gameplay
##
## Worked example: tests/behavior_test.gd in the project this kit came from.
