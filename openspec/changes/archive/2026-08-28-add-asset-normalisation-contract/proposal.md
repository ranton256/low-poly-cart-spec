## Why

The design document's §3 is unusually blunt about which step people get wrong:

> **Re-measure** the bounding box after scaling. (Measuring once and reusing
> pre-scale numbers is the single most common porting error; it buries props
> halfway into the ground.)

That error is invisible until you look at the world, and by then it is in every
prop, every scatter, and every visual baseline. It is arithmetic, so it can be
proven now — against synthetic bounding boxes, with no model file present and
nothing rendered.

The same arithmetic produces the world-axis-aligned box that M3's collision
resolves against. Getting it wrong there is worse than a buried prop: the design
document's own collision numbers (a contracted kart hitbox of 1.80 × 1.96 wu)
only come out if the normalisation and the yaw projection are both right.

**Design document sections implemented:** *Art & Asset Specification §3 Asset
normalisation contract*, and the scale-variation and re-grounding behaviour from
*Feature: Procedural World Generation* (the scenario *Varying repeated instances
so the field does not look tiled*).

**Acceptance checklist items advanced:** **2** — "every prop stands exactly on the
ground — none floating, none sunk — at every random scale" — in its arithmetic
half. The other half is M3, which places actual props.

## What Changes

- Implement the four-step contract as pure functions in the simulation core:
  measure, scale to a target height, **re-measure**, then offset so the lowest
  point is exactly at Y = 0 and the box is centred on X and Z.
- Implement scale variation as a factor applied **on top of** the target-height
  normalisation, with the instance **re-grounded after** it — the ordering the
  world-generation scenario specifies.
- Implement the world-axis-aligned box for an instance at a given yaw, which is
  what M3's collision will test and what M2's kart needs.
- Add the per-asset target heights to `godot/data/tuning.json`. They live in the
  design document's §3 table rather than its four constant tables, so the M0
  transcription did not cover them.
- Prove the contract against **synthetic** bounding boxes: an adversarial one on
  which the two orderings differ by 3.0 wu, a non-dyadic one that no real `.glb`
  would land on exactly, and degenerate inputs (zero height, zero target, zero
  variation factor).

Not in this change: loading a `.glb`, the kart's +90° yaw correction (M2, and it
must be derived rather than transcribed), prop population counts, scatter, and
collision resolution (all M3).

## Capabilities

### New Capabilities

- `godot/asset-normalisation`: how an instance of a supplied model is sized,
  grounded and bounded — the transform from an authored bounding box to a placed
  instance, and the world-axis-aligned box that follows from it.

### Modified Capabilities

None. `godot/simulation-core` exists only as an unarchived delta in
`add-simulation-tick-core`, so there is nothing to modify against; this
capability is self-contained arithmetic that the tick does not touch.

## Impact

- **New**: `godot/scripts/core/normalise.gd`, `godot/tests/normalise_test.gd`.
- **Modified**: `godot/data/tuning.json` gains the per-asset target heights;
  `godot/tools/test.sh` gains the suite. `check_tuning_transcription.py` may need
  to learn that the §3 table is a fourth source of named constants — if so, that
  is part of this change, because a gate that silently ignores new data is worse
  than no gate.
- **Unmodified**: the design document, and everything in `add-simulation-tick-core`.
- **Risk**: the tempting shortcut is to compute the ground offset from the
  pre-scale box, which is exactly the error the design document names. A test that
  would pass either way would be worthless, so the suite must include a case where
  the two differ measurably.
- **Backlog**: closes the asset-normalisation half of `att` 6; the prop
  population counts stay open for M3.
- **Verification criteria touched**: none newly enforced; V19's static-typing gate
  and the boundary gates cover the new core file.
