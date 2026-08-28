# TEMPLATE — bot x seed survival matrix.
#
# Runs a crude bot through every level across a FIXED seed set and prints a
# survival table. The bot is far below human skill, so the numbers are read
# RELATIVELY: early levels should show clearly higher survival than late ones,
# and no early level should be a spike.
#
# This is a difficulty-SHAPE instrument, not a skill model. Reading it as
# "level 7 is 62% hard" is a mistake; reading it as "level 4 is somehow harder
# than level 9" is exactly what it is for.
#
# Prints rather than asserts, on purpose — difficulty shape is a judgement call.
# Assert the things that are not judgement calls in the balance invariants
# template instead.
extends SceneTree

const SEEDS := [11, 22, 33, 44, 55, 66, 77, 88]


## A bot only needs to be good enough to differentiate levels. Nearest-threat
## avoidance plus a fallback sweep is usually enough. Resist making it clever:
## a strong bot compresses the differences you are trying to see.
func _bot_tick(sim, tick: int) -> void:
	# sim.in_fire = true
	# find the nearest incoming threat above the player; dodge away from it
	# otherwise sweep left/right on a fixed period
	pass


func _init() -> void:
	print("level | survive | median t% | avg hp lost")
	print("------|---------|-----------|------------")
	for level in range(1, 2):  # TODO: your level count
		var survived := 0
		var progress: Array[float] = []
		for seed_value in SEEDS:
			# MyRng.seed_rng(seed_value)
			# var sim := MySim.new(); sim.setup(level, ...)
			# var tick := 0
			# while sim.outcome == "" and tick < max_ticks:
			#     _bot_tick(sim, tick); sim.step(); sim.events.clear(); tick += 1
			# record survival, and how far it got when it died
			pass
		print("  L%d  |  %d/%d    |     -     |     -" % [level, survived, SEEDS.size()])
	quit(0)


## Give the bot a loadout appropriate to the level, or early levels look hard
## for the wrong reason — the bot arriving under-equipped rather than the level
## being badly tuned.
##
## Worked example: tests/difficulty_probe.gd in the project this kit came from.
