# Tasks: streamline-process

Process surgery (this session, reviewed before commit):

- [x] 1. Rewrite CONSTRAINTS §11 Work tracking (two layers) and §12 Review
       (archive checklist + milestone Critic); trim every section's narrative
       to its enforceable core. Section numbers and titles unchanged (V11).
- [x] 2. ROADMAP.md: add `## Backlog` with the six triaged lines (D4); update
       every att reference; update "How this connects to the other layers".
- [x] 3. Retire `.att/`: `git rm -r`, references updated in
       `openspec/config.yaml`, `godot/CLAUDE.md`,
       `godot/docs/testing_toolkit.md`, `godot/docs/GLOSSARY.md`,
       `godot/docs/AMBIGUITIES.md` (att 10 / att 20 pointers → backlog).
- [x] 4. `godot/CLAUDE.md`: Toolchain table, tracker section, and the five
       erosion rules updated to the two-layer, two-moment process.

Implementation (picked up after review):

- [x] 5. `godot/tools/test.sh` green; `openspec validate streamline-process
       --strict`, `check_links.py`, `check_section_refs.py`,
       `check_placeholders.py` all pass over the edited documents.
- [x] 6. Close att 19: every suite now runs through `run_suite`, which fails
       the run naming the suite on `SCRIPT ERROR`/`Parse Error`/`Failed to
       load script` in its output or a non-zero exit;
       `check_suites_registered.py` learned the wrapper counts as a run.
       Mutation-verified both ways: an injected runtime error in
       camera_test.gd failed the run naming the suite (after the suite
       printed its own success line — the exact att-19 hole), and an
       unregistered probe suite still fails the registration gate.
- [ ] 7. Archive the five completed M2/M3 changes
       (`add-world-presentation-layer`, `add-kart-view-orientation-and-input`,
       `add-chase-camera`, `add-seeded-world-scatter`,
       `add-aabb-collision-response`) under the new archive checklist.
- [ ] 8. Archive this change.
