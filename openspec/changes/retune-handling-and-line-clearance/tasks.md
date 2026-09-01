# Tasks: retune-handling-and-line-clearance

- [ ] 1. Tuning: the ×1.25 values + `steerEaseSeconds` (0.12) into
       `data/tuning.json`'s named groups mirroring GDD 3e0c98c;
       `lineClearanceWu` (1.5) into port_decisions; `tuning.gd` fields.
- [ ] 2. Sim: the ease ramp in the core (pure; per-direction hold counter;
       reset on release/reversal; threshold gating untouched; ease state in
       `stats_line()`). RED-first suite: linear climb, reset both ways,
       peak == turnRate, no steering below threshold at any ease.
- [ ] 3. Verify the ratio-invariance claim the amendment leans on:
       tick_test and conformance item 4 must pass UNMODIFIED (dial 103/115
       at the same seconds). If they do not, the claim was wrong — stop and
       say so rather than adjusting the tests.
- [ ] 4. Authoring: worst-case-AABB line-clearance rule; iterate
       pilot→clearance→re-bake to a fixed point; the 48°-yaw tree at
       (44.40, −10.79) must be named as an offender and resolved; shipped
       file + baked tables regenerated (twice-baked byte-compare).
- [ ] 5. Consumers re-pointed and re-proven on the faster drive:
       LAP_PHASES/SMOKE_PHASES/LAP_SCRIPT, content-test pins, smoke exit 0,
       lap suite threads-and-banks; conformance item 5 holds through the
       ramp window (a 60-tick hold is ~7 ticks of ramp + full rate — keep
       the case honest).
- [ ] 6. Targets re-derived from the faster baked lap (same scheme as the
       rework, recorded); refresh probe re-run, record regenerated.
- [ ] 7. Gallery re-blessed (drive-timed states all shift); noise floor
       re-measured and appended; images looked at.
- [ ] 8. Gate green; `openspec validate --strict`; tasks honest; archive;
       gate green again; commit. The owner plays the retune before any
       version bump or distribution.
