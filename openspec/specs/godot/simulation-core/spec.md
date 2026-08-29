# godot/simulation-core Specification

## Purpose

Defines how this port's simulation object advances the kart — the order of work in
a tick, what a caller may set and read, and what must remain true of it — so that
the design document's motion behaviour is reproducible and testable with nothing on
screen.

## Requirements

### Requirement: A tick is a single ordered advance

The simulation SHALL expose one operation that advances the world by exactly one
fixed step, and that operation SHALL perform the design document's tick stages in
its stated order. The order is the contract: several of the document's own
statements are only true because of it.

#### Scenario: The stages run in the specified order

- **WHEN** one tick is advanced
- **THEN** velocity is settled before any position work begins
- **AND** the speed clamp is applied before friction, so the achievable steady speed
  is below the clamp rather than equal to it
- **AND** the steering test reads the velocity as it stands after clamping and
  before friction
- **AND** the boundary is enforced after the position has been integrated

#### Scenario: Stages not yet implemented keep their place in the order

- **WHEN** a tick runs before collision response and lap detection exist
- **THEN** their stages are present in the sequence and do nothing
- **AND** implementing them later changes what a tick does, not the order in which
  it does it

#### Scenario: A tick never reads wall-clock or frame time

- **WHEN** the simulation advances
- **THEN** it derives every duration from the number of ticks elapsed
- **AND** it consults no host clock, no frame delta, and no engine state

### Requirement: The caller supplies input as held state

Input SHALL reach the simulation as plain held flags set by the caller before a
tick, never read by the simulation from an input device.

#### Scenario: Held input persists across ticks until cleared

- **WHEN** an input is set held and several ticks are advanced
- **THEN** every one of those ticks observes it as held
- **AND** it stops being observed only once the caller clears it

#### Scenario: Opposing inputs cancel

- **WHEN** both the forward and reverse inputs are held on the same tick
- **THEN** their contributions cancel and the velocity changes only by friction

#### Scenario: Combined inputs both apply

- **WHEN** an acceleration input and a steering input are held on the same tick
- **THEN** both take effect within that tick

#### Scenario: All input can be released at once

- **WHEN** the caller clears all held input
- **THEN** the following tick observes nothing held
- **AND** the kart continues under friction rather than stopping abruptly

### Requirement: Speed builds and decays to the specified curve

Acceleration, the speed clamp and friction SHALL combine to produce the design
document's stated timings, and those timings SHALL be met within its tolerances
rather than approximated.

#### Scenario: Spin-up reaches nine tenths of steady state on time

- **WHEN** the forward input is held from rest
- **THEN** the speedometer reading first reaches the design document's stated
  nine-tenths value at its stated time, within the stated tolerance

#### Scenario: The dial settles at its achievable maximum and stays

- **WHEN** the forward input continues to be held
- **THEN** the reading first reaches the design document's stated steady value at
  its stated time, within tolerance
- **AND** it does not subsequently exceed that value
- **AND** the value is below the dial's nominal maximum, because friction is applied
  after the clamp

#### Scenario: Coasting falls below the steering threshold on time

- **WHEN** all drive input is released from steady-state speed
- **THEN** the speed falls below the steering threshold at the design document's
  stated time, within tolerance
- **AND** it approaches zero asymptotically rather than snapping to a halt

#### Scenario: Reverse is limited more tightly than forward

- **WHEN** the reverse input is held from rest
- **THEN** the achievable reverse speed settles at the design document's stated
  fraction of the forward steady speed

### Requirement: Steering depends on motion

Heading SHALL change only while the kart is moving faster than the steering
threshold, and the direction of that change SHALL depend on the sign of travel.

#### Scenario: A stationary kart cannot be turned

- **WHEN** a steering input is held and the speed is at or below the threshold
- **THEN** the heading does not change
- **AND** the kart cannot be spun on the spot

#### Scenario: Steering sense inverts in reverse

- **WHEN** the same steering input is held while travelling backwards
- **THEN** the heading turns in the opposite direction to the equivalent forward case

#### Scenario: Turn rate does not vary with speed

- **WHEN** the kart is steering at any speed above the threshold
- **THEN** the heading changes by the same amount per tick regardless of how fast it
  is travelling

### Requirement: The kart travels along its own heading

Position SHALL advance along the kart's facing direction, with no lateral component.

#### Scenario: Travel direction matches heading at every angle

- **WHEN** the kart moves at any heading
- **THEN** its displacement is along that heading
- **AND** there is no sideways drift or slip

#### Scenario: Reverse travels backwards along the same heading

- **WHEN** the velocity is negative
- **THEN** the kart moves opposite to its facing direction without the heading
  changing

### Requirement: The world boundary contains the kart

The kart SHALL be confined to the drivable extent on both horizontal axes, and
contact with that limit SHALL cost it speed exactly once per tick.

#### Scenario: Crossing the limit clamps and rebounds

- **WHEN** a tick would carry the kart beyond the drivable extent on an axis
- **THEN** that axis is clamped exactly to the limit
- **AND** the velocity is reduced and reversed by the bounce factor

#### Scenario: A corner costs the same as an edge

- **WHEN** a single tick clamps both axes at once
- **THEN** the bounce factor is applied exactly once, not once per axis
- **AND** the resulting speed is lower in magnitude than before the impact, never
  higher

### Requirement: Tuning is supplied to the simulation, not fetched by it

The simulation SHALL receive the values and the world state it needs, rather than
locating or loading them, so that it stays constructible and steppable with no
scene loaded and no files present.

#### Scenario: A changed value applies immediately

- **WHEN** a tuning value is changed at run time
- **THEN** the next tick uses the new value
- **AND** no restart, reload or reconstruction is needed

#### Scenario: The simulation reads no files

- **WHEN** the simulation is constructed and stepped
- **THEN** it opens nothing and locates nothing
- **AND** a test can drive it with values it constructed itself

#### Scenario: The props the tick collides with are supplied in order

- **WHEN** the simulation resolves a collision
- **THEN** the props it tests were handed to it, in registration order, rather than
  read back out of a scene
- **AND** a test can therefore place two props exactly where it wants them and step
  the tick, with nothing loaded

### Requirement: A run is reproducible

Identical starting state, tuning and input SHALL produce an identical sequence of
states, so that a divergence is always a defect rather than noise.

#### Scenario: Two identical runs agree exactly

- **WHEN** the same inputs are applied to two separately constructed simulations for
  the same number of ticks
- **THEN** their reported states are identical at every tick
- **AND** comparing them requires no tolerance

#### Scenario: Precision is sufficient for the stated tolerances

- **WHEN** the velocity recurrence is accumulated over the thousands of ticks the
  timing scenarios require
- **THEN** the accumulated error is far smaller than the tolerances those scenarios
  assert
