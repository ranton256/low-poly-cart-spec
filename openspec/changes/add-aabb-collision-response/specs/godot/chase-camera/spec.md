## ADDED Requirements

### Requirement: The camera absorbs a collision jolt

A collision SHALL displace the camera by a bounded random offset, and the easing
that already makes the camera lag SHALL pull it back, so the visible result is a
brief shudder rather than a permanent offset.

#### Scenario: The jolt is bounded

- **WHEN** a collision jolts the camera
- **THEN** the displacement is within the specified horizontal and vertical limits
- **AND** it is drawn from the game's own seeded randomness, so a run reproduces its
  own shudders

#### Scenario: The easing absorbs it

- **WHEN** frames pass after a jolt with no further collision
- **THEN** the camera returns to its trailing position
- **AND** it does so by the same easing that makes it lag through a turn, at the
  same rate — no separate decay

#### Scenario: A jolt does not move the kart or the aim

- **WHEN** the camera is jolted
- **THEN** the kart's position, heading and velocity are unaffected
- **AND** the aim point is unaffected, so the horizon does not lurch with the camera
