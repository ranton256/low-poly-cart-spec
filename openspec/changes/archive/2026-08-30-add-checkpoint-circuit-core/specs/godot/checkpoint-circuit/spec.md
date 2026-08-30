# godot/checkpoint-circuit — delta for add-checkpoint-circuit-core

## ADDED Requirements

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
