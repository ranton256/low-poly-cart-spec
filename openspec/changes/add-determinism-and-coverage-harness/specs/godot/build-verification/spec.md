## MODIFIED Requirements

### Requirement: Single-source facts are asserted, not maintained by hand

Where a fact is recorded in one authoritative place and restated elsewhere — the
engine version, the design document's tuning constants, **the design document's
list of specified scenarios** — the suite SHALL verify the restatements against the
source rather than trusting them to stay in step.

#### Scenario: A restated fact that has drifted is caught

- **WHEN** a governing document or data file states a value that disagrees with its
  authoritative source
- **THEN** the standing suite fails
- **AND** it names the file, the value found, and the value expected

#### Scenario: The check covers values, not only names

- **WHEN** a transcribed constant carries the right name but the wrong number
- **THEN** the standing suite fails
- **AND** any constant the check cannot attribute automatically is reported as
  unattributable rather than silently passed over

#### Scenario: The design document's scenario list is one of those facts

- **WHEN** the design document gains, loses or renames a scenario
- **THEN** the standing suite reflects the change on its next run without anyone
  editing a second list to match
- **AND** a scenario left unaccounted for fails the suite

## ADDED Requirements

### Requirement: The simulation is indifferent to tick batching

The suite SHALL prove that one input sequence produces one outcome regardless of how
the ticks are grouped, because a frame loop groups them differently at every display
rate and the design document requires frame-rate independence.

#### Scenario: Different batchings of the same sequence agree exactly

- **WHEN** the same scripted input sequence is stepped through separately constructed
  simulations, one tick at a time and in the groupings a slower and a faster display
  rate would produce
- **THEN** every simulation ends in an identical state
- **AND** the states are compared exactly, with no tolerance, because any difference
  is a defect rather than noise

#### Scenario: The comparison would notice a difference

- **WHEN** the simulation is altered so that its result depends on how ticks are
  grouped
- **THEN** the suite fails
- **AND** the check is therefore known to discriminate, rather than assumed to

#### Scenario: The sequence exercises more than straight-line driving

- **WHEN** the scripted sequence is chosen
- **THEN** it includes turning, reversing and released input, not acceleration alone
- **AND** it runs long enough to accumulate any divergence that batching could
  introduce
