## Purpose

Defines how an instance of a supplied model is sized, grounded and bounded — the
transform from an authored bounding box to a placed instance, and the
world-axis-aligned box that follows — so that props stand on the ground rather
than in it, and so collision has a box to test that matches the design document's
own numbers.

## ADDED Requirements

### Requirement: Normalisation follows the specified order

An instance SHALL be normalised by measuring its box, scaling it uniformly to its
target height, **re-measuring**, and only then computing its offset. The order is
the contract, not an implementation detail.

#### Scenario: The offset is computed from the scaled box, not the authored one

- **WHEN** a model whose authored height differs from its target height is normalised
- **THEN** the vertical offset places the **scaled** instance's lowest point at zero
- **AND** an implementation that reused the pre-scale measurement would place it
  somewhere measurably different

#### Scenario: Scaling is uniform

- **WHEN** a model is scaled to its target height
- **THEN** the same factor is applied to all three axes
- **AND** the instance's proportions are unchanged

### Requirement: An instance rests exactly on the ground

After normalisation an instance's lowest point SHALL be at zero height, and its box
SHALL be centred horizontally on its transform position.

#### Scenario: The lowest point is exactly at ground level

- **WHEN** any supplied model is normalised to any target height
- **THEN** the lowest point of its box is at zero, within floating-point tolerance
- **AND** it is neither above the ground nor below it

#### Scenario: The transform position is a ground-contact point

- **WHEN** an instance is placed at a horizontal position
- **THEN** its box is centred on that position in both horizontal axes
- **AND** the position therefore names where the instance touches the ground

#### Scenario: An authored box that is not centred on its origin still grounds

- **WHEN** a model arrives with its box offset from its own origin
- **THEN** normalisation still places the lowest point at zero and centres the box
  horizontally
- **AND** the authored offset does not leak into the result

### Requirement: Scale variation is applied on top, and re-grounded

Where a model is placed with random size variation, that factor SHALL be applied
after target-height normalisation, and the instance SHALL be re-grounded afterwards.

#### Scenario: A varied instance still rests on the ground

- **WHEN** an instance is scaled by any factor within the permitted variation
- **THEN** its lowest point is at zero after that scaling
- **AND** this holds at both extremes of the permitted range

#### Scenario: Variation compounds with the target height, not instead of it

- **WHEN** an instance is normalised to a target height and then varied
- **THEN** its final height is the target height multiplied by the variation factor
- **AND** the resulting heights span the range the design document states for that asset

#### Scenario: Repeated normalisation does not drift

- **WHEN** an already-normalised instance is normalised again with the same target
- **THEN** its size and position are unchanged
- **AND** repeating the operation does not progressively shrink or grow it

### Requirement: An instance has a world-axis-aligned box at any heading

An instance SHALL yield a world-axis-aligned box computed from its current heading,
because that is what collision tests against and it changes as the instance turns.

#### Scenario: The box grows when the instance is turned off-axis

- **WHEN** an instance is rotated away from the world axes
- **THEN** its world-axis-aligned box is larger than when it is axis-aligned
- **AND** this is accepted rather than corrected, because the design document
  chooses the cheap axis-aligned test over an oriented one

#### Scenario: The box matches the design document at a known heading

- **WHEN** the kart is normalised and placed at the heading it starts at
- **THEN** its world extents are the ones the design document states for that pose
- **AND** contracting the box by the specified amount per side yields the
  contracted hitbox the collision feature cites

#### Scenario: Vertical extent is unaffected by heading

- **WHEN** an instance is rotated about the vertical axis by any angle
- **THEN** its height is unchanged
- **AND** its lowest point remains at ground level

### Requirement: Target heights are data, not literals

Each asset's target height SHALL live in the tuning data under the name the design
document gives that asset, and SHALL be supplied to the normalisation rather than
compiled into it.

#### Scenario: A target height is read from the tuning data

- **WHEN** normalisation is asked for an asset's target height
- **THEN** the value comes from the tuning data
- **AND** no target height appears as a literal in the scripts

#### Scenario: The tuning gate covers the added values

- **WHEN** the tuning data is checked against the design document
- **THEN** the per-asset target heights are among the values verified
- **AND** a drifted or renamed one fails the standing suite
