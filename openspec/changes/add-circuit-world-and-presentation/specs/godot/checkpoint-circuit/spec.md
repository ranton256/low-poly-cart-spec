# godot/checkpoint-circuit — delta for add-circuit-world-and-presentation

## ADDED Requirements

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
the simulation clock. The HUD SHALL show `GATE n/N` and an edge chevron
toward an off-screen next gate; the minimap SHALL mark every gate with the
next emphasised, under the standing mask guarantee.

#### Scenario: The view tells the cursor's truth at any tick

- **WHEN** the gate view is bound to a simulation snapshot at any tick
- **THEN** passed, next, and idle gates carry exactly their state colours,
  the counter reads the cursor, and no view element computed any of it

#### Scenario: The pulse is deterministic

- **WHEN** the same tick is rendered twice
- **THEN** the next gate's pulse phase is identical — sim clock, not wall
  clock

### Requirement: The banked medal is shown for the hold window

When a lap banks with a medal, the held `TIME` readout SHALL be joined by
the medal's name in its colour for exactly the hold window, from the core's
bank-time verdict.

#### Scenario: A medal lap shows its medal, a medal-less lap shows nothing

- **WHEN** one lap banks under gold and another over bronze
- **THEN** the first hold shows GOLD in `medalGoldColour` and the second
  hold shows only the time
