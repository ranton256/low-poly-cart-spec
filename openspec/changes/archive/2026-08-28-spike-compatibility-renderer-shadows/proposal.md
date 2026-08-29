## Why

`CONSTRAINTS §2 Tech stack` pins the Compatibility renderer on every target and
marks the choice **❓ open**, owned by this change. It is the last open question
in that document, and it is pinned on reasoning rather than evidence: web export
cannot dependably use Forward+, and running two renderers would mean two looks
from one specification and two sets of visual baselines.

Nobody has looked at a shadow.

The design document is unambiguous that this matters — *"shadows are a
load-bearing part of the look — the kart's contact shadow is the primary cue for
where it actually is on the ground"* — and it specifies the sun's shadow precisely:
2048 × 2048 map, soft/percentage-closer filtering, an orthographic volume spanning
±60 wu, near 0.5 / far 200, and a small negative depth bias.

**M6 captures the visual baselines that every later change is diffed against.** If
the renderer is wrong, every one of those baselines is wrong, and the cost of
reversing grows with each capture. This is the cheapest moment to find out.

**Design document sections:** *Art & Asset Specification* §6 Lighting — this change
implements no game behaviour and advances **no acceptance checklist item**. Its
deliverable is evidence and a decision.

## What Changes

- Build a throwaway lighting probe scene: the specified three lights, the ground
  plane, and enough geometry to cast a legible shadow — including the kart, whose
  contact shadow the design document names as the primary cue.
- Capture it under **Compatibility** and under **Forward+**, deterministically and
  from the committed capture tool, so the comparison can be re-run rather than
  remembered.
- Judge the result against criteria written down **before** the captures are
  looked at, so the answer is not fitted to whichever image appeared.
- Record the outcome and flip CONSTRAINTS §2 Tech stack from ❓ to a settled state — either
  ✅ Compatibility confirmed, or a stated finding that it is not adequate.
- Commit the comparison captures as evidence under `godot/docs/progress/`.

**If Compatibility proves inadequate**, this change does not silently switch
renderers. It reports, and the choice between dropping the web target, accepting a
degraded web look, or running two renderers is a proposal of its own — that is a
product decision, not a spike's to make.

## Capabilities

### New Capabilities

None. A spike produces a decision, not a new behaviour.

### Modified Capabilities

- `godot/project-configuration`: its *One renderer on every target* requirement
  currently carries a scenario asserting the choice is **provisional, pending this
  spike**. Once the spike has run that is no longer true, whichever way it goes.
  The requirement is updated to require the choice be **evidenced** rather than
  merely recorded.

## Impact

- **New**: a probe scene and its capture, under `godot/docs/progress/`. The probe
  scene itself is scaffolding — the change states plainly whether it is kept or
  deleted.
- **Modified**: `CONSTRAINTS §2 Tech stack` (the ❓ resolves), and `ROADMAP.md` M0,
  whose visual proof requires "the renderer spike's shadow comparison".
- **Unmodified**: the design document, `godot/scripts/`, and every gate. This
  change adds no game code.
- **Risk**: the honest one is confirmation bias — Compatibility is already pinned,
  and a spike run by the person who pinned it will tend to confirm it. The
  criteria-before-captures ordering exists for that reason.
- **Closes**: `att` 2, and the last ❓ in `CONSTRAINTS §2 Tech stack`.
- **Verification criteria touched**: none directly; V9's visual gate in M6 depends
  on this answer being right.
