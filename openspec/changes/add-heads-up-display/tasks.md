# Tasks: add-heads-up-display

- [x] 1. Data: §7's colours and px values join `unnamed_in_spec` (several
       collide with named constants as literals); A1's settlement recorded in
       `godot/docs/AMBIGUITIES.md` and the CONSTRAINTS §5 Conformance to the specification register row.
- [x] 2. `hud_test.gd` (RED first): timer block top-right with §7 sizes and
       colours; dial size, rim, readout at steady speed (the core's 115),
       needle angle formula and tick-clock easing; pointer input ignored;
       every value from data.
- [x] 3. Overlay: timer block restyled and moved top-right (labels above
       values); title & controls block; countdown/loading faces and sizes per
       §7 via SystemFont; speedometer control with clipped half-dial, rim,
       gradient needle, KM/H and readout.
- [x] 4. M4 Critic debts: countdown label assertions in `driver_test.gd`
       (GO! green while priors white; goLinger hide-and-reset; inspection
       camera looks toward the origin), and the `LPC_FAIL_LOADS` seam in
       `PropField` with the driver-level failure-boot test (visible error +
       logged cause). Backlog lines retired.
- [x] 5. `godot/tools/test.sh` green (suite registered); `openspec validate
       --strict`; archive checklist run.

Notes: task 2 ran RED first. The tuning-literal gate earned its keep four
times in one change — 90/160/10/30 as layout literals, plus a collision it
raised in rng.gd the moment hintPx entered the data (the same
new-row-breaks-an-untouched-file lesson the sim.gd 60 entry records).
Both M4 Critic Backlog debts are retired: the countdown-overlay clauses and
the inspection camera's look-at are standing driver_test assertions, and the
LPC_FAIL_LOADS seam boots the real scene into the terminal LOADING error.
