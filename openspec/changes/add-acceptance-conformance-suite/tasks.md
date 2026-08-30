# Tasks: add-acceptance-conformance-suite

- [ ] 1. `tests/conformance_test.gd`: the fourteen named cases at literal
       tolerances, self-checking that all fourteen ran; registered in the
       standing suite. V7 → ✅ in CONSTRAINTS §10 and the §13 gate table.
- [ ] 2. The ordering discriminator case (Backlog line retired); verified by
       the §7 mutation rule — moving the gate's stage must fail it.
- [ ] 3. `tools/refresh_probe.gd`: the ~60 s scripted sequence at 30/60/144
       fps caps; run on the reference machine, bounds asserted, numbers
       recorded; the 14b roadmap bullet ticks on the recorded run.
- [ ] 4. The grazing-angle gallery state staged, added to `gallery.sh`,
       baselined and blessed (Backlog line retired).
- [ ] 5. A12's GDD amendment (by proposal, this change): the pin sentence
       rewritten to the measured truth; A12 → Resolved in the register and
       CONSTRAINTS §5; the §4 pin note updated; `collision_test`'s pin
       assertions unchanged (they already assert the truth).
- [ ] 6. `godot/tools/test.sh` green; `openspec validate --strict`; archive
       checklist run.
