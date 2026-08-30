# Tasks: add-checkpoint-circuit-core

- [x] 1. `scripts/core/circuit.gd`: gates, cursor, gate-frame pass test on
       the stage-5 observable; wired into stage 8 beside the lap gate;
       banned-symbols clean; joins `stats_line()`.
       *Note:* `sim.gd` gained `last_step5_dx` — the band only ever needed
       the +Z half of the observable, and a gate at an arbitrary yaw needs
       the whole displacement to project onto gate-forward. The circuit
       advances BEFORE the lap gate within stage 8, so a final gate sited on
       the line itself threads the course on the tick it is passed.
       *Deviation:* `tuning.gd` gained only the two circuit constants the
       core reads — `gateDepth` and `gateCrossingThreshold`.
       `gatePylonHeight` and the six colours in the same table are
       presentation; adding fields nothing reads would put them in
       `missing_fields()` and fail a loader for values no simulation needs.
       `add-circuit-world-and-presentation` adds them when it draws a gate.
- [x] 2. `lap_gate.gd`: threaded-lap condition when a circuit is loaded;
       per-circuit best keying; core medal determination at bank time.
       The threaded condition REPLACES `minLapTime` rather than joining it —
       with no circuit loaded the interim guard is untouched. `best_seconds`
       stays the field every reader already holds and now carries the played
       circuit's best, with `bests` behind it and `select_circuit()`
       switching between them from `sim.arm_circuit()`.
- [x] 3. `layout_io.gd`: v2 parse/validate/round-trip of the circuit
       object; malformed-circuit whole-file refusal; save writes it back
       byte-identically.
       *Deviation, already recorded in the delta and the proposal:* a file
       WITHOUT a circuit — version 1 included — is still accepted. The GDD
       refuses it; the game must stay playable until the boot ships a
       circuit, so that refusal lands with the next change.
       *Judgement call, recorded:* a `circuit` object that declares an EMPTY
       `gates` array is treated as malformed and refuses the file. That is a
       validity rule of the circuit object, not the deferred gateless-file
       refusal — a circuit with no gates is not a circuit, the way a prop
       record with no asset is not a record.
       *Shape change:* `import_layout()` now returns a `Loaded` record
       (`ok`, `placements`, `circuit`) instead of an array. The empty array
       could not distinguish a refusal from a valid file of no props and
       left the circuit no way to travel back beside the placements.
- [x] 4. `tests/circuit_test.gd` (RED first): gate frames at several yaws,
       push-out immunity (mutation-verified like the band's ordering
       discriminator), cursor forgiveness, reset-keeps-progress, threaded
       banking with no minimum time, per-circuit bests, medal at-target
       edge. layout_test grows the v2 cases.
       RED: 26 failing assertions against an inert stub. Mutation: the pass
       test made to read net position change instead of the stage-5
       observable produced 16 failures including "a push-out cannot pass a
       gate — stage 5's gate-forward component stayed at nothing"; restored
       and re-verified green.
       *Note:* the exact "AT the threshold does not pass" edge is staged at
       yaw 0 only, where `sin`/`cos` are exactly 0 and 1 so the projection is
       exactly the threshold; at an arbitrary yaw `sin²+cos²` lands a few ulp
       off unity and the staged value is no longer exactly the threshold.
       Every yaw still asserts that a sub-threshold displacement is refused.
- [x] 5. Coverage: the five core deferrals claimed with `@covers`; the
       layout deferral split honestly (round-trip claimed, refusal still
       deferred); register updated.
       Register 11 entries → 6; M9 deferrals 10 → 5. "Track Layout
       Persistence / A layout is a circuit" keeps its deferral with a reason
       that now says the round-trip half is tested and names the refusal
       half as what it still waits for. "Checkpoint Circuit / Medal targets"
       is NOT claimed: that scenario is written about the held `TIME`
       readout, and nothing is drawn yet — only the core verdict the display
       will read is tested.
- [x] 6. Gate green (`tools/test.sh`); `openspec validate --strict`;
       archive checklist run.
       *Out-of-scope fix, recorded:* the gate was already RED on this branch
       before any work here — `check_section_refs.py` failed on
       `add-circuit-world-and-presentation/tasks.md:18`, a section-5
       reference written without its title, introduced by the proposal commit
       f428b47. One line there was given the section's title so this change
       could reach a green gate. Nothing else in that change was touched.
