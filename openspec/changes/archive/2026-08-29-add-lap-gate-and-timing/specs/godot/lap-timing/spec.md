# godot/lap-timing — delta for add-lap-gate-and-timing

The design document specifies the gate's rules, geometry, and timings. These
requirements are the port's decisions: which observable carries the crossing
test, where the clocks live, and how the readouts derive from them.

## ADDED Requirements

### Requirement: The crossing test reads stage 5's own displacement

The simulation SHALL record the +Z displacement stage 5 actually applied
(`velocity × forward_z()`, before any boundary or collision adjustment) as an
observable, and the lap gate SHALL test that observable against
`lapCrossingThreshold` — never the scalar velocity's sign, and never net
position change across the tick.

#### Scenario: A push-out cannot bank a lap

- **WHEN** a kart sits motionless in the band while a collision push-out moves
  it +Z by more than the threshold each tick
- **THEN** no lap is recorded, because stage 5 displaced it nothing

#### Scenario: Driving forward heading south is the wrong way

- **WHEN** the kart crosses the band under power with its forward axis
  pointing −Z
- **THEN** stage 5's +Z displacement is negative and no lap is recorded

### Requirement: The lap clock is its own counter, stopped by the hold

The lap module SHALL own its clock as a tick counter advanced by stage 8:
running while RACING, stopped for exactly `lapRestartDelay` after a bank
(during which the banked time is the displayed time and detection stays
suppressed), then restarted from zero and re-armed. The race state's own
clock is untouched by laps.

#### Scenario: The hold window is dead time belonging to no lap

- **WHEN** a lap banks and `lapRestartDelay` passes
- **THEN** the next lap's clock begins at the end of the hold, from 0.00
- **AND** the kart's position, heading, and velocity were untouched throughout

### Requirement: Best-time state is session state in the core

The best time SHALL live in the lap module: −1.0 until a first lap, updated
only by a strictly faster lap, arming a `bestFlashDuration` countdown when it
updates. It survives world regeneration and is never written to storage.

#### Scenario: The first lap sets the best and flashes

- **WHEN** the first lap of a session banks
- **THEN** the best becomes that time and the flash countdown arms

#### Scenario: A slower lap changes nothing but the clock

- **WHEN** a lap banks at or above the current best
- **THEN** the best and its readout are unchanged, no flash arms, and the
  clock still restarts

### Requirement: The readouts are pure consumers of the lap counters

The overlay SHALL derive `TIME` (two decimal places; the banked time during
the hold) and `BEST` (`--.--` until a first lap; yellow base, green for the
flash countdown) from the lap module's counters and the data layer each
frame, holding no timing state of its own. The lap clock, banked time, and
best SHALL appear in the determinism summary.

#### Scenario: The readout at a given tick is a function of the counters

- **WHEN** the overlay is bound to a simulation at any tick
- **THEN** its text and colours are computed from the snapshot and data alone
