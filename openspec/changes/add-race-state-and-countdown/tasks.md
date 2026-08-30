# Tasks: add-race-state-and-countdown

- [x] 1. `scripts/core/race_state.gd`: the three states, ticks-in-state, the
       derived countdown index, the error condition. Pure, typed, headless-
       constructible. `race_state_test.gd` covers transitions-taken-once,
       tick-240 GO!, and the freeze (RED first, then green).
- [x] 2. `Sim.step()` gains the race-state stage and the RACING gate on the
       kart pipeline; state + countdown tick join the state summary. Extend
       `determinism_test.gd`/`replay_test.gd` to boot from LOADING so 14a
       spans the countdown.
- [x] 3. Driver/bootstrap: LOADING until the world is built, automatic
       handoff to STARTING, failure path sets the error and halts. Extended
       `driver_test.gd` with the boot/suspension test. *Deviation, recorded
       honestly:* the halt is proven at the race-state level (terminal
       LOADING) — a driver-level broken-model injection needs a load seam
       `PropField` does not have; that seam is a Backlog line, and the wiring
       under test is the three-line verdict in `main.gd`'s `_ready`.
- [x] 4. View: countdown overlay (glyphs + colours from data, `goLinger`
       from ticks-since-RACING), loading indicator and error swap, the
       inspection camera until RACING, chase engage on the first racing
       frame. Headless-scene assertions where possible.
- [x] 5. Input during STARTING: held keys tracked, kart frozen, focus-loss
       clearing unregressed. Extend `input_test.gd` both directions.
- [x] 6. `# @covers` claims for every implemented scenario; the coverage
       gate's M4-deferred count drops to the lap-gate cluster only.
- [x] 7. `godot/tools/test.sh` green; `openspec validate --strict` passes;
       archive checklist run.
- [x] 8. Capture: the countdown at GO! (green, kart still at the line) for
       `docs/progress/` — half of M4's visual proof.

Notes: task 1 ran RED first (the suite parse-failed before race_state.gd
existed, then assertions drove the implementation). Coverage moved 33 → 41
verified; M4's deferred count is now the lap-gate cluster alone (6). The
suite-registration and tuning-literal gates each caught this change once —
race_state_test unregistered, and the 60-ticks constant colliding with
shadowVolumeExtent — which is two of the gates paying rent.
