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

**This port decided:** the correction is **derived empirically** from the imported
glTF bounds, held in one named constant in the view layer, and pinned by a test
that samples 16 headings. The figure "+90°" is never transcribed as a literal.

**Why:** both frames are right-handed and Y-up, so positions map one to one and
nothing is mirrored — but a node's facing does not. Copying the number would
produce a kart that crabs sideways, which the design document names as the classic
failure of this asset.

*Recorded during `add-godot-project-foundations` (M0). Implemented in M2.*

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

---

## Open

| # | Ambiguity | Settled by |
|---|---|---|
| A1 | HUD element sizes are given in px (200×200 minimap, 160×90 speedometer, ~120 px countdown) with no design resolution named anywhere | M5 |
| A2 | "A layout file … delivered to the player" — the delivery mechanism is unspecified, and it differs between desktop and web | M7 |
| A3 | Whether prop registration order survives a layout reload. It is unstated, and it changes collision outcomes, because collision resolves the first intersecting prop in registration order | M7 |
| A9 | Light intensities are in the reference build's units, not Godot's. Applied at face value, Compatibility clips 67% of the frame against Forward+'s 0.0%, and lit ground differs by +43% | M2 |

### A9 (open, detail) — Light intensities are in the reference build's units, not Godot's

**The specification says** ambient 0.60, hemisphere 0.40, directional sun 1.00.

**It does not say** — and cannot, being engine-agnostic — that those numbers are
in the reference build's units. Applying them at face value in Godot under the
Compatibility renderer clips **67% of the frame**, with the specified grass albedo
`#3D8C40` rendering at green 255. Forward+ at the identical settings clips 0.0%,
and lit ground differs by **+43%** in luminance between the two.

**This port has NOT decided.** The renderer spike judged shadows on a blown-out
frame, which does not invalidate a shadow verdict — clipping raises contrast — but
leaves exposure open.

**Owner: M2**, which builds the real environment and is the first change that has
to make the game look right rather than merely cast a shadow. The likely shapes
are a tonemap and white point on the `WorldEnvironment`, or intensities rescaled
into Godot's units with the ratios preserved. Whichever it is, it is a decision
with evidence, not a default.

*Recorded during `spike-compatibility-renderer-shadows` (M0). Open.*


An open entry is not a licence to decide quietly later. Whichever change settles
one moves it above the line, with its reasoning, before it is archived.
