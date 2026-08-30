# Tasks: add-visual-conformance-gate

- [ ] 1. `tools/gallery.sh`: the five deterministic states (READY boot, GO!,
       HUD at speed, pinned boundary, banked lap) through the post-draw
       capture path, into `gallery/`.
- [ ] 2. Calibrate: run the set twice, diff, record the floor and the limits
       in `gallery_config.json`.
- [ ] 3. Bless the baselines into `tests/baselines/` and commit them — M6's
       visual proof.
- [ ] 4. CONSTRAINTS: V9 ✅, §7 Testing's image-diff row ✅ with the
       calibration; `godot/tools/test.sh` untouched (windowed split).
- [ ] 5. Gate green; `openspec validate --strict`; archive checklist run.
