# godot/simulation-core — delta for retune-handling-and-line-clearance

## MODIFIED Requirements

### Requirement: Steering depends on motion

Heading SHALL change only while the kart is moving faster than the steering
threshold, and the direction of that change SHALL depend on the sign of
travel. The per-tick change SHALL be `turnRate × ease`, where `ease` climbs
linearly from 0 to 1 over `steerEaseSeconds` of continuously holding one
direction, holds at 1 thereafter, and resets to 0 on the tick the direction
is released or reversed. The ease state SHALL appear in the reproducibility
summary.

#### Scenario: A stationary kart cannot be turned

- **WHEN** a steering input is held and the speed is at or below the threshold
- **THEN** the heading does not change
- **AND** the kart cannot be spun on the spot

#### Scenario: Steering sense inverts in reverse

- **WHEN** the same steering input is held while travelling backwards
- **THEN** the heading turns in the opposite direction to the equivalent forward case

#### Scenario: Turn rate does not vary with speed

- **WHEN** the kart has held one steering direction for at least
  `steerEaseSeconds` at any speed above the threshold
- **THEN** the heading changes by exactly `turnRate` per tick regardless of
  how fast it is travelling

#### Scenario: The onset is a ramp, not a step

- **WHEN** a steering direction is pressed, released, and pressed again
- **THEN** each hold's per-tick change climbs linearly from zero, reaching
  `turnRate` after `steerEaseSeconds`
- **AND** reversing the held direction resets the ramp the same way release
  does
