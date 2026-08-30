# godot/render-pipeline — delta for add-render-pipeline-and-web-budget

## ADDED Requirements

### Requirement: A capture is the frame it claims to be

Capture tools SHALL grab the viewport only after the renderer has presented a
frame reflecting the reported simulation state (`RenderingServer`'s
frame-post-draw signal), and SHALL fail rather than write a frame that does
not correspond to it. Settle behaviour is measured, not guessed: the recorded
noise floor comes from diffing two captures of an identical state.

#### Scenario: A stale frame cannot become evidence

- **WHEN** a capture is requested after N driven ticks
- **THEN** the written frame shows the state after N ticks — never the
  countdown of a run that ended hundreds of ticks earlier

### Requirement: The ground's edge sits beyond the fog (A11's settlement)

The world SHALL carry a ground skirt in the ground's own albedo from beyond
the specified 200×200 plane out past the fog's end, so that from anywhere in
the drivable area no ground edge is drawn nearer than full fog — while §5's
Ground, the ±90 boundary, and the 50→150 fog remain exactly as the document
states them. The skirt has no grid, casts nothing, and takes no part in
collision or scatter.

#### Scenario: Looking out from the boundary

- **WHEN** the kart is held against the boundary and the chase camera looks
  outward
- **THEN** visible grass continues beyond the kart and every ground edge lies
  past the fog's end

### Requirement: The minimap does not look through fog

The minimap camera SHALL carry its own Environment with fog disabled — the
map is an instrument, and an instrument's job is legibility. Nothing else
about the shared world changes; the main view's fog is untouched.

#### Scenario: The map stays legible at any altitude of fog

- **WHEN** the main view is fogged per §5
- **THEN** the minimap renders the field unfogged

### Requirement: Render density is bounded and resize is survivable

The effective render scale SHALL be capped at 2× where the display reports a
higher device pixel ratio, and a resized window SHALL leave every HUD element
unclipped and correctly anchored with the minimap keeping `minimapSize` and
`minimapInset` — the project's stretch mode does the scaling, and a test
proves the survival.

#### Scenario: A resize leaves the instruments intact

- **WHEN** the window size changes
- **THEN** the minimap's size and inset values are unchanged and every HUD
  anchor still resolves on screen

#### Scenario: A very dense display does not quadruple the render cost

- **WHEN** the reported device pixel ratio exceeds 2
- **THEN** the applied scale factor is exactly 2

### Requirement: The web payload fits its budget

The project SHALL carry a Web export preset, and the compressed export SHALL
fit the 25 MB budget of CONSTRAINTS §8 Performance and size budgets. The
cold-load half of that table lands with M8's web smoke.

#### Scenario: The export is measured, not assumed

- **WHEN** the web export is built and compressed
- **THEN** its size is measured and recorded against the 25 MB budget
