## Why

The kart drives, and you watch it from a placeholder camera parked in the field.
This change gives the game the camera the design document specifies — the last of
M2, and the change that closes the milestone.

It implements the *Chase Camera* feature's first three scenarios and settles
ambiguity **A10**, which `add-kart-view-orientation-and-input` sharpened and left
open because the camera is where the question is answered.

**Acceptance item 8**: the camera lags through turns and settles behind the kart,
and the field of view visibly widens with speed. That completes M2's acceptance
items — 3 and 11 landed with the kart.

**GDD scenarios: three.** *Trailing the kart*, *Lagging through a turn*, and
*Widening the field of view with speed* move from deferred to verified, taking
M2's deferred count to zero. *Absorbing a collision jolt* is the fourth in the
feature and belongs to M3, which introduces the collisions that shake it.

**Why this is worth doing carefully.** The document specifies the easing as a
per-tick recurrence with a time constant of ≈0.2 s, and specifies the camera
update as one step of one frame. Those are the same sentence at 60 fps and
different behaviour everywhere else: eased per frame, the camera snaps tighter on
a fast display and wallows on a slow one, which the *Reference Tick* section calls
non-conformant. A10 records the tension; this change resolves it.

## What Changes

- **`scripts/core/chase_camera.gd`** — a pure module, no engine types, stepped
  once per tick by the composition root immediately after `Sim.step()`. Position
  eases toward its target by `chaseSmoothing`; the aim point is computed without
  smoothing, so the horizon stays level while the position lags.
- **A10 is settled**: the easing is **per tick**, not per frame. The frame-ordering
  scenario's *sequence* is normative and its *cardinality* is incidental — the
  camera is updated after the frame's ticks, however many there were.
- **The field of view** is `fovBase + speedRatio × (fovMax − fovBase)`, a pure
  function of the simulation's own speed ratio, continuous as the kart accelerates.
- **The placeholder camera is replaced.** `add-world-presentation-layer` shipped a
  static viewpoint at a written-down transform, explicitly temporary; this is the
  change that was named as replacing it.
- **A settle-time test** for acceptance item 8: after a turn ends the camera
  returns behind the kart within the ≈0.5 s the document states — a number, not a
  judgement, which is what putting the camera in the core buys.
- **Visual proof**: the camera trailing at speed, mid-turn showing the swing-wide,
  and the field of view at rest against at steady-state top speed.

**Not in this change**: the collision shake (M3), the minimap's own camera (M5),
and the frame-ordering scenario in full, which needs the HUD and minimap and is
M5's. This change orders physics → camera only, which is the half M2 can verify.

## Capabilities

### New Capabilities

- `godot/chase-camera`: where the camera sits, what it looks at, how it lags, and
  how its field of view responds to speed — expressed as a fixed-step recurrence so
  the result does not depend on the display rate, and so "settles behind the kart"
  is measurable rather than judged.

### Modified Capabilities

- `godot/world-presentation`: **The world can be seen before anything moves** — its
  scenario *"A viewpoint exists and is declared temporary"* requires the viewpoint
  be recorded as a placeholder a later change replaces. This is that change, so the
  requirement gains the other half: `scenes/world.tscn` still ships a viewpoint for
  its own captures, and the running game now uses the specified camera instead.

## Impact

- **New**: `godot/scripts/core/chase_camera.gd`, `godot/scripts/view/camera_view.gd`,
  `godot/tests/camera_test.gd`, captures in `godot/docs/progress/`.
- **Modified**: `godot/scripts/main.gd` (steps the camera after the simulation),
  `godot/scenes/main.tscn`, `godot/data/scenario_register.json` (three scenarios
  verified), `godot/docs/AMBIGUITIES.md` (**A10** resolved), `CONSTRAINTS.md`,
  `ROADMAP.md` (M2 complete).
- **Risk**: the camera is cosmetic, and putting cosmetic state in `scripts/core/`
  is a judgement that could look wrong later. It earns its place by being a
  fixed-step recurrence whose correctness is a matter of numbers, and because
  `scripts/core/` is the only directory the boundary gate polices — a pure module
  is testable anywhere, but only here is it *held* to staying pure. The boundary
  still holds: no engine types, and the view reads it.
- **Risk**: interpolation. `add-kart-view-orientation-and-input` draws the kart
  between simulation states. A camera eased per tick and then interpolated per
  frame is smoothed twice, and the second smoothing is one nobody specified.
  Design D3 decides what the camera does about it.
- **Backlog**: nothing closed. `att` 15 (A11, the ground's visible edge) is
  sharpened by this change — the specified camera's pitch and field of view are
  what M6 needs in order to judge that, and this change should say what it sees.
- **Ambiguities**: settles **A10**. Does not touch A11, which M6 owns.
- **Verification criteria touched**: none change status.
