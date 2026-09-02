# Tasks: retune-handling-and-line-clearance

- [x] 1. Tuning: the ×1.25 values + `steerEaseSeconds` (0.12) into
       `data/tuning.json`'s named groups mirroring GDD 3e0c98c;
       `lineClearanceWu` (1.5) into port_decisions; `tuning.gd` fields.
       `steer_ease_seconds` joins `missing_fields()` — the tick reads it.
       `line_clearance_wu` does NOT: only the authoring tool and the content
       test read it, and a loader must not refuse to run the game over a
       value the tick never touches. `author_first_light.gd` refuses for
       itself when it is zero, which is the same guarantee where it belongs.
- [x] 2. Sim: the ease ramp in the core (pure; per-direction hold counter;
       reset on release/reversal; threshold gating untouched; ease state in
       `stats_line()`). RED-first suite: `tests/steer_test.gd`, seven cases,
       19 failures before the implementation and green after — linear climb
       tick by tick, reset on release, reset on reversal (and on both-held),
       peak exactly `turnRate` from tick 8, no steering at or below the
       threshold at any ease value.
       **The threshold edge, decided:** the hold counter advances BEFORE the
       threshold gate, so the ramp counts HELD ticks, not steering ticks. The
       GDD says the ease "never gates the threshold rule" but does not settle
       this; this port rules that the ramp models the hand on the key, not the
       kart's speed — the alternative reintroduces a jerk exactly where the
       kart accelerates through `steerThreshold`, which is the moment the
       feature exists to smooth. Asserted by name in
       `_test_the_ramp_counts_held_ticks`, and written into `_stage_3_steer`'s
       docstring.
- [x] 3. THE CLAIM HELD, and exactly rather than within tolerance. With only
       the four constants changed, dial 103 is first read on tick 56, dial 115
       on tick 156, and the coast falls below `steerThreshold` on tick 73 —
       the SAME TICK INDICES as before the retune, measured side by side with
       both tuning sets in one process. `tests/tick_test.gd` and
       `tests/tuning_loader_test.gd` (the shipped table against item 4) and
       conformance item 4 all pass with every dial anchor and every timing
       literal untouched. The gallery says it too: `hud_at_speed` reads
       112 KM/H at tick 330 before and after.
       **Two edits inside those files that are NOT dial or timing
       assertions**, both disclosed: (a) `tick_test`'s `SETTLE_TICKS` guard
       band 300 → 200 — it is derived from the speed ("the kart covers the
       90 wu to the limit in ~469 ticks"), and at 0.24 wu/tick it covers them
       in 399, so the settle-and-stay run had to end before the fence rather
       than 57 ticks past it; (b) `_test_steering_magnitude_and_both_directions`
       now holds each direction through the ramp before measuring, because the
       GDD scenario it quotes was itself amended to "the PEAK turn rate".
       Conformance item 5 needed no change and got none.
- [x] 4. Authoring: worst-case-AABB line-clearance rule, iterating
       bake → drop → re-bake to a fixed point (settled after 2 passes). The
       48°-yaw tree at (44.40, −10.79) is named and dropped —
       "dropping tree #12 at (44.40, -10.79) — 0.51 wu from the racing line,
       under 1.50" — leaving 52 props (53 minus the one gate-mouth blocker
       already dropped). Twice-run byte-compare of the shipped file: identical
       (sha256 a00afb80…).
       **Deviation, and the load-bearing one in this change: the racing line
       is a CORRIDOR, not the pilot's arc alone.** Measured against the arc
       only, the retuned drive swings wide on the gate-3→4 leg and clears that
       tree's box by 2.75 wu — the rule as first written would have passed the
       very placement this change exists to remove. The tight line through the
       gate centres clears it by 0.51. So `racing_line()` is the union of the
       two, and the delta spec was amended to say so. The justification is the
       proposal's own diagnosis (which measures the tree against the *leg*,
       2.34 wu) and the tool's own target scheme (gold is "a tighter line
       through the same gates, which the bang-bang pilot does not drive").
       **Second deviation: the pilot's deadband.** It was one tick of
       `turnRate`; with the ease, a fresh press buys a seventh of that, and
       the pilot chattered — 170 baked phases of press-release-press. The
       deadband is now `turnRate / (steerEaseSeconds × 60)`, the authority a
       fresh press really has, which is the same reasoning the old constant
       was chosen by. 36 phases.
       **Clearance is box-to-line with the kart's width NOT subtracted** — the
       quantity the delta spec names. The proposal's headline "0.12 wu" is
       that distance minus the kart's contracted half-width; both readings are
       recorded in `author_first_light.gd`'s header so neither is mistaken for
       the other.
- [x] 5. Consumers re-pointed and re-proven on the faster drive: LAP_PHASES,
       SMOKE_PHASES and LAP_SCRIPT all carry the new 36-phase table;
       `circuit_content_test` re-pinned to bank tick 1075 / 17.9167 s / gate
       ticks [116, 246, 444, 599, 756, 886, 984] and gained
       `_test_no_prop_ambushes_the_racing_line`, which re-checks the committed
       file against the tool's own `racing_line()`. Lap suite green;
       `LPC_SMOKE=1 godot --path .` exits 0 — "banked a 17.93 s lap at tick
       1315" (1315 − 240 countdown ticks = the baked 1075 exactly); conformance
       green, with item 14's recorded best lap re-pinned 22.00 → 17.93. That
       one SHOULD move: it pins regenerated content, not a checklist figure.
       Item 5 holds as written.
       `tests/{replay,determinism,smoke,boundary}_test.gd` also carry the
       amended physics table — they transcribe the GDD's constants like every
       other core suite, and leaving them at the old values would have left
       four suites testing physics the document no longer specifies.
- [x] 6. Targets re-derived by the tool from the 17.9167 s baked lap, same
       scheme as the rework (gold = lap − 1.0, silver = +1.5, bronze = +4.0,
       each rounded DOWN to a half second): **gold 16.5, silver 19.0,
       bronze 21.5** — ordered, all positive, gold under the baked lap, which
       `circuit_content_test` asserts. Refresh probe re-run WINDOWED and
       unoccluded (3600 / 1800 / 8641 frames drawn, so no pass was refused);
       all three rate pairs 0.0000 wu and 0.0000 s; record regenerated as
       `docs/progress/2026-09-01-refresh-probe.txt` and `RECORDED_14B`
       re-pointed at it. The 2026-08-30 record is left in place as the
       1.1.0 build's own evidence.
- [x] 7. Gallery re-blessed; noise floor re-measured from two fresh
       `--capture-only` sets and appended to `_calibration`; every image read.
       Exactly three baselines actually moved — `gate_next`, `hud_at_speed`,
       `lap_banked`, the three timed off the drive — and the other six
       measured under their own noise against the pre-retune ones, which is
       the retune's signature. No state was restaged: each still frames its
       subject, `gate_next` better than before.
       **Disclosed:** `gate_next`'s `strong_pct` floor is 0.083% against a
       0.10% limit (three samples: 0.005 / 0.074 / 0.083) — the tightest
       margin the set has carried, because the retune drove the kart from 8 wu
       short of gate 1 to 4.4 and filled the frame with yellow edges. The
       limit was NOT widened and no override was added; the measured fallback
       (tick 288 → 0.043%) is recorded beside it and in ROADMAP's Backlog.
       **Also disclosed:** no gallery state looks at the gate-3→4 leg, so the
       dropped tree is not visible in any frame. Its removal is proven by the
       shipped file and by `circuit_content_test`, not by a picture.
- [x] 8. Gate green; `openspec validate --strict`; tasks honest; archive;
       gate green again; commit. The owner plays the retune before any
       version bump or distribution.
