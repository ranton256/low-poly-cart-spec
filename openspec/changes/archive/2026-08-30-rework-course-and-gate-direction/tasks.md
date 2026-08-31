# Tasks: rework-course-and-gate-direction

- [x] 1. Waypoint pilot in `tools/author_first_light.gd` (pure, per-tick,
       bang-bang steering to the next gate then the band); bake to the
       LAP_PHASES table shape; the tool emits the table, the pinned ticks,
       and the lap time.
       *Done. `pilot_input()` is static and takes plain values: accelerate
       always, steer on the sign of the wrapped angle to the waypoint, deadband
       one tick of `turnRate` — a smaller one chatters and bakes hundreds of
       one-tick phases (measured: 656 phases at half this deadband, 27 at this
       one). The bake runs against the FILE the tool just wrote, so it sees the
       five-decimal quantized props and gates the game reads, and it runs twice
       — once with the curated props and once with none, the world
       lap_gate_test replays on — refusing to emit a table if the two differ or
       if the drive touches a prop at all. Determinism verified by running the
       tool twice and byte-comparing: identical file, identical output.*
- [x] 2. Spread first-light: six-to-eight gates touring distinct field
       regions, band finish northbound; curation re-run (mouths clear,
       bounds); targets re-derived from the baked lap and recorded.
       *Done. Seven gates: (0,22) north up the start straight, (26,36)
       north-east, (54,0) east, (35,-30) south-east, (2,-48) far south,
       (-19,-28) south-west, (-4,-16) the run-in, then north through the band.
       All mouths 12 wu, every turn <= 98 degrees, no U-turn and no second
       corridor. Curation dropped ONE prop (a tree in gate 4's mouth); 53 of 54
       remain. Targets from the baked 21.9833 s lap: gold 20.5, silver 23.0,
       bronze 25.5 — baked -1.0 / +1.5 / +4.0 s, each rounded DOWN to the half
       second so the readouts are round and gold stays under the reference lap.
       The tool derives them; they are no longer a hand-typed constant.*
       *Deviation: gate 7 was first placed at (-3,-4), beside the start line,
       keeping the M9 tool's "a wider last gate frames the start" idea. The
       first blessing pass showed the pre-race frame filled by its pylons and
       its ground arrow, so it moved south of the inspection camera and back to
       a 12 wu mouth. Judged from the image, not from the table.*
- [x] 3. Re-point the consumers to the baked table: lap_gate_test
       LAP_PHASES, main.gd SMOKE_PHASES (restated, source named),
       conformance LAP_SCRIPT, lap_capture (uses the suite's table),
       circuit_content_test pins. LPC_SMOKE must exit 0 banking; the lap
       suite must thread-and-bank.
       *Done. Proof: `lap_gate_test` green; `circuit_content_test` green with
       the pass ticks pinned element for element (139/298/544/735/931/1090/
       1208) and the bank tick 1319; `LPC_SMOKE=1 godot --path .` exits 0
       having banked a 22.00 s lap at tick 1532; conformance green with item 14
       replaying the cycled table.*
       *Two consumers were passing on a coincidence and now say what they mean:
       `prop_field_test` asserted the boot field held the tuning's requested
       totals, true only while curation dropped nothing; conformance item 15
       compared the restarted world's prop COUNT with the shipped file, which a
       fresh scatter also satisfies, and now compares prop for prop against the
       arrangement the session is playing.*
- [x] 4. Direction visuals: chevron → arrowhead along gate-forward; stripe
       → arrow; headless orientation assertions at several yaws (RED
       first); back-of-gate legibility judged in the blessed images.
       *Done, RED first: the assertion was written against the symmetric
       furniture and reported "points along gate-forward (0,0,1), not (0,0,0)"
       — no direction at all — ten times before a line of view code changed.
       The test derives each mesh's forward from its own vertices in world
       space (the mean of its distinct horizontal corners against the midpoint
       of its widest span, both affine, so the answer rotates with the gate) at
       yaws 0, +/-45, 90 degrees and 2.317 rad. Mutation-verified twice more:
       arrows built backwards fail at all five yaws, and furniture built on a
       world axis fails at every yaw but 0 and 90.*
       *No new tuning constant was needed for the chevron; ONE was added for
       the stripe — `gateStripeReachWu` in the existing `port_decisions` group
       — after the first blessing pass showed a mark only `gateDepth` deep
       foreshortening into the bar it replaced. The GDD was not touched.*
- [x] 5. Refresh probe re-run against the new course; the recorded txt
       regenerated (conformance item 14 pins it).
       *Done, windowed: 0.0000 wu / 0.0000 s across all three rate pairs, a
       22.00 s lap banked at each of 30/60/144 fps, 1800/3600/8641 frames
       drawn. Item 14's literal is re-pinned to `best lap 22.00`. Recorded in
       the txt: an earlier attempt reported 0 frames drawn on two of the three
       passes because the window had stopped being drawn behind another one —
       that run was discarded rather than recorded, because a pass reporting no
       frames is not evidence of a rate.*
- [x] 6. Gallery: re-bless all states (course + gate art changed);
       gate_next restaged if composition needs it; double-capture noise
       floor re-measured and appended to the calibration record; images
       actually looked at.
       *Done — the measured floor is in `tools/gallery_config.json`'s
       calibration block and the state list is in `tools/gallery.sh`. gate_next
       did NOT need restaging: gate 1 at z = 22 sits about eight world units
       ahead of the kart at tick 336. TWO STATES WERE ADDED, `gate_front` and
       `gate_back`: the amended requirement is a COMPARISON ("a gate met from
       behind reads as the back of a gate"), no single frame can carry it, and
       the judgement that signs this task off should be re-runnable rather than
       a sentence in a commit message — `tools/gate_side_capture.gd`.*
- [x] 7. A15 in `godot/docs/AMBIGUITIES.md` (directional furniture gap,
       playtest-found, amendment-resolved, GDD commit 869893e) + the
       CONSTRAINTS §5 Conformance to the specification mirror row; release
       record untouched (that is v1.0.0's history, not this change's).
       *Done. A15 files the gap, why no gate could have caught it, why a flat
       overhead arrow was rejected on the camera geometry, and how the
       direction is held. A14's text was corrected in passing: it quoted the
       15.05 s lap as though it were fixed, and that lap is regenerated
       content. "## Open: None" still holds. `docs/release/1.0.0.md`
       untouched.*
- [x] 8. Gate green; `openspec validate --strict`; archive checklist run.
       The next owner playtest judges the course and targets before the M9
       Critic runs.
       *One deferral, and it has its ROADMAP Backlog line: SMOKE_PHASES is a
       restated copy of a GENERATED table living inside `godot/scripts/`, so
       every re-bake churns `tuning_literal_allowlist.json` entries for
       whichever tick counts collide with a tuning magnitude — two retired and
       one raised inside this change alone. The proposal keeps SMOKE_PHASES in
       its current form, so the fix is a later change, not this one.*
