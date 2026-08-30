# Tasks: add-heads-up-display

- [ ] 1. Data: §7's colours and px values join `unnamed_in_spec` (several
       collide with named constants as literals); A1's settlement recorded in
       `godot/docs/AMBIGUITIES.md` and CONSTRAINTS §5's register row.
- [ ] 2. `hud_test.gd` (RED first): timer block top-right with §7 sizes and
       colours; dial size, rim, readout at steady speed (the core's 115),
       needle angle formula and tick-clock easing; pointer input ignored;
       every value from data.
- [ ] 3. Overlay: timer block restyled and moved top-right (labels above
       values); title & controls block; countdown/loading faces and sizes per
       §7 via SystemFont; speedometer control with clipped half-dial, rim,
       gradient needle, KM/H and readout.
- [ ] 4. M4 Critic debts: countdown label assertions in `driver_test.gd`
       (GO! green while priors white; goLinger hide-and-reset; inspection
       camera looks toward the origin), and the `LPC_FAIL_LOADS` seam in
       `PropField` with the driver-level failure-boot test (visible error +
       logged cause). Backlog lines retired.
- [ ] 5. `godot/tools/test.sh` green (suite registered); `openspec validate
       --strict`; archive checklist run.
