# Ambiguity register

Places where [the design document](../../low-poly-cart-game-design-document.md)
did not settle something this port had to decide.

**This is a deliverable, not a complaint file.** The repository exists to ask how
much two independent implementations of one specification agree on, and where the
specification was quietly ambiguous. This register is the answer to the second
half, and it is published with the port.

Recording rules — CONSTRAINTS §12 Review's archive checklist (register
current before archive) and §10's V15:

- Every ambiguity resolved *in code* is entered here **before** the change that
  resolved it is archived.
- An entry names what the specification does not say, what this port decided, and
  why. "We picked one" is not an entry.
- An entry is never deleted. A decision that is later reversed gains a note.

The `A`-numbers are stable and are also listed in CONSTRAINTS §5 Conformance to
the specification, which is the summary; this file is the detail.

---

## Resolved

### A1 — HUD px values had no design resolution

**The specification says**, throughout §7, sizes in pixels — a 200×200 minimap,
a 160×90 speedometer, a ~120 px countdown face — and never names the resolution
those pixels are measured against.

**The port resolves** (add-heads-up-display): px values are literal at the
project's **1280×720** viewport (`window/size/viewport_width/height`), which is
therefore the design resolution. The project's `canvas_items` stretch with
`expand` aspect scales the whole canvas for other window sizes, so every element
keeps its proportions and anchors without any per-element arithmetic. All §7
sizes and colours live in `data/tuning.json`'s `unnamed_in_spec` group and are
asserted at these literal values by `tests/hud_test.gd`.

One §7 sentence is self-tense under this resolution and is resolved as a
recorded deviation rather than silently: the speedometer's unit label and
readout are specified "beneath the pivot", but the pivot sits on the 160×90
element's own bottom edge, inset 16 px from the screen — 30 px of text cannot
sit strictly below it. The text sits inside the dial face, centred on the
pivot's x, which the hud suite asserts.

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

### A10 — The camera eases per tick, but is updated per frame

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

**This port decided: per tick.** The camera is a module in `scripts/core/`,
advanced by the composition root immediately after `Sim.step()`. The frame-ordering
scenario's **sequence** is read as normative — physics, then camera — and its
**cardinality** as incidental: the camera is updated after the frame's ticks,
however many there were.

**Why:** the *Reference Tick* section requires frame-rate independence in general
terms and calls a naive per-frame port non-conformant. Reading the ordering
scenario literally would contradict a stronger and more general statement in the
same document.

**What this gives up, stated plainly:** at a display rate below the tick rate the
camera is updated more than once per frame, which the ordering scenario, read
literally, does not describe. That is the cost, and it buys a camera that behaves
identically on every display.

**Evidence.** The time constant measures 0.200 s against the document's ≈0.2 s, and
settling 0.450 s against its "roughly half a second" — both predicted from
`chaseSmoothing` before being measured, in a commit that precedes them
(`docs/camera_thresholds.md`). `camera_test.gd` compares four tick-to-frame
groupings against a one-per-frame reference and fails on all four when the easing
is moved to a per-frame call — though that check holds by construction and can only
be broken by editing the test, so it is a regression guard rather than a
demonstration. `driver_test.gd` carries the demonstration: it asserts the running
game advances the camera exactly once per simulation step, and fails both when the
camera is stepped again per frame and when it is not stepped at all.

*Recorded during M2 exploration. Resolved in `add-chase-camera` (M2); see
`docs/progress/2026-08-29-m2-camera.md`.*


### A2 — How the layout file reaches the player (RESOLVED)

**The specification says** a layout file "is produced and delivered to the
player", and nothing about the mechanism — which necessarily differs between
a desktop process with a filesystem and a browser sandbox without one.

**The port resolves** (add-layout-persistence): on desktop, Save Layout
writes `track_layout.json` to the user data directory and prints the
absolute path — a real file in a real folder. On the web, the same bytes are
offered as a browser download through the JS bridge (exercised at M8's web
smoke). Loading reads the same location, bound to `L` (`load_layout`,
pinned in `check_settings.py`); `LPC_LAYOUT_FILE` overrides the path so no
suite ever touches a real user file.

*Recorded during M2 exploration. Resolved in M7.*

### A3 — Registration order through a layout reload (RESOLVED)

**The specification says** collision resolves "the first intersecting prop in
registration order", and separately that a restored layout registers each
prop as a solid obstacle — without saying whether the order survives.

**The port resolves** (add-layout-persistence): export writes records in the
field's registration order, and import registers in the file's record order,
through the same `build()` path regeneration uses. `layout_test.gd` asserts
the collision array element by element across the round trip — a reloaded
track collides identically to the one that was saved.

*Recorded during M2 exploration (CONSTRAINTS §4 Architectural boundaries
carries the ordering contract). Resolved in M7.*

### A11 — A finite ground cannot have an invisible edge (RESOLVED)

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

**Resolved in M6** (`add-render-pipeline-and-web-budget`), by the fourth
option: a `GroundSkirt` plane in the Ground's own albedo, spanning
`groundSkirtSize` (800 wu — nearest edge ≥ 310 wu from any drivable position,
against a 150 wu `fogEnd`), a hair below Y = 0. §5's Ground stays exactly
200×200, the boundary ±90, fog 50→150. Judged through the specified chase
camera at the pinned boundary: grass dissolves into fog with no drawn edge —
`docs/progress/2026-08-29-m6-boundary-skirt.png`, with the guaranteeing
geometry asserted by `world_test.gd`.

*Recorded during `add-world-presentation-layer` (M2). Resolved in M6.*


### A14 — What "replayed at 30, 60, and 144 fps" quantifies over (RESOLVED at M8)

**The specification says** (Acceptance Checklist, item 14): "A scripted
60-second input sequence replayed at 30, 60, and 144 frames per second ends
with the kart within 0.5 wu of the same position and within 0.05 s of the same
lap time."

**It does not say** whether the replayed inputs are timed on the simulation
clock (the same tick receives the same input at every rate) or arrive as a
player's would (edges quantised to whatever frame boundary the render rate
offers).

**The port resolves: tick-timed.** The two readings are not close. The M8
Critic demanded the frame-quantised reading be tried, and it was measured:
the same edge schedule applied on 1-, 2-, and 4-tick frame boundaries — an
edge shifted by at most one tick per batching — ends **8.83 wu** apart and
0.0667 s apart on the lap clock, because a steering edge one tick late turns
the kart ~2.6 degrees and a minute of driving multiplies that into world
units. No implementation whose steering matches the specified turn rate could
hold 0.5 wu under that reading, so the tolerance is only a meaningful test
under the other one: the same tick-timed sequence, replayed while the
renderer runs at three different verified rates. That is what
`tools/refresh_probe.gd` does (input applied per physics tick; drawn-frame
counts prove the rates), and its recorded run — 0.0000 wu / 0.0000 s across
all three rate pairs, a 15.05 s lap banked in each — is pinned by
`conformance_test.gd` item 14, which also re-proves headlessly that the
script banks and replays byte-stably.

*Recorded in the M8 remediation of `add-acceptance-conformance-suite`.
Resolved.*

## Open

None. A12, the last open entry, was settled at M8 by amending the design
document itself (history below); A14 was raised and resolved in the same
milestone's remediation pass.

### A13 — Props below the blessed 1024 (RESOLVED)

**The specification says** (§2): *"downsampling the texture set to 1024 × 1024
is acceptable and visually near-identical at gameplay distances; do not go
below that for the kart."*

**It does not say** whether anything other than the kart may go below 1024 —
the floor's qualifier names only the kart. The 25 MB web budget forced the
question: at 1024 across the set the payload measured well over budget.

**The port resolves** (add-render-pipeline-and-web-budget, registered by the
M6 review): props ship at 512, the kart at its stated 1024 floor, Basis
Universal throughout. Defence: the budget is normative and something had to
give; props are seen at gameplay distances where the document itself calls
1024 "visually near-identical"; the gallery baselines gate the resulting look;
and `tools/stamp_texture_imports.py --check` fails the suite if any sidecar
drifts. Payload: 89.2 → 20.5 MB gzip-9.

*Recorded during M6. Resolved.*

### A12 — The pinned kart cannot stay pinned (RESOLVED at M8)

**The specification says**, under *Not becoming trapped inside an obstacle*, that
two cottages at the minimum 3 wu separation leave a 0.09 wu gap against a
contracted kart hitbox of 1.80 × 1.96 wu, and that a kart reaching such a pair
"oscillates in place with its velocity zeroed every tick **and cannot drive
out**". Reset Kart is named as the escape, and a port is told explicitly that the
remedy is the placement rule and **not** the collision response.

**It does not say** what holds the kart there. The response it specifies is a push
along the horizontal unit vector from the prop's volume centre to the kart's
position. That is *radial*, so whatever transverse offset the kart has is
multiplied by roughly `pushDistance / separation` on every push. The centred state
is an unstable equilibrium, not a trap — and the document's sentence describes a
state its own rule cannot maintain.

**What actually happens.** `godot/tests/collision_test.gd` drives the pair at the
same sixteen headings the rest of that suite uses:

| yaw | 0° | 22.5° | 45° | 67.5° | **90°** | 112.5° | 135° | 157.5° |
|---|---|---|---|---|---|---|---|---|
| ticks held | 20 | 15 | 17 | 16 | **125** | 16 | 17 | 15 |

| yaw | 180° | 202.5° | 225° | 247.5° | **270°** | 292.5° | 315° | 337.5° |
|---|---|---|---|---|---|---|---|---|
| ticks held | 20 | 15 | 16 | 16 | **127** | 16 | 16 | 15 |

The pin is **strongly heading-dependent**. It lasts about two seconds only at the
two headings that drive along the line joining the props — where the kart is
driving into a cottage — and about a quarter of a second at the other fourteen.
`cos(π/2)` is `6.1e-17` rather than zero, so the transverse offset exists from the
first tick even at the longest-lived heading, and grows until the kart is squeezed
out sideways.

**Those numbers are the test's synthetic cubes**, sized `minPropSeparation − 0.09`
so the gap is exactly the document's. Against the **shipped cottage models**,
`tools/collision_capture.sh pin` shows the kart still held at 60 ticks
(`v = 0.00000`) and free by 90 (`v = 0.107`) — roughly **1.2 s**, not 2.1.

**This port has NOT decided anything here, and that is deliberate.** What it has
done is reproduce the specified response exactly and measure the consequence. Two
things are true and both are asserted:

- driving along the pair's axis never carries the kart past it — the direction the
  document's scenario is about, and the guarantee that survives;
- the pin ends, at every heading, and it ends transversely.

`collision_test.gd` requires both, so a change that lets the kart drive through the
pair fails, and so does one that quietly makes the pin permanent.

**Why the response was not changed.** The obvious "fix" — damping the transverse
component of the push — is a second, unspecified rule in the most prescriptive
feature in the document, and it fails the sixteen-heading push-direction sweep,
which is the right outcome. The document's own remedy is the placement rule. So
the port matches the response and the document's *consequence* is what is wrong.

**This is a defect in the design document, not a gap in it**, which is why it is
filed Open rather than resolved in a delta spec. `CONSTRAINTS.md` §12 routes
"game behaviour as designed" to the GDD by proposal; the ROADMAP Backlog carries that proposal
against the sentence "cannot drive out". Until it is settled, the delta spec in
`add-aabb-collision-response` states the two surviving guarantees and does not
restate the one that fails — and it does not relax the rule the document is
emphatic about, which is that no more than one collision is resolved per tick.

**The resolution (M8, `add-acceptance-conformance-suite`): the document was
amended, not the response.** The GDD's pin sentence now states the measured
truth — the kart "cannot make forward progress through the gap", the pin is "
transient, not permanent", the radial push's instability "squeezes the kart out
sideways within a fraction of a second at most headings and inside a couple of
seconds at the worst", and Reset Kart is the *immediate* escape. Nothing about
the placement rule, the one-resolution-per-tick rule, or the response changed;
`collision_test.gd`'s two guarantees (never through the pair; ejection always
transverse) were already asserting the amended sentence before it was written.

*Recorded in `add-aabb-collision-response` (M3). Resolved in M8 by GDD
amendment.*

An open entry is not a licence to decide quietly later. Whichever change settles
one moves it above the line, with its reasoning, before it is archived.
