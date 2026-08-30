# godot/layout-persistence — delta for add-checkpoint-circuit-core

## ADDED Requirements

### Requirement: Version 2 carries the circuit, whole or not at all

A version-2 layout SHALL carry a `circuit` object — `name`, ordered `gates`
(each a `position` `[X, Z]`, a `yaw`, and a `width`), and optional `targets`
(`bronze`/`silver`/`gold` seconds) — validated completely before anything is
released, exactly as prop records are; a malformed circuit refuses the whole
file. Saving SHALL write the loaded circuit back out byte-identically, so
the existing round-trip guarantees extend to it. (The GDD's refusal of
*gateless* files is deliberately NOT implemented here: the game must stay
playable until the boot ships a circuit — that refusal lands with
`add-circuit-world-and-presentation`, and the deferral stays open until it
does.)

#### Scenario: A circuit round-trips byte-identically

- **WHEN** a v2 layout is loaded, saved, reloaded, and saved again
- **THEN** the two saved files are byte-identical from the first cycle,
  circuit object included

#### Scenario: A malformed circuit refuses the whole file

- **WHEN** a v2 file's circuit has a gate missing its width, or a
  non-numeric target
- **THEN** no prop is released, no gate is armed, the current world and
  clock are untouched, and the reason is logged
