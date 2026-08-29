# godot/architecture-enforcement Specification

## Purpose
Defines what the project mechanically refuses to accept — engine dependencies in
the simulation core, the Godot physics engine anywhere, tuning values written as
literals, and project settings drifting from their pinned values — so that the
architecture the design document's tick order depends on cannot erode quietly.

## Requirements

### Requirement: The simulation core stays free of the engine

Nothing under the simulation core directory SHALL reference engine node types, the
scene tree, engine time, engine input, or engine randomness. The core must remain
constructible and steppable with no scene loaded.

#### Scenario: An engine dependency in the core is refused

- **WHEN** a file in the simulation core references a node type, a scene-tree
  accessor, an engine lifecycle callback, engine time, engine input, or the engine's
  global random functions
- **THEN** the standing suite fails
- **AND** it names the file, the line, and the specific symbol

#### Scenario: Mentioning a banned symbol in prose is not a violation

- **WHEN** a comment explains why a banned symbol must not be used
- **THEN** no violation is reported
- **AND** a symbol name appearing as part of a longer identifier is likewise not
  reported, because the constraint is about calling the engine, not about spelling

#### Scenario: Math types remain available

- **WHEN** the core uses the engine's vector, transform, or bounding-volume value
  types
- **THEN** no violation is reported, because these carry no engine dependency

### Requirement: The Godot physics engine plays no part, anywhere

No file anywhere in the Godot project SHALL reference a physics body, a collision
shape, a physics area, the physics server, or the engine's movement helpers. The
design document's tick is a scalar recurrence with no solver; a physics body in the
tree means the port has become a different game.

#### Scenario: A physics symbol anywhere in the tree is refused

- **WHEN** any script or scene file in the project references a banned physics
  symbol
- **THEN** the standing suite fails
- **AND** it names the file, the line, and the symbol
- **AND** this holds for a violation already present in the tree, not only for one
  being introduced

#### Scenario: A violation is also refused at the commit that introduces it

- **WHEN** a commit stages content containing a banned physics symbol
- **THEN** the commit is refused before the standing suite would next run

### Requirement: One definition of what is banned

The commit-time gate and the standing suite SHALL derive their banned symbols from
a single shared definition, so the two cannot disagree about what the project
forbids.

#### Scenario: The two gates cannot drift apart

- **WHEN** a symbol is added to or removed from the banned set
- **THEN** both the standing suite and the commit-time gate observe the change
- **AND** neither carries its own private copy of the list

### Requirement: Tuning values appear only in the tuning data

A **distinctive** numeric value defined in the tuning data SHALL NOT appear as a
literal in the project's game-logic scripts. The design document's central
discipline is that every number lives in exactly one place and is referred to by
name; a literal silently forks that.

The rule is deliberately narrower than "any tuning value anywhere", because a gate
that flags loop bounds and scene format versions trains everyone to exempt
reflexively and then guards nothing. What it gives up is stated below and reported
on every run, so the narrowing is visible rather than assumed.

#### Scenario: A distinctive tuning value written as a literal is refused

- **WHEN** a game-logic script contains a numeric literal equal to a distinctive
  value defined in the tuning data
- **THEN** the standing suite fails
- **AND** it names the file, the line, the value, and the constant it belongs to

#### Scenario: Values indistinguishable from ordinary code are not searched

- **WHEN** a tuning constant's value is a small integer, of the kind that also
  appears as an index, a count, an axis selector or a loop bound
- **THEN** it is not searched for
- **AND** every such constant is reported by name and value on each run, so what
  the gate does not cover is visible

#### Scenario: A value written in an unusual but equivalent form is still caught

- **WHEN** a tuning value is written with trailing zeros, a leading decimal point, or
  in exponent form
- **THEN** it is recognised as the same value and refused
- **AND** a value produced by arithmetic rather than written as a literal is outside
  what this gate can see, and is documented as such rather than implied to be covered

#### Scenario: The search is scoped to where a literal would fork the contract

- **WHEN** a literal appears in a test's expected values, a scene file's format
  version, or a development tool
- **THEN** it is not reported, because those are not the game's logic
- **AND** the scope the gate did search is reported on each run

#### Scenario: An unavoidable coincidence can be recorded rather than removed

- **WHEN** a literal is genuinely not the tuning constant it collides with
- **THEN** it can be exempted only by an explicit, individually justified entry in a
  committed allowlist
- **AND** an allowlist entry without a stated reason is itself a failure
- **AND** the number of exemptions is reported on every run, so a growing allowlist
  is visible rather than silent

#### Scenario: An exemption that is no longer needed is reported

- **WHEN** an allowlist entry no longer matches anything in the tree
- **THEN** the standing suite fails
- **AND** it names the stale entry, so exemptions cannot outlive their reason

### Requirement: Pinned project settings cannot drift

The determinism-critical project settings and the committed model import presets
SHALL be asserted, because the engine rewrites both without asking and a silent
revert would invalidate every measurement taken against them.

#### Scenario: A determinism-critical setting has changed

- **WHEN** the simulation tick rate, the physics step-smoothing setting, or the
  renderer differs from its pinned value
- **THEN** the standing suite fails
- **AND** it names the setting, the value found, and the value required

#### Scenario: A model import preset is missing or records a failure

- **WHEN** a supplied model has no committed import preset, or its preset records a
  failed import
- **THEN** the standing suite fails
- **AND** it names the affected model

### Requirement: Every gate reports what it inspected

Each gate SHALL report a non-zero count of the files, symbols, or settings it
examined, and SHALL fail when that count is zero.

#### Scenario: A gate that would inspect nothing fails loudly

- **WHEN** a gate's target directory is renamed, emptied, or otherwise yields no
  input
- **THEN** the gate fails rather than reporting success
- **AND** it says that it found nothing to inspect, rather than that nothing is wrong
