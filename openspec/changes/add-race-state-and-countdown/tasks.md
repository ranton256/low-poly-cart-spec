# Tasks: add-race-state-and-countdown

- [ ] 1. `scripts/core/race_state.gd`: the three states, ticks-in-state, the
       derived countdown index, the error condition. Pure, typed, headless-
       constructible. `race_state_test.gd` covers transitions-taken-once,
       tick-240 GO!, and the freeze (RED first, then green).
- [ ] 2. `Sim.step()` gains the race-state stage and the RACING gate on the
       kart pipeline; state + countdown tick join the state summary. Extend
       `determinism_test.gd`/`replay_test.gd` to boot from LOADING so 14a
       spans the countdown.
- [ ] 3. Driver/bootstrap: LOADING until the world is built, automatic
       handoff to STARTING, failure path sets the error and halts. Extend
       `driver_test.gd`; a deliberately-broken model path proves the halt.
- [ ] 4. View: countdown overlay (glyphs + colours from data, `goLinger`
       from ticks-since-RACING), loading indicator and error swap, the
       inspection camera until RACING, chase engage on the first racing
       frame. Headless-scene assertions where possible.
- [ ] 5. Input during STARTING: held keys tracked, kart frozen, focus-loss
       clearing unregressed. Extend `input_test.gd` both directions.
- [ ] 6. `# @covers` claims for every implemented scenario; the coverage
       gate's M4-deferred count drops to the lap-gate cluster only.
- [ ] 7. `godot/tools/test.sh` green; `openspec validate --strict` passes;
       archive checklist run.
- [ ] 8. Capture: the countdown at GO! (green, kart still at the line) for
       `docs/progress/` — half of M4's visual proof.
