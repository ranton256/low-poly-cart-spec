# godot/simulation-core — delta for add-lap-gate-and-timing

## MODIFIED Requirements

### Requirement: A tick is a single ordered advance

The simulation SHALL expose one operation that advances the world by exactly one
fixed step, and that operation SHALL perform the design document's tick stages in
its stated order. The order is the contract: several of the document's own
statements are only true because of it. The race state SHALL advance as the
first stage, every tick in every state; the kart pipeline stages SHALL run only
in RACING (ambiguity A4). The lap gate SHALL run last and observe only — it
never moves the kart, and it reads a crossing observable that stages 6 and 7
cannot have influenced.

#### Scenario: The stages run in the specified order

- **WHEN** one tick is advanced
- **THEN** the race state advances before any kart work begins
- **AND** velocity is settled before any position work begins
- **AND** the speed clamp is applied before friction, so the achievable steady speed
  is below the clamp rather than equal to it
- **AND** the steering test reads the velocity as it stands after clamping and
  before friction
- **AND** the boundary is enforced after the position has been integrated
- **AND** the lap gate runs after collision resolution, so a push-out has already
  happened by the time the gate observes the position

#### Scenario: Stages not yet implemented keep their place in the order

- **WHEN** a stage lands after the sequence was laid down — as the lap gate now
  has, the last placeholder to fill
- **THEN** implementing it changed what a tick does, not the order in which it
  does it
- **AND** the sequence now carries no placeholder stages; a ninth stage would
  enter the same way

#### Scenario: A tick never reads wall-clock or frame time

- **WHEN** the simulation advances
- **THEN** it derives every duration from the number of ticks elapsed
- **AND** it consults no host clock, no frame delta, and no engine state

#### Scenario: Outside RACING the kart pipeline is skipped entirely

- **WHEN** a tick runs in LOADING or STARTING
- **THEN** no kart stage executes — no acceleration, steering, friction,
  integration, boundary, collision, or lap work
- **AND** the tick count still advances
