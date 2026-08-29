## MODIFIED Requirements

### Requirement: The world can be seen before anything moves

The world SHALL be renderable and capturable on its own, without a kart, an input
device or a running simulation, so that changes which build the environment can
produce the visual proof they are required to produce.

#### Scenario: The scene renders with nothing stepping

- **WHEN** the world scene is loaded
- **THEN** it renders a complete environment
- **AND** no simulation is stepped, and nothing in the scene advances over time

#### Scenario: A viewpoint exists and is declared temporary

- **WHEN** the scene is captured
- **THEN** a viewpoint exists from which the environment can be seen
- **AND** it is recorded as a placeholder that a later change replaces, so it is not
  mistaken for the specified chase camera

#### Scenario: The running game uses the specified camera, not the placeholder

- **WHEN** the game runs
- **THEN** the camera the player looks through is the one the design document
  specifies, not the placeholder
- **AND** the placeholder remains available to the world scene's own captures,
  because those must still work with no kart and nothing stepping
