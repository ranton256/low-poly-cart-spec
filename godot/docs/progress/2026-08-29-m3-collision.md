# M3 — hitting a tree

**Status: the kart collides.** Seven GDD scenarios verified — all six of
*Collision Detection and Response* plus *Chase Camera / Absorbing a collision
jolt* — and **M3's deferred count reaches zero**. `sim.gd`'s stage 7, empty since
M1 with a comment naming this change, has a body.

One thing is left open rather than closed: the design document's claim that a kart
pinned between two props "cannot drive out" is not producible by the response the
document itself specifies. That is ambiguity **A12**, raised against the document
as `att` 20, and it is the subject of the longest section below.

## What the captures show

- `2026-08-29-m3-collision-stopped.png` — the kart driven at full speed into a
  staged tree at z = 10 and **stopped dead against it**: `z = 8.075`, `v = 0.00000`
  exactly, having been pushed back along the horizontal vector from the tree's
  volume centre. Collision resolved on tick 66.
- `2026-08-29-m3-collision-stopped-unjolted.png` — **the same tick, with the jolt
  suppressed.** This pair is how the shudder is shown, and the reason is worth
  stating: the jolt is at most `±0.15` wu horizontally on a camera sitting
  `chaseBack = 8` wu behind the kart, which is about a degree of view. A single
  frame captioned "mid-shudder" is a claim nobody can check. Both frames come from
  the same command with `nojolt` flipped, so the kart is in an identical state
  (`x = 0.000 z = 8.075 v = 0.00000`) and the two differ by the jolt and nothing
  else. Measured at the grab: **0.1739 wu** of shudder against **0.0000 wu**.
- `2026-08-29-m3-collision-pin.png` — the kart wedged between two cottages at
  exactly `minPropSeparation`, 40 ticks after first contact and still held
  (`v = 0.00000`). This is specified behaviour, not a bug — and it is a transient;
  see below.

## How the shudder frame was chosen

The frame is the collision tick itself — `after = 0` — which is the jolt's peak,
because there is no decay of its own and the easing starts absorbing it on the
next tick. Measured through the tool by stepping **a second chase camera in
lockstep that is never jolted**, and reporting the distance between the two: that
difference is the shudder and nothing else, where "distance from the trailing
target" would have been mostly the camera's ordinary lag (1.5112 wu, of which only
0.1739 was the jolt).

Decay, from the same tool at increasing `after`:

| ticks after contact | shudder (wu) | if it were a single jolt decaying at 0.92/tick |
|---|---|---|
| 0 | 0.1739 | — |
| 3 | 0.1354 | 0.1354 |
| 6 | 0.1055 | 0.1055 |
| 12 | 0.1339 | 0.0651 |
| 18 | 0.0647 | 0.0367 |
| 30 | 0.0836 | 0.0139 |

**The first three rows are the decay; the rest are not, and the difference is the
point.** The kart is still holding forward, so it drives back into the tree and is
jolted again — `z` goes 8.226 at tick 6, 8.083 at 12, 8.088 at 30, each dip a fresh
contact. An earlier version of this table stopped at row three and read as though
the whole curve had been checked, which is the same sampled-where-it-looks-right
shape this change's tests were rewritten to avoid; review caught it here, in the
evidence rather than the test.

The retention per tick is `1 − chaseSmoothing` = 0.92, and the isolated claim —
one jolt, then easing, with no second decay — is asserted directly in
`camera_test.gd` on a stationary camera where nothing re-contacts anything: the
ratio after a single step must equal 0.92 to within 1e-6. A mutation adding a
separate decay fails it. That is the mechanism the design document's *Absorbing a
collision jolt* asks for; the table above is the same mechanism seen through a
player who has not let go of the accelerator.

## The pin, and what driving it actually showed

The design document specifies a **failure** and requires a port to reproduce it:
two cottages at the minimum 3 wu leave a 0.09 wu gap against a contracted kart
hitbox of 1.80 × 1.96 wu, and a kart that reaches such a pair "oscillates in place
with its velocity zeroed every tick **and cannot drive out**". Reset Kart (M7,
`att` 10) is the named escape, and the document says explicitly that the remedy is
the placement rule and **not** the collision response.

The pin reproduces. "Cannot drive out" does not, and it cannot: the push the same
document specifies is radial from the prop's volume centre, so the centred state is
an unstable equilibrium — any transverse offset is multiplied by roughly
`pushDistance / separation` on every push, and `cos(π/2)` is `6.1e-17` rather than
zero, so an offset exists from the first tick.

**Swept over the same sixteen headings the rest of the suite uses**, because the
first version of this test ran at one heading and generalised from it — the exact
shape this change spent its review budget designing against, caught by review:

| yaw | 0° | 22.5° | 45° | 67.5° | **90°** | 112.5° | 135° | 157.5° |
|---|---|---|---|---|---|---|---|---|
| ticks held | 20 | 15 | 17 | 16 | **125** | 16 | 17 | 15 |

| yaw | 180° | 202.5° | 225° | 247.5° | **270°** | 292.5° | 315° | 337.5° |
|---|---|---|---|---|---|---|---|---|
| ticks held | 20 | 15 | 16 | 16 | **127** | 16 | 16 | 15 |

Two seconds only at the two headings driving along the line joining the props —
into a cottage — and a quarter of a second at the other fourteen. Those figures are
the test's synthetic cubes, sized `minPropSeparation − 0.09` so the gap is exactly
the document's; against the **shipped cottage models** `tools/collision_capture.sh
pin` shows the kart still held at 60 ticks (`v = 0.00000`) and free by 90
(`v = 0.107`), roughly **1.2 s**.

What survives, and what the suite asserts at every heading:

- the velocity is **exactly zero** on every tick of contact;
- **one** of the two overlaps is resolved per tick, so the kart is displaced a full
  `pushDistance` rather than a fraction — the multi-resolve "fix" cancels the two
  pushes and fails here;
- driving straight **along the pair's axis never carries the kart past it**, and
  when the pin ends the kart is still short of the pair, so what freed it was the
  transverse instability and never the push it was driving into;
- and the pin **ends**. Asserted, so that damping the transverse component to make
  it permanent fails too. That mutation also fails the sixteen-heading
  push-direction sweep, which is the right outcome.

**This is a defect in the design document, not a gap in it**, so it is not settled
in a delta spec. It is recorded as ambiguity **A12**, left **open**, and raised
against the document by proposal as **`att` 20**. The delta spec states the three
guarantees above and does not restate the one that fails — and it does not touch
the rule the document is emphatic about, which is that no more than one collision
is resolved per tick.

An earlier draft of this change amended the delta spec to say the guarantee "holds
in the direction the player is driving and not in the one they are not". That was
derived from yaw 90 alone and is backwards at yaw 0, where the kart leaves in the
direction it is driving in a third of a second. It has been withdrawn.

## The RNG refactor, and what the smoke vectors proved

`rng.gd` became instantiable. `add-seeded-world-scatter`'s design D2 deferred this
and named its trigger — a second gameplay consumer of randomness — and the camera
shake is it. With one process-global stream, scatter re-seeds at every generation,
so the shake sequence would have depended on how many props were scattered and
would have reset whenever the player pressed Regenerate World.

`Rng.new()` now gives an independent stream; the static functions remain and share
one default stream. Both paths run the *same* arithmetic — the statics delegate —
so they cannot diverge.

**`smoke_test.gd`'s known-answer vectors passed unchanged, and were not touched.**
They are the fixture proving this is mulberry32 and not merely something that looks
random; if the sequence had moved, the refactor would have been wrong, not the
vectors. `determinism_test`, `replay_test` and `scatter_test` all stayed green, and
`check_scatter_conformance.py` reported the identical field for seed 20260829 (54
props: tree 15, rock 10, cone 12, crate 8, tires 6, cottage 3).

`scatter_test.gd`'s isolation check was **rewritten**, because the old one could
not tell an owned stream from a re-seeded global. The replacement seeds the shared
stream, draws from it, generates a field, and asserts the shared stream's state is
untouched. Verified falsifiable: reverting scatter to the static API produces
`FAIL: generating a field leaves the shared stream untouched (3343436752 ->
2773063097)`.

## The sweeps, and the mutations that prove they bite

Acceptance item 6 says the kart can reverse out of a single prop **at any approach
angle**, and the document says one collision is resolved **however many props
overlap**. Both quantify over inputs, and the last four reviews of this project
each found a check that passed because it ran at the one input where the bug was
invisible. This change was written against that shape and **review found three more
instances of it anyway**, listed below with the rest.

- **16 approach headings.** Each asserts the push equals `pushDistance` times the
  unit vector from the prop's centre to where the kart stood — not that the kart
  moved, which a push along the forward axis also satisfies.
- **16 reverse-outs**, one from each of those approaches, each guarded against
  becoming vacuous if the approach ever stops colliding.
- **8 degenerate headings**, asserted against the **backward** axis specifically —
  and separately that the push projects *negatively* onto the kart's nose, which is
  a claim that survives if the equality tolerance is ever loosened.
- **16 pin headings**, which the first version did not have.
- **Registration order**, with the array **reordered** and a different prop required
  to be resolved.
- **Every tick checked** while driving into a prop at full speed, because a
  final-position check cannot tell "never crossed" from "crossed and came back".

Each was verified by breaking the code and confirming the right check failed:

| mutation | caught by |
|---|---|
| degenerate branch uses the **forward** axis | the backward-axis check at all 8 headings |
| push direction negated (toward the prop) | all 16 approach headings, both assertions |
| resolve the **last** overlap instead of the first | the ordering test and its reorder |
| resolve the **nearest** overlapping prop | the ordering test — **only after the fixture was fixed** |
| resolve the **largest** overlapping prop | the ordering test |
| resolve **every** overlap per tick — the tempting "fix" | the pin's full-push assertion, at every heading |
| damp the transverse push, making the pin permanent | the approach sweep, and the pin's "it ends" assertion |
| `hitboxContraction` not applied | the contraction dimensions and the forgiveness case |
| volume **not** recomputed from the heading | the 45° growth test, both halves |
| velocity damped instead of zeroed | all 16 approach headings |
| **stage 7 moved before stage 6** | the boundary-order test — **which did not exist** |
| `sim.props` never wired in `main.gd` | the driver test — **which did not exist** |
| the camera never jolted in `main.gd` | the driver test |
| registration order reversed on the way into the simulation | the driver test |

Four more were run against the camera jolt: drawing the vertical offset from
`shakeHorizontal`, moving the aim as well as the position, adding a second decay,
and never advancing the shake stream. All four fail.

### Three holes review found, and they are the same hole

Every one is a check that could not distinguish the right behaviour from a wrong
one, because of the input it happened to run at.

**The ordering test could not tell "first" from "nearest".** `_overlapping_trio`
placed three props at the same distance from the kart and gave them the same size,
so distance was a perfect tie that fell through to iteration order. A
`first_overlap` rewritten to return the nearest overlapping prop passed the entire
gate. The trio is now asymmetric on every axis a plausible rule might use —
distance, size, penetration depth, and direction from the kart — with `second`
simultaneously the nearest, largest and deepest while `first` is none of those. A
further check asserts the fixture still has that discriminating power, so tidying it
back into three symmetric props fails.

**Nothing held stage 7 after stage 6.** `sim.gd`'s comment claimed "the ordering
tests hold it there" and the task list claimed the existing order tests were
confirmed. Neither was true — the only order assertion in the project was
steering-before-friction. Swapping the two stages left the whole gate green. The new
test puts the kart against the fence with a prop inboard so the push must carry it
*outside* the drivable extent: after the boundary the shove stands, before it the
clamp eats the shove in the same tick and returns the kart into the prop it was just
pushed out of.

**Nothing held the shipped game's wiring.** `collision_test.gd` builds its own props
and never loads a scene, so deleting `sim.props = props.collision_props()` from
`main.gd` — leaving the game with no collision at all — passed all sixteen suites.
The capture tool did not cover it either, because it wired `sim.props` itself; it now
goes through `main.gd`'s `build_field()`, and `driver_test.gd` asserts the wiring,
its order, that regeneration re-wires, and that a collision in the running game
reaches the camera.

**A fifth turned up while committing.** `prop_field_test.gd` set the kart's state,
regenerated the world, awaited a frame and asserted the kart was unchanged. It
passed alone and flaked once in a full gate run with "its velocity is untouched" —
because a physics tick can land inside that await, and once stage 7 had a body a
prop dropped on the kart zeroes the velocity outright. The suite now stops the
root's stepping across the assertion, needs no frame (`regenerate_world()` is
synchronous), and compares exactly rather than approximately. Eight consecutive
full gate runs are green, and two mutations — resetting the kart on regeneration,
and not regenerating at all — both fail. Recorded in `GOTCHAS.md`.

**And the contraction mutation had already been caught the same way** while this
change was being written: the clearance in the passing-close test was derived from
the contracted volume, so removing the contraction moved the expectation along with
the code. It is now pinned against the uncontracted footprint and the tuning value.

Four instances of one shape, in one change. The lesson is not "sweep more inputs" —
the change did sweep — but that a fixture can be symmetric in exactly the dimension
the rule under test discriminates on, and a sweep over the wrong dimension proves
nothing.

## Reproducing everything

```sh
./tools/test.sh                                  # the standing gate, 16 suites
godot --headless -s tests/collision_test.gd      # the sweeps alone
godot --headless -s tests/camera_test.gd         # the jolt alone

# The captures. Windowed, and launched so they do not steal focus.
tools/collision_capture.sh shudder docs/progress/2026-08-29-m3-collision-stopped.png 0 0
tools/collision_capture.sh shudder docs/progress/2026-08-29-m3-collision-stopped-unjolted.png 0 1
tools/collision_capture.sh pin     docs/progress/2026-08-29-m3-collision-pin.png 40
```

`tools/collision_capture.sh` stages the arrangement and drives the **shipped
game** into it — same scene, same tick, same collision code, same chase camera, and
the props wired in through `main.gd`'s own `build_field()` rather than by the tool,
so a capture cannot show a collision in a build that has none.
The pin capture is the one exception to "through the game's own camera": the pin
only holds when the kart drives along the line joining the two props, which is
exactly when the chase camera has the near cottage filling the frame. It is lifted
to an elevated view, in the tool, with the reason in the tool.
