# Tasks: rework-course-and-gate-direction

- [ ] 1. Waypoint pilot in `tools/author_first_light.gd` (pure, per-tick,
       bang-bang steering to the next gate then the band); bake to the
       LAP_PHASES table shape; the tool emits the table, the pinned ticks,
       and the lap time.
- [ ] 2. Spread first-light: six-to-eight gates touring distinct field
       regions, band finish northbound; curation re-run (mouths clear,
       bounds); targets re-derived from the baked lap and recorded.
- [ ] 3. Re-point the consumers to the baked table: lap_gate_test
       LAP_PHASES, main.gd SMOKE_PHASES (restated, source named),
       conformance LAP_SCRIPT, lap_capture (uses the suite's table),
       circuit_content_test pins. LPC_SMOKE must exit 0 banking; the lap
       suite must thread-and-bank.
- [ ] 4. Direction visuals: chevron → arrowhead along gate-forward; stripe
       → arrow; headless orientation assertions at several yaws (RED
       first); back-of-gate legibility judged in the blessed images.
- [ ] 5. Refresh probe re-run against the new course; the recorded txt
       regenerated (conformance item 14 pins it).
- [ ] 6. Gallery: re-bless all states (course + gate art changed);
       gate_next restaged if composition needs it; double-capture noise
       floor re-measured and appended to the calibration record; images
       actually looked at.
- [ ] 7. A15 in `godot/docs/AMBIGUITIES.md` (directional furniture gap,
       playtest-found, amendment-resolved, GDD commit 869893e) + the
       CONSTRAINTS §5 Conformance to the specification mirror row; release
       record untouched (that is v1.0.0's history, not this change's).
- [ ] 8. Gate green; `openspec validate --strict`; archive checklist run.
       The next owner playtest judges the course and targets before the M9
       Critic runs.
