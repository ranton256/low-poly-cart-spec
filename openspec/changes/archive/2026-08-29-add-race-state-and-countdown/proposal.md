# Proposal: add-race-state-and-countdown

## Why

The game currently boots straight into a drivable kart. The design document
says it boots into a **countdown** — READY, 3, 2, 1, GO! — and hands the
player control on the GO! frame, 4.0 s later, with no interaction and no
configuration. Until there is a moment control is released, "the elapsed
timer" has no zero, so every other M4 timing figure waits on this change.

**Design-document features implemented:** *Race Start Sequence and Game State
Machine* entire; the remaining scenarios of *Session Bootstrap and Asset
Normalisation* (the loading state, the handoff, and the failure path); and
*Frame Loop and Render Pipeline*'s "Suspending the simulation outside the
racing state". The coverage gate's M4-deferred count drops accordingly — read
its output rather than a number written here.

**Acceptance-checklist items advanced:** item **1** (boot to countdown, control
at 4.0 s ± 0.1 s). Item 10 (the lap gate) is the milestone's second change,
`add-lap-gate-and-timing`, which needs this one's RACING state and timer zero.

**The 4.0 s figure is the trap, and the document says so twice.** READY appears
immediately and the four `countdownStep` intervals reach GO! at 4.0 s, not
5.0 — the document states the total "is therefore **4.0 s**, not 5.0 s" in as
many words, which is the shape of a mistake someone has already made. The
tolerance is ± 0.1 s: three ticks either side of tick 240.

## What Changes

- **`scripts/core/race_state.gd`** — the three states (LOADING, STARTING,
  RACING) and the countdown as a fixed-step recurrence over the simulation
  clock. No engine types; transitions taken once each; no path out of RACING.
- **`Sim.step()`** runs every tick in every state (ambiguity A4's resolution,
  now load-bearing): the race state advances first, and the kart pipeline —
  accelerate through collision — is gated on RACING. Held inputs stay tracked
  while frozen, so a key held through GO! acts on the first racing tick.
- **The state and countdown tick join the determinism summary**, so the
  replay/determinism suites (acceptance 14a) cover the countdown for free.
- **View:** a countdown overlay that derives READY/3/2/1/GO! and its colours
  from the simulation snapshot and the data layer, holding `goLinger` past the
  handover; the pre-race inspection camera at (0, 5, −10); the loading
  indicator and its error replacement.
- **Bootstrap failure:** a model that fails to load leaves the game in LOADING
  with a visible error and a logged cause — never a countdown into a broken
  world.
- Tests: a `race_state_test.gd` suite; extensions to the driver, input, and
  determinism suites; `# @covers` claims for every scenario above.

## What is deliberately excluded

- The lap gate, the 5 s minimum, best-time tracking and the TIME/best flashes —
  `add-lap-gate-and-timing`, this milestone's second change.
- HUD instruments (speedometer, timer display, minimap) — M5. The countdown
  overlay is part of the start sequence, not an instrument.
- Any fourth state, pause, or path out of RACING — CONSTRAINTS §15 Not
  applicable.
