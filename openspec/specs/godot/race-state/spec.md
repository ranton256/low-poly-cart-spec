# godot/race-state Specification

## Purpose
TBD - created by archiving change add-race-state-and-countdown. Update Purpose after archive.

## Requirements

### Requirement: The race state is simulation state, advanced by the tick

The state machine (LOADING, STARTING, RACING) SHALL live in the simulation
core with no engine types, advanced as the first stage of `Sim.step()` — which
runs every tick in every state (ambiguity A4's resolution). The kart pipeline
stages SHALL be gated on RACING; held input SHALL be tracked in every state.

#### Scenario: Stepping while STARTING freezes the kart, not the clock

- **WHEN** the simulation is stepped in STARTING with drive and steer held
- **THEN** the kart's velocity, position, and yaw are unchanged
- **AND** the tick count and countdown advance
- **AND** the held input is visible to the first RACING tick

#### Scenario: The machine is constructible and steppable headless

- **WHEN** the race state is constructed and stepped from a test with no scene
  loaded
- **THEN** it reaches RACING through the specified transitions, taken once each

### Requirement: The countdown is derived from the tick count

The countdown SHALL carry no clock of its own: the core stores ticks since
STARTING began, `countdownStep` is 60 ticks, and the overlay index (READY, 3,
2, 1, GO!) is derived by integer division. The STARTING → RACING transition
and the timer zero SHALL occur on the tick the index reaches GO! — tick 240,
where acceptance item 1's ± 0.1 s is ± 6 ticks.

#### Scenario: GO! lands on tick 240 exactly

- **WHEN** STARTING begins at tick T and the simulation is stepped
- **THEN** the derived index shows READY at T, then 3, 2, 1 at 60-tick
  boundaries
- **AND** the state becomes RACING and the elapsed timer zeroes at exactly
  T + 240
- **AND** no wall-clock or frame time participates

### Requirement: The race state joins the reproducibility summary

The state and its tick counter SHALL be part of the reported state summary, so
the determinism and replay harnesses (acceptance 14a) cover the countdown with
no new machinery.

#### Scenario: Two runs agree through the countdown

- **WHEN** two separately constructed simulations run the same inputs from boot
- **THEN** their summaries are identical at every tick, including state and
  countdown fields, with no tolerance

### Requirement: A failed bootstrap is a terminal LOADING condition, not a fourth state

A supplied model that cannot be retrieved or parsed SHALL leave the state
machine in LOADING with an error flag and message exposed to the view, and the
underlying error written to the developer log. No countdown begins. The state
enumeration stays at three.

#### Scenario: A missing model halts in LOADING visibly

- **WHEN** bootstrap runs with one model unloadable
- **THEN** the state remains LOADING with its error set and logged
- **AND** stepping the simulation never leaves LOADING

### Requirement: The countdown overlay is a pure consumer

The view SHALL derive the overlay's glyph and colour from the simulation
snapshot and the data layer — the GO! green and `goLinger` come from data,
never as script literals (V23). The overlay's post-GO! persistence SHALL be
computed from ticks-since-RACING; the core carries no linger timer. Before
RACING, the camera SHALL hold the inspection pose from the design document,
with the chase camera engaging on the first RACING frame.

#### Scenario: The overlay at a given tick is a function of the snapshot

- **WHEN** the overlay is bound to a simulation at any tick during STARTING or
  within `goLinger` of the RACING transition
- **THEN** its glyph and colour are computed from the snapshot and data alone,
  with no state of its own beyond the binding
