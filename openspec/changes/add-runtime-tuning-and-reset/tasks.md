# Tasks: add-runtime-tuning-and-reset

- [ ] 1. `Sim.reset_kart()` (RED first, in a persistence-suite extension):
       surgical reset asserted field by field — including best-time
       persistence through the reset (the M4 review's standing note) — and
       the staged two-prop pin freed.
- [ ] 2. `R` wired in `_read_input`, racing only; the §4 pin note's escape
       is real.
- [ ] 3. The tuning watch in `main.gd`: mtime polled once a second on the
       sim clock; a changed table applied into the shared object; suite
       asserts application via the loader path without writing repo files.
- [ ] 4. Milestone visual proof: the before/save/regenerate/restore pair via
       a layout capture tool; ROADMAP M7 ticks.
- [ ] 5. `godot/tools/test.sh` green; `openspec validate --strict`; archive
       checklist run.
