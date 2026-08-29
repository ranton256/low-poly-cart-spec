# Design: add-race-state-and-countdown

## D1 — The race state lives inside the simulation core, stepped by `Sim.step()`

**Decision.** `race_state.gd` is a pure module owned and stepped by the
simulation: state, ticks-in-state, and the derived countdown index are
simulation state, serialized into the summary.

**Alternative: a view-side state machine** (the reference build's shape —
overlay timers driving game state). Rejected: the GDD's tolerance is stated in
seconds of *simulation* time (± 0.1 s = ± 6 ticks); a wall-clock or
frame-driven countdown reintroduces the frame-rate dependence the port exists
to remove, and puts a state transition in the view, which CONSTRAINTS §4
Architectural boundaries forbids.

**Alternative: gate `Sim.step()` itself on RACING** (don't step outside the
race). Rejected: ambiguity A4 already resolved the other way — the countdown
must advance on the simulation clock, so the sim must step while the kart
pipeline is gated. Gating the whole step would need a second clock for the
countdown, which is the two-clock bug in different clothes.

## D2 — The countdown is a derived value, not stored text

**Decision.** The core stores ticks since STARTING began; the countdown index
(READY, 3, 2, 1, GO!) is derived by integer division on `countdownStep`
ticks. The view maps index → glyph and colour, reading both from the data
layer (V23 keeps `#00FF00` out of scripts).

**Alternative: store the current label and a step timer.** Rejected: two
pieces of state that can disagree, and text in the core couples the
simulation to presentation. A derived index cannot drift from the clock that
defines the tolerance.

## D3 — Bootstrap failure is a terminal LOADING sub-state, not a fourth state

**Decision.** A failed model load sets an error flag and message on the
existing LOADING state. The view swaps the loading indicator for the error;
the state machine never advances.

**Alternative: a FAILED state.** Rejected: the GDD enumerates exactly three
states and CONSTRAINTS §15 Not applicable bans a fourth. The scenario's own
wording — "remains in the LOADING state" — says the document already chose.

## D4 — GO! release semantics: state first, overlay linger in the view

**Decision.** The transition STARTING → RACING happens on the tick the
countdown index reaches GO!; the elapsed timer zeroes on that tick. The
overlay's `goLinger` persistence is view-only — it reads "ticks since RACING
began" from the snapshot and hides itself; the core carries no linger timer.

**Why it matters:** "the player has control the instant they read GO!" is the
scenario's point, and the ± 0.1 s acceptance tolerance measures control, not
the overlay. Keeping the linger out of the core keeps the state machine's
transitions at exactly two.

## Risks

- **The inspection camera** (0, 5, −10) predates the chase camera's engage;
  the cut to chase on RACING must not jolt — the chase camera's own settle
  behaviour (M2) covers this, but the first racing frames are worth a capture.
- **Input focus loss during STARTING** already clears held input (M2); the
  freeze scenario's "inputs are still tracked" must not regress that. The
  input suite covers both directions.
