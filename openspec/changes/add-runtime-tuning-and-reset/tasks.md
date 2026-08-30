# Tasks: add-runtime-tuning-and-reset

- [x] 1. `Sim.reset_kart()` (RED first, in a persistence-suite extension):
       surgical reset asserted field by field — including best-time
       persistence through the reset (the M4 review's standing note) — and
       the staged two-prop pin freed.
- [x] 2. `R` wired in `_read_input`, racing only; the §4 pin note's escape
       is real.
- [x] 3. The tuning watch in `main.gd`: mtime polled once a second on the
       sim clock; a changed table applied into the shared object; suite
       asserts application via the loader path without writing repo files.
- [x] 4. Milestone visual proof: the before/save/regenerate/restore pair via
       a layout capture tool; ROADMAP M7 ticks.
- [x] 5. `godot/tools/test.sh` green; `openspec validate --strict`; archive
       checklist run.

Notes: RED first (R needed a second physics frame — just_pressed lands the
frame after the synthetic press). The M4 review's standing note is closed:
best and banked persist through the reset, asserted beside the surgical
field-by-field checks, and the pin's escape runs through the REAL binding
against a staged hold. The milestone proof is the strongest yet: with the
sim frozen, the restored frame is BYTE-identical to the original (pixel
mean 0.0000) while the regenerated world between them differs at 2.14.
Coverage: 63 verified + 1 visual-with-baseline, ZERO deferred — every
scenario in the document is owned.
