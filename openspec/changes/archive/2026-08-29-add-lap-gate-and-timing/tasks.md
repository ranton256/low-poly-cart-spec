# Tasks: add-lap-gate-and-timing

- [x] 1. Tuning: the core object gains `min_lap_time`, `lap_crossing_threshold`,
       `lap_restart_delay`, `best_flash_duration`, and the three gate-geometry
       values; `missing_fields()` extended; loader test still green.
- [x] 2. `scripts/core/lap_gate.gd` (RED first): the clock, the gate test
       against stage 5's displacement, the hold window, best tracking, the
       flash countdown. `lap_gate_test.gd` drives a real scripted lap and
       every Rejecting-a-crossing row, plus the push-out and heading-south
       traps from the document's own paragraph.
- [x] 3. `Sim`: stage 5 records its +Z displacement; stage 8 drives the gate;
       lap clock, banked time, and best join `stats_line()`. Determinism and
       replay suites still green (their runs now carry lap state).
- [x] 4. Overlay: `TIME` and `BEST` readouts — two decimals, the hold, the
       placeholder, yellow base and green flash from data rows
       (`bestTextColour`, `bestFlashColour` join `unnamed_in_spec`).
- [x] 5. `# @covers` claims: the six lap scenarios, the race timer, and the
       unset best; the register's deferrals pruned; M4's deferred count
       reaches zero.
- [x] 6. `godot/tools/test.sh` green (suite registered); `openspec validate
       --strict`; archive checklist run.
- [x] 7. Capture: `TIME` frozen on a banked lap with `BEST` flashing green —
       M4's second mandated proof — via a deterministic scripted drive.

Notes: task 2 ran RED first. The run_suite guard landed by
streamline-process caught this change's own suite mid-development — a
runtime error (wrong Prop field name) aborted the push-out test while the
suite still printed its success line, the exact hole the guard exists for,
on the very next change after it shipped. Coverage 41 -> 49 verified; M4's
deferred count is zero, and the two mandated captures are committed.
