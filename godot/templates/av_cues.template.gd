# TEMPLATE — assert the game's feedback vocabulary.
#
# Requires one thing from the simulation: it must PUBLISH its one-shot effects
# as data rather than calling the audio player directly. An event list the view
# drains each frame:
#
#   sim.events == [{"type": "sfx", "id": "laser_fire", "volume": 0.18}, ...]
#
# That one design choice makes every cue assertable without a sound card, and
# keeps the sim free of engine dependencies. If your sim calls play() directly,
# do this refactor first — it is small and it is the whole prerequisite.
#
# THE NEGATIVE ASSERTIONS ARE THE POINT. "A shielded hit must NOT play the
# hull-damage sound" is a design promise no gameplay test would notice breaking,
# because the game still works perfectly — it just stops telling the player the
# truth about what happened.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _drain(sim) -> Array:
	var out: Array = sim.events.duplicate()
	sim.events.clear()
	return out


func _run_ticks(sim, ticks: int) -> Array:
	var out: Array = []
	for i in range(ticks):
		sim.step()
		out.append_array(_drain(sim))
	return out


func _has(events: Array, id: String) -> bool:
	for e in events:
		if e.get("type", "") == "sfx" and e["id"] == id:
			return true
	return false


func _volume(events: Array, id: String) -> float:
	for e in events:
		if e.get("type", "") == "sfx" and e["id"] == id:
			return e["volume"]
	return -1.0


func _init() -> void:
	# SHAPE 1 — positive: the action produces its cue.
	#   _check(_has(events, "laser_fire"), "firing emits the laser cue")

	# SHAPE 2 — negative: the WRONG cue must not fire. Any state the player is
	# meant to distinguish by ear belongs here.
	#   _check(not _has(events, "player_damage"),
	#       "a shielded hit must NOT emit the hull-damage cue")

	# SHAPE 3 — silence is a behaviour too. Invulnerability windows, cooldowns
	# and dead states should produce nothing; otherwise cues machine-gun.
	#   _check(events.is_empty(), "hit inside invulnerability emits nothing")

	# SHAPE 4 — relationships, not literals. Assert that richer pickups are
	# LOUDER, not that a volume equals 0.45; the first survives a mix pass, the
	# second turns every tuning tweak into a test edit.
	#   _check(v1 < v3 and v3 < v5, "pickup volume rises with tier")

	# SHAPE 5 — telegraphs. If the design promises a warning before a threat
	# commits, assert the warning fires.

	RVTest.finish(self, "a/v cues: <what was checked> ok", "a/v cue check(s)")


## Worked example: tests/av_event_test.gd in the project this kit came from.
