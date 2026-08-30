# godot/visual-gate — delta for add-visual-conformance-gate

## ADDED Requirements

### Requirement: The look is gated by committed baselines

A windowed gallery SHALL capture a fixed, deterministic set of game states
and compare them against committed baselines on three criteria — mean
absolute difference, percentage of pixels changed, percentage changed
strongly — failing when any state exceeds its recorded limit. The gallery
never joins the headless suite.

#### Scenario: Drift is caught on all three criteria

- **WHEN** a change alters what any gallery state renders beyond the recorded
  limits
- **THEN** the compare fails, names the state, and writes a side-by-side
  sheet

### Requirement: Thresholds are measured, never guessed

The limits SHALL be calibrated from a recorded noise floor — the diff of two
captures of identical states — and both the floor and the limits SHALL be
recorded together, so every number is evidence rather than a guess. A floor
that is not near zero is a harness defect to fix, never a threshold to raise.

#### Scenario: The calibration is on the record

- **WHEN** the limits are read from the configuration
- **THEN** the measured floor sits beside them with the command that produced
  it
