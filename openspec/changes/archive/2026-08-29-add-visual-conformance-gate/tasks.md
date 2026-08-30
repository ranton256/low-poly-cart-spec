# Tasks: add-visual-conformance-gate

- [x] 1. `tools/gallery.sh`: the five deterministic states (READY boot, GO!,
       HUD at speed, pinned boundary, banked lap) through the post-draw
       capture path, into `gallery/`.
- [x] 2. Calibrate: run the set twice, diff, record the floor and the limits
       in `gallery_config.json`.
- [x] 3. Bless the baselines into `tests/baselines/` and commit them — M6's
       visual proof.
- [x] 4. CONSTRAINTS: V9 ✅, §7 Testing's image-diff row ✅ with the
       calibration; `godot/tools/test.sh` untouched (windowed split).
- [x] 5. Gate green; `openspec validate --strict`; archive checklist run.

Notes: reaching a ~zero floor took three harness fixes, each caught by the
calibration itself: captures drove to loop-iteration counts while boot frame
variance shifted the sim tick (whole-scene drift on hud_at_speed); the lap
phases had the same flaw; and the settle frames let the sim coast a
run-varying tail after the target tick (fixed by pausing the tree). Final
floor: three states byte-identical, worst 0.038 / 0.23% / 0.05% against
limits 0.50 / 1.00% / 0.10%. The gate is mutation-verified. The §8 hard
budgets were measured while the tools were open: 1.34 ms/frame racing and
0.0087 ms/step over 54 props.
