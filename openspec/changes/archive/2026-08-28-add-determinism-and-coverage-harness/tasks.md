## 1. The claim mechanism

- [x] 1.1 Settle the in-file claim form — an explicit declaration beside the test function, quoting the design document's feature and `### Scenario:` heading verbatim, independent of the function's own name (design D1; spec: *A test's claim survives renaming the test*)
- [x] 1.2 Confirm a claim is findable by searching the test sources without running anything (spec: *A claim is discoverable without running the suite*)
- [x] 1.3 Add the committed register for the two kinds that have no code to sit beside — `visual` and `deferred` — as data rather than prose (design D2)

## 2. The coverage gate

- [x] 2.1 Write `godot/tools/check_spec_coverage.py`, extracting every `### Scenario:` heading from the design document and every claim from the test tree and the register
- [x] 2.2 Require a bijection: every heading claimed exactly once, every claim matching a heading verbatim (design D3; spec: *Every specified scenario is accounted for*)
- [x] 2.3 Fail on a `deferred` entry with no milestone (spec: *A deferral without a milestone is refused*)
- [x] 2.4 Fail on a `visual` entry with no stated reason and no named capture (spec: *A visual claim without a reason says why*)
- [x] 2.5 Report counts — total scenarios, verified, visual, and deferred **grouped by owning milestone** — on every run, so the deferred number is visible as it falls (spec: *Deferrals are counted and visible*)
- [x] 2.6 Discover claims by scanning the test directory rather than from a hardcoded file list, so the gate cannot drift from the tree
- [x] 2.7 Fail when the design document yields no scenarios at all, rather than reporting success (spec: *The gate reports what it inspected*)

## 3. Proving the gate discriminates

- [x] 3.1 **Mutation check** — remove a claim from a test; confirm the gate fails naming the feature and scenario; restore
- [x] 3.2 **Mutation check** — claim the same scenario from two tests; confirm the gate fails naming both claimants; restore
- [x] 3.3 **Mutation check** — claim a scenario that does not exist; confirm the gate fails naming the stale claim; restore
- [x] 3.4 **Mutation check** — reword a `### Scenario:` heading in the design document; confirm the gate fails rather than absorbing the rename; restore
- [x] 3.5 **Mutation check** — a `deferred` entry without a milestone, and a `visual` entry without a reason; confirm each fails; restore
- [x] 3.6 **Mutation check** — point the gate at a document with no scenarios; confirm it fails rather than passing on zero; restore

## 4. Registering all 64

- [x] 4.1 Claim, from the existing tests, every scenario they genuinely verify — quoting headings verbatim. Claim only what a test actually checks; a claim that overstates is worse than a deferral
- [x] 4.2 Register the visual set with a reason and the capture that covers it, or defer to M6 where no capture exists yet
- [x] 4.3 Defer the remainder to the milestone that owns it, cross-checked against `ROADMAP.md` rather than guessed
- [x] 4.4 Confirm the totals reconcile: verified + visual + deferred = **64**, with no scenario claimed twice
- [x] 4.5 Review the deferral list against the roadmap once more — a scenario deferred to a milestone that does not own it is invisible to the gate and is exactly what D4 says review has to catch

## 5. The replay harness

- [x] 5.1 Write `godot/tests/replay_test.gd` with a scripted input sequence that **turns, reverses and releases input**, not acceleration alone — a straight-line run is nearly symmetric under batching and would pass against a broken implementation (design D5; spec: *The sequence exercises more than straight-line driving*)
- [x] 5.2 Drive it through three separately constructed simulations: one tick at a time; in groups of two, as a 30 fps loop consumes them; and in a repeating 0-1-1 pattern, as 144 fps does
- [x] 5.3 Assert all three end byte-identical, compared with no tolerance (spec: *Different batchings of the same sequence agree exactly*; **acceptance 14a**)
- [x] 5.4 **Mutation check** — make the simulation batch-dependent; confirm the harness fails; restore. **The first attempt could not fail**: `step()` receives no frame information, so batch-independence held by construction and every mutation inside it moved all three drivers equally. The core gained an empty `begin_frame()` as the seam a composition root will call anyway; with it, per-frame velocity decay fails the replay harness and stays invisible to `determinism_test.gd` (design D6; spec: *The comparison would notice a difference*)
- [x] 5.5 Confirm the sequence is long enough to accumulate divergence — 3600 ticks, the 60 seconds acceptance item 14 names

## 6. Close-out

- [x] 6.1 Add both to `godot/tools/test.sh`
- [x] 6.2 Move `CONSTRAINTS §5 Conformance to the specification` G1 and `§10` V6 from 📋 to ✅, naming the gate
- [x] 6.3 Update `§5`'s scenario-split estimate — it guesses "~40 core, ~16 headless-scene, ~8 visual"; the register now knows the real numbers, so replace the estimate with them
- [x] 6.4 Close `att` 14 and `att` 12; update `att` 9 now that V6 is enforced
- [x] 6.5 Re-measure suite wall time and update `CONSTRAINTS §8 Performance and size budgets` if it moved
- [x] 6.6 Run `openspec validate add-determinism-and-coverage-harness --strict`
- [x] 6.7 `godot/tools/test.sh` green
- [x] 6.9 Critic pass: two `verified` claims overstated and are now strengthened. *Steering while rolling* tested only that the rate was constant — halving `turnRate` passed the whole suite, and no test ever pressed the right input. *Clamping to the configured speed limits* asserted a speed below the clamp, which is arithmetic at 0.192 vs 0.2 and held whether or not the clamp existed; deleting it passed. Both now drive the condition and fail on mutation
- [x] 6.10 Critic pass: four scenarios were parked on milestones the roadmap does not give them — Reset Kart on M2 rather than M7, the bootstrap handoff and asset-failure on M2 rather than M4, the loading indicator on M2 rather than M5. Re-parked; the split moves from M2:11 M3:13 M4:12 M5:7 M7:3 to M2:8 M3:13 M4:14 M5:7 M7:4
- [x] 6.11 Critic pass: disclose the gate's **third** limitation — it counts a claim whose test is never called. Recorded in `CONSTRAINTS §5 Conformance to the specification` and design D4
- [x] 6.12 Critic pass: the delta spec required a visual entry to name a committed capture, which no entry does and the gate never enforced; softened to capture-or-milestone with the second half specified, and design D4 corrected to match
- [x] 6.13 Critic pass: withdraw the `CONSTRAINTS §3 Language and style` rule that test names encode GDD scenarios. Design D1 rejected it and `att` 12 and 14 were closed around it while it still stood as planned for M1. Also correct §5's stale description of G1 as matching *test names*, its orphaned "third group" sentence, and the 64 = 62 + 2 Outline count
- [x] 6.14 Critic pass: correct the `begin_frame()` framing. With the method empty, batch-independence still holds by construction — the harness is a regression guard for a property that cannot currently be violated, not a present-tense proof
- [x] 6.8 Critic review against CONSTRAINTS §12 Review criteria R1–R8, by a reviewer who did not write the change, with an explicit [APPROVED] or [REJECTED] verdict. **Ask it to audit the register against the roadmap** — whether any scenario is deferred to a milestone that does not own it, and whether any `verified` claim overstates what its test checks. Those are the two things the gate cannot see, and D4 says so. **Two passes run; both [REJECTED], both on real defects. Round 1's six fixes were re-verified by round 2 and hold. Round 2's seven are 6.15-6.21.** The register audit D4 asked for is what found Finding B and, in round 1, four other mis-parked deferrals — the gate cannot see any of them

### Review round 2 findings

The second Critic pass confirmed the first round's six fixes hold, found 12 of 13
`verified` claims survive mutation, and returned [REJECTED] on seven further items.
All seven are addressed below.

- [x] 6.15 **Finding A (Major, R7).** §5 restated the per-milestone deferral split
      three lines below text asserting "Those are counts, not an estimate" — and the
      split was the pre-fix one. Rather than correct the copy, §5 no longer states
      the counts at all: the gate prints them every run, and a second source is what
      drifted. The paragraph now records both stale versions as the reason
- [x] 6.16 **Finding B (Moderate, R3).** Re-parked *Frame Loop and Render Pipeline /
      Ordering the work within a frame* from M2 to M5. The scenario closes on the
      kart's position, the speedometer and the minimap marker agreeing within one
      frame; neither the minimap nor the HUD exists before M5. Split is now
      M2:7 M3:13 M4:14 M5:8 M7:4. Also expanded *Mapping the control scheme*'s note,
      which defers to M2 while two of its bindings invoke M7 actions
- [x] 6.17 **Finding C (Minor).** *Coasting to a stop*'s third clause — "asymptotically
      approaches zero without ever snapping to a halt" — was unguarded: the check sat
      at steerThreshold-sized velocity, far above any cutoff a snap would use. The
      test now coasts 12,000 further ticks asserting the tick is **bit-exactly**
      `velocity *= friction`. Verified with the reviewer's own mutation
      (`if absf(velocity) < 0.005: velocity = 0.0` after the friction stage): green
      before, `FAIL: coast tick decays by exactly friction (want 0.00487203183065,
      got 0.0)` after
- [x] 6.18 **Finding D (Minor).** `proposal.md` claimed "every existing test file gains
      scenario claims"; four of ten do, carrying 13 claims, 10 of them in
      `tick_test.gd`. Corrected, with why the other six should not claim a scenario
- [x] 6.19 **Finding E (Cosmetic).** Removed the doubled blank line in §5
- [x] 6.20 The disclosed limit "it counts a claim whose test never runs" was narrower
      than the real one — the claiming file need not be a suite `test.sh` runs, and
      need not contain a test body at all. Widened to say so
- [x] 6.21 The withdrawn test-naming row in §9 carried ✅, which means gate-enforced
      everywhere else in that table. Added a ⊘ **Withdrawn** marker to the legend and
      used it
