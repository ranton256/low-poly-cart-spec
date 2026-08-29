## Purpose

Defines where the camera sits, what it aims at, how far behind it lags through a
turn, and how its field of view answers to speed — as a fixed-step recurrence, so
that what the player sees does not depend on how fast their display runs and so
that "settles behind the kart" is a measurement rather than an opinion.

## ADDED Requirements

### Requirement: The camera trails the kart in the kart's own frame

The camera SHALL sit behind and above the kart by the distances the design document
specifies, measured in the kart's frame rather than the world's, and SHALL aim at a
point ahead of and above it.

#### Scenario: The target follows the kart around a turn

- **WHEN** the kart's heading changes
- **THEN** the camera's target position moves with it, staying behind the kart
  rather than behind a fixed world direction
- **AND** the aim point stays ahead of the kart in the same frame

#### Scenario: The aim is not smoothed

- **WHEN** the camera is updated
- **THEN** the point it aims at is computed from the kart's current state with no
  lag applied
- **AND** the horizon therefore stays level while the camera's position lags, which
  is what separates a trailing camera from a swaying one

### Requirement: The lag is a fixed-step recurrence

The camera's position SHALL ease toward its target by a fixed proportion **per
simulation tick**, never per rendered frame, because the design document states the
easing per tick and states a time constant for it, and a per-frame easing produces
a different time constant at every display rate.

#### Scenario: The same lag at any display rate

- **WHEN** the same manoeuvre is driven on a slow display and a fast one
- **THEN** the camera lags by the same amount at the same point in the manoeuvre
- **AND** the number of eases applied depends on elapsed time, not on frames drawn

#### Scenario: The camera swings wide and then settles

- **WHEN** the kart turns at the full steering rate and then straightens
- **THEN** the camera swings wide of the turn rather than snapping to the new
  heading
- **AND** it returns behind the kart within the settling time the design document
  states, measured rather than judged

#### Scenario: The lag is visible as lag

- **WHEN** the kart is turning
- **THEN** the camera is measurably off the kart's current heading
- **AND** a camera that tracks perfectly fails this, because a lag of zero is not a
  lag the design document would accept

### Requirement: The field of view widens with speed

The vertical field of view SHALL be a continuous function of the kart's speed ratio,
running from the resting value at zero to the maximum at the speed clamp.

#### Scenario: At rest and at speed

- **WHEN** the kart is stationary
- **THEN** the field of view is the resting value the design document specifies
- **AND** at the kart's achievable top speed it is near the specified maximum,
  short of it by the same margin the speed falls short of the clamp

#### Scenario: The change is continuous

- **WHEN** the kart accelerates from rest
- **THEN** the field of view changes smoothly with the speed ratio, with no step
- **AND** it is a function of speed alone, so the same speed always gives the same
  field of view

#### Scenario: The field of view is bounded

- **WHEN** the speed ratio is computed
- **THEN** it is clamped, so a speed above the limit cannot widen the view past the
  specified maximum

### Requirement: The camera is testable without a renderer

The camera's behaviour SHALL be computable and assertable with no scene loaded,
because the properties the design document states about it — a time constant, a
settling time, a field-of-view curve — are numbers, and a screenshot cannot check a
number.

#### Scenario: Camera state can be advanced without a display

- **WHEN** a test drives the camera through a manoeuvre
- **THEN** it can do so headlessly, with no viewport and no renderer
- **AND** the values it reads are the same ones the view draws from

#### Scenario: The view applies the camera and does not compute it

- **WHEN** the view is inspected
- **THEN** it reads the camera's position, aim and field of view and applies them
- **AND** it computes none of them, so there is one place where the behaviour lives
