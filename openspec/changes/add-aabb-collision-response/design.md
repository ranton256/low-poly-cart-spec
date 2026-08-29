## Context

See `proposal.md` — *Why*. What shapes the approach:

- **The document is at its most prescriptive here.** The volume, the contraction,
  the ordering rule, the push direction, the degenerate fallback, the velocity kill
  and the shake bounds are all stated. Almost nothing is left to decide, and the
  interesting work is in the checks.
- **`sim.gd` stage 7 has been an empty placeholder since M1**, in the normative tick
  order, with a comment naming this change. The order — accelerate, clamp, steer,
  friction, integrate, boundary, collision, lap gate — is a committed requirement.
- **Registration order already exists and is guarded.** `scatter.gd` emits
  placements carrying an acceptance index, `prop_field.gd` carries it through, and
  both suites assert the array agrees. This change is that contract's consumer.
- **`normalise.gd` already has the two geometric helpers** this needs:
  `world_box(normalised, yaw)` recomputes an axis-aligned volume from a heading, and
  `contracted(box, amount)` shrinks one on every side. Both were built in M1 and
  proved against synthetic boxes.
- **`rng.gd` is a static, process-global stream** with one gameplay consumer.
  `add-seeded-world-scatter`'s design D2 said: *"If a second gameplay consumer
  appears, this becomes a real conflict and the answer is a stream object rather
  than a global."* The camera shake is that consumer.

## Goals / Non-Goals

**Goals:**
- Collision that matches the document clause for clause.
- The pinned-between-two-props case reproduced and asserted, not fixed.
- Acceptance item 6 held at many approach angles, not one.

**Non-Goals:**
- Reset Kart. The document names it as the escape from the pin; M7 builds it.
- Raising `minPropSeparation`. The document explicitly tells a port not to use that
  as a collision fix, and this change does not.
- Oriented bounding volumes. The document chooses axis-aligned and says the growth
  at 45° is accepted.

## Decisions

### D1 — Collision is a pure module; the tick calls it at stage 7

`scripts/core/collision.gd` holds the detection and the response as functions over
plain values. `sim.gd`'s stage 7 calls it. Props arrive as an ordered array the
caller supplies.

*Why props are supplied rather than looked up.* The simulation must stay
constructible with no scene loaded — a committed requirement — and a collision test
worth having places two props exactly where it wants them and steps one tick. Both
follow from the props being data.

*Alternatives considered.* **The view owns collision and tells the simulation** —
rejected: it inverts the boundary, and the response mutates position and velocity,
which are the simulation's. **The simulation reads `prop_field`'s records** — the
records already exist and carry the order; rejected because the core would then
depend on a `Node3D`, which the boundary gate forbids and which would make every
collision test need a scene tree.

### D2 — `rng.gd` becomes instantiable, and each gameplay consumer owns a stream

`rng.gd` gains a constructible form so scatter and the shake each hold their own,
seeded independently.

*Why now.* `add-seeded-world-scatter` deferred this explicitly, and its stated
trigger has arrived. With one global stream and scatter re-seeding at every
generation, the shake sequence would depend on how many props were scattered and
would reset whenever the player regenerates the world — so the camera's state stops
being a function of the tick sequence, which is what `camera_test.gd`'s grouping
check rests on.

*What must not change.* `smoke_test.gd` holds known-answer vectors proving this is
mulberry32 and not something that merely looks random. The refactor must reproduce
them exactly. **If the sequence changes, the refactor is wrong — not the vectors.**

*Alternatives considered.* **Keep the global and let the shake share it** — least
work; rejected for the reason above, and because it would make a cosmetic feature
able to perturb a gameplay one. **Derive the shake from the tick number with a
hash, no stream at all** — deterministic and needs no refactor; rejected because it
would be a second, private notion of randomness in a project whose determinism story
rests on there being one, and because "reproduces the same shudder" is a property of
a seeded stream, not of a hash nobody can reseed.

### D3 — The push is computed from the prop's volume CENTRE, and the degenerate case is a named branch

Push direction is the horizontal unit vector from the prop's volume centre to the
kart's position. When its length is below tolerance, the kart's backward axis is
used.

*Why the backward axis is a decision and not a detail.* The document explains it:
the forward axis "would drive it further into the prop and walk it out the far
side". A test asserting only that *some* displacement happened passes on the
forward axis, and the resulting behaviour — the kart squirting through the far side
of a tree — is exactly the tunnelling another scenario forbids.

*Tolerance.* Stated as a constant with its reasoning, not chosen after seeing a
measurement, following the discipline that carried the exposure and camera work
through review.

### D4 — Acceptance item 6 is swept, not sampled

"At any approach angle" and "however many overlap" are quantified claims. The suite
drives:

- approach at **16 headings** around a prop, asserting the push moves the kart
  *away from the prop centre* in each — not merely that it moved;
- the **degenerate** case explicitly, asserting the direction is the backward axis
  and not the forward one;
- **several props overlapping at once**, asserting the resolved one is first in
  registration order and that reordering the array changes which is resolved;
- reversing out from each of those 16 approaches.

*Why this is a decision.* Three consecutive reviews of this project found a check
that passed because it ran at the one input where the bug was invisible — the
kart's aim at yaw 0, a grid extent that moved with its step, two scatter axes
collapsed into one number. Every clause here that says "any" or "however many" gets
a sweep, and the sweep is written before the code it checks.

### D5 — The pin is a test that asserts failure

A scenario asserts the kart placed between two props at the minimum separation
**cannot** drive free, and that its velocity is zeroed each tick.

*Why write a test that demands a bad outcome.* Because the document demands it, and
because the alternative is worse: without it, a future contributor "fixes" the pin
by resolving every overlap per tick, passes every other test here, and silently
diverges from the specification. The test is the thing that makes the divergence
loud. Its body says so, and cites the document's own remedy — the placement rule,
not the response.

*This is the one place in the project where a test encodes a known-bad behaviour as
correct.* It is worth the discomfort only because the document is explicit; if it
were merely silent, this would be an ambiguity instead.

**What driving it revealed, and how D5 changed — twice.**

The pin is a TRANSIENT. The specified push is radial from the prop's centre, so a
kart between two props sits on an unstable equilibrium: any transverse offset is
multiplied by roughly `pushDistance / separation` on every push, and `cos(PI/2)` is
6.1e-17 rather than zero, so the offset exists from the first tick.

The first version of this decision measured that at **one heading** and generalised
— the exact failure shape D4 exists to prevent, in the test D5 rests on. Review
caught it. Swept over the same sixteen headings the rest of the suite uses, the
kart is held for 125 and 127 ticks at the two headings driving along the pair's
axis and 15-20 ticks at the other fourteen. At yaw 0 it leaves **in the direction
it is driving**, in a third of a second, which is the reverse of what the first
version claimed. Those are the test's synthetic cubes; against the shipped cottages
the capture tool shows the kart held at 60 ticks and free by 90.

So D5 now asserts only what holds at every heading: the velocity is zeroed on every
tick of contact, exactly one of the two overlaps is resolved, driving along the
pair's axis never carries the kart past it, and the pin **ends**. The last of those
is asserted so that damping the transverse component to make the pin permanent
fails loudly — and that mutation also fails the sixteen-heading push-direction
sweep, which is the right outcome.

**The disposition changed too.** The first version amended the delta spec to a
narrower guarantee and filed ambiguity A12 as resolved. That is a tolerance relaxed
to fit a measurement, which CONSTRAINTS forbids, and it is the wrong instrument: the
document did not fail to decide here, it decided something its own response cannot
produce. That is a defect in the design document, and CONSTRAINTS §12 Review routes
game behaviour as designed to the GDD by proposal. A12 is therefore **open**, owned
by `att` 20, and the delta spec states the surviving guarantees without restating
the failing one.

The response was NOT changed. Damping the transverse component would be a second,
unspecified rule in the most prescriptive feature in the document, whose own remedy
for the pin is the placement rule and explicitly not the response.

## Risks / Trade-offs

- **A push-out tested from one side.** The single most likely way this looks correct
  and is not. → D4's sweep, and the assertion is "further from the prop centre than
  before", which is direction-sensitive.
- **The degenerate branch never exercised.** It needs the kart's position to
  coincide with a prop's centre, which ordinary play reaches rarely and a test
  reaches trivially. → Driven directly, and asserted against the backward axis
  specifically.
- **The RNG refactor breaking replay or determinism.** → `smoke_test.gd`'s vectors
  are the guard, and they are not to be updated to match a new sequence.
- **The pin test making the suite look broken to a newcomer.** → The test's name and
  body say it asserts specified behaviour and cite the document's paragraph.
- **Tunnelling at speed.** Top speed is 0.192 wu/tick against props more than a
  world unit across, so a tunnel is unlikely rather than impossible. → Asserted by
  driving at full speed into a prop and checking every tick's position, not just the
  final one.

## Open Questions

- Whether a prop's collision volume should be its own axis-aligned box at its placed
  yaw, or the axis-aligned box of the rotated instance. The document says
  "world-axis-aligned bounding volume of every registered prop" and props do not
  rotate after placement, so both give the same answer for a fixed field. It changes
  neither the specs nor the tasks; it is recorded because a future moving prop would
  make the two differ.
