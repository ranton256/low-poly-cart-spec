# Ambiguity register

Places where [the design document](../../low-poly-cart-game-design-document.md)
did not settle something this port had to decide.

**This is a deliverable, not a complaint file.** The repository exists to ask how
much two independent implementations of one specification agree on, and where the
specification was quietly ambiguous. This register is the answer to the second
half, and it is published with the port.

Recording rules — CONSTRAINTS §12 Review criterion R6, and V15:

- Every ambiguity resolved *in code* is entered here **before** the change that
  resolved it is archived.
- An entry names what the specification does not say, what this port decided, and
  why. "We picked one" is not an entry.
- An entry is never deleted. A decision that is later reversed gains a note.

The `A`-numbers are stable and are also listed in CONSTRAINTS §5 Conformance to
the specification, which is the summary; this file is the detail.

---

## Resolved

### A4 — The countdown clock while the simulation is suspended

**The specification says** the game states are LOADING, STARTING and RACING, that
the countdown advances at `countdownStep` intervals during STARTING, and — in
*Frame Loop and Render Pipeline* — that outside RACING "the physics update is
skipped entirely".

**It does not say** what advances the countdown, given that the thing which
advances time is the thing being skipped.

**This port decided:** `Sim.step()` runs on every tick in every state, and only
the kart pipeline (the eight-step tick) is gated on RACING. The countdown is
therefore driven by the simulation clock — 60 ticks per `countdownStep` — and not
by wall time, which keeps the 4.0 s ± 0.1 s acceptance tolerance measurable
headlessly.

**Why:** the alternative — a separate wall-clock timer for the countdown — would
put a second time source in the project, and acceptance item 1's tolerance would
then depend on frame pacing.

*Recorded during `add-godot-project-foundations` (M0). Implemented in M4.*

### A5 — Which position the lap gate and minimap observe

**The specification says** the frame runs physics, then camera, then minimap, then
HUD, then render, and that the kart's visible position, the speedometer and the
minimap marker "always agree within a single frame". It also requires
frame-rate independence via a fixed 60 Hz accumulator with interpolated rendering.

**It does not say** whether the gate and the minimap read the *stepped*
simulation position or the *interpolated* render position, which differ by up to
one tick whenever the display rate is not exactly 60 Hz.

**This port decided:** the stepped position. The view may lag it by up to one
tick.

**Why:** the lap gate is specified as step 8 of the tick, observing "the step-5
integration of this tick". Reading an interpolated position would make lap times
depend on display refresh rate, which acceptance item 14 forbids.

*Recorded during `add-godot-project-foundations` (M0). Implemented in M4.*

### A6 — The kart's "+90° yaw correction" is stated in another engine's frame

**The specification says** a fixed +90° yaw correction must be baked in so the
driver faces world +Z, and that the movement solver must use the same corrected
heading as the visual.

**It does not say** — and cannot, being engine-agnostic — what that correction is
in an engine whose own facing convention differs. The design document's world
forward is +Z; Godot's is −Z.

**This port decided:** the correction is **derived** from the imported glTF
bounds, held in one named constant in the view layer, and evidenced three ways.
The figure "+90°" is never transcribed as a literal.

**The axis** is the longer horizontal extent of the authored box — measured
2.000 × 1.019 × 1.868, so local X — which corroborates §3's own statement that
"the kart's authored long axis is its local X". Deriving rather than assuming it
means a re-exported model authored down a different axis fails loudly instead of
driving sideways.

**The sign** could not come from the bounds: an axis-aligned box is symmetric, so
it identifies the axis and says nothing about which end is the nose. Three
witnesses settle it, and the first is the only one that can:

1. `docs/progress/2026-08-29-m2-kart-front.png` — from the +Z side, showing the
   steering wheel in front of the seat and the floor pan toward the camera, so the
   kart's front faces world forward. The first attempt rendered it tail-first and
   this capture is what caught it.
2. The mesh's **vertex centroid**, +0.0764 from the box centre along the long axis
   — toward the engine, seat and rear tyres. The nose is the end the mass is not
   at, which is local −X, established without reference to the capture.
   `tests/kart_test.gd` checks it, and refuses to speak if a future mesh is too
   symmetric for the heuristic to mean anything.
3. The derived correction is **+90°**, which is what §4 states. That agreement is
   pinned by `tools/check_kart_conformance.py`, which reads the figure from the
   document and compares it against the derivation. If they ever diverge, this
   entry reopens.

**Why not the obvious test.** A 16-heading check that travel matches facing
**passes on a kart driving backwards**: it derives the nose from the same constant
it is testing, so a sign error makes both sides wrong together. Demonstrated by
inverting the sign — the travel test and the footprint check both passed; only the
centroid and the document comparison failed. The test says so in its own header.

**Why it matters:** both frames are right-handed and Y-up, so positions map one to
one and nothing is mirrored — but a node's facing does not. Copying the number
would have been right by luck here, and there was no way to know that in advance.

*Recorded during `add-godot-project-foundations` (M0). Amended during M2
exploration. Resolved in `add-kart-view-orientation-and-input` (M2); see
`docs/progress/2026-08-29-m2-kart.md`.*

### A7 — The sun's orthographic shadow volume has no direct Godot equivalent

**The specification says** the sun's shadow uses "an orthographic shadow volume
spanning **±60 wu** in X and Y with near 0.5 / far 200".

**It does not say** how that maps onto an engine with no explicit orthographic
shadow volume. Godot's `DirectionalLight3D` exposes
`directional_shadow_max_distance` — how far from the *camera* shadows are drawn,
and therefore how thinly the map is spread.

**This port decided:** `directional_shadow_max_distance = 120` — the **±60 wu
volume**, not the far plane of 200.

**Why:** the volume is what governs texel density, and the far plane is a
different quantity. At 120 with a 2048 map the density is 0.0586 wu per texel.

*Correction: an earlier version of this entry claimed a 2048 map over 200 units
put the kart's shadow "below one texel". That is arithmetically wrong — 200/2048
is 0.098 wu per texel against a 2.78 wu kart, about 28 texels. The kart's missing
shadow had a different cause entirely; see A8. The decision stands, the original
reasoning did not.*

*Recorded during `spike-compatibility-renderer-shadows` (M0). Binds M2 and M6.*

### A8 — Godot has two shadow bias parameters; the design document specifies one

**The specification says** the sun's shadow uses "a small negative depth bias
(≈ −0.0001) to suppress acne".

**It does not say** what to do with `shadow_normal_bias`, because the reference
engine has no equivalent. Godot's defaults to **2.0** and is scaled by texel world
size.

**This port decided:** `shadow_normal_bias = 0.1`, set explicitly wherever a
shadow-casting sun is configured.

**Why:** at `max_distance` 120 with a 2048 map — 0.0586 wu per texel — the default
2.0 offsets a caster **0.117 wu** along its normal, about 29% of a kart wheel, and
**erases the kart's contact shadow entirely**. Measured: shadowed ground beneath
the kart rises from **6.5% to 27.2%** when the bias is lowered — measured over the
region `KART_BOX` names in `godot/tools/measure_shadow.py`, and independently
reproduced by review. The
design document names that contact shadow as "the primary cue for where the kart
actually is on the ground", so a default that removes it is the wrong reading of a
specification that mentions only one bias.

*Recorded during `spike-compatibility-renderer-shadows` (M0). Binds M2 and M6.*

### A9 — Light intensities are in the reference build's units, not Godot's

**The specification says** ambient 0.60, hemisphere 0.40, directional sun 1.00.

**It does not say** — and cannot, being engine-agnostic — that those numbers are
in the reference build's units. Applied at face value in Godot under the
Compatibility renderer they saturate **59.75%** of the frame, with the specified
grass `#3D8C40` rendering `[115, 255, 131]`.

**This port decided:** the document's **ratios are normative and its absolute
scale is not**. All three intensities are transcribed unscaled and multiplied by
one shared factor, `port_decisions.lightScale = 0.2809`, so the ratios are
preserved by construction — nothing scales one light alone. Tonemapping stays
**linear**: the document specifies its look as exact hex colours, and a filmic or
ACES curve would make the specified albedo unreachable by construction.

**How the number was chosen:** it is the value **minimising the ground's deviation
from its specified albedo**, subject to nothing saturating and the unlit sky
rendering exactly `#87CEEB`. At 0.2809 the grass renders `[56, 141, 65]` against
the specified `[61, 140, 64]` — deviation 0.0309 against a tolerance of 0.0401
computed from the document's own hemisphere ratio. Scales 5% and 10% either side
deviate more. Reproduce with `tools/find_light_scale.py`; every sample region is a
named constant printed on each run.

**Why not "the largest scale that clips nothing":** that was the rule this change
was approved with, and it returns **0.6882** — the largest scale at which nothing
saturates, and a fluorescent field: grass at `[94, 218, 108]`, a deviation of
1.6756 against a tolerance of 0.0401. It passed every criterion as
written, because the ground criterion constrained hue but not lightness and so
nothing pulled brightness down. Both captures are committed in `docs/progress/`.

**The limit of this result, stated plainly:** preserving the document's ratios is
not the same as reproducing its image. Godot's ambient and the reference build's
`HemisphereLight` are different integrators, and the reference build cannot be run
side by side here. What is established is that the specified colours render as
themselves under the specified lighting, and that the choice is reproducible from
a committed tool. A match against the original is neither claimed nor tested.

*Recorded during `spike-compatibility-renderer-shadows` (M0). Resolved in
`add-world-presentation-layer` (M2). See `docs/progress/2026-08-29-m2-world.md`.*

---

## Open

| # | Ambiguity | Settled by |
|---|---|---|
| A1 | HUD element sizes are given in px (200×200 minimap, 160×90 speedometer, ~120 px countdown) with no design resolution named anywhere | M5 |
| A2 | "A layout file … delivered to the player" — the delivery mechanism is unspecified, and it differs between desktop and web | M7 |
| A3 | Whether prop registration order survives a layout reload. It is unstated, and it changes collision outcomes, because collision resolves the first intersecting prop in registration order | M7 |
| A10 | The chase camera's easing rate is specified **per tick**, but the frame-ordering scenario places the camera update **once per frame**. At 60 fps those are the same sentence; at no other rate are they | M2 |
| A11 | The ground is specified as a finite 200 wu plane, the drivable extent as ±90, and fog as beginning at 50 wu. From the boundary the ground's edge is 10 wu away — far inside fog's start — so it renders as a hard line, while acceptance item 7 asks for grass beyond the boundary and no drawn edge | M6 |

### A10 (open, detail) — The camera eases per tick, but is updated per frame

**The specification says**, in *Chase Camera / Trailing the kart*, that "the camera
position eases toward its target by `chaseSmoothing` per tick (a time constant of
≈ 0.2 s)". It also says, in *Frame Loop and Render Pipeline / Ordering the work
within a frame*, that "the camera is then updated from the kart's post-physics
transform" — once, as one step of one frame.

**It does not say** which governs when a frame does not contain exactly one tick.
The reference build runs tick and frame together at ~60 fps, where the question
cannot arise. A port with a fixed-step accumulator faces it on every frame that is
not 1/60 s long:

| | eased per tick | eased per frame |
|---|---|---|
| 30 fps | 2 eases · time constant 0.2 s ✓ | 1 ease · 0.4 s ✗ |
| 60 fps | 1 ease · 0.2 s ✓ | 1 ease · 0.2 s ✓ |
| 144 fps | 0 or 1 ease · 0.2 s ✓ | 1 ease · 0.083 s ✗ |

Per-frame easing gives a camera that snaps tighter on a fast display and wallows on
a slow one — frame-rate-dependent behaviour, which the *Reference Tick* section
calls non-conformant in the general case.

**This port leans to easing per tick**, reading the frame-ordering scenario as
"after this frame's ticks" rather than "once per frame". That reading is not
free — it makes the ordering scenario's *sequence* normative and its *cardinality*
incidental — which is exactly why it is recorded rather than assumed. Recording it
also protects the decision: read literally, the ordering scenario invites someone
later to "fix" the camera back into frame-rate dependence.

**Owner: M2**, the change that builds the chase camera. It settles alongside the
decision to implement the camera as a pure module in `scripts/core/`, stepped by
the composition root immediately after `sim.step()` — which is what makes "per
tick" the natural implementation rather than the awkward one.

*Recorded during M2 exploration. Open.*

### A11 (open, detail) — A finite ground cannot have an invisible edge

**The specification says**, in *World Boundary Containment / Keeping the boundary
invisible*, that when the kart is held against the boundary "there is still
visible grass beyond the kart in every direction" **and** "no wall, fence, or
edge of the ground is drawn or visible". The same scenario opens by giving the
ground plane as spanning **±100 wu**, §5 sizes it at 200 × 200, the drivable
extent is **±90**, and fog runs from **50 wu** to 150.

**It does not say** how those numbers coexist. They leave **10 wu** of ground
beyond the boundary, and fog does not begin until 50 wu, so from the boundary the
plane's edge is five times nearer than the nearest fogged distance. It is drawn,
and the scenario says it must not be.

**What it actually looks like matters, and is less alarming than it sounds.**
`docs/progress/2026-08-29-m2-boundary.png` is taken from x = +90 — the boundary
the scenario names — at roughly the chase camera's eye height, looking outward.
The edge presents as a horizon: a straight line where grass meets sky, 10 wu away
and indistinguishable at that eye height from the horizon of a plane that never
ends. An earlier version of this capture used an elevated oblique viewpoint 28 wu
inside the limit, where the same edge reads unmistakably as an edge. Both are
true; only the first is the view the scenario describes, and only the first is
what a player at the boundary will see.

**This port has NOT decided**, and the ways out are more numerous than an earlier
version of this entry claimed. It asserted that all three options — enlarging the
plane past ±100, pulling fog nearer than 50 wu, or accepting a visible edge — break
something the document states. Review pointed out a fourth that breaks nothing: a
distant skirt of ground in the same albedo, beyond about ±240, leaves §5's Ground
exactly 200 × 200 at Y = 0, leaves fog at 50 → 150, and puts every edge past fog's
end from anywhere in the drivable area. Whether that is the right answer is a
question about the look; that it exists means "every resolution breaks one of the
document's own numbers" was an assertion this entry had not earned.

What decides it is how the edge reads through the specified chase camera, whose
pitch and field of view do not exist yet.

**Owner: M6**, which owns the look and the visual conformance gate, with the chase
camera change expected to sharpen the question first.

*Recorded during `add-world-presentation-layer` (M2). Open.*

An open entry is not a licence to decide quietly later. Whichever change settles
one moves it above the line, with its reasoning, before it is archived.
