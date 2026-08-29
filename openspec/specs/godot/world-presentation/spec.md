# godot/world-presentation Specification

## Purpose
Defines what the player sees before anything moves — the field, its markings, and
its light — and, because the design document specifies lighting in another engine's
units, defines how this port converts that specification into an image without
either copying numbers that do not transfer or choosing an exposure by eye.

## Requirements

### Requirement: The environment matches the specified values

Every element of the design document's environment art SHALL be present at the value
the document gives it, compared against the document rather than restated here.

#### Scenario: Each specified element exists

- **WHEN** the world scene is loaded
- **THEN** the ground, the reference grid, the start/finish band, the sky colour and
  the fog are all present
- **AND** each carries the dimensions, colours and distances the design document
  specifies for it
- **AND** an element the document specifies but the scene omits is a defect, not a
  simplification

#### Scenario: No environment value is written as a literal

- **WHEN** the scripts that build the environment are inspected
- **THEN** no dimension, colour, distance or intensity appears as a literal in them
- **AND** each is read from the tuning data under the name the design document gives
  it, or under a stated name where the document names nothing

#### Scenario: Changing a value in the data changes the image

- **WHEN** a value in the tuning data is edited and the scene is rebuilt
- **THEN** the rendered result reflects the edit with no code change
- **AND** this holds because the scene reads its values rather than carrying copies

### Requirement: The lighting ratios are normative and the scale is not

The design document's three light intensities SHALL be preserved as ratios exactly.
The absolute scale SHALL be treated as this port's to choose, because the document
states intensities in the reference build's units and cannot state them in Godot's.

#### Scenario: The ratios survive the conversion

- **WHEN** the lighting is configured
- **THEN** the relative strengths of the ambient, hemisphere and directional terms
  are those the design document gives
- **AND** they are stored as the document's own numbers rather than as products
  already multiplied by a scale

#### Scenario: One scale governs all three

- **WHEN** the overall brightness is adjusted
- **THEN** a single shared factor scales every light together
- **AND** no light is adjusted independently of the others, because that would
  change the ratios the document does fix

### Requirement: The lighting scale is fixed by measurement, not by eye

The chosen scale SHALL be the outcome of a stated, re-runnable measurement against
criteria recorded before any image is judged, because an exposure chosen by
inspection cannot be defended, reproduced, or re-derived when the renderer changes.

#### Scenario: The criteria precede the captures

- **WHEN** the scale is chosen
- **THEN** the criteria it had to satisfy were written down before the captures were
  taken
- **AND** they are committed alongside the result

#### Scenario: The chosen scale clips nothing

- **WHEN** the scene is rendered at the chosen scale
- **THEN** no pixel anywhere in the frame is saturated in any channel
- **AND** saturation is looked for over the whole image rather than over sample
  regions, because a region clean of it says nothing about the rest

#### Scenario: A lit surface renders as its specified colour

- **WHEN** ground lit by the specified lighting is compared against the albedo the
  design document gives it
- **THEN** they match in both hue and lightness, within a tolerance stated before
  any capture was judged
- **AND** the comparison is made in linear space, because a ratio between colours is
  only scale-invariant there
- **AND** absence of saturation is NOT sufficient on its own: the brightest scale
  that saturates nothing still renders the specified colour far brighter than
  itself, and that must fail

#### Scenario: The choice is determinate rather than preferred

- **WHEN** two people apply the criteria to the same scene
- **THEN** they arrive at the same rendered result, because the scale is defined as
  minimising the lit surface's deviation from its specified colour rather than as
  the one that looked best
- **AND** the criteria select an INTERVAL rather than a point, because an 8-bit
  capture quantises the deviation into a staircase and a run of scales share its
  lowest step
- **AND** any scale in that interval is an equally correct answer; which one a
  search reports is an artefact of the search, not of the criteria

#### Scenario: The measurement can be re-run

- **WHEN** someone later doubts the exposure
- **THEN** the captures can be regenerated from a committed scene and a committed
  tool, and the measurement repeated
- **AND** the tool reports what it measured, not merely a verdict

#### Scenario: A renderer that cannot carry the lighting is reported

- **WHEN** no scale satisfies the criteria under the selected renderer
- **THEN** the finding is recorded with its evidence
- **AND** the renderer is not changed as part of this work, because that trades away
  a shipping target and is a product decision

### Requirement: Specified colours render as themselves

Where the design document specifies a colour, the rendered result SHALL be that
colour. No tone curve that reshapes hue or luminance SHALL be applied, because the
document specifies its look as exact colours and a curve would make them
unreachable by construction.

#### Scenario: The unlit sky is the specified colour exactly

- **WHEN** the rendered sky is sampled
- **THEN** it is exactly the colour the design document specifies
- **AND** any deviation indicates the pipeline is reshaping colour and is treated as
  a defect in the pipeline rather than corrected by adjusting the input colour

#### Scenario: The sky stays flat whatever the lighting is made of

- **WHEN** the lighting is configured by any means
- **THEN** the sky remains a single flat colour with no gradient and no visible
  horizon
- **AND** a lighting arrangement that produces the specified tinting at the cost of
  a flat sky is rejected, because the design document specifies both

#### Scenario: A colour is never pre-distorted to survive the pipeline

- **WHEN** a specified colour is entered into the project
- **THEN** it is entered as the document gives it
- **AND** it is not adjusted to compensate for a transform applied later

### Requirement: The field extends past the drivable area

The ground SHALL extend beyond the boundary the simulation enforces, and nothing
SHALL be drawn to mark that boundary, so that the limit of travel reads as open
field rather than as a wall.

#### Scenario: Ground remains visible beyond the limit of travel

- **WHEN** the view looks outward from the boundary in any direction
- **THEN** ground is visible beyond it, so the limit of travel is not the limit of
  the world
- **AND** no wall, fence, or edge of the ground is drawn or visible
- **AND** ground far enough away to be fogged dissolves into the horizon rather than
  popping

#### Scenario: The boundary is not drawn

- **WHEN** the world is inspected
- **THEN** no wall, fence, marker or ground edge coincides with the boundary
- **AND** the only track furniture present is the start/finish band

### Requirement: The world can be seen before anything moves

The world SHALL be renderable and capturable on its own, without a kart, an input
device or a running simulation, so that changes which build the environment can
produce the visual proof they are required to produce.

#### Scenario: The scene renders with nothing stepping

- **WHEN** the world scene is loaded
- **THEN** it renders a complete environment
- **AND** no simulation is stepped, and nothing in the scene advances over time

#### Scenario: A viewpoint exists and is declared temporary

- **WHEN** the scene is captured
- **THEN** a viewpoint exists from which the environment can be seen
- **AND** it is recorded as a placeholder that a later change replaces, so it is not
  mistaken for the specified chase camera

#### Scenario: The running game uses the specified camera, not the placeholder

- **WHEN** the game runs
- **THEN** the camera the player looks through is the one the design document
  specifies, not the placeholder
- **AND** the placeholder remains available to the world scene's own captures,
  because those must still work with no kart and nothing stepping
