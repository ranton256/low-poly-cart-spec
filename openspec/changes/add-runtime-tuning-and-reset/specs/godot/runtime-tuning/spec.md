# godot/runtime-tuning — delta for add-runtime-tuning-and-reset

## ADDED Requirements

### Requirement: Reset Kart restores the start pose and nothing else

`Sim.reset_kart()` SHALL set position to the origin, heading to world +Z,
and velocity to exactly zero, leaving the lap clock, banked time, session
best, race state, and world untouched — and SHALL free a kart pinned
between props, since the pose it restores is clear ground.

#### Scenario: The reset is surgical

- **WHEN** Reset Kart runs mid-race with a best on the board
- **THEN** the kart stands at the origin facing +Z at zero velocity, and the
  clock, banked time, and best read exactly as before

#### Scenario: The pin's specified escape works

- **WHEN** a kart held between two props at the minimum separation triggers
  Reset Kart
- **THEN** it stands free at the origin

### Requirement: The tuning file is the live surface

The composition root SHALL watch `data/tuning.json`'s modification time on
the simulation clock and re-apply a changed table into the same shared
tuning object — in force on the next tick, with position, heading, velocity,
and the clock undisturbed by the change itself. The surface is not part of
the player-facing HUD; nothing renders it.

#### Scenario: An edit lands without a restart

- **WHEN** the file's table changes while the game runs
- **THEN** the new values are read into the shared object and the next tick
  uses them
