# godot/hud Specification

## Purpose
TBD - created by archiving change add-heads-up-display. Update Purpose after archive.

## Requirements

### Requirement: HUD px values are literal at the 1280×720 design resolution

Every §7 px value SHALL be interpreted at the project's 1280×720 viewport
(ambiguity A1's settlement), with `canvas_items` stretch scaling the canvas
for other window sizes. Sizes and colours SHALL come from the data layer,
never as script literals.

#### Scenario: The dial is 160×90 at design resolution

- **WHEN** the HUD is built
- **THEN** the speedometer control's size is the data layer's 160×90 and the
  timer block anchors top-right, both in design-resolution pixels

### Requirement: The needle eases on the simulation clock

The needle's ~0.1 s easing SHALL advance per simulation tick — never per
rendered frame and never from wall time — so its motion is a function of the
tick count like every other animation.

#### Scenario: The needle position is reproducible

- **WHEN** two runs present the same tick sequence
- **THEN** the needle angle at any tick is identical, and a frame rendered
  twice without a tick between draws the same needle

### Requirement: The HUD draws core values and computes none of them

The readout SHALL be the core's `speedo_readout()`, the needle sweep SHALL be
`(speed_ratio × 180°) − 90°` from the core's ratio, and the timer block SHALL
keep M4's lap-counter derivation. No HUD element intercepts pointer input;
every element reads the post-physics snapshot.

#### Scenario: The dial readout is the core's number

- **WHEN** the kart holds steady-state forward speed
- **THEN** the readout label shows the core's 115 and the needle angle is the
  formula's, within easing

### Requirement: The broken-model boot is provable through the real driver

`PropField` SHALL expose a load seam (an env override, `LPC_FAIL_LOADS`, in
the `LPC_SAVE_FILE` tradition) that makes model loading report failure, so a
suite can boot the real scene into the terminal LOADING error — the visible
message and the developer-log line — without damaging any asset.

#### Scenario: A forced load failure halts the real boot visibly

- **WHEN** the main scene boots with the seam active
- **THEN** the state stays LOADING, the loading label shows the error, and
  the failure was pushed to the log
