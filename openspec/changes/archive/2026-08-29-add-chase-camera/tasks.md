# Tasks — add-chase-camera

Order is dependency order: the recurrence exists and is proved before anything
looks through it, and the settling threshold is fixed before it is measured.

## 1. The camera as a recurrence

- [x] 1.1 `scripts/core/chase_camera.gd` — position, aim and field of view as plain
      scalars, no engine types, constructible and steppable with no scene loaded
      (design D1). The boundary gate covers this directory; confirm it stays clean
- [x] 1.2 Target position `chaseBack` behind and `chaseUp` above the kart **in the
      kart's own frame**, and an aim point `aimAhead` ahead and `aimUp` above it,
      every value read from tuning
- [x] 1.3 Position eases toward the target by `chaseSmoothing` per tick; the aim is
      applied with no smoothing, so the horizon stays level while the position lags
- [x] 1.4 Field of view `fovBase + speedRatio × (fovMax − fovBase)`, from the
      simulation's own `speed_ratio()`, with the ratio clamped

## 2. Fixing the thresholds BEFORE measuring

- [x] 2.1 Write down what "settles behind the kart" means as a number — the angle
      between the camera's offset and the kart's reversed heading, and the threshold
      below which it counts as settled — with the reasoning, committed before any
      measurement is taken (design D5)
- [x] 2.2 Write down the time-constant check: after how many ticks the offset must
      have decayed to 1/e of its starting value, derived from `chaseSmoothing`
      rather than from a measurement

## 3. Proving it

- [x] 3.1 `tests/camera_test.gd`: the camera trails at the specified offsets at
      several headings, in the kart's frame and not the world's
- [x] 3.2 The time constant matches the document's ≈0.2 s, computed from the decay
      rather than asserted as a literal
- [x] 3.3 **The lag is visible as lag**: while turning, the camera is measurably off
      the kart's heading. A camera that tracks perfectly must FAIL this — verify by
      setting `chaseSmoothing` to 1.0 and confirming it does
- [x] 3.4 Settling: after a full-rate turn ends, the offset falls below 2.1's
      threshold within the stated time. Report the measured time on every run,
      passing or failing
- [x] 3.5 Field of view at the document's own anchors — the resting value, ≈89.4° at
      the achievable top speed, monotonic in between, and clamped above the limit.
      **Not** a restatement of the formula, which would prove nothing (design D3
      risks)
- [x] 3.6 The same manoeuvre driven with ticks grouped differently produces the same
      camera state, which is what "per tick, not per frame" buys (**A10**)
- [x] 3.7 **Verify 3.6 by breaking it**: ease once per frame instead of once per
      tick and confirm the grouping test fails

## 4. Looking through it

- [x] 4.1 `scripts/view/camera_view.gd` — reads the core camera and applies position,
      aim and field of view to a `Camera3D`. It computes none of them
- [x] 4.2 The composition root steps the camera once per tick, immediately after
      `sim.step()`
- [x] 4.3 The chase camera is current in `main.tscn`; `world.tscn` keeps its
      placeholder so its own captures still work with nothing stepping (design D4)
- [x] 4.4 Confirm the camera is NOT interpolated, and that this is deliberate
      (design D3) — one thing smooths the camera, and it is the camera

## 5. Proof

- [x] 5.1 Capture the camera trailing the kart at speed
- [x] 5.2 Capture mid-turn, showing the swing-wide the document describes
- [x] 5.3 Capture the field of view at rest and at top speed, as a pair
- [x] 5.4 Capture what the specified camera sees at the drivable boundary, and say
      what it shows. **A11** needs this and M6 owns the decision; this change
      reports rather than decides
- [x] 5.5 Progress note: the thresholds, when they were fixed, the measured settling
      time and time constant, and the commands that reproduce them

## 6. Documentation

- [x] 6.1 Move **A10** above the line in `docs/AMBIGUITIES.md`: the easing is per
      tick, the ordering scenario's sequence is normative and its cardinality
      incidental, and state what that reading gives up
- [x] 6.2 Update A10's row in `CONSTRAINTS.md` §5
- [x] 6.3 Move three scenarios to verified in `data/scenario_register.json`.
      **Expect M2's deferred count to reach zero**
- [x] 6.4 Record in `CONSTRAINTS.md` §4 that `scripts/core/` now holds one piece of
      cosmetic state, and why — D1 widens what that directory means and the
      constraint document should not have to be inferred from a design file
- [x] 6.5 Add any new term to `docs/GLOSSARY.md`
- [x] 6.6 `ROADMAP.md`: M2 complete, with its done-when clauses checked off against
      what actually shipped
- [x] 6.7 Check every governing document for drift

## 7. Closing

- [x] 7.1 `./tools/test.sh` green
- [x] 7.2 `openspec validate add-chase-camera --strict` passes
- [x] 7.3 Confirm the coverage gate reports M2 at zero deferred, and that the
      `UNMET` entry for *Keeping the boundary invisible* is unchanged
- [x] 7.4 Raise an `att` task for anything found in passing
- [x] 7.5 Critic review against CONSTRAINTS §12 Review criteria R1–R8, by a reviewer
      who did not write the change. **Ask it to attack the thresholds**: whether
      2.1's settling threshold and 2.2's time constant were genuinely fixed before
      the measurements or reverse-engineered to pass, and whether any test
      re-implements the formula it claims to check. Also ask it to re-run every
      mutation this change claims to have verified — three reviews of
      `add-world-presentation-layer` each found a false verification claim from the
      round before, and the round after that found one in `world_test.gd` that had
      never been in the file at all

## 8. Found while building
       *Superseded: per-change Critic reviews were retired by
       `streamline-process`; this change was archived under its §12 archive
       checklist (gate green, validate --strict, docs current) instead.*
- [x] 8.1 **A defect in committed work, fixed in its own commit (`20e61fa`).**
      `3f43233` added three test suites and never registered them in `test.sh` —
      they passed when run by hand and protected nothing on any later run. The
      cause was a Python edit that mutated in memory, hit a failed assertion on a
      SECOND anchor, threw, and never wrote. Third time this shape has appeared in
      this project; the commit message records the lesson, which is to assert the
      anchor before mutating and verify the file on disk afterwards
- [x] 8.2 `driver_test.gd` gained the half of A10's resolution that
      `camera_test.gd` cannot carry. The tick-grouping check drives the camera
      itself, so it proves the property holds when stepped per tick and says
      nothing about the running game. The root is now asserted to advance the
      camera exactly once per simulation step
- [x] 8.3 **The focus-clearing behaviour defeats background captures**, which is the
      game working. Captures run unfocused so they do not interrupt anyone, and
      `main.gd` clears every held input on focus-out exactly as the design document
      requires — so a synthetic hold is cleared and the kart coasts. A first run
      drove 560 ticks and stopped at z=56.064. `drive_capture.gd` re-presses each
      tick, driving through the real input path rather than around it. `att` 16
- [x] 8.4 `drive_capture.gd` reports the kart's final position on every run. A
      capture whose subject sat still looks much like one whose subject drove, and
      the number is the difference — it is how 8.3 was found
- [x] 8.5 A first camera test measured a camera that never lagged, because 600
      spin-up ticks drove the kart 115 wu into a ±90 boundary and left it bouncing
      near a standstill. Steady state arrives at 156 ticks; the constant is now 200
      with the reasoning beside it

## 9. Review round 1

Critic pass: [REJECTED] on R2 twice and R7. Part 1 held — the thresholds were
genuinely fixed before measuring, the derivations reproduce independently, and the
reviewer found the time-constant check tighter than advertised (quantised to 1/60 s
against a +/-0.01 s band, so only exactly 12 ticks passes). All findings addressed.

- [x] 9.1 **F1 (Critical, R2/R3) — the change's headline deliverable was guarded by
      nothing.** Deleting the `ChaseCamera` node from `main.tscn`, putting the game
      back on the placeholder this change exists to retire, left the whole suite
      green: the root reads it with `get_node_or_null` and skips it when absent. The
      change's OWN delta spec has the scenario for it — "The running game uses the
      specified camera, not the placeholder" — and no test claimed it.
      `scripts/view/camera_view.gd` had zero coverage of any kind.
      `driver_test.gd` now asserts the camera exists, is `current`, that the
      placeholder is NOT current, and that the view's field of view and position are
      the core camera's unmodified — which also closes the untested scenario "The
      view applies the camera and does not compute it"
- [x] 9.2 **F2 (Major, R2) — `aimUp` had no assertion anywhere in the repository.**
      Setting `aim_y = 0` left the suite green, and the tuning-literal gate excludes
      it as a small integer, so nothing held a value the design document states. The
      aim was also asserted at yaw 0 ONLY — where `sin(yaw)` is zero, so computing
      it in the world frame instead of the kart's passed. That is the failure this
      same file warns about for the position three functions above; the position
      obeyed the rule and the aim did not. Now asserted at 8 headings, on all three
      axes, plus that the aim is ahead of the kart and the camera behind it
- [x] 9.3 **F3 (R7) — the tick-grouping check cannot fail from any production
      change**, and `camera_thresholds.md` listed it under "verified by breaking what
      they guard" beside a real production mutation. It drives the camera itself, so
      only editing the test breaks it. Corrected to say which evidence is which:
      `driver_test.gd` carries the production demonstration, and both directions of
      it were re-run
- [x] 9.4 **F5 (R7) — the governing document rationalised where the design file was
      honest.** CONSTRAINTS §4 Architectural boundaries claimed `scripts/core/` is "the only place a per-tick
      recurrence can be driven and asserted without a renderer". False: any
      `RefCounted` module is. The real reason is ENFORCEMENT — it is the only
      directory the boundary gate polices — which `design.md` D1's alternatives had
      already said. The false version had been copied into three other places;
      corrected in all four, with the correction noted rather than silent
- [x] 9.5 **F4 (R7).** The register's UNMET entry still said the kart-height capture
      "waits for the chase camera". It has shipped. The entry now names
      `2026-08-29-m2-camera-boundary.png`, with the position the tool reported, and
      keeps the oblique capture as the contrasting view. `att` 15 updated
- [x] 9.6 **F6.** A10 said the grouping check "fails on all five"; there are four
      comparisons and it failed on four
- [x] 9.7 **F7.** The fov-rest capture had no recorded command. Added — the reviewer
      confirmed it is byte-identical to `capture.sh res://scenes/main.tscn`
- [x] 9.8 **F8.** Dead `camera` field in `camera_view.gd`, never read or written
- [x] 9.9 **F9.** Task 6.6 promised M2's done-when clauses "checked off" and the
      ROADMAP added only a prose header. Each of the ten clauses now carries ✅ or
      ⚠️, so the one that is unmet is visible in the list rather than only in the
      paragraph above it
- [x] 9.10 **Part 1 nit.** The progress note said the thresholds were committed "in
      its own commit"; `871541f` also carries `chase_camera.gd` and its tuning
      fields. Corrected — in a document whose whole argument is commit ordering, that
      distinction is the argument
- [x] 9.11 **F11 (observation, now gated).** Nothing enforced that a suite is
      registered, which is what let `3f43233` ship three dark ones.
      `tools/check_suites_registered.py` compares every `tests/*.gd` against what
      `test.sh` actually runs, with the two helpers excluded by name and a stated
      reason each. Verified by removing `camera_test.gd`'s line and watching it fail
