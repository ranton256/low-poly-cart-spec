# Renderer spike — can Compatibility carry the specified shadows?

**Status: settled. Compatibility passes all five criteria — see the Verdict.**

This section was written and committed *before* any image existed, and is not
edited afterwards except to append the verdict. That ordering is the whole
defence against grading a spike on the answer it already has: the Compatibility
renderer is already pinned in CONSTRAINTS §2 Tech stack, by the same author
running this spike, so a bar set after the pictures are on screen would find
whatever it needed to find.

## What is being decided

CONSTRAINTS §2 Tech stack pins `gl_compatibility` on every target and marks the
choice ❓ open, owned by this change. It was pinned on reasoning — web export
cannot dependably use Forward+, and two renderers would mean two looks from one
specification and two sets of visual baselines — not on evidence that
Compatibility can carry the lighting the design document specifies.

The design document is explicit that this matters:

> Shadows are a load-bearing part of the look — the kart's contact shadow is the
> primary cue for where it actually is on the ground.

## The five criteria

Each is pass or fail on its own. "Close enough" is not a verdict. If Compatibility
fails one, the finding names which.

| # | Criterion |
|---|---|
| **C1** | **The kart casts a contact shadow that reads as contact** — attached to the wheels, not floating or detached |
| **C2** | **A prop's shadow has a soft edge** — a penumbra, not a hard aliased staircase, at the specified 2048 map and filtering |
| **C3** | **No shadow acne** on lit surfaces at the specified depth bias |
| **C4** | **No peter-panning severe enough to break C1** — a small gap is acceptable; a shadow visibly separated from its caster is not |
| **C5** | **Shadowed faces are not black** — the ambient and hemisphere fills read, which is what the design document asks them for |

## What is being reproduced

The design document's §6 Lighting, verbatim:

- Ambient, white, intensity 0.60
- Hemisphere, sky `#87CEEB` → ground `#228B22`, intensity 0.40
- Directional "sun", white, intensity 1.00, at (30, 50, 30) aiming at the origin,
  casting shadows
- Sun shadow: 2048 × 2048 map, soft/percentage-closer filtering, orthographic
  volume ±60 wu in X and Y, near 0.5 / far 200, depth bias ≈ −0.0001
- Ground: flat plane at Y = 0, grass green `#3D8C40`, roughness 0.9, metalness 0.0,
  receives shadows and does not cast

Casters: the **kart** — the asset whose contact shadow the design document names —
and a **tree**, for a tall caster with a legible penumbra.

**One substitution, recorded because C5 depends on it.** Godot has no hemisphere
light type. The design document's hemisphere — sky `#87CEEB` → ground `#228B22` at
0.40, "tints undersides green" — is approximated the standard way, with two
non-shadowing directional lights: one pointing down carrying the sky colour, one
pointing up carrying the ground colour. That reproduces the specified effect
rather than the specified mechanism, which is what the design document asks for
throughout ("runtime facilities are described by their effect; the implementer
picks the mechanism"). It is noted here because C5 asks whether shadowed faces
read, and this fill is what makes them read. **The same substitution will be
needed in M2**, where the real environment is built — this is an ambiguity the
design document does not settle for Godot, and it belongs in the register.

## Method

Both captures come from one probe scene through the committed capture tool,
differing only in `renderer/rendering_method`. Forward+ is the reference, not a
candidate: the web target rules it out, but it shows what the specified lighting is
supposed to look like. Without it, "the shadow looks a bit rough" has nothing to be
rough against.

Engine version: **4.6.1** (from `godot/.godot-version`, gated by
`check_engine_version.py`).

```sh
cd godot
./tools/capture.sh res://scenes/renderer_probe.tscn docs/progress/2026-08-28-renderer-compatibility.png 30
# then flip renderer/rendering_method to forward_plus and repeat:
./tools/capture.sh res://scenes/renderer_probe.tscn docs/progress/2026-08-28-renderer-forward-plus.png 30
```

The probe scene is committed at `scenes/renderer_probe.tscn` so this comparison
can be re-run rather than taken on trust. Its header says what it is: spike
evidence, superseded by M2's environment, referenced by nothing. It is not the
place to change the lighting.

## What this spike cannot answer

Shadow behaviour **in motion** — shimmer, swimming, cascade transitions under a
moving camera. A static capture cannot show it, and there is no camera to move
until M2. That belongs to M6, with the visual gate.

## Verdict

**Compatibility passes all five criteria at the specified configuration — but only
once two settings the design document never names are corrected, and with one
finding the criteria could not see.**

### This is the second run. The first was invalid.

An independent review rejected the first run and was right to. It found:

- **The captures were taken at a 4096² shadow map, not the specified 2048².**
  `directional_shadow/size` was set nowhere, so it resolved to Godot's desktop
  default — 4× the specified texel count, in the direction that flattered the
  answer. Now pinned explicitly in `project.godot`.
- **Both hemisphere fill lights pointed sideways.** Measured aims were
  `(0,0,+1)` and `(0,0,−1)` — horizontal and anti-parallel — while this note and
  the scene header both claimed one pointed down and one up. The ground plane
  therefore received nothing from either, and "tints undersides green" was not
  reproduced at all. Now `(0,−1,0)` and `(0,+1,0)`, verified by dumping the
  instantiated scene.
- **The sun was off by 4.68°** — a hand-built 45° rotation instead of the 49.68°
  that aiming at the origin from (30,50,30) requires. Now computed, not typed.
- **C5's number was unreproducible.** This note reported 60% retention from a
  patch it never named; the reviewer measured 47% from three umbra samples. The
  measurement is now a committed tool, `tools/measure_shadow.py`, which finds the
  umbra by a stated rule rather than a hand-picked box, and it independently
  reproduces the reviewer's figure.

The bar itself was not the problem — the reviewer examined that and agreed the
criteria were fixed first, noting that nobody fitting criteria to these images
would write *"not floating"* or *"visibly separated from its caster."* The failure
was **unexamined generosity at every fork below the bar**. D1 is a real defence
and it does not catch that; auditing the scene is what catches that.

*(One reviewer finding was itself wrong: it measured the casters floating at
Y = +0.599. Measuring each `MeshInstance3D` by its own `global_transform` gives
kart lowest Y = −0.0009 at height 1.2019 wu and tree Y = 0.0000 at 4.0000 wu —
both grounded, both matching the design document's target heights. Its figure
applied a parent transform to a child's local AABB, double-counting the offset.)*

### The finding that decides it

At the specified 2048² map the kart cast **no contact shadow at all** — the one
cue the design document calls primary. That was not the renderer.

Godot has **two** shadow bias parameters; the design document specifies one.
`shadow_normal_bias` defaults to **2.0** and is scaled by texel world size. At
`max_distance` 120 with a 2048 map that is 0.0586 wu per texel, so the default
offsets a caster **0.117 wu** along its normal — about 29% of a kart wheel — and
erases the contact shadow. Setting it to 0.1 restores it: shadowed ground beneath
the kart goes from **6.5% to 27.2%**, measured over the region `KART_BOX` names in
`tools/measure_shadow.py`.

*(Those figures are corrected. The first write-up said 6.6% → 31.5% from a region
no committed artefact defined — the same defect this change had just fixed for
C5, relocated to the number that decides C1. Review measured 6.4% and 27.0% on the pre-correction geometry
independently; naming the region in the tool reproduces those, and the final
figure moved to 27.2% when the kart's transform was corrected below.)*

Recorded as ambiguity **A8**. It binds M2 and M6.

### The criteria

| # | Criterion | Result | Evidence |
|---|---|---|---|
| **C1** | Contact shadow reads as contact | **PASS** | Attached beneath the chassis and wheels at 2048² with `shadow_normal_bias = 0.1`. **Fails at Godot's default bias**, which is the finding above |
| **C2** | Soft edge, not an aliased staircase | **PASS** | The tree-shadow edge is a smooth multi-pixel gradient at the specified map size |
| **C3** | No acne | **PASS** | Lit ground over 56,000 px: mean luminance 216.7, **std 0.14** (min 216.5, max 217.1) |
| **C4** | No peter-panning breaking C1 | **PASS** | No separation between wheels and shadow once C1's bias is set. Note this criterion was *unfalsifiable in the first run* — with the bias erasing the shadow, no observation could have failed it |
| **C5** | Shadowed faces not black | **PASS** | Umbra retains **49.2%** of open-ground luminance (rule-based sample). Not the 60% first reported. Note this is measured against a **clipped** denominator, so the true retention is somewhat lower — the margin over 'reads as black' is wide enough that the verdict holds |

### What no criterion could see

**At the design document's stated light intensities, Compatibility clips 67% of
the frame; Forward+ clips 0.0%.** Lit ground measures luminance 216.7 against
Forward+'s 152.0 — **+43%** — with green at 255, fully clipped, against a
specified albedo of `#3D8C40` = (61, 140, 64).

The intensities (ambient 0.60, hemisphere 0.40, sun 1.00) are stated in the
reference build's units, and Godot's are not the same. This spike judged shadows
on a blown-out frame. It does not invalidate the shadow verdict — clipping raises
contrast rather than hiding a shadow — but **the exposure question is unsettled
and belongs to M2**, where the real environment is built. Recorded as **A9**.

A five-criterion bar that cannot see a 43% exposure divergence is not wrong, but
it is incomplete. The reviewer spotted this and it is the most useful thing in
either run.

### Two corrections review found in this run

**The kart's transform bypassed the very contract it illustrates.** It used a
hand-typed scale of 1.18 and offset 0.6 rather than the design document's §3
arithmetic — 1.20 target / 1.019 native = **1.177625** — leaving the kart 1.2 mm
under the grass. Corrected; it now grounds at +0.00026 wu, the residual being the
model's own bounding box rather than the transform.

**The shadow map pin was itself ungated.** `project.godot` warns in its own header
that Godot rewrites the file on an editor save, and the one setting whose absence
invalidated the first run had nothing watching it. `check_settings.py` now gates
it, along with `soft_shadow_filter_quality` — which was the *other* half of "at the
specified map and filtering" and had been left at an engine default.

### Reproducing this

```sh
cd godot
./tools/capture.sh res://scenes/renderer_probe.tscn docs/progress/2026-08-28-renderer-compatibility.png 30
# flip renderer/rendering_method and .mobile to forward_plus, repeat, then flip back
.venv/bin/python tools/measure_shadow.py docs/progress/2026-08-28-renderer-compatibility.png docs/progress/2026-08-28-renderer-forward-plus.png
```

The probe scene is committed so this can be re-run rather than taken on trust.
Engine 4.6.1, macOS Metal-backed OpenGL Compatibility.

**Not tested: the actual web/GLES3 target.** Every capture here is desktop. The
platform that motivated the renderer decision has never been rendered, and its
`.mobile` overrides differ. That is a real gap and it is M8's, with the export
smoke tests.
