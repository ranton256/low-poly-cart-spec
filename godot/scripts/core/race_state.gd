# The race state machine — LOADING, STARTING, RACING — as simulation state.
#
# The design document specifies the states, the countdown sequence and the
# 4.0 s figure; godot/race-state's delta specs record the port decisions this
# file embodies:
#
#   1. It lives in scripts/core/ with no engine types, because the acceptance
#      tolerance (± 0.1 s) is stated in SIMULATION time — ± 6 ticks — and a
#      wall-clock or frame-driven countdown reintroduces the frame-rate
#      dependence the port exists to remove (design D1).
#   2. The countdown is a DERIVED index over the tick count, never stored
#      text: two pieces of state that can disagree become one that cannot
#      (design D2). READY is index 0 at tick 0; GO! is the RACING transition
#      itself, on the 240th advance — "4.0 s, not 5.0 s", as the document
#      insists twice.
#   3. A failed bootstrap is a TERMINAL LOADING condition, not a fourth
#      state — the document enumerates exactly three and CONSTRAINTS §15 Not
#      applicable bans another (design D3).
#
# Transitions are taken once each and there is no path out of RACING. The
# owner (Sim) advances this machine as the first stage of every tick, in every
# state — ambiguity A4's resolution.
extends RefCounted

# The three states, in transition order. Plain constants rather than an enum:
# every consumer reads them through preload, and the summary serializes the
# integer.
const LOADING := 0
const STARTING := 1
const RACING := 2

## The countdown labels between READY and GO! — index 0 is READY, then 3, 2, 1.
const COUNTDOWN_STEPS := 4

## Mirrors Sim.TICKS_PER_SECOND (a preload here would be circular): the
## Reference Tick section fixes 60 ticks per second, pinned in project.godot.
const TICKS_PER_SECOND := 60

var state: int = LOADING
var ticks_in_state: int = 0

## Ticks per countdown interval — `countdownStep` × 60, injected by the owner
## from the tuning table like every other constant (zero = not yet supplied).
var countdown_step_ticks: int = 0

## Set by fail_load(); non-empty means LOADING is terminal. The view displays
## it; the developer log has already received it.
var error_message: String = ""


## One tick, called first in Sim.step() — every tick, in every state.
func advance() -> void:
	if state == STARTING:
		ticks_in_state += 1
		if ticks_in_state >= countdown_step_ticks * COUNTDOWN_STEPS:
			# The GO! tick: control this very tick, racing clock at zero.
			state = RACING
			ticks_in_state = 0
		return
	if state == RACING:
		ticks_in_state += 1
	# LOADING accumulates nothing: there is no countdown to measure and a
	# terminal failure should not look like progress.


## Bootstrap completed: LOADING → STARTING, taken once. A repeat call or a
## failed load is a no-op — the transition either already happened or must
## never happen.
func mark_world_ready() -> void:
	if state != LOADING or error_message != "":
		return
	state = STARTING
	ticks_in_state = 0


## Bootstrap failed: LOADING becomes terminal, with a message for the view.
## The caller logs the underlying error; this records what the player sees.
func fail_load(message: String) -> void:
	if state != LOADING:
		return
	error_message = message


## Both transitions, immediately. A seam for suites and staging tools that
## study the kart pipeline in isolation — the shipped driver never calls it.
func start_racing_immediately() -> void:
	mark_world_ready()
	if state == STARTING:
		state = RACING
		ticks_in_state = 0


func is_racing() -> bool:
	return state == RACING


## The countdown display index: 0 READY, 1 "3", 2 "2", 3 "1" — or -1 when no
## countdown is running. GO! is not an index: it is the RACING state itself,
## and the overlay derives its linger from ticks_in_state there.
func countdown_index() -> int:
	if state != STARTING or countdown_step_ticks <= 0:
		return -1
	return mini(ticks_in_state / countdown_step_ticks, COUNTDOWN_STEPS - 1)


## Seconds since RACING began — the elapsed race clock, zeroed on the GO! tick.
func race_seconds() -> float:
	if state != RACING:
		return 0.0
	return float(ticks_in_state) / float(TICKS_PER_SECOND)
