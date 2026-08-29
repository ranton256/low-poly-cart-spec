## Purpose

Defines how the simulation is advanced and drawn: at a fixed rate regardless of display rate,
from exactly one place, with the view reading state between steps and never advancing it. This
is what makes the game frame-rate independent in fact rather than only in the core.

## ADDED Requirements

### Requirement: The simulation advances at a fixed rate, whatever the display does

The simulation SHALL advance in fixed steps at its specified rate, accumulating elapsed time
rather than stepping once per rendered frame, because the design document requires frame-rate
independence and states every per-tick constant at that one rate.

#### Scenario: A slower display runs the same number of steps

- **WHEN** the game runs for a given period on a display slower than the simulation rate
- **THEN** the number of steps taken matches the elapsed time at the specified rate, not the
  number of frames drawn
- **AND** the kart therefore travels the same distance per second at any display rate

#### Scenario: A faster display does not run the simulation faster

- **WHEN** the game runs on a display faster than the simulation rate
- **THEN** frames are drawn on which no step occurs
- **AND** nothing in the simulation advances on those frames

#### Scenario: Leftover time is carried, not discarded

- **WHEN** elapsed time does not divide evenly into whole steps
- **THEN** the remainder is carried into the next frame rather than dropped or rounded away
- **AND** the simulation therefore neither loses nor gains time over a long run

#### Scenario: The simulation's rate and the engine's fixed-rate callback agree

- **WHEN** the project's fixed-rate setting is compared against the rate the simulation core
  declares for itself
- **THEN** they are the same number
- **AND** a divergence fails the standing suite, because the two are independent declarations
  of one rate and every timing figure in the design document is stated at it

### Requirement: One caller advances the simulation

Exactly one place in the running game SHALL call the simulation's step, so that "how many times
has the world advanced" has one answer and one owner.

#### Scenario: The view never steps

- **WHEN** the view is inspected
- **THEN** it reads simulation state and never advances it
- **AND** no node outside the composition root calls the step

#### Scenario: One step per fixed-rate callback

- **WHEN** the fixed-rate callback fires
- **THEN** the simulation advances exactly one step
- **AND** the per-frame callback advances it none, so the number of steps is a function of
  elapsed time alone

#### Scenario: A per-frame entry point exists and is distinct from a step

- **WHEN** a frame is processed
- **THEN** the simulation's per-frame entry point is called exactly once, before that frame's
  steps
- **AND** it is distinct from the step, so that work which must happen once per frame cannot be
  mistaken for work that happens once per tick

### Requirement: The view draws between simulation states

The view SHALL render the kart at an interpolated position between the previous and current
simulation states, because a fixed step slower than the display rate otherwise shows visible
stutter.

#### Scenario: Motion is smooth at a display rate above the simulation rate

- **WHEN** the kart is moving and the display rate exceeds the simulation rate
- **THEN** its drawn position advances on frames where no step occurred
- **AND** the interpolation is a function of the simulation's own clock, never of wall time

#### Scenario: Interpolation changes what is drawn and never what is stored

- **WHEN** the interpolated position is computed
- **THEN** the simulation's stored state is unchanged by it
- **AND** a value read back from the simulation is the stepped value, not the drawn one

### Requirement: The running game reads its tuning at startup

The composition root SHALL load the tuning data and hand it to the simulation, and SHALL refuse
to run rather than start with defaults, because a silently defaulted constant produces a game
that is subtly wrong rather than obviously broken.

#### Scenario: Missing or malformed tuning stops the game

- **WHEN** the tuning data cannot be read or is missing a required value
- **THEN** the failure is reported with the name of what is missing
- **AND** the game does not start with substituted values
