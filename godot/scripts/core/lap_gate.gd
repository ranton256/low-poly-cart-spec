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
#
# Observes only. Nothing in this file writes a position, a velocity, or a yaw.
extends RefCounted

## Mirrors Sim.TICKS_PER_SECOND (a preload here would be circular): the
## Reference Tick section fixes 60 ticks per second, pinned in project.godot.
const TICKS_PER_SECOND := 60

# --- injected ---
var tuning: RefCounted = null

# --- state, all of it in the determinism summary ---
var clock_ticks: int = 0
var hold_ticks: int = 0
var banked_seconds: float = -1.0
var best_seconds: float = -1.0
var best_flash_ticks: int = 0

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

	if clock_seconds() < tuning.min_lap_time:
		return  # too soon — no farming the line at the start
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
	if best_seconds < 0.0 or banked_seconds < best_seconds:
		best_seconds = banked_seconds
		best_flash_ticks = int(roundf(tuning.best_flash_duration * TICKS_PER_SECOND))
	hold_ticks = int(roundf(tuning.lap_restart_delay * TICKS_PER_SECOND))


func clock_seconds() -> float:
	return float(clock_ticks) / float(TICKS_PER_SECOND)


## What the TIME readout shows: the running clock, or the banked time while
## the hold window has the player reading what they scored.
func display_seconds() -> float:
	return banked_seconds if hold_ticks > 0 else clock_seconds()
