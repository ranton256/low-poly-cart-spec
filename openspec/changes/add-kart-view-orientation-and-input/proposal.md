## Why

The simulation has been correct since M1 and has never been driven. `add-world-presentation-layer`
built a field with nothing in it. This is the change where the two meet: a composition root
that steps the simulation at a fixed rate, a kart that shows where it is, and input that
reaches it.

It implements the design document's **§4 Kart orientation contract**, the *Input Handling*
feature, and the *Placing the kart at the start line* scenario of *Session Bootstrap and
Asset Normalisation*, and it makes the *Reference tick*'s accumulator requirement real:

> A port MUST be frame-rate independent, and MUST achieve it with a fixed 60 Hz accumulator.

**Acceptance items.** Closes **3** — the kart drives in the direction it visually faces, at
every heading, forward and reverse — and **11**, releasing focus mid-throttle stops the kart
driving away. Item 8 needs the chase camera and is `add-chase-camera`'s.

**The risk is item 3, and it is not where it looks.** §4 warns that a port getting this wrong
produces "a kart that crabs sideways, which is the classic failure of this asset". The
non-obvious part is that the natural test for it **passes on a kart driving backwards**: a
16-heading check compares travel against a nose direction derived from the yaw correction, so
deriving that correction with the wrong sign compares a wrong nose to a wrong heading and
agrees with itself at all 16. Ambiguity **A6** records this and what settles it instead.

**GDD scenarios: four.** *Placing the kart at the start line*, *Mapping the control scheme*,
*Clearing stuck inputs on focus loss*, and *Ignoring unbound keys* move from deferred to
verified. Two Input Handling scenarios — *Tracking held inputs as continuous state* and
*Combining simultaneous inputs* — are already verified against the core and are not re-claimed.

## What Changes

- **A composition root** in `scenes/main.tscn`: it loads tuning, constructs the simulation,
  owns a fixed 60 Hz accumulator, and is the only caller of `Sim.step()`. It calls the
  simulation's `begin_frame()` once per rendered frame — the seam
  `add-determinism-and-coverage-harness` built for exactly this and left empty.
- **Render interpolation.** The view draws between simulation states rather than at them, and
  advances nothing itself.
- **The kart**, normalised through the §3 contract already implemented in
  `scripts/core/normalise.gd` and placed at the start line: X = 0, Z = 0, wheels at Y = 0,
  facing world +Z, velocity 0.
- **The yaw correction of §4**, held in one named constant. Its **axis** comes from the
  imported bounds and is corroborated by §3's statement that the kart's authored long axis is
  its local X; its **sign** comes from a committed capture, with a vertex-centroid measurement
  as a mechanical second witness. The document's "+90°" is never transcribed as a literal.
- **A conformance check against the design document, not against our own data.** §3 states the
  kart's final world footprint as **2.36 × 2.20** and §1 its authored bounding box as
  2.000 × 1.019 × 1.868. Those are numbers the document owns, so the built kart is asserted
  against them rather than against `tuning.json`, which is where every other check in this
  project bottoms out.
- **Input**, from the engine to the simulation's held-state model: the bindings §*Mapping the
  control scheme* specifies with both key sets equivalent, held state that persists across
  ticks, clearing on focus loss, and unbound keys changing nothing and polluting no log.
- **Visual proof**: the kart at the start line, and mid-turn at speed.

**Not in this change**: the chase camera and its FOV curve (`add-chase-camera` — the
placeholder viewpoint stands until then), props and collision (M3), the state machine and
countdown (M4), and the **effects** of the `R` and `P` bindings, which invoke actions that do
not exist until M7. This change declares those two bindings and verifies they are bound; it
does not make them do anything.

## Capabilities

### New Capabilities

- `godot/simulation-driver`: how the simulation is driven and drawn — a fixed-step accumulator
  owning the only call to `step()`, a per-frame entry point, and a view that interpolates
  between states without advancing anything. This is what makes the game frame-rate
  independent in fact rather than in the core alone.
- `godot/kart-presentation`: the kart as the player sees it — normalised to its specified size,
  standing at the start line, and facing the direction it travels at every heading. Includes
  the rule that the orientation correction is derived and evidenced rather than transcribed,
  and that a consistency test is not an orientation test.
- `godot/input-handling`: how the engine's input reaches the simulation — the specified
  bindings, held state, release on focus loss, and silence on unbound keys.

### Modified Capabilities

None. `godot/world-presentation`'s requirement that the world render with nothing stepping
stays true because `scenes/world.tscn` remains standalone and static; the composition root
lives in `main.tscn`, which instantiates it. `godot/project-configuration`'s tuning requirement
already covers a running reader, and this change adds a second one rather than changing what is
required.

## Impact

- **New**: `godot/scripts/main.gd` (the composition root), `godot/scripts/view/` for the kart
  view and the orientation constant, `godot/tests/kart_test.gd`, `godot/tests/input_test.gd`,
  `godot/tools/check_kart_conformance.py`, captures in `godot/docs/progress/`.
- **Modified**: `godot/scenes/main.tscn`, `godot/project.godot` (the input map),
  `godot/tools/check_settings.py` (to pin the bindings), `godot/data/scenario_register.json`
  (four scenarios move to verified), `godot/docs/AMBIGUITIES.md` (**A6** moves to Resolved with
  its evidence).
- **Risk — the one that matters**: the 16-heading test proves travel and facing are
  *consistent*, not that the facing is *correct*. A 180° error passes it. The capture is the
  only artefact that can see which end is the nose, and the centroid measurement is a second
  witness rather than a proof. This limit is stated in the test itself, not just in A6.
- **Risk**: Godot 4 has built-in physics interpolation as well as the manual
  `Engine.get_physics_interpolation_fraction()` route the roadmap names. They differ in what
  gets interpolated and in how a per-tick-eased camera behaves later. Design D2 decides it, and
  the decision binds `add-chase-camera`.
- **Backlog**: closes `att` 11 (focus loss clears held input) and `att` 13 (the simulation's
  loader wired into the running game). Closes the start-pose half of `att` 10; the Reset Kart
  action stays open for M7.
- **Ambiguities**: settles **A6**. **A10** — whether the camera eases per tick or per frame —
  is sharpened here, because the accumulator is what makes "per tick" meaningful, but it is
  settled by `add-chase-camera`, which builds the camera.
- **Verification criteria touched**: none change status. V2 and V19 gain new files; V14's
  visual-proof expectation applies.
