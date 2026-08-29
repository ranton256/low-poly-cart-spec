## Why

Nothing in this project has ever been drawn. `scenes/main.tscn` is a bare `Node3D`,
`tuning.json` still records `readers: "None yet"`, and the simulation that M1 proved
correct has never been connected to anything a player could look at.

M2 is where the game first runs, and this is the change that gives it somewhere to
run. It builds the field: the ground, the reference grid, the start/finish band, the
sky, the fog and the three lights of the design document's **§5 Environment art**
and **§6 Lighting** — every element of which is authored in code, not supplied as a
file, so none of it exists until someone writes it.

It also has to settle **A9**. The design document's light intensities are in the
reference build's units; applied at face value under Compatibility they saturate most of
the frame and render the specified grass `#3D8C40` at green 255. The renderer
spike measured 67% on its own probe scene; this change measures **59.75%** on the
environment it builds. The renderer spike
recorded that and deliberately left it open, because judging shadows on a blown-out
frame is sound but choosing an exposure is not a shadow question. This is the first
change that has to make the game *look right* rather than merely cast a shadow, so
the register names it the owner.

**Acceptance items.** This change completes none of the fourteen on its own. It
establishes part of **item 7**: the ground is 200 wu across against a drivable
extent of ±90, so there are 10 wu of grass beyond the boundary in every direction,
and no wall or fence is drawn. It does **not** satisfy the rest — the ground
plane's own edge IS visible from the boundary, which *Keeping the boundary
invisible* forbids, and ambiguity **A11** records why the document's own numbers
make it unreachable. This change is also a precondition for **3** and **8**, which
cannot be captured until something exists to see.

**GDD scenarios.** §5 and §6 are specification tables, not features with scenarios,
so this change claims none as verified. It does, however, produce the first evidence
about one: *World Boundary Containment / Keeping the boundary invisible*, and that
evidence shows it **failing**. The register records it as `unmet` and the coverage
gate now prints that separately from `visual`, so a scenario the project knows it
does not meet cannot be counted as covered. An earlier version of this paragraph
said the gate's count "does not move" and offered that as proof nothing was
over-claimed — which is the one place in this change where a green gate was saying
something the change knew to be false.

## What Changes

- **The environment.** Ground plane 200 × 200 wu at Y = 0 in grass `#3D8C40`,
  roughness 0.9, metalness 0.0, receiving shadows and casting none. A wireframe
  reference grid over the central 100 × 100 wu at 20 divisions, drawn 0.01 wu above
  the ground, centre axes `#555555` and minor lines `#333333`. A flat unlit white
  start/finish band, 10 wu × 2 wu, centred at (0, 0.02, +5), 80% opaque and visible
  from both sides. Flat sky `#87CEEB` with no skybox or gradient, and linear fog in
  the same colour from 50 wu to fully opaque at 150 wu.
- **The three lights**, with the document's ratios preserved exactly: ambient white
  0.60 as a flat Godot ambient, hemisphere `#87CEEB` → `#228B22` 0.40 as two
  non-shadowing directional fills each at the full specified intensity, and a
  directional sun at (30, 50, 30) aiming at the origin, carrying the shadow
  configuration `spike-compatibility-renderer-shadows` settled (A7, A8). The
  hemisphere expression is **design D2a**: sky-sourced ambient was tried first, as
  D2 specified, and rejected because it makes Godot draw the sky and lose §5's flat
  sky. `tools/check_sky_ambient.sh` regenerates that evidence.
- **A9 is settled by measurement.** Tonemapping stays linear, the ratios are
  preserved, and the single shared intensity scale is chosen as **the value making
  the specified ground albedo render as itself**, verified to saturate nothing —
  found by search with a committed tool, against criteria written before any capture
  is judged. That rule is **design D3a**: the original "largest scale that clips
  nothing" was implemented, produced a fluorescent field, and is kept as a committed
  counterexample. A9 moves above the line in `docs/AMBIGUITIES.md` with its evidence.
- **New tool** `tools/measure_exposure.py`, sibling to the spike's
  `measure_shadow.py`: reports clipped-pixel fraction per channel and the rendered
  colour of a named region against its specified albedo.
- **The §5 and §6 constants enter `tuning.json`** — colours, fog distances, ground
  material values, light intensities, sun position and shadow settings — and the
  transcription gate is extended to cover them, as `asset_target_heights` was.
- **The running game reads `tuning.json` for the first time** — through a new
  `scripts/art_tuning.gd`, not through `scripts/tuning_loader.gd`, which builds the
  simulation's `Tuning` and has no use for a sky colour. One file, two readers with
  different needs, so "exactly one home" is unaffected. The scene reads its
  dimensions and colours from the data rather than carrying them as literals, which
  is what puts the new constants under the tuning-literal gate. **`att` 13 stays
  open**: it asks for the simulation's loader to be wired, and that waits for
  `add-kart-view-orientation-and-input`.
- **A static camera ships with the scene.** The chase camera is a later change, but
  visual proof is mandatory for a milestone and expected for any task that changes
  what the player sees — so without a camera here, neither this change nor the kart
  change that follows could be captured at all. It is explicitly a placeholder and
  `add-chase-camera` replaces it.
- **Visual proof**: committed captures of the field at the settled exposure, and the
  before/after that justifies the A9 decision.

**Not in this change**: the kart, props, input, the chase camera, the HUD, the
minimap, the state machine, and the countdown. The composition root and its
fixed-step accumulator belong to `add-kart-view-orientation-and-input` — this change
renders a static world and steps nothing.

## Capabilities

### New Capabilities

- `godot/world-presentation`: what the player sees before anything moves — the
  ground, grid, band, sky, fog and lights at their specified values; the rule that
  the design document's lighting *ratios* are normative while the absolute scale is
  this port's to choose; and the requirement that the scale be chosen by committed
  measurement rather than by eye.

### Modified Capabilities

- `godot/project-configuration`: **Tuning constants have exactly one home** — its
  scenario *"Transcription alone changes no behavior"* asserts that nothing in the
  project reads the tuning file yet. This change makes that false — the running game
  reads it through `scripts/art_tuning.gd` — so the requirement gains a scenario
  about the running game reading its values instead.

## Impact

- **New**: `godot/scenes/world.tscn` and the scripts that build the environment,
  `godot/tools/measure_exposure.py`, captures under `godot/docs/progress/`.
- **Modified**: `godot/scenes/main.tscn` (currently an empty `Node3D`),
  `godot/data/tuning.json` (§5/§6 constants), `godot/tools/check_tuning_transcription.py`
  (to cover them), `godot/docs/AMBIGUITIES.md` (**A9** moves to Resolved),
  `CONSTRAINTS.md` (A9's row, A10 and A11), `godot/GOTCHAS.md`,
  `godot/tools/{capture.sh,check_tuning_transcription.py}`, `godot/tests/capture_scene.gd`.
- **Risk — the honest one**: preserving the document's *ratios* is not the same as
  preserving its *look*. Godot's ambient term and the reference build's
  `HemisphereLight` are different integrators, so a faithful ratio can still produce
  a different image. The measurement pins exposure and clipping; it cannot certify
  that the result matches an implementation we cannot run side by side. That limit
  belongs in the A9 entry when it moves above the line.
- **Risk, and it landed**: sky-sourced ambient may behave differently under
  Compatibility than under Forward+. It did — it draws the sky and ignores the flat
  background colour — so the hemisphere term is expressed differently (D2a) and the
  substitution is recorded with a re-runnable tool rather than made silently.
- **Also new**: `godot/scripts/art_tuning.gd`, `godot/tests/world_test.gd`,
  `godot/tools/find_light_scale.py`, `godot/tools/check_sky_ambient.sh`,
  `godot/scenes/{world,boundary_view}.tscn`.
- **Backlog**: `att` 13 stays open — it asks for the simulation's loader to be wired
  into the running game, which waits for `add-kart-view-orientation-and-input`.
  Raises `att` 15 for A11. Does not touch `att` 6, which is M3's.
- **Verification criteria touched**: none change status. V5 gains the §5/§6 values
  as newly searchable literals; V14's visual-proof expectation applies.
