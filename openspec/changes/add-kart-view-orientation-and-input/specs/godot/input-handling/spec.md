## Purpose

Defines how a player's key presses become the simulation's held-input state: which keys are
bound, what happens when focus is lost mid-press, and what happens when a key nobody bound is
pressed.

## ADDED Requirements

### Requirement: The specified control scheme is bound

Every action the design document's control table names SHALL be bound to the keys it names,
with both listed key sets equivalent.

#### Scenario: Both key sets drive the same actions

- **WHEN** the bindings are inspected
- **THEN** every action in the document's table is bound to both its primary and its alternate
  key, where the table gives two
- **AND** neither set is preferred: either produces the same action

#### Scenario: A binding whose action does not exist yet is still a binding

- **WHEN** an action is bound whose effect is not implemented in this change
- **THEN** the binding exists and is verified as a binding
- **AND** pressing it changes nothing, rather than producing a partial or placeholder effect

### Requirement: Held input reaches the simulation as held state

Input SHALL be delivered to the simulation as state that persists while a key is held, not as
events, because the simulation's tick reads held state and runs at a rate unrelated to the
host's key-repeat behaviour.

#### Scenario: A held key applies on every tick

- **WHEN** a bound key is held across several simulation ticks
- **THEN** its action applies on each of them
- **AND** the host's key-repeat rate does not change how many ticks it applies to

#### Scenario: Releasing a key stops its action

- **WHEN** a held key is released
- **THEN** the held state is cleared
- **AND** no tick after the release applies that action

### Requirement: Losing focus releases everything

When the application loses input focus, every held input SHALL be cleared immediately, because a
key the host stops reporting would otherwise stay held forever and drive the kart away
unattended.

#### Scenario: Focus lost mid-throttle

- **WHEN** the application loses input focus while one or more inputs are held
- **THEN** every held input is cleared
- **AND** the kart coasts to a stop under friction rather than continuing under power

#### Scenario: Regaining focus does not restore what was held

- **WHEN** focus returns
- **THEN** no input is held until the player presses something again
- **AND** a key still physically down is not treated as held until it is pressed anew

### Requirement: Unbound keys do nothing and say nothing

A key with no binding SHALL change no state and SHALL produce no log output.

#### Scenario: An unbound key is ignored

- **WHEN** a key with no binding is pressed
- **THEN** no simulation state changes
- **AND** nothing is written to the log, so that holding an unbound key cannot flood it
