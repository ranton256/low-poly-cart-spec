## Why

`add-seeded-world-scatter` put obstacles in the field and collided with none of
them. This change makes hitting a tree feel like hitting a tree, which is the goal
the design document states for M3 in as many words.

It implements the **Collision Detection and Response** feature — all six of its
scenarios — and the *Chase Camera*'s fourth, *Absorbing a collision jolt*. It fills
`sim.gd`'s stage 7, which has stood empty since M1 with a comment naming this
change, and it is the consumer of the registration order that
`add-seeded-world-scatter` spent most of its review effort getting right.

**Acceptance item 6**: hitting a tree stops the kart dead, shoves it clear, and
shakes the camera — and the kart can always reverse back out of a **single** prop,
**at any approach angle**.

**GDD scenarios: seven.** The six collision scenarios plus the camera jolt. M3's
deferred count falls from 7 to zero, completing the milestone.

**Two things here are unusual and both are load-bearing.**

The document specifies a **failure** and requires it be reproduced. Two props at
the minimum separation leave a 0.09 wu gap against a 1.80 × 1.96 wu contracted
hitbox; a kart reaching such a pair overlaps both, only the first in registration
order is resolved, and the push-out drives it into the second. The document names
Reset Kart as the escape and says explicitly that a port wanting the stronger
guarantee should raise `minPropSeparation` rather than resolve more than one
collision per tick — *"the placement rule is the root cause, not the collision
response"*. This change reproduces that behaviour and tests for it.

**Driving it showed the document is wrong about the outcome, and that is recorded
rather than absorbed.** The document says such a kart "cannot drive out". The
push it specifies is radial from the prop's centre, so the centred state is an
unstable equilibrium: swept over sixteen headings, the kart is held for 125 ticks
driving along the pair's axis and 15–20 ticks across it, then squeezed out
sideways. What survives is that it is stopped dead on every tick of contact and
never driven past the pair. The tests assert exactly that — including that the pin
**does** end, so a change quietly making it permanent fails too — and the
discrepancy is raised against the design document as ambiguity **A12**.

And **"at any approach angle" is the shape three consecutive reviews have caught**
— the kart's aim tested at yaw 0, the grid extent that missed a doubled cell, the
scatter's two axes collapsed into one number. A push-out test at one approach angle
passes on a response that is wrong at the others.

## What Changes

- **`scripts/core/collision.gd`** — detection and response as pure functions. The
  kart's world-axis-aligned volume recomputed from its current yaw, contracted by
  `hitboxContraction` on every side, tested against each registered prop's volume
  in registration order, stopping at the first intersection. At most one collision
  per tick, however many overlap.
- **The response**: push along the horizontal unit vector from the prop's volume
  **centre** to the kart's **position**; when that is degenerate, along the kart's
  **backward** axis — the document explains that the forward axis would drive it
  further in and walk it out the far side. Displace by `pushDistance`, set velocity
  to **exactly zero**, and emit a camera jolt.
- **`sim.gd` stage 7 gains a body**, in the normative tick order, after the boundary
  and before the lap gate.
- **The camera absorbs the jolt.** The shake displaces the chase camera's position
  by up to `±shakeHorizontal` and `±shakeVertical`; the easing already specified
  pulls it back over the following fraction of a second, so the visible result is a
  shudder rather than a permanent offset.
- **`scripts/core/rng.gd` becomes an instantiable stream.** The shake is the second
  gameplay consumer of randomness, which `add-seeded-world-scatter`'s design D2
  predicted and said would need this: with one process-global stream, regenerating
  the world re-seeds it mid-play and the shake sequence depends on how many props
  were scattered. Scatter and the shake get their own streams.
- **Props reach the simulation as data**, in registration order, derived from the
  same placements the view draws — not read back out of the scene tree.
- **Visual proof**: the kart pushed clear of a tree, and the camera mid-shudder.

**Not in this change**: the lap gate and timing (M4), Reset Kart's implementation
(M7, `att` 10 — this change makes the case for it concrete but does not build it),
and raising `minPropSeparation`, which the document explicitly tells a port not to
do as a collision fix.

## Capabilities

### New Capabilities

- `godot/collision-response`: what counts as a collision, which prop is resolved
  when several overlap, how the kart is pushed clear, what happens to its velocity,
  and the guarantee — and the stated limit of that guarantee — about not becoming
  trapped.

### Modified Capabilities

- `godot/chase-camera`: gains a requirement for absorbing a collision jolt. The
  easing that makes the camera lag is the same mechanism that makes a shake decay,
  so the jolt is specified here as an input to a recurrence that already exists.
- `godot/simulation-core`: **Tuning is supplied to the simulation, not fetched by
  it** — the same rule now has a second subject. Props are supplied to the
  simulation in registration order rather than looked up, so the tick stays
  constructible with no scene loaded.

## Impact

- **New**: `godot/scripts/core/collision.gd`, `godot/tests/collision_test.gd`,
  captures in `godot/docs/progress/`.
- **Modified**: `godot/scripts/core/sim.gd` (stage 7), `godot/scripts/core/rng.gd`
  (instantiable streams), `godot/scripts/core/scatter.gd` and
  `godot/scripts/core/chase_camera.gd` (their own streams),
  `godot/scripts/main.gd`, `godot/tests/smoke_test.gd` (the RNG fixture),
  `godot/data/scenario_register.json`, `ROADMAP.md` (M3 complete).
- **Risk — the one every recent review has found**: "at any approach angle" and
  "however many overlap" are both quantified-over-inputs claims, and a test at one
  input passes on a response that is wrong at the rest. Design D4 says what is swept.
- **Risk**: the RNG refactor touches `determinism_test.gd`, `replay_test.gd` and
  `smoke_test.gd`'s known-answer vectors. Those vectors are the fixture proving the
  generator matches mulberry32; if the refactor changes the sequence, the refactor
  is wrong, not the vectors.
- **Risk**: the pinning case is specified behaviour that looks exactly like a bug.
  A future contributor "fixing" it by resolving multiple collisions per tick would
  pass a naive test and break conformance. The spec states it as a requirement, and
  the test asserts that exactly one of the two overlaps is resolved each tick — the
  multi-resolve "fix" halves the displacement and fails there.
- **Backlog**: closes nothing. Makes `att` 10 (Reset Kart, M7) concrete, since it is
  the document's named escape from the pinned case. Opens `att` 19 (a runtime error
  inside a test leaves its suite green) and `att` 20 (the A12 proposal), both found
  in review.
- **Ambiguities**: **A12**, opened here and left Open. The document states an
  outcome — the permanent pin — that the response it specifies cannot produce. It
  is a defect in the document rather than a gap in it, so it is raised against the
  document by proposal (`att` 20) rather than decided in this change's delta spec.
- **Verification criteria touched**: none change status.
