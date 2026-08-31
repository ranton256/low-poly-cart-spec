# godot/checkpoint-circuit Specification

## Purpose
TBD - created by archiving change add-checkpoint-circuit-core. Update Purpose after archive.

## Requirements

### Requirement: The circuit is a pure core module advanced at stage 8

`scripts/core/circuit.gd` SHALL hold the ordered gates and the progress
cursor with no engine types, advanced from the tick's stage 8 beside the lap
gate, observing only — reading position and the stage-5 displacement
observable, never writing simulation state.

#### Scenario: A push-out cannot pass a gate

- **WHEN** a collision push-out carries the kart through a gate's slab on a
  tick whose stage-5 gate-forward displacement is at or under the threshold
- **THEN** the cursor does not advance

#### Scenario: The gate test works at every yaw

- **WHEN** the same crossing is staged against gates yawed at 0, ±45, 90,
  and arbitrary angles
- **THEN** the pass verdict is identical in every gate frame

### Requirement: The cursor forgives everything except the gate it names

Only the gate the cursor names SHALL advance it; passes of any other gate —
already passed, not yet due, or the named gate backwards — SHALL change
nothing. Banking a lap SHALL return the cursor to the first gate, and Reset
Kart SHALL NOT touch it.

#### Scenario: An out-of-order pass is ignored

- **WHEN** the kart passes gate 3 while the cursor names gate 1
- **THEN** the cursor still names gate 1 and no state changed

#### Scenario: Reset Kart mid-lap keeps progress

- **WHEN** the kart resets with the cursor at gate 4 of 6
- **THEN** the cursor still names gate 4, and the band still refuses to bank

### Requirement: Bests and medals are per-circuit core state

The lap module's session best SHALL be keyed by the loaded circuit's name
(the no-circuit interim keys as "procedural"); medal determination against
the circuit's targets SHALL happen in the core at bank time. Cursor, circuit
name, and the banked medal SHALL join the determinism summary.

#### Scenario: Switching circuits switches the best

- **WHEN** a lap banks on circuit A, circuit B loads, and a slower lap banks
- **THEN** B's best is the slower lap and A's best is unchanged

#### Scenario: A lap exactly on a target earns its medal

- **WHEN** a lap banks at exactly the silver time
- **THEN** the medal is silver — "at or under", not "under"

### Requirement: The shipped circuit is the boot world

Boot SHALL build the world by loading the committed shipped circuit file
through the layout path; failure is the existing terminal LOADING verdict.
A layout without a circuit SHALL be refused on load with a named error. The
shipped file SHALL be validated by a test: every gate inside the boundary,
no curated prop overlapping a gate mouth, targets ordered.

#### Scenario: Boot is a circuit or a named failure

- **WHEN** the game boots with the shipped file present, and again with it
  broken
- **THEN** the first run reaches the countdown on the authored world and the
  second is a terminal LOADING state naming the failure

#### Scenario: A gateless file no longer loads

- **WHEN** a version-1 layout is loaded through the real binding
- **THEN** the world is unchanged and the named refusal is logged

### Requirement: Restart Circuit rebuilds the attempt, not the world's identity

The action bound to `G` SHALL rebuild the props from the loaded circuit,
return the kart to the start pose, reset the cursor to gate 1, restart the
lap clock from zero, keep the per-circuit best, and never leave RACING.

#### Scenario: Restart is instant and total for the attempt

- **WHEN** the player restarts mid-lap at speed with three gates passed
- **THEN** the next tick's world is the authored arrangement with the kart
  at the start, cursor at 1, clock at 0.00 — and the best is untouched

### Requirement: Gates are visible state machines and pure consumers

Each gate SHALL be drawn as generated geometry (pylons of `gatePylonHeight`,
ground stripe, overhead chevron, billboard numeral), non-colliding, coloured
by cursor state from the data layer, with the next gate's pulse animated on
the simulation clock. The gate's **pass direction SHALL be readable from
either side**: the chevron is an arrowhead pointing along gate-forward and
the stripe is an arrow in the same direction, so a gate approached from
behind reads as the back of a gate. The HUD SHALL show `GATE n/N` and an
edge chevron toward an off-screen next gate; the minimap SHALL mark every
gate with the next emphasised, under the standing mask guarantee.

#### Scenario: The view tells the cursor's truth at any tick

- **WHEN** the gate view is bound to a simulation snapshot at any tick
- **THEN** passed, next, and idle gates carry exactly their state colours,
  the counter reads the cursor, and no view element computed any of it

#### Scenario: The pulse is deterministic

- **WHEN** the same tick is rendered twice
- **THEN** the next gate's pulse phase is identical — sim clock, not wall
  clock

#### Scenario: The arrow points the way through

- **WHEN** a gate is built at any yaw
- **THEN** its chevron's and stripe's forward axes equal the gate's forward
  axis — never the reverse, never a fixed world direction

### Requirement: The banked medal is shown for the hold window

When a lap banks with a medal, the held `TIME` readout SHALL be joined by
the medal's name in its colour for exactly the hold window, from the core's
bank-time verdict.

#### Scenario: A medal lap shows its medal, a medal-less lap shows nothing

- **WHEN** one lap banks under gold and another over bronze
- **THEN** the first hold shows GOLD in `medalGoldColour` and the second
  hold shows only the time

### Requirement: The harness drive is baked from the course

The canonical scripted drive SHALL be produced by a deterministic waypoint
pilot in the authoring tool and baked into the phase-table form the suites,
captures, smoke seam, and refresh probe consume; the baked table SHALL
thread every gate of the shipped circuit and bank, and re-authoring the
course regenerates it rather than editing it by hand.

#### Scenario: Moving a gate cannot silently orphan the drive

- **WHEN** the shipped circuit's gates change and the drive is re-baked
- **THEN** the content test re-pins the pass ticks and the bank tick, and a
  drive that no longer banks fails the suite rather than the player
