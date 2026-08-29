## Context

See `proposal.md` — Why. Starting state: `add-simulation-tick-core` is committed,
so `scripts/core/` holds a real simulation, a `Tuning` value object and an
`InputState`. The gates are live: core purity, whole-tree physics ban, tuning
literals scoped to `godot/scripts/`, and static typing on every signature.

The design document's §3 gives four ordered steps and names the third as the one
ports get wrong. Its §3 table gives seven target heights. A separate scenario in
*Procedural World Generation* adds the scale-variation behaviour: the factor is
applied on top of the normalisation, and the instance is re-grounded after it.

## Goals / Non-Goals

**Goals**

- The four-step contract as pure arithmetic, provable with no model file present
- A test that fails if the offset is computed from the pre-scale box
- The world-axis-aligned box M3's collision will test, matching the design
  document's own contracted-hitbox figures
- The seven target heights in the tuning data, gated

**Non-Goals**

- Loading a `.glb`, or anything that needs one
- The kart's yaw correction (M2, and derived rather than transcribed)
- Prop counts, scatter, placement rules, collision resolution (M3)
- Rendering anything

## Decisions

### D1 — A bounding box is a value the caller supplies

Normalisation takes an authored box — origin and size — and returns a scale, an
offset and a resulting box. It never asks an engine for one.

This is the same reasoning as `add-simulation-tick-core`'s D2, and it is what makes
acceptance item 2 provable in M1 rather than M3: the arithmetic can be exercised
against boxes no supplied asset has, including the adversarial ones below, with no
filesystem and no scene. The view will hand it a real `AABB` in M2.

*Alternative rejected:* read the model's box inside the function. It would make
every test need an imported asset, and would put a file operation in `scripts/core/`.

### D2 — Re-measurement is structural, not a comment

The function computes the scaled box as a distinct value and derives the offset
from *that*, rather than scaling and offsetting in one expression against the
authored numbers.

The design document calls reusing pre-scale numbers "the single most common
porting error". A comment saying "re-measure here" is not a defence; a separate
value that the offset is visibly derived from is harder to collapse by accident,
and the test in D3 fails if someone does.

### D3 — The test must distinguish the two orderings, by construction

At least one case uses an authored box whose height differs from its target height
**and** whose authored box is not centred on its own origin, so that
offset-from-authored and offset-from-scaled give measurably different answers.

A test built only on the supplied assets would be weak here: the design document
says they arrive centred on their own origin, which is exactly the case where the
two orderings can coincide. The adversarial box is the point.

*Alternative rejected:* assert against the seven real assets' published dimensions.
Those are worth checking too, but they cannot fail the way this needs to fail.

### D4 — Scale variation re-grounds, and the test proves the order matters

Variation is a second scaling applied to an already-normalised instance, followed
by a fresh offset. A case at each extreme of the permitted range asserts the lowest
point is still exactly zero.

Applying variation *before* grounding leaves a prop floating or sunk by
`(factor − 1) × height / 2` — for a cottage at ×1.2 that is 0.3 wu, which is
visible and is precisely the "buries props halfway into the ground" symptom.

### D5 — The world box is a function of the instance and a heading

A separate pure function projects a normalised instance's local extents onto the
world axes for a given yaw. It is not stored on the instance, because the design
document requires it be recomputed every tick as the kart turns.

Its known-answer test starts from §1's **authored** inventory
(2.000 × 1.019 × 1.868) and applies the real chain — §3's normalisation to a 1.20
target, then §4's +90° correction — so both the scaling and the projection have to
be right for the answer to come out.

**This was wrong in the first implementation and review caught it.** The test fed
a box already 1.20 tall at yaw 0, which makes `to_target_height` the identity and
`world_box` the identity: it asserted that 2.2 comes back as 2.2 and could not
have failed. The rebuilt version fails if the yaw is dropped from the projection.

One consequence worth recording for M3: the document's 2.20 / 2.36 and 1.80 / 1.96
are **two-decimal roundings** of the exact 2.19980 / 2.35525 and 1.79980 / 1.95525.
The test's tolerance admits that rounding and nothing looser; collision should use
the exact figures.

### D6 — The seven target heights go into the tuning data, and the gate must see them

They are added to `godot/data/tuning.json` under the asset names the design
document uses.

They come from the §3 table, not the four tables `check_tuning_transcription.py`
parses, so the checker will not know about them. **Teaching it that table is part
of this change**: a gate that silently ignores newly added data is worse than no
gate, because it reads as coverage. If teaching it proves disproportionate, the
honest alternative is to mark the addition as ungated and say so — not to leave the
gate looking like it covers them.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| The suite passes against both orderings and proves nothing | D3 constructs a case where they differ measurably, and a mutation check confirms swapping the order fails it |
| Floating-point comparison against "exactly zero" is brittle | Two tolerances, each measured rather than guessed. Grounding is exact and holds at 1e-9. **Sizes cannot be**: `AABB` is 32-bit `real_t`, so a 1.2 target lands at 1.200000048 — a measured worst case of 4.77e-8 across the seven heights. The size bound is 1e-6, ~20× that margin and still under a micrometre at the document's 1 wu ≈ 0.75 m |
| The world-box function drifts from what M3's collision actually needs | Its test is anchored on the design document's own two figures rather than on my arithmetic, so M3 inherits a checked contract |
| Adding data the tuning gate does not parse leaves a hole that looks like coverage | D6: extend the gate, or mark the values ungated. Not silence |
| Scope creep toward placement | Non-Goals names scatter, counts and collision explicitly; the world box stops at geometry |

## Migration Plan

Nothing to migrate; this is new arithmetic that nothing yet calls. Ordering: the
tuning data and the gate's awareness of it land before or with the functions that
read it, so the gate is never green over values it cannot see.

Rollback is `git revert`.

## Open Questions

None. The one judgement — whether the world-axis-aligned box belongs here or in M3
— is settled by the roadmap, which lists "bounds → scale, ground offset, AABB" as
this change's scope, and by D5's test being a design-document known answer rather
than an implementation detail.
