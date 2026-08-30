# Tasks: add-layout-persistence

- [ ] 1. `layout_test.gd` (RED first): export fields/format, restore at exact
       transforms with release-first, round-trip identity (fp tolerance),
       double-cycle byte-identity, collision-order preservation, malformed
       rejection leaving the world untouched.
- [ ] 2. `scripts/world/layout_io.gd`: export from records in registration
       order; import reconstructing placements in file order through the
       existing `build()` path; validation before any release.
- [ ] 3. Wiring: `save_layout` acts on `P`; new `load_layout` on `L`, bound
       in project.godot and pinned in `check_settings.py`;
       `LPC_LAYOUT_FILE` honoured and exported by the harness; the web
       download half behind the platform check (M8 smoke exercises it).
- [ ] 4. A2 and A3 recorded resolved (register details + CONSTRAINTS §5
       Conformance to the specification mirror); the §7 Testing save-file row
       updated to name the layout seam.
- [ ] 5. `godot/tools/test.sh` green (suite registered); `openspec validate
       --strict`; archive checklist run.
