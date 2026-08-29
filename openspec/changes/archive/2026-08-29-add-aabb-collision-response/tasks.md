# Tasks — add-aabb-collision-response

Order is dependency order: the RNG refactor before anything draws from it, the
detection before the response, and the sweeps written before the code they check.

## 1. Streams before consumers

- [x] 1.1 `scripts/core/rng.gd` becomes instantiable, so each gameplay consumer owns
      a stream (design D2). This is what `add-seeded-world-scatter`'s D2 deferred and
      named the trigger for
- [x] 1.2 `scatter.gd` takes its own stream; the shake will take another
- [x] 1.3 **`smoke_test.gd`'s known-answer vectors must pass unchanged.** They are the
      fixture proving this is mulberry32. If the sequence moves, the refactor is
      wrong — do not update the vectors
- [x] 1.4 Confirm `determinism_test.gd` and `replay_test.gd` still pass, and that
      `scatter_test.gd`'s "unrelated draws do not change the field" still means
      something once the streams are separate

## 2. Detection

- [x] 2.1 `scripts/core/collision.gd` — no engine types beyond `AABB`, which the core
      already uses. The boundary gate covers this directory; confirm it stays clean
- [x] 2.2 Recompute the kart's world-axis-aligned volume from its current yaw each
      tick, through `normalise.world_box()`
- [x] 2.3 Contract it by `hitboxContraction` on every side, through
      `normalise.contracted()`
- [x] 2.4 Test against each registered prop in order, stopping at the first
      intersection — at most one collision resolved per tick
- [x] 2.5 Wire it into `sim.gd` stage 7, after the boundary and before the lap gate.
      The tick order is a committed requirement; confirm the existing order tests
      still pass. **Corrected in review: there were none.** The only order assertion
      in the project was steering-before-friction, and swapping stages 6 and 7 left
      the whole gate green. `collision_test.gd` now holds stage 7 after the boundary;
      stage 8 is empty until M4, which owns the other half

## 3. Response

- [x] 3.1 Push direction: the horizontal unit vector from the prop volume's **centre**
      to the kart's **position**
- [x] 3.2 The degenerate branch: when that vector is shorter than a stated tolerance,
      use the kart's **backward** axis. State the tolerance and its reasoning in the
      code, before measuring anything (design D3)
- [x] 3.3 Displace by `pushDistance`; set velocity to **exactly zero** — not
      reflected, not damped
- [x] 3.4 Emit a camera jolt within `±shakeHorizontal` and `±shakeVertical`, drawn
      from the shake's own stream

## 4. The sweeps — written before the code is trusted

- [x] 4.1 `tests/collision_test.gd`: approach a prop from **16 headings**, asserting
      after each push that the kart is **further from the prop's centre than before**
      — direction-sensitive, not merely "it moved" (design D4)
- [x] 4.2 Reverse out from each of those 16 approaches, asserting the kart is freed.
      This is acceptance item 6's "at any approach angle"
- [x] 4.3 The degenerate case: kart exactly on a prop's centre. Assert the push is
      along the **backward** axis, and **not** the forward one — a test asserting only
      that it moved passes on forward, and forward is the tunnelling the document
      forbids
- [x] 4.4 Several props overlapping at once: the resolved one is first in
      registration order. **Reorder the array and confirm a different prop is
      resolved** — that is what makes this a test of order rather than of proximity
- [x] 4.5 Passing close: clearance greater than the contracted volume registers no
      collision, and position, heading and velocity are all unchanged
- [x] 4.6 The 45° volume is larger than the axis-aligned one — asserted as accepted
      behaviour, so a future "fix" to oriented volumes fails loudly
- [x] 4.7 Driving into one prop repeatedly: each contact repeats push and kill; the
      kart never wedges, jitters through, or tunnels past. Check **every tick's**
      position while driving at full speed, not only the final one
- [x] 4.8 A prop scattered onto the kart pushes it clear on the following tick

## 5. The pin, asserted as specified behaviour

- [x] 5.1 Two props at `minPropSeparation` with a gap smaller than the contracted
      hitbox: the kart overlaps both, one is resolved, the push drives it into the
      other, velocity is zeroed each tick, and it **cannot** drive free (design D5)
- [x] 5.2 The test's name and body state that this asserts SPECIFIED behaviour and
      cite the design document's paragraph, so it does not read as a bug nobody fixed
- [x] 5.3 **Verify 5.1 by "fixing" the pin**: resolve every overlap per tick instead
      of the first, and confirm this test fails while the others still pass. That is
      what stops a well-meaning change from silently diverging

## 6. The camera absorbs it

- [x] 6.1 The jolt displaces the chase camera's position; the existing easing pulls it
      back with no separate decay
- [x] 6.2 Assert the shudder decays at the SAME rate as the turn lag — the time
      constant already measured at 0.200 s — rather than at a new one
- [x] 6.3 Assert a jolt leaves the kart's position, heading, velocity and the camera's
      aim point unaffected
- [x] 6.4 Assert the offset is within the specified bounds, and that repeating a run
      from one seed reproduces the same shudder

## 7. Proof

- [x] 7.1 Capture the kart stopped against a tree, pushed clear
- [x] 7.2 Capture the camera mid-shudder, and say how the frame was chosen — a shake
      lasting a fraction of a second is easy to miss and easy to claim
- [x] 7.3 Capture the pinned case between two props, since it is specified behaviour
      that a reader will otherwise assume is a defect
- [x] 7.4 Progress note: the approach-angle sweep, the pin, the RNG refactor and what
      the `smoke_test` vectors proved about it, and the commands that reproduce
      everything

## 8. Documentation

- [x] 8.1 Move seven scenarios to verified in `data/scenario_register.json` — the six
      collision scenarios and *Absorbing a collision jolt*. **Expect M3's deferred
      count to reach zero**
- [x] 8.2 Record the one-collision-per-tick rule and the pin in `CONSTRAINTS.md`,
      beside the registration-order contract it depends on. A reader should not have
      to open a change's `design.md` to learn that a known-bad behaviour is required
- [x] 8.3 Add any new term to `docs/GLOSSARY.md`
- [x] 8.4 `ROADMAP.md`: M3 complete, with its done-when clauses marked individually —
      ✅ where met and ⚠️ where not, as M2's were
- [x] 8.5 Note on `att` 10 that the pinned case is the document's named use for Reset
      Kart, so M7 has a concrete reason rather than a general one
- [x] 8.6 Check every governing document for drift

## 9. Closing

- [x] 9.1 `./tools/test.sh` green
- [x] 9.2 `openspec validate add-aabb-collision-response --strict` passes
- [x] 9.3 Confirm the coverage gate reports **M3 at zero deferred** and the `UNMET`
      entry unchanged
- [x] 9.4 Raise an `att` task for anything found in passing
- [x] 9.5 Critic review against CONSTRAINTS §12 Review criteria R1–R8, by a reviewer
      who did not write the change. **Ask it to attack the quantifiers**: whether "at
      any approach angle" is genuinely swept or sampled, whether the
      registration-order test would notice a different prop being resolved, and
      whether the degenerate branch is asserted against the backward axis
      specifically rather than against "some movement". The last four reviews each
      found a check passing at the one input where the bug was invisible — the kart's
      aim at yaw 0, a grid extent that moved with its step, two scatter axes collapsed
      into one number, and an ordering asserted against the port's own constant. Ask
      for that shape by name, and ask it to re-run every mutation this change claims
- [x] 9.6 Address the review. Two Critics, both **REJECTED**. Four instances of the
      named shape were found and fixed: an ordering fixture that could not tell
      "first" from "nearest", a missing stage-order assertion, the untested `main.gd`
      wiring, and the pin asserted at one heading. A12 was re-derived from a
      sixteen-heading sweep, re-filed as **open**, and raised against the design
      document as `att` 20; the delta spec's relaxed wording was withdrawn. Also
      raised `att` 19 — a runtime error inside a test leaves its suite green
