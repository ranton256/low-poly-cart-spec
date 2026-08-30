# Tasks: add-checkpoint-circuit-core

- [ ] 1. `scripts/core/circuit.gd`: gates, cursor, gate-frame pass test on
       the stage-5 observable; wired into stage 8 beside the lap gate;
       banned-symbols clean; joins `stats_line()`.
- [ ] 2. `lap_gate.gd`: threaded-lap condition when a circuit is loaded;
       per-circuit best keying; core medal determination at bank time.
- [ ] 3. `layout_io.gd`: v2 parse/validate/round-trip of the circuit
       object; malformed-circuit whole-file refusal; save writes it back
       byte-identically.
- [ ] 4. `tests/circuit_test.gd` (RED first): gate frames at several yaws,
       push-out immunity (mutation-verified like the band's ordering
       discriminator), cursor forgiveness, reset-keeps-progress, threaded
       banking with no minimum time, per-circuit bests, medal at-target
       edge. layout_test grows the v2 cases.
- [ ] 5. Coverage: the five core deferrals claimed with `@covers`; the
       layout deferral split honestly (round-trip claimed, refusal still
       deferred); register updated.
- [ ] 6. Gate green (`tools/test.sh`); `openspec validate --strict`;
       archive checklist run.
