# godot/lap-timing — delta for add-checkpoint-circuit-core

## MODIFIED Requirements

### Requirement: The crossing test reads stage 5's own displacement

The simulation SHALL record the +Z displacement stage 5 actually applied
(`velocity × forward_z()`, before any boundary or collision adjustment) as an
observable, and the lap gate SHALL test that observable against
`lapCrossingThreshold` — never the scalar velocity's sign, and never net
position change across the tick. When a circuit is loaded, a crossing SHALL
bank only with the progress cursor past the final gate; without one (the
pre-boot-swap interim), the `minLapTime` guard from `port_decisions` applies
and dies with `add-circuit-world-and-presentation`.

#### Scenario: A push-out cannot bank a lap

- **WHEN** a kart sits motionless in the band while a collision push-out moves
  it +Z by more than the threshold each tick
- **THEN** no lap is recorded, because stage 5 displaced it nothing

#### Scenario: Driving forward heading south is the wrong way

- **WHEN** the kart crosses the band under power with its forward axis
  pointing −Z
- **THEN** stage 5's +Z displacement is negative and no lap is recorded

#### Scenario: An unthreaded crossing banks nothing

- **WHEN** a circuit is loaded and the kart crosses the band with the cursor
  short of the final gate
- **THEN** no lap is recorded, the clock keeps running, and no minimum-time
  rule applies in either direction

### Requirement: Best-time state is session state in the core

The best time SHALL live in the lap module, **keyed by the loaded circuit's
name** ("procedural" in the no-circuit interim): −1.0 until a first lap on
that circuit, updated only by a strictly faster lap, arming a
`bestFlashDuration` countdown when it updates. Every keyed best survives
world rebuilds and circuit switches for the session and is never written to
storage.

#### Scenario: The first lap sets the best and flashes

- **WHEN** the first lap of a session banks
- **THEN** the best becomes that time and the flash countdown arms

#### Scenario: A slower lap changes nothing but the clock

- **WHEN** a lap banks at or above the current best
- **THEN** the best and its readout are unchanged, no flash arms, and the
  clock still restarts

#### Scenario: Another circuit's best is another best

- **WHEN** a faster lap banks on a different circuit than the session's
  fastest so far
- **THEN** only that circuit's keyed best updates, and returning to the
  first circuit shows its own best unchanged
