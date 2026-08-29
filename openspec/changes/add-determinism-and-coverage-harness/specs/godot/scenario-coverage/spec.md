## Purpose

Defines how the project knows which of the design document's specified behaviours
are verified, which are deliberately verified by eye, and which are not yet due —
so that a milestone cannot be called complete while a behaviour it owns is
silently untested.

## ADDED Requirements

### Requirement: Every specified scenario is accounted for

Every scenario in the design document SHALL be claimed, exactly once, as one of:
verified by a named test, verified by eye against committed visual proof, or not
yet due. A scenario claimed by nothing SHALL fail the standing suite.

#### Scenario: An unclaimed scenario fails the suite

- **WHEN** the design document contains a scenario that no test claims and no
  register entry covers
- **THEN** the standing suite fails
- **AND** it names the feature and the scenario

#### Scenario: A scenario claimed twice fails

- **WHEN** two tests claim the same scenario, or a test claims one the register also
  covers
- **THEN** the standing suite fails
- **AND** it names the scenario and both claimants
- **AND** this holds because a scenario covered twice usually means one of the two
  is covering something else and nobody noticed

#### Scenario: A claim on a scenario that does not exist fails

- **WHEN** a test or register entry claims a scenario the design document does not
  contain
- **THEN** the standing suite fails
- **AND** it names the stale claim
- **AND** renaming a scenario in the design document is therefore visible rather
  than silent

#### Scenario: The gate reports what it inspected

- **WHEN** the coverage check runs
- **THEN** it reports how many scenarios the design document contains and how many
  are claimed in each way
- **AND** it fails when it finds no scenarios at all, rather than reporting success

### Requirement: A deferred scenario names when it is due

A scenario declared not-yet-due SHALL name the milestone that will cover it, so
that deferral is a schedule rather than an excuse.

#### Scenario: A deferral without a milestone is refused

- **WHEN** a register entry defers a scenario without naming a milestone
- **THEN** the standing suite fails

#### Scenario: Deferrals are counted and visible

- **WHEN** the coverage check runs
- **THEN** the number of deferred scenarios is reported, grouped by the milestone
  that owns them
- **AND** the count is therefore visible as it falls, rather than only when it
  reaches zero

### Requirement: A scenario verified by eye says why

A scenario declared visual SHALL state why it cannot be verified headlessly, and
SHALL name either the committed capture that covers it or the milestone that will
produce one — a scenario can be known un-headless before the capture exists.

#### Scenario: A visual claim without a reason is refused

- **WHEN** a register entry declares a scenario visual without a stated reason
- **THEN** the standing suite fails
- **AND** "not unit-testable" is a claim that must be written down, not an omission

#### Scenario: A visual claim with neither a capture nor a milestone is refused

- **WHEN** a visual entry names no capture and no milestone that will produce one
- **THEN** the standing suite fails
- **AND** a scenario cannot therefore be parked as visual with nothing owning it

### Requirement: A test's claim survives renaming the test

A test SHALL claim a scenario by an explicit declaration rather than by the spelling
of its own name.

#### Scenario: Renaming a test does not break its claim

- **WHEN** a test function is renamed without changing what it verifies
- **THEN** its claim on the scenario is unaffected
- **AND** the coverage check still reports that scenario as verified

#### Scenario: A claim is discoverable without running the suite

- **WHEN** someone asks which test covers a given scenario
- **THEN** the answer is findable by searching the test sources
- **AND** it does not require executing anything
