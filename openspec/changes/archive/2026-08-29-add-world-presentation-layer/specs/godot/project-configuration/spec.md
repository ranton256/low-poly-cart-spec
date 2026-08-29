## MODIFIED Requirements

### Requirement: Tuning constants have exactly one home

Every numeric constant the game design document defines SHALL be transcribed into a
single data file, under the name the design document gives it, and every part of the
game that needs one SHALL read it from there rather than carry a copy.

#### Scenario: Constants are transcribed once, by name

- **WHEN** the tuning data file is compared against the design document's constant tables
- **THEN** every named constant in those tables is present exactly once
- **AND** each is recorded under the identical name the design document uses
- **AND** no constant appears twice or under a renamed key

#### Scenario: Transcription alone changes no behavior

- **WHEN** a constant is transcribed into the data file and nothing yet reads it
- **THEN** its presence alters no observable behavior
- **AND** transcription is therefore safe to complete ahead of the change that
  consumes it, which is how the table came to be filled in before anything ran

#### Scenario: The running game reads its constants from the data file

- **WHEN** the game builds anything the design document gives a constant for
- **THEN** the value comes from the tuning data file at run time
- **AND** editing that file changes what the game produces, with no code change
- **AND** a constant that has a reader is no longer merely transcribed, so the
  data file is load-bearing rather than documentary

#### Scenario: A constant the document does not name still has one home

- **WHEN** the design document specifies a value without giving it a name
- **THEN** it is recorded in the same data file under a name this port states
- **AND** it is kept distinct from the set the design document does name, so that
  the named set stays exactly the named set
