## 1. The values the tick is written against

- [x] 1.1 Add `godot/scripts/core/tuning.gd` — a plain value object holding the physics and world constants, constructible directly with no file access (design D2; spec: *The simulation reads no files*)
- [x] 1.2 Add `godot/scripts/core/input_state.gd` — held flags for forward, reverse, left, right, with a clear-all operation, and no engine input types (spec: *The caller supplies input as held state*)
- [x] 1.3 Add a loader outside the core that builds a `Tuning` from `godot/data/tuning.json`, so the core never locates or parses it (design D2)
- [x] 1.4 Confirm `check_boundaries.py` still passes — the new core files must reference no engine type

## 2. The tick

- [x] 2.1 Replace `godot/scripts/core/sim.gd` with the real simulation: 64-bit scalar velocity, yaw and position, an integer tick count, and no `Vector3` in the recurrence (design D3)
- [x] 2.2 Implement `step()` as the design document's **eight named stages in order**, with collision and the lap gate present and empty, each commented with the change that will fill it (design D1; spec: *A tick is a single ordered advance*, *Stages not yet implemented keep their place in the order*)
- [x] 2.3 Stage 1 accelerate, stage 2 clamp — clamp **before** friction, forward and reverse limits distinct (spec: *Reverse is limited more tightly than forward*)
- [x] 2.4 Stage 3 steer — gated on the **post-clamp, pre-friction** speed exceeding the threshold, direction multiplied by the sign of travel (spec: *Steering depends on motion*)
- [x] 2.5 Stage 4 friction, stage 5 integrate along the kart's own heading with no lateral component (spec: *The kart travels along its own heading*)
- [x] 2.6 Stage 6 boundary — clamp each axis, then apply the bounce factor **once** if either or both clamped, tracked by a flag so it cannot be written as two independent clamps (design D5; spec: *A corner costs the same as an edge*)
- [x] 2.7 Expose the speed ratio and the integer dial readout as core arithmetic (design D4; spec: *Speed builds and decays to the specified curve*)
- [x] 2.8 Confirm elapsed time is derived from the tick count and nothing reads a host clock or frame delta (spec: *A tick never reads wall-clock or frame time*)

## 3. Behaviour tests

- [x] 3.1 Add `godot/tests/tick_test.gd`. Expected timings come from the design document, never from running the implementation and recording what it did (design D6)
- [x] 3.2 **Acceptance item 4a** — holding accelerate from rest, the dial first reads the nine-tenths value at the stated time, within ±0.05 s
- [x] 3.3 **Acceptance item 4b** — the dial first reads its steady value at the stated time within ±0.05 s, and never exceeds it thereafter
- [x] 3.4 **Acceptance item 4c** — coasting from steady state falls below the steering threshold at the stated time, within ±0.05 s
- [x] 3.5 Assert the steady speed is strictly **below** the clamp, which is what applying friction after clamping produces (spec: *The dial settles at its achievable maximum and stays*)
- [x] 3.6 **Acceptance item 5** — steering does nothing at or below the threshold, and reverses sense when travelling backwards
- [x] 3.7 Assert the turn rate is independent of speed above the threshold
- [x] 3.8 Assert travel direction matches heading at a spread of angles, forward and reverse, with no lateral drift
- [x] 3.9 Assert opposing inputs cancel, combined inputs both apply, and held input persists until cleared

## 4. Boundary tests

- [x] 4.1 Add `godot/tests/boundary_test.gd`
- [x] 4.2 Assert a single-axis crossing clamps exactly to the limit and reverses velocity by the bounce factor
- [x] 4.3 **Assert a corner impact applies the factor once** — the resulting speed must be lower in magnitude than before, and must not match the squared-factor value that per-axis application would produce (design D5)

## 5. Reproducibility and tuning

- [x] 5.1 Assert two separately constructed simulations given identical tuning and input agree exactly, tick for tick, with no tolerance (spec: *Two identical runs agree exactly*)
- [x] 5.2 Assert accumulated error over the longest run the timing tests need is far below ±0.05 s (spec: *Precision is sufficient for the stated tolerances*)
- [x] 5.3 Assert a tuning value changed mid-run takes effect on the next tick and disturbs no other state (spec: *A changed value applies immediately*)
- [x] 5.4 Assert the simulation can be constructed and stepped with tuning supplied directly, no file present

## 6. Wiring and close-out

- [x] 6.1 Rewrite the inherited smoke suite's determinism and tick-rate checks against the real simulation, in the same commit that replaces `sim.gd`, so the suite is never green against a simulation that no longer exists (design, Migration Plan)
- [x] 6.2 Add the new suites to `godot/tools/test.sh`
- [x] 6.3 Remove both `godot/data/tuning_literal_allowlist.json` entries — they justify coincidences in the placeholder `sim.gd`, which no longer exists. Confirm the staleness rule flags them if left
- [x] 6.4 Confirm `check_tuning_literals.py` passes with real game code present — this is the first change it has anything to bite on
- [x] 6.5 Update `CONSTRAINTS §10 Verification criteria`: V2 now rests on a real simulation rather than a placeholder
- [x] 6.6 Re-measure the suite wall time and update `CONSTRAINTS §8 Performance and size budgets` if it moved
- [x] 6.7 File `att` tasks for anything deferred out of scope
- [x] 6.8 Run `openspec validate add-simulation-tick-core --strict`
- [x] 6.9 `godot/tools/test.sh` green
- [x] 6.11 Critic pass follow-up: add the two assertions that discriminate the steering threshold and the post-clamp/pre-friction stage order. The review found both mutants surviving the entire suite — the at-rest test passed on `sign(0) == 0` rather than on the threshold, leaving `steer_threshold` wholly unguarded
- [x] 6.12 Critic pass follow-up: add `tests/tuning_loader_test.gd`, asserting acceptance item 4 against the **shipped** `data/tuning.json` rather than inline literals, and giving the loader the test `design.md` had claimed it already had
- [x] 6.13 Critic pass follow-up: correct three false claims — a nonexistent `tick.gd` in the proposal's file list, two omitted files, and a boundary-scenario count that included one belonging to M2
- [x] 6.10 Critic review against CONSTRAINTS §12 Review criteria R1–R8, by a reviewer who did not write the change — **one pass, [REJECTED]**. It passed the implementation (tick order correct, all three acceptance timings independently derived and hit) and rejected on R2 and R7: two mutants survived the whole suite, and three documentation claims outran the code. All addressed in 6.11–6.13. **[APPROVED]** by the repository owner
