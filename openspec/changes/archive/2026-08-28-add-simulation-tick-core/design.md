## Context

See `proposal.md` — Why. Starting state: M0 is complete and committed. The gates
are live — core purity bans engine types from `scripts/core/`, the tuning-literal
gate watches `godot/scripts/`, and `check_static_typing.py` requires typed
signatures. `godot/scripts/core/sim.gd` is still the skeleton's 2D placeholder and
is what this change replaces.

Three constraints from `CONSTRAINTS.md` shape everything below: the core touches no
engine types (§4), the simulation never reads frame delta and derives time from tick
count (§6), and no tuning literal may appear in `godot/scripts/` (§3).

## Goals / Non-Goals

**Goals**

- The design document's tick order, reproduced exactly, with acceptance items 4 and
  5 met at their stated tolerances
- A simulation object a test can construct and step with no scene loaded
- Tuning injected, so a test can drive the tick with synthetic values

**Non-Goals**

- Collision response (M3) and lap detection (M4) — their stages exist and are empty
- The asset normalisation contract, the determinism harness, G1 — sibling changes
- Anything that renders, and the speedometer's *appearance* (M5)

## Decisions

### D1 — All eight stages exist from the first commit; two are empty

`step()` runs the eight named stages in order. Collision and the lap gate are
present as empty stages with a comment naming the change that will fill them.

The design document is explicit that the ordering is normative and that several of
its statements are only true because of it — the lap gate observing the step-5
integration, a collision discarding the tick's acceleration. Adding stages later
means re-reading the ordering argument and inserting into a sequence someone else
wrote; declaring them now means M3 and M4 fill a slot.

*Alternative rejected:* implement six stages and add two later. Smaller diff now,
and it invites inserting them in the wrong place.

### D2 — Tuning is injected, never read

A plain `Tuning` value object holds the constants. The composition root loads
`godot/data/tuning.json` and constructs it; the core receives it.

`FileAccess` is not on the banned list, so the core *could* read the file. It should
not: a simulation that locates and parses a file is no longer constructible from a
test without a filesystem, and the tuning-adjustment requirement wants values
swapped at runtime rather than re-read. Injection also makes the timing tests
independent of the real table — a test can assert the curve for any friction.

*Alternative rejected:* constants in the core. Forbidden by §3, and it would put
the numbers in two places.

### D3 — Velocity, yaw and the clock are 64-bit scalars

Velocity and yaw are `float` (GDScript floats are 64-bit). Position is held as two
scalars, not a `Vector3`. Elapsed time is an integer tick count; seconds are derived
only when reporting.

`Vector3` is `real_t`, which is 32-bit in a standard build. The spin-up curve is a
recurrence accumulated over ~150 ticks to reach the first assertion and ~2600 for
the coast test, and acceptance item 4 asserts three timings to ±0.05 s — three
ticks. Accumulating that in 32-bit throws away precision the tolerance cannot spare.
Conversion to `Vector3` happens at the view boundary, in M2.

### D4 — The dial's arithmetic is core; its appearance is M5

Acceptance item 4 is stated in dial readings (103, 115), not in wu/tick, so the core
exposes the speed ratio and the integer readout derived from it. That is
specification arithmetic, not presentation — drawing a needle is M5's problem.

Stating it here because it looks like a layering violation and is not: the core
would otherwise force every test of item 4 to re-derive the formula, which is how
two definitions of the same number appear.

### D5 — The boundary applies its penalty once, tracked by a flag

Step 6 clamps each axis independently, sets a flag if either clamped, and applies
the bounce factor once if the flag is set.

The design document calls this out specifically: applying it per axis squares the
factor, and at a corner that leaves the kart moving *into* the corner at +9% speed
instead of rebounding. The flag exists so the two-axis case cannot be written as two
independent clamps by someone reading only step 6.

### D6 — Tests assert the curve, not a hand-computed table of positions

The timing scenarios step the simulation and assert the first tick at which the
dial reaches a value, converted to seconds by the tick count. Expected timings come
from the design document, not from running the implementation and recording what it
did.

An expectation produced from the code under test agrees with it by construction and
verifies nothing. `CONSTRAINTS §7 Testing` says this outright for fixture
generators; it applies with more force to the one curve this milestone exists to get
right.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| A timing lands just outside ±0.05 s and the temptation is to widen it | §5 forbids it. A miss means the recurrence or the stage order is wrong — those are the only two things that can move these numbers |
| The empty collision and lap stages are forgotten | Each carries a comment naming the change that fills it, and the design document's step numbering is preserved in the code |
| Injected tuning drifts from `data/tuning.json` | `check_tuning_transcription.py` gates the file against the design document, and `tests/tuning_loader_test.gd` loads the **real** table and asserts acceptance item 4's three timings against it. Every other suite builds tuning from inline literals — good for testing the curve in isolation, and a hole on its own, since a retuned file would leave them all green while the shipped game was wrong |
| Replacing `sim.gd` breaks the inherited smoke suite, which asserts on the placeholder | Expected. The smoke suite's determinism and tick-rate checks are rewritten against the real simulation; that is a gain, not a loss |
| Both tuning-literal allowlist entries go stale when `sim.gd` is replaced | Intended, and the staleness rule will fail the suite until they are removed. Removing them is a task |
| 64-bit accumulation still drifts over a long run | A scenario asserts the error is far below the tolerances; if it is not, the fixed-point alternative is a proposal, not a silent tweak |

## Migration Plan

`sim.gd` is replaced, not edited. Ordering that matters:

1. `Tuning` and `InputState` land first — they are what the tick is written against.
2. The tick replaces `sim.gd` in one step, with the smoke suite updated in the same
   commit, so the suite is never green against a simulation that no longer exists.
3. The allowlist entries are removed with the file that justified them.

Rollback is `git revert`. Nothing outside the repository is touched.

## Open Questions

None. The one judgment call — whether the dial's arithmetic belongs in the core —
is settled in D4 and is visible in the spec, which asks for the readout rather than
for a rendered dial.
