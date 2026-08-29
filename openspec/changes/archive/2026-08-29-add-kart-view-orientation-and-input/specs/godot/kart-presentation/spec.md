## Purpose

Defines the kart as the player sees it — at its specified size, standing at the start line, and
facing the direction it actually travels at every heading — and defines how the orientation
correction the design document states in another engine's frame is established here, since
copying the number is what produces the crabbing kart the document names as this asset's
classic failure.

## ADDED Requirements

### Requirement: The kart stands at the start line at its specified size

The kart SHALL be placed and sized as the design document's bootstrap scenario states, and its
dimensions SHALL be checked against the document's own figures rather than against this port's
transcription of them.

#### Scenario: The kart's pose at the start of a session

- **WHEN** the world is ready
- **THEN** the kart stands at the origin on both horizontal axes with its lowest point exactly
  at ground level
- **AND** it faces the world's forward direction, toward the start/finish band
- **AND** its velocity is zero

#### Scenario: The kart's dimensions match the document, checked against the document

- **WHEN** the built kart's bounding box is measured
- **THEN** it matches the final dimensions the design document states for it
- **AND** the expected values are read from the design document itself, not from this port's
  tuning data, so that a transcription error cannot make the check agree with the mistake

#### Scenario: The kart's world extent at the start line

- **WHEN** the kart stands at the start line
- **THEN** its world-axis-aligned extent is the document's stated footprint, wider across the
  lateral axis than it is long along the forward axis or the reverse, as the document specifies
- **AND** this distinguishes a correctly oriented kart from one turned a quarter turn

### Requirement: The kart travels in the direction it visually faces

At every heading, forward and in reverse, the direction the kart moves SHALL be the direction
its visible front points, because the design document requires it and names the failure by name.

#### Scenario: Travel matches facing at every heading

- **WHEN** the kart is driven forward from a range of headings covering a full turn
- **THEN** its displacement is along its visible forward direction at each one
- **AND** reversing moves it backwards along the same direction rather than along another

#### Scenario: A consistency check is not an orientation check

- **WHEN** the check above passes
- **THEN** it establishes that travel and facing agree, and NOT that the facing is correct
- **AND** a kart whose correction is wrong by half a turn satisfies it while driving backwards
- **AND** the specification therefore requires separate evidence of which end is the front

#### Scenario: Which end is the front is established by evidence, not assertion

- **WHEN** the orientation correction is chosen
- **THEN** committed visual proof shows the kart's front facing the world's forward direction
- **AND** a mechanical measurement of the mesh corroborates it, so the conclusion does not rest
  on one person's reading of one image
- **AND** both are re-runnable from committed artifacts

### Requirement: The orientation correction is derived, not transcribed

The correction SHALL be computed from the imported asset and held in one named place. The
figure the design document states SHALL NOT be copied as a literal, because it is expressed in
a frame this engine does not share.

#### Scenario: The correction is computed from the asset

- **WHEN** the correction is established
- **THEN** its axis is derived from the imported model's own bounds
- **AND** it is held in exactly one named constant, which the view and any conformance check
  both read

#### Scenario: Re-importing the asset does not silently change the answer

- **WHEN** the model is re-imported or replaced
- **THEN** the correction is recomputed from what was imported
- **AND** a model whose bounds no longer support the derivation fails rather than producing a
  quietly wrong heading
