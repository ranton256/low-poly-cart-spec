## Context

See `proposal.md` — *Why*. The constraints that shape the approach:

- **The design document specifies its look as exact colours.** `#87CEEB` sky and
  fog, `#3D8C40` grass, `#555555`/`#333333` grid lines. That single fact decides
  more of this design than anything else.
- **A9 is open and owned here.** Intensities 0.60 / 0.40 / 1.00 applied at face
  value under Compatibility saturate most of the frame and render the grass at green
  255 — 66.8% on the spike's probe scene, 59.75% on the environment this change builds.
- **Godot has no hemisphere light.** The reference build's `HemisphereLight` has no
  direct counterpart, so the two fill terms need an expression that keeps their
  ratio rather than a component-for-component translation.
- **The spike already settled the sun's shadow configuration** (A7, A8) and left
  behind `capture.sh`, `measure_shadow.py` and `renderer_probe.tscn`. The exposure
  work is a sibling of that, not new infrastructure.
- **Nothing runs yet.** No composition root, no reader of `tuning.json`.

## Goals / Non-Goals

**Goals:**
- An environment that can be captured on its own, before a kart or a simulation
  exists, so this change and the next one can produce visual proof.
- An exposure decided by a committed, re-runnable measurement.
- Every environment value living in data, so the tuning-literal gate covers it.

**Non-Goals:**
- Matching the reference build's image. We cannot run it side by side; see *Risks*.
- Any motion. The scene renders and nothing advances — the accumulator, `step()`
  and interpolation belong to `add-kart-view-orientation-and-input`.
- Choosing the chase camera's behaviour. The camera here is a placeholder and the
  spec says so, so it cannot quietly become the specified one.

## Decisions

### D1 — Tonemapping stays LINEAR; no filmic or ACES curve

The document specifies its look as exact hex colours. A filmic or ACES curve
reshapes hue and luminance by design, so under one the specified albedo *cannot*
render as itself — the colour spec would be violated in order to satisfy the
exposure spec.

*Alternatives considered.* **ACES** — the usual default for outdoor scenes, and it
would solve clipping gracefully with highlight rolloff; rejected because it visibly
shifts hue, and the sky test in D3 would fail by construction rather than by defect.
**Filmic** — same objection, smaller magnitude. **Reinhard** — preserves hue better
than ACES but still compresses luminance non-linearly, so the ground's rendered
value stops being a stated function of the light. All three make the pipeline the
thing under test instead of the lighting.

The consequence is accepted deliberately: with a linear transfer there is no
rolloff, so anything above the white point hard-clips. That is precisely why the
scale has to be chosen by measurement rather than assumed — see D3.

### D2 — The two fill terms become one Godot ambient with a 0.40 sky contribution

Ambient (white, 0.60) and hemisphere (`#87CEEB` → `#228B22`, 0.40) are expressed as
a single ambient term whose sky contribution is `0.40 / (0.60 + 0.40) = 0.40`, with
a sky resource carrying the specified up/down colours and a white ambient colour for
the remainder. The background stays a flat colour, so "no skybox, no gradient" holds
in what the player sees while the sky resource serves only as the ambient source.

This mapping is chosen because it stores *the document's own ratio* — 0.40 lands on
the sky-contribution parameter exactly — rather than a product someone computed.

*Alternatives considered.* **Two directional lights** faking the hemisphere —
rejected at design time: they cast, they are directional where the spec is
hemispherical, and they introduce lights the document does not have.
**Ambient colour only, dropping the green bounce** — rejected: the tint of
undersides is specified, not decorative, and dropping it is a silent substitution.
**Background mode SKY** — rejected: it puts a gradient on screen, which §5 forbids
in the same sentence that specifies the colour.

### D2a — AMENDED: the mapping above does not work, and the rejected alternative is adopted

**Task 3.3 verified D2 before relying on it, and it failed.** Setting
`ambient_light_source = SKY` makes Godot draw the sky and **ignore
`background_mode = BG_COLOR`**. Demonstrated by setting the background to magenta
and capturing: the frame still rendered sky blue. The visible consequence is a
band of the hemisphere's *ground* colour across the horizon — the row-230 median measuring
`[32, 139, 32]` against `#228B22`'s `[34, 139, 34]` — where §5 requires a flat sky
with no gradient.

Measured, with a flat-colour ambient and no sky resource, every row above the
horizon reads exactly `[135, 206, 235]`. The flat sky is reachable; it is
sky-sourced ambient that costs it.

**Adopted instead — the renderer spike's approximation**, which is already prior
art in this repository and documented in `scenes/renderer_probe.tscn`: the 0.60
ambient term as a flat ambient colour, and the 0.40 hemisphere term as **two
non-shadowing directional lights**, one aimed down carrying the sky colour and one
aimed up carrying the ground colour. Aiming them is the point — the spike records
an earlier version with both horizontal, where the ground received nothing from
either and undersides went untinted.

The original objections stand and are accepted as costs: these lights are
directional where the specification is hemispherical, and there are two more
lights than §6 lists. What they buy is both specified properties at once — a flat
sky and a tinted underside — which neither Godot ambient source delivers alone.
Shadow casting is disabled on both, so the objection that they cast does not
survive into the implementation.

The `_hemisphere_fills()` seam in `world_builder.gd` exists for this and was
written empty precisely so the substitution could not happen silently.

### D3 — One shared scale, chosen as the largest that satisfies pre-stated criteria

A single factor `k` multiplies all three intensities together. It is found by
bisection with a committed tool, against criteria written before any capture is
judged:

1. **No saturated pixel** on the ground or the sky, in any channel. These surfaces
   carry no speculars, so a saturated pixel there is exposure, not highlight.
2. **The unlit sky renders exactly its specified colour.** The background is not
   lit, so this is an equality, and it is the falsification test for the whole
   pipeline: if it fails, something is reshaping colour and *nothing else measured
   afterwards means anything*. It costs nothing and it runs first.
3. **The ground's rendered chromaticity matches its albedo**, allowing only the
   shift the specified hemisphere term can account for — a bound computed from the
   document's own 0.40 ratio and `#228B22`, not a number someone liked.
4. **`k` is the largest value satisfying 1–3.**

Criterion 4 is what makes this determinate. Without it "correct exposure" is a
preference; with it, two people applying the criteria reach the same number, and the
scene is as bright as it can be without clipping.

> **Criteria 3 and 4 above are superseded — see D3a.** They are left as written
> because the amendment's whole point is what they let through, and a design record
> that quietly repairs itself teaches nobody anything.

### D3a — AMENDED: criterion 4 was "the largest scale that clips nothing", and that was wrong

Implemented literally, the original rule returns **k = 0.6882** — the largest scale
at which no pixel of the frame saturates, with the smallest clipping scale at
0.6910. The specified grass `#3D8C40` (`[61, 140, 64]`) renders `[94, 218, 108]`
there: a deviation of 1.6756 against a tolerance of 0.0401, forty-two times outside it (1.6756 / 0.0401). It satisfied every criterion as written: nothing clipped, and
the hue stayed inside the bound. It was still obviously wrong, and the captures
`docs/progress/` carries record both rules side by side.

The hole was in criterion 3, which constrained **hue but not lightness**, leaving
nothing to pull brightness down; "largest that does not clip" then drove the scale
to the top of the range by construction. A second defect compounded it: hue was
computed in gamma-encoded sRGB, where it is not scale-invariant, so the bound
derived from the document's hemisphere ratio did not mean what it claimed.

**Criterion 3 now requires the ground to render as its specified albedo** — hue and
lightness together, in linear space — and criterion 4 selects the scale minimising
that deviation. Clipping becomes a constraint the answer must satisfy rather than
the thing that picks it. The spec's exposure scenarios were amended in step, so that the
contract and the tool say the same thing rather than the tool quietly carrying a
rule the spec never stated.

*Why the ground is the anchor:* every other specified colour is unlit — the sky is
background, the band and grid are unshaded materials — so the ground is the one lit
surface whose specified colour can calibrate an exposure at all.

**The criteria, as they now stand:**

1. No saturated pixel **anywhere in the frame**, in any channel. *(changed: the
   original wording said "the ground or the sky" and the tool implemented it as two
   sample rectangles, which reported no saturation on a frame whose ground was
   blown out beyond them)*
2. The unlit sky renders exactly its specified colour, checked first. *(unchanged)*
3. The ground renders as its specified albedo — hue **and** lightness, compared in
   linear space — within a tolerance stated before any capture is judged.
4. `k` is the value minimising that deviation, subject to 1–3.

*Alternatives considered.* **Choosing by eye and recording the number afterwards** —
rejected; A9's own entry demands evidence, and this project has twice been rejected
in review for numbers taken from unnamed regions. **Matching a reference screenshot**
— rejected: we cannot run the reference build, and a screenshot of it would carry
its renderer's decisions, which is the thing in question. **Godot's auto-exposure** —
rejected: it varies with what is on screen, so it would make visual baselines
unstable at M6 and break the gate that has to compare them.

### D4 — Sample regions are named constants in the tool

Every region the measurement reads — the ground patch, the sky patch — is a named
rectangle declared in `measure_exposure.py`, printed in its output, and committed.

This is a direct consequence of review history: the renderer spike was rejected once
for deriving A8's own number from an unnamed region, and the fix was to name the
region in code. A number is only as good as the ability to say where it came from.

### D5 — The §5/§6 values go into `tuning.json`, not a separate art file

`project-configuration` requires that every numeric constant the document defines
has exactly one home. Environment art values are constants the document defines;
splitting them into a second file would create the second home that requirement
exists to prevent. They are grouped so the set the document *names* stays exactly
the named set, following the precedent `unnamed_in_spec` and `asset_target_heights`
already set.

*Alternative considered.* **A separate `art.json`**, on the grounds that §5/§6 are
not the four Tuning Constants tables — rejected: the requirement is about homes, not
about which table a value came from, and two files means two things to keep in step.

### D6 — The grid is line geometry, not a shader

The reference grid is an `ArrayMesh` of lines with an unlit material, 20 divisions
over the central 100 × 100 wu, drawn 0.01 wu above the ground.

*Alternatives considered.* **A shader-drawn grid** — resolution-independent and
anti-aliases better at distance; rejected because the document specifies a wireframe
grid with two named line colours, and a procedural grid makes "is this the specified
grid?" a question about shader parameters rather than about geometry. **Godot's
editor grid** — not a runtime object.

Line width is 1 px under Compatibility and cannot be thickened; that is accepted, as
the document specifies colours and divisions but not a width.

### D7 — The placeholder camera has a committed transform

A static camera ships with the scene, at a transform written down rather than
nudged into place, so every capture this change and the next produce is
reproducible. The spec requires it be recorded as temporary; `add-chase-camera`
replaces it.

*Alternative considered.* **No camera, deferring all capture to the kart change** —
rejected: it would leave this change with no visual proof, and V14 expects proof
from any work that changes what the player sees. This change is nothing *but* that.

### D8 — `world.tscn` stands alone and `main.tscn` instantiates it

The environment is a scene that can be loaded and captured by itself. This keeps the
capture path independent of whatever the composition root later becomes, and it is
what makes the "renders with nothing stepping" scenario checkable.

## Risks / Trade-offs

- **Preserving the ratios is not the same as preserving the look.** Godot's ambient
  and the reference build's `HemisphereLight` are different integrators, so a
  faithful ratio can still produce a different image. → The measurement pins
  exposure and clipping and cannot certify a match against an implementation we
  cannot run. That limit goes into the A9 entry when it moves above the line, stated
  plainly rather than left for a reader to infer.
- **Compatibility may not carry sky-sourced ambient the way Forward+ does.** → The
  change verifies this before relying on it. If it cannot, that is a recorded
  finding with evidence and a different expression of the hemisphere term — never a
  silent substitution, and never a renderer swap, which is a product decision.
- **A linear transfer has no headroom.** Anything above the white point clips hard,
  so the specular-free criteria in D3 hold only while the scene stays specular-free.
  → When the kart arrives it brings a metallic-rough material; if it clips, that is
  a finding for the kart change against these same criteria, not a reason to revisit
  the tonemap decision.
- **The grid may alias into moiré at distance.** → The grid spans ±50 wu and fog
  begins at 50 wu, so the document's own fog covers the range where aliasing would
  show. Worth confirming in the capture rather than assuming.
- **Z-fighting between ground, grid and band.** → The document already separates
  them at 0.00 / 0.01 / 0.02 wu. If it still fights under Compatibility's depth
  precision, that is a GOTCHAS entry.

## Open Questions

- The exact `k` and the exact albedo tolerance in D3a's criterion 3 are outputs of
  the measurement, not inputs to it. They are recorded when the tool produces them,
  before any image is judged. Nothing about the specs, the approach or the task
  breakdown depends on their values.
- The interval D3a's criterion 4 selects is a staircase step, not a point (see the
  spec's *The choice is determinate rather than preferred*). Which scale inside it a
  search reports is the search's arithmetic. Reporting the interval rather than a
  single value would be more honest still; it is not done here because every scale
  in it renders identically at 8 bits.
