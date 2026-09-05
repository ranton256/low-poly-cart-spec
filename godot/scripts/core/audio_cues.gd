# The per-tick audio cue list — the design document's Audio Feedback, as
# simulation DATA and nothing else. Nothing in this file makes a sound.
#
# THE ARCHITECTURE IS THE FIRST RULE, and it is the reason the feature is
# testable at all. The simulation never touches an audio API: it appends a
# RECORD — an id, a volume from the Audio table, and for a spatial cue a world
# position — and the view drains the list each frame and plays it, exactly as
# every other view reads state. `AudioStreamPlayer` is a banned symbol under
# scripts/core/ (CONSTRAINTS §4 Architectural boundaries) and check_boundaries.py
# is the enforcement, not this comment. The consequence worth having: a headless
# run produces the complete cue stream with no sound hardware at all, so every
# promise the document makes about sound — including the NEGATIVE ones, which no
# gameplay test would notice breaking — is assertable in tests/audio_cue_test.gd.
#
# CLEARED AT TICK START, appended by the stage that owns each event. Nothing here
# decides WHEN a cue happens; sim.gd's stages do, at the stage the document
# names. One exception, stated because it is STATE rather than policy: the impact
# rate limit. "A pin is one event, not a drum roll" is a property of the cue
# stream and not of the collision, so the window lives here — counted in TICKS,
# injected by the owner from `impactRateLimit` like every other constant, never
# read from a clock — and it appears in the determinism summary with the rest.
#
# WHAT IS NOT A CUE. The engine note. It is a continuous curve on the speed
# ratio, which is already core state the view reads every frame; a per-tick
# one-shot record is the wrong shape for it entirely. It arrives with the audio
# view, in add-audio-playback.
#
# WHAT THE SUMMARY CARRIES, and why it is not the whole stream. sim.stats_line()
# is compared string-for-string by the determinism suites, and determinism_test
# builds it TWICE PER TICK for three thousand ticks. A cumulative list of every
# cue ever emitted would make that quadratic — a boundary rebound alone can emit
# on hundreds of ticks — and would grow without bound in a running game for the
# benefit of nobody. So the summary carries this tick's cues verbatim, plus the
# running COUNT and a running DIGEST over every record emitted so far. Every
# field of every cue is mixed into the digest as it is appended, so a stream that
# differs anywhere differs in the summary, which is the property the standing
# suites need. The full stream itself is recoverable the way a view recovers it —
# by reading the list every tick — and tests/audio_cue_test.gd does exactly that
# to byte-compare two replays of the baked lap script.
extends RefCounted

## The cue ids. The design document names each one; they are constants here so
## that a caller and a test cannot disagree about the spelling of an event.
const COUNTDOWN_TICK := "countdown_tick"
const COUNTDOWN_GO := "countdown_go"
const REBOUND := "rebound"
const IMPACT := "impact"
const GATE_PASSED := "gate_passed"
const LAP_BANKED := "lap_banked"
const NEW_BEST := "new_best"
const MEDAL := "medal"

## FNV-1a, 32-bit, over each record's own text. Chosen because it is a few lines
## of integer arithmetic with no engine dependency and no floating point — the
## digest must be bit-identical across runs and platforms or it is worse than
## nothing. The mask keeps every intermediate inside 2^53, so the multiply cannot
## overflow before it is folded. These three numbers are the algorithm's
## definition, like the shifts in rng.gd's mulberry32, not tuning values.
const DIGEST_SEED := 2166136261
const DIGEST_PRIME := 16777619
const DIGEST_MASK := 0xFFFFFFFF

## What a tick with no cues renders as. A literal empty string would make an
## empty list and a missing field indistinguishable in the summary.
const NO_CUES := "-"


## One cue: what happened, how loud, when, and — for a spatial cue — where.
class Cue:
	extends RefCounted
	var id: String = ""
	var volume: float = 0.0
	## Whether the position fields mean anything. The document splits the cues:
	## `impact`, `gate_passed` and `rebound` are heard from a place; the
	## race-moment cues are not. Recorded rather than derived from the id so the
	## view has no table of its own to drift.
	var spatial: bool = false
	var x: float = 0.0
	var z: float = 0.0
	## The tick this was emitted on — the tick COUNT at emission, so the first
	## tick of a run is 0.
	var tick: int = 0

	## The record as stable text. FIXED FORMAT, and it matters: this string is
	## compared byte for byte by the determinism suites and is what the digest is
	## taken over. %.9f matches the precision sim.stats_line() already carries for
	## every other float, so a divergence too small to see here is too small to
	## see anywhere in the summary.
	func text() -> String:
		if spatial:
			return "%s@%d:%.9f(%.9f,%.9f)" % [id, tick, volume, x, z]
		return "%s@%d:%.9f" % [id, tick, volume]


## The tick being recorded, set by begin_tick(). Stamped onto every record.
var current_tick: int = 0

## This tick's cues, in EMISSION ORDER. The order is the contract: the stages run
## in the document's order and append as they go, so the list reads as the tick's
## own story and renders as stable text.
var cues: Array = []

## How many cues have been emitted since construction, and the digest over all of
## them. Both are simulation state and both are in the summary.
var emitted: int = 0
var digest: int = DIGEST_SEED

## The impact rate limit's window, in ticks — `impactRateLimit` x 60, injected by
## the owner from the tuning table like race_state's countdown length (zero = not
## yet supplied, which is no limit at all rather than a guessed default).
var impact_window_ticks: int = 0

## Ticks remaining before another impact may sound. Counted down at tick start,
## never against a clock, and carried in the summary so the rate limit is as
## reproducible as everything else it gates.
var impact_cooldown_ticks: int = 0


## Start a tick: the list is emptied and the rate-limit window ages by one.
## Called first in Sim.step(), before any stage can append.
func begin_tick(tick_index: int) -> void:
	current_tick = tick_index
	cues.clear()
	if impact_cooldown_ticks > 0:
		impact_cooldown_ticks -= 1


## A non-spatial cue — the race's moments, which are heard from nowhere.
func emit(id: String, volume: float) -> void:
	_append(_record(id, volume, false, 0.0, 0.0))


## A spatial cue, at a world position on the ground plane.
func emit_at(id: String, volume: float, x: float, z: float) -> void:
	_append(_record(id, volume, true, x, z))


## The impact cue, under its rate limit. Returns whether it sounded.
##
## The limit is here and not at the collision, because the collision is not what
## is being limited: the kart pinned between two props really does collide on
## every tick, and the suite asserts that it does. What must not happen is a cue
## on every one of those ticks.
func emit_impact(volume: float, x: float, z: float) -> bool:
	if impact_cooldown_ticks > 0:
		return false
	emit_at(IMPACT, volume, x, z)
	impact_cooldown_ticks = impact_window_ticks
	return true


## This tick's cues as stable text, in emission order.
func line() -> String:
	if cues.is_empty():
		return NO_CUES
	var parts := PackedStringArray()
	for cue: Cue in cues:
		parts.append(cue.text())
	return "|".join(parts)


## This tick's contribution to sim.stats_line(): the cues themselves, the running
## count, the running digest, and the rate-limit window's remaining ticks.
func summary() -> String:
	return "cues=%s n=%d d=%d iw=%d" % [line(), emitted, digest, impact_cooldown_ticks]


func _record(id: String, volume: float, spatial: bool, x: float, z: float) -> Cue:
	var cue := Cue.new()
	cue.id = id
	cue.volume = volume
	cue.spatial = spatial
	cue.x = x
	cue.z = z
	cue.tick = current_tick
	return cue


func _append(cue: Cue) -> void:
	cues.append(cue)
	emitted += 1
	_mix(cue.text())


func _mix(text: String) -> void:
	for i in range(text.length()):
		digest = (digest ^ text.unicode_at(i)) & DIGEST_MASK
		digest = (digest * DIGEST_PRIME) & DIGEST_MASK
