# The lap gate, the lap clock, and the session best — the design document's
# Lap Detection and Best-Time Tracking feature, as the tick's eighth stage.
#
# The port decisions this file embodies (godot/lap-timing):
#
#   1. The crossing test reads STAGE 5'S OWN +Z DISPLACEMENT, handed in by the
#      caller — never the scalar velocity's sign (forward-heading-south must
#      not bank) and never net position change (the boundary clamp and the
#      collision push-out both move the kart without the player driving; the
#      document's pinned-kart paragraph does that arithmetic). Design D1.
#   2. The lap clock is ITS OWN counter. It restarts on every bank and stops
#      for the hold window, so deriving it from time-since-RACING would need a
#      ledger; a counter that is the thing itself cannot disagree with it.
#      The hold is dead time belonging to no lap: the counter simply does not
#      run. Design D2.
#   3. Best state is session state, here in the core: −1.0 until a first lap,
#      surviving world regeneration because regeneration never touches the
#      simulation, never written to storage. Design D3.
#   4. Best state is KEYED BY CIRCUIT (Checkpoint Circuit, "Best times belong
#      to their circuit"). `best_seconds` remains the best of the circuit being
#      played — every reader keeps working — and `bests` holds the rest.
#      "procedural" is the key while no circuit is loaded.
#
# THE THREADED-LAP CONDITION. With a circuit loaded the band banks only when the
# progress cursor is past the final gate, and there is NO minimum lap time: the
# ordered gates are the farming defence. With no circuit loaded — the interim
# that ends when add-circuit-world-and-presentation ships the boot circuit —
# port_decisions' minLapTime remains the defence, unchanged.
#
# Observes only. Nothing in this file writes a position, a velocity, or a yaw;
# the one thing it writes outside itself is the cursor's rewind on a bank, which
# the document states ("banking a lap returns the cursor to 1").
extends RefCounted

const Circuit := preload("res://scripts/core/circuit.gd")

## Mirrors Sim.TICKS_PER_SECOND (a preload here would be circular): the
## Reference Tick section fixes 60 ticks per second, pinned in project.godot.
const TICKS_PER_SECOND := 60

# --- injected ---
var tuning: RefCounted = null

## The loaded circuit, or null in the no-circuit interim. Read for the threaded
## condition, the best key, and the medal targets; written only by rewind().
var circuit: RefCounted = null

# --- state, all of it in the determinism summary ---
var clock_ticks: int = 0
var hold_ticks: int = 0
var banked_seconds: float = -1.0
var best_seconds: float = -1.0
var best_flash_ticks: int = 0

## The best of every circuit played this session, keyed by circuit name.
## `best_seconds` is this dictionary's entry for the circuit being played, kept
## as a field so every existing reader and the flash logic are untouched.
var bests: Dictionary = {}

## Which key `best_seconds` currently holds.
var best_key: String = Circuit.NO_CIRCUIT_KEY

## The medal the last banked lap earned — "gold", "silver", "bronze", or "" for
## none. Determined here, at bank time, from the circuit's own targets; showing
## it is the presentation change's job.
var banked_medal: String = ""

## True only on the tick a lap banks — the view's edge, if it ever wants one.
var banked_this_tick := false


## One advance, from the tick's stage 8, RACING only. `step5_dz` is the +Z
## displacement stage 5 actually applied this tick.
func advance(pos_x: float, pos_z: float, step5_dz: float) -> void:
	banked_this_tick = false
	if best_flash_ticks > 0:
		best_flash_ticks -= 1

	# The hold: clock stopped, detection suppressed, display on the banked
	# time. When it expires the clock restarts from zero, re-armed — the next
	# lap's clock begins here, lapRestartDelay after the crossing.
	if hold_ticks > 0:
		hold_ticks -= 1
		if hold_ticks == 0:
			clock_ticks = 0
		return

	clock_ticks += 1

	if circuit != null and circuit.has_gates():
		# The threaded condition REPLACES the minimum entirely — the document
		# retires minLapTime, it does not keep it as a second hurdle.
		if not circuit.is_threaded():
			return  # the course has not been threaded; the line alone is never enough
	elif clock_seconds() < tuning.min_lap_time:
		return  # the no-circuit interim: too soon — no farming the line at the start
	if pos_z <= tuning.lap_gate_z_min or pos_z >= tuning.lap_gate_z_max:
		return  # not in the band
	if absf(pos_x) >= tuning.lap_gate_abs_x_limit:
		return  # around the band, not through it
	if step5_dz <= tuning.lap_crossing_threshold:
		return  # not northbound under the kart's own power
	_bank()


func _bank() -> void:
	banked_seconds = clock_seconds()
	banked_this_tick = true
	banked_medal = circuit.medal_for(banked_seconds) if circuit != null else ""
	if best_seconds < 0.0 or banked_seconds < best_seconds:
		best_seconds = banked_seconds
		best_flash_ticks = int(roundf(tuning.best_flash_duration * TICKS_PER_SECOND))
	bests[best_key] = best_seconds
	hold_ticks = int(roundf(tuning.lap_restart_delay * TICKS_PER_SECOND))
	# The document: banking a lap returns the cursor to 1.
	if circuit != null:
		circuit.rewind()


## Point the best readout at another circuit, stashing the outgoing one. Called
## when a circuit is armed — a switch mid-session must not carry one circuit's
## best onto another's board, and returning shows the first circuit's own best
## unchanged.
func select_circuit(key: String) -> void:
	if key == best_key:
		return
	bests[best_key] = best_seconds
	best_key = key
	best_seconds = float(bests.get(key, -1.0))
	best_flash_ticks = 0


func clock_seconds() -> float:
	return float(clock_ticks) / float(TICKS_PER_SECOND)


## What the TIME readout shows: the running clock, or the banked time while
## the hold window has the player reading what they scored.
func display_seconds() -> float:
	return banked_seconds if hold_ticks > 0 else clock_seconds()
