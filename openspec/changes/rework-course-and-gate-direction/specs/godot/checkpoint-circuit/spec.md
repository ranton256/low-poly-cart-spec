# godot/checkpoint-circuit — delta for rework-course-and-gate-direction

## MODIFIED Requirements

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
