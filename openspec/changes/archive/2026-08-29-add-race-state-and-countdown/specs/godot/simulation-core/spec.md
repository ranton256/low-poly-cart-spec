# godot/simulation-core — delta for add-race-state-and-countdown

## MODIFIED Requirements

### Requirement: A tick is a single ordered advance

The simulation SHALL expose one operation that advances the world by exactly one
fixed step, and that operation SHALL perform the design document's tick stages in
its stated order. The order is the contract: several of the document's own
statements are only true because of it. The race state SHALL advance as the
first stage, every tick in every state; the kart pipeline stages SHALL run only
in RACING (ambiguity A4).

#### Scenario: The stages run in the specified order

- **WHEN** one tick is advanced
- **THEN** the race state advances before any kart work begins
- **AND** velocity is settled before any position work begins
- **AND** the speed clamp is applied before friction, so the achievable steady speed
  is below the clamp rather than equal to it
- **AND** the steering test reads the velocity as it stands after clamping and
  before friction
- **AND** the boundary is enforced after the position has been integrated

#### Scenario: Stages not yet implemented keep their place in the order

- **WHEN** a tick runs before lap detection exists
- **THEN** its stage is present in the sequence and does nothing
- **AND** implementing it later changes what a tick does, not the order in which
  it does it

#### Scenario: A tick never reads wall-clock or frame time

- **WHEN** the simulation advances
- **THEN** it derives every duration from the number of ticks elapsed
- **AND** it consults no host clock, no frame delta, and no engine state

#### Scenario: Outside RACING the kart pipeline is skipped entirely

- **WHEN** a tick runs in LOADING or STARTING
- **THEN** no kart stage executes — no acceleration, steering, friction,
  integration, boundary, or collision work
- **AND** the tick count still advances
