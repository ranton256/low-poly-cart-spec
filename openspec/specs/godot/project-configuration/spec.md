# godot/project-configuration Specification

## Purpose
Defines what the Godot port's project configuration must guarantee about itself —
engine version, renderer, simulation rate, language, asset reachability, and where
tuning constants live — so that later milestones can rely on those guarantees
rather than re-establishing them.

## Requirements

### Requirement: Pinned engine version

The project SHALL declare the exact Godot version it is developed against in a
single authoritative place, and every other statement of that version SHALL be
verified against it rather than maintained by hand.

#### Scenario: The declared version is discoverable without opening the editor

- **WHEN** the project is read by a tool or a person from a clean checkout
- **THEN** one file states the full major.minor.patch version the project targets
- **AND** the engine's own project configuration agrees with it to the precision the
  engine is capable of recording

#### Scenario: A document disagreeing about the version is caught

- **WHEN** any governing document states a Godot version other than the declared one
  or its series
- **THEN** the standing suite fails
- **AND** it names the document, the line, and both versions

### Requirement: Fixed simulation rate

The simulation SHALL advance at a fixed 60 ticks per second, and the engine SHALL
NOT adjust the physics step to smooth frame pacing.

#### Scenario: The tick rate is 60 Hz

- **WHEN** the project's physics configuration is read
- **THEN** the physics tick rate is exactly 60 per second

#### Scenario: Step smoothing is disabled

- **WHEN** the project's physics configuration is read
- **THEN** physics jitter compensation is disabled
- **AND** the duration of a simulation tick is therefore identical on every frame, so the
  race clock cannot drift against wall time

### Requirement: One renderer on every target

The project SHALL use a single renderer across every shipping target, so that one
specification produces one look and one set of visual baselines.

#### Scenario: Desktop and web render through the same path

- **WHEN** the project is exported to any supported target
- **THEN** the renderer is the same one used on every other target
- **AND** no second render path exists for any platform

#### Scenario: The choice is recorded as provisional

- **WHEN** the renderer is selected before the shadow-quality spike has run
- **THEN** the selection is recorded as a decision with a named owner and a spike that may reverse it
- **AND** it is not left to an engine default

### Requirement: Single implementation language

The shipped project SHALL contain exactly one implementation language, so that the
simulation producing the game's numbers has exactly one implementation across all
targets.

#### Scenario: No second language enters the project

- **WHEN** the project's sources are enumerated
- **THEN** every script is GDScript
- **AND** no compiled-language project file, native extension, or third-party engine addon is present

### Requirement: Shared assets are reachable from the project

The supplied models live outside the Godot project directory and are shared by every
port. The project SHALL reach them by a mechanism that works on every shipping
target without depending on filesystem features git cannot guarantee, and that
mechanism SHALL be recorded.

#### Scenario: Assets resolve on every target platform

- **WHEN** the project is prepared on any supported platform and then opened or exported
- **THEN** all seven supplied models import and load successfully
- **AND** the mechanism relies on no filesystem feature that a git checkout may decline
  to reproduce

#### Scenario: The models remain single-sourced

- **WHEN** the working copies inside the project are compared with the shared originals
- **THEN** each working copy is byte-identical to its source
- **AND** only one copy of each model is under version control
- **AND** a working copy that has drifted from its source is detected by content, not
  by timestamp, and replaced

#### Scenario: A failed import cannot be inherited

- **WHEN** an import preset under version control records a failed import
- **THEN** preparing the project fails and names the affected preset
- **AND** it says how to regenerate it, because the engine does not repair such a
  preset once the source is corrected

#### Scenario: The mechanism is written down, not inferred

- **WHEN** a contributor asks how the project reaches the shared assets
- **THEN** the mechanism and its platform caveats are stated in the constraints document
- **AND** the previously open question about asset reachability is closed there

### Requirement: Tuning constants have exactly one home

Every numeric constant the game design document defines SHALL be transcribed into a
single data file, under the name the design document gives it.

#### Scenario: Constants are transcribed once, by name

- **WHEN** the tuning data file is compared against the design document's constant tables
- **THEN** every named constant in those tables is present exactly once
- **AND** each is recorded under the identical name the design document uses
- **AND** no constant appears twice or under a renamed key

#### Scenario: Transcription alone changes no behavior

- **WHEN** this change is complete
- **THEN** nothing in the project reads the tuning data file yet
- **AND** the file's presence alters no observable behavior
