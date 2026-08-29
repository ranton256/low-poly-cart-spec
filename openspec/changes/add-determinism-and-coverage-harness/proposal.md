## Why

Two gaps close together here, and they are the last of M1.

**Nothing proves the simulation is indifferent to how ticks are batched.**
Acceptance item 14 requires a scripted 60-second sequence replayed at 30, 60 and
144 frames per second to end within 0.5 wu of the same position. At 30 fps a frame
consumes two ticks; at 144 fps most frames consume none. `determinism_test.gd`
proves two runs of the *same* driver agree — it says nothing about batching, which
is the thing a frame loop actually varies.

**Nothing knows which of the design document's 64 scenarios are covered.**
`CONSTRAINTS §5 Conformance to the specification` names G1 as the gate that makes
every later milestone's "done" claim honest: a scenario nobody verified should fail
the suite rather than sit unnoticed until M8. Today the answer to "is scenario X
tested?" is a grep and a guess.

G1 is the more important of the two. Without it, "M3 is complete" means whatever
the person saying it believes.

**Design document sections implemented:** none — this change implements no game
behaviour. It measures what other changes implement.

**Acceptance checklist items advanced:** **14a**, the headless half. Item 14's
other half needs a real frame loop and belongs to M8.

## What Changes

- Add a **replay harness** that drives one scripted input sequence through the
  simulation under several different tick-batching patterns — the batching a 30,
  60 and 144 fps frame loop would produce — and asserts every driver ends in an
  identical state, compared byte for byte with no tolerance.
- Add **G1**: a checker that parses every `### Scenario:` heading out of the design
  document and fails when one is claimed by nothing.
- Establish how a test **claims** a scenario, and how scenarios that are
  deliberately not unit-testable, or not yet in scope, are declared.
- Register all **64** scenarios. Roughly a dozen are claimable by existing tests
  today; the rest are visual-only or belong to M2–M8, and each must say which.
- Close `att` 14 by settling the claim mechanism.

Not in this change: acceptance 14b (a real frame loop at real refresh rates, M8),
the visual gallery gate itself (M6), and any new game behaviour.

## Capabilities

### New Capabilities

- `godot/scenario-coverage`: how the project knows which of the design document's
  specified behaviours are verified, which are deliberately verified by eye, and
  which are not yet due — and what happens when one is none of those.

### Modified Capabilities

- `godot/build-verification`: the standing suite gains the coverage gate and the
  replay harness. Its existing requirement *Single-source facts are asserted, not
  maintained by hand* extends naturally: the design document's scenario list
  becomes another single source that the suite checks the project against.

## Impact

- **New**: `godot/tools/check_spec_coverage.py`, `godot/tests/replay_test.gd`, and a
  committed register declaring the non-test claims.
- **Also modified**: `godot/scripts/core/sim.gd` gains an empty `begin_frame()`.
  Not behaviour, but a real edit to the core — see design D6 for why the harness
  could not otherwise fail.
- **Modified**: `godot/tools/test.sh`; **four** of the ten existing test files gain
  scenario claims — 13 in total, and `tick_test.gd` carries 10 of them. The other
  six verify acceptance-checklist items, tuning transcription, asset import, or the
  harness itself, none of which are scenarios and none of which should claim one.
  `CONSTRAINTS.md` §5 G1 and §10 V6 move from 📋 to ✅.
- **Risk**: G1 can be satisfied dishonestly — by registering everything as pending
  and moving on. The design addresses this directly; it is the failure mode that
  matters most and it cannot be fully gated.
- **Backlog**: closes `att` 14 (and `att` 12, which it supersedes); `att` 9's V6
  line resolves.
- **Verification criteria touched**: **V6** (G1) becomes enforced. V2 gains the
  batching dimension.
