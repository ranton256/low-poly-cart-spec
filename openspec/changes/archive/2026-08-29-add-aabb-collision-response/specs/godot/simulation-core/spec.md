## MODIFIED Requirements

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
