# godot/world-scatter — delta for add-circuit-world-and-presentation

## MODIFIED Requirements

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
