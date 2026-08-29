## Why

M2 ended with a kart driving across an empty field. M3 fills it, and this is the
change that decides where things stand.

It implements the design document's **Procedural World Generation** feature — all
six of its scenarios — and produces the placements that `add-aabb-collision-response`
will then collide with. That dependency is the reason this change matters more than
"put some trees down": collision resolves **the first intersecting prop in
registration order**, so the *order* this change emits props in is part of the
collision contract, not an implementation detail.

**Acceptance item 2**: every prop stands exactly on the ground — none floating,
none sunk — at every random scale. The normalisation contract that guarantees it
was built and proved in M1 against synthetic boxes; this is where it meets the six
scattered models at hundreds of random scales.

**GDD scenarios: six.** *Scattering the standard prop population*, *Rejecting a
candidate placement* (an Outline with two rules), *Giving up gracefully when
placements cannot be found*, *Varying repeated instances so the field does not look
tiled*, *Leaving an empty outer ring*, and *Regenerating the world on demand*. M3's
deferred count falls from 13 to 7, the rest being collision and the camera shake.

## What Changes

- **`scripts/core/scatter.gd`** — a pure module that turns a seed into an ordered
  list of placements. No engine types, no meshes: a placement is a position, a yaw,
  a scale and an asset name, and the view instantiates from it. Deterministic and
  steppable with no scene loaded, so every placement rule is a numeric test.
- **The placement rules**, from the document: candidates uniform over
  `±scatterExtent`; rejected if nearer the origin than the asset's clearance radius
  or within `minPropSeparation` of an already-placed prop; abandoned after
  `attemptBudget × N` attempts with the achieved count reported.
- **Variation**: uniform yaw in [0, 360°), a uniform scale factor within
  `scaleVariation` applied on top of the target-height normalisation, and
  re-grounding after that scaling — the path `scripts/core/normalise.gd` already
  implements and M1 proved.
- **Registration order is part of the contract**, stated in the spec rather than
  left to fall out of a loop, because the next change resolves collisions by it.
- **The prop counts and clearance radii enter `tuning.json`**, closing `att` 6. They
  live in the *Procedural World Generation* scenario rather than the four Tuning
  Constants tables, so `check_tuning_transcription.py` gains a **sixth** source —
  as it gained a fifth for §3's target heights.
- **A conformance check that reads the design document**, in the pattern
  `check_kart_conformance.py` established: the scatter's achieved population,
  clearances and separation are asserted against the document's own table, not
  against our transcription of it.
- **The view** instantiates props from placements and releases them on
  regeneration.
- **Regeneration** removes every prop, scatters a fresh population by the same
  rules, and leaves the kart's position, heading, velocity and the running clock
  untouched.
- **Visual proof**: a seeded field from the chase camera, the empty outer ring, and
  cottages sitting only as distant landmarks.

**Not in this change**: collision detection and response, the camera shake, and the
kart being pushed clear — all `add-aabb-collision-response`. This change *registers*
props as collidable and collides with nothing. The lap gate (M4) and the HUD (M5)
are untouched.

## Capabilities

### New Capabilities

- `godot/world-scatter`: how a seed becomes a field — the populations requested,
  the rules that reject a candidate, what happens when placement runs out of
  attempts, how repeated instances are varied so the field does not look tiled, and
  the order placements are emitted in, which a later change resolves collisions by.

### Modified Capabilities

None. `godot/asset-normalisation` already specifies scale variation applied on top
of the target height and re-grounded after; this change is its first real consumer
and adds no requirement to it. `godot/build-verification`'s "single-source facts"
requirement already covers a new transcription source without changing.

## Impact

- **New**: `godot/scripts/core/scatter.gd`, `godot/scripts/world/prop_field.gd`,
  `godot/tests/scatter_test.gd`, `godot/tools/check_scatter_conformance.py`,
  captures in `godot/docs/progress/`.
- **Modified**: `godot/data/tuning.json` (counts and clearances),
  `godot/tools/check_tuning_transcription.py` (the sixth source),
  `godot/scripts/main.gd` and `godot/scenes/main.tscn` (the field, and the
  Regenerate World action), `godot/project.godot` (its binding),
  `godot/tools/check_settings.py`, `godot/data/scenario_register.json`.
- **Risk — the one the next change depends on**: registration order. A test that
  compares the *set* of placements from a seed passes while the *order* varies, and
  the order is what collision resolves by. Asserted as a sequence, and design D3
  says how.
- **Risk**: `scripts/core/rng.gd` is a static, process-global stream. Anything else
  drawing from it between generations changes the field. Design D2 decides whether
  scatter owns its own stream.
- **Risk**: acceptance item 2 is "at every random scale", and a test that checks one
  scale proves nothing — the same shape as the kart aim asserted at one heading,
  which review caught in `add-chase-camera`. Checked across the full variation range
  and across all six scattered assets.
- **Backlog**: closes `att` 6. Does not touch `att` 10 (the Reset Kart action, M7)
  or `att` 15 (A11, M6).
- **Ambiguities**: none expected. The document is unusually specific here — counts,
  radii, distributions and the budget are all stated. If the registration order
  turns out to be underspecified where collision needs it pinned, that is an
  ambiguity and gets an entry.
- **Verification criteria touched**: none change status.
