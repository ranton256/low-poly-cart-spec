# godot/world-scatter Specification

## Purpose
Defines how a seed becomes a field of obstacles: which populations are requested,
what rejects a candidate position, what happens when placement cannot succeed, how
repeated instances are varied so the field does not read as tiled, and — because a
later change resolves collisions by it — the order placements are emitted in.

## Requirements

### Requirement: A seed determines the field

Scattering SHALL be a function of its seed alone. The same seed SHALL produce the
same placements, in the same order, on any machine and in any run.

#### Scenario: The same seed gives the same field

- **WHEN** the same seed is scattered twice
- **THEN** the two results are identical placement for placement, including order
- **AND** they are compared as a sequence, not as a set: a later change resolves
  collisions by registration order, so two fields with the same props in a
  different order are not the same field

#### Scenario: Different seeds give different fields

- **WHEN** two different seeds are scattered
- **THEN** the resulting fields differ
- **AND** this is asserted, because a generator that ignores its seed satisfies
  every other requirement here

#### Scenario: Scattering draws from its own stream

- **WHEN** scattering runs
- **THEN** the numbers it consumes are not affected by anything else in the game
  having drawn from a random source
- **AND** scattering twice from one seed therefore agrees even if unrelated code ran
  in between

### Requirement: The specified populations are requested

Each asset the design document names SHALL be requested at the count and target
height the document gives it, checked against the document rather than against this
port's transcription.

#### Scenario: Every asset is requested at its stated count

- **WHEN** a field is generated with placement unconstrained
- **THEN** each asset appears the number of times the design document states
- **AND** the expected counts are read from the design document itself, so a
  transcription error cannot make the check agree with the mistake

#### Scenario: Candidates are drawn from the specified area

- **WHEN** candidate positions are generated
- **THEN** they are uniformly distributed over the specified extent on both
  horizontal axes
- **AND** no placement falls outside it, so the ring beyond stays empty

### Requirement: A candidate too near the start or another prop is rejected

A candidate position SHALL be rejected, and another attempted, when it falls inside
the asset's clearance radius of the world origin or within the minimum separation of
an already-placed prop.

#### Scenario: The start area stays clear

- **WHEN** the field is generated
- **THEN** no prop is nearer the origin than its own clearance radius
- **AND** the asset with the larger radius is held to the larger one, so it appears
  only as a distant landmark near the edges of the field

#### Scenario: Props do not crowd each other

- **WHEN** the field is generated
- **THEN** no two placed props are nearer each other than the minimum separation
- **AND** this holds between props of different assets, not only within one asset

#### Scenario: A rejected candidate places nothing

- **WHEN** a candidate is rejected
- **THEN** no prop is placed at it
- **AND** another candidate is attempted in its place

### Requirement: Placement gives up rather than looping

Placement for an asset SHALL stop after the specified budget of attempts per
requested instance, and the world SHALL be usable with however many succeeded.

#### Scenario: An impossible request terminates

- **WHEN** the rules make the requested population impossible to place
- **THEN** generation completes rather than looping
- **AND** it does so after the specified number of attempts, not an arbitrary one

#### Scenario: The shortfall is reported

- **WHEN** fewer instances are placed than requested
- **THEN** the achieved count and the requested count are both reported
- **AND** a field quietly short of props is therefore visible as a shortfall rather
  than mistaken for a sparse seed

#### Scenario: A shortfall is not an error

- **WHEN** placement falls short
- **THEN** the world is still generated and usable
- **AND** the placements that succeeded are unaffected

### Requirement: Repeated instances are varied

Each placed instance SHALL be rotated and scaled by independently drawn random
values, and SHALL rest on the ground after that scaling.

#### Scenario: Yaw and scale vary across instances

- **WHEN** several instances of one asset are placed
- **THEN** their yaws differ, spanning the full turn
- **AND** their scales differ, within the specified variation range

#### Scenario: Every instance rests on the ground at every scale

- **WHEN** any placed instance is measured
- **THEN** its lowest point is exactly at ground level
- **AND** this holds at the extremes of the scale range as well as the middle,
  because a check at one scale would pass on a generator that ignored scale
  entirely

#### Scenario: Variation compounds with the target height

- **WHEN** an instance is scaled by the variation factor
- **THEN** the factor applies on top of the asset's target-height normalisation
- **AND** the result is not the target height alone, nor the variation alone

### Requirement: Placements are emitted in a defined order

Scattering SHALL emit placements in a stated, reproducible order, because a later
change resolves a collision against the first intersecting prop in that order.

#### Scenario: The order is part of the output

- **WHEN** a field is generated
- **THEN** the placements have a defined sequence, not merely a membership
- **AND** the same seed reproduces that sequence exactly

#### Scenario: The order is stated, not incidental

- **WHEN** the ordering rule is inspected
- **THEN** it is written down where a reader can find it
- **AND** it does not depend on iteration order over an unordered collection

### Requirement: The field can be regenerated without disturbing the drive

Scatter regeneration SHALL remain available to the authoring tools and
suites — replacing every prop by the same rules and counts without touching
the kart or clock — but SHALL no longer be bound to a player action: the
player-facing binding is Restart Circuit (godot/checkpoint-circuit), whose
semantics deliberately DO reset the attempt. (Amended with the GDD's
Restart Circuit rename; the old scenario pair survives as the authoring
contract.)

#### Scenario: A fresh population replaces the old one

- **WHEN** the world is regenerated through the authoring path
- **THEN** every existing prop is removed and its resources released
- **AND** a fresh population is scattered by the same rules and counts

#### Scenario: The kart and the clock are untouched

- **WHEN** the world is regenerated through the authoring path while the
  kart is moving
- **THEN** its position, heading and velocity are unchanged
- **AND** the running timer is unchanged

#### Scenario: No player binding reaches the scatter

- **WHEN** the player uses the binding formerly known as Regenerate World
- **THEN** Restart Circuit runs, and no fresh scatter occurs
