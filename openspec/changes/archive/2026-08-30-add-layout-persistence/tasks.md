# Tasks: add-layout-persistence

- [x] 1. `layout_test.gd` (RED first): export fields/format, restore at exact
       transforms with release-first, round-trip identity (fp tolerance),
       double-cycle byte-identity, collision-order preservation, malformed
       rejection leaving the world untouched.
- [x] 2. `scripts/world/layout_io.gd`: export from records in registration
       order; import reconstructing placements in file order through the
       existing `build()` path; validation before any release.
- [x] 3. Wiring: `save_layout` acts on `P`; new `load_layout` on `L`, bound
       in project.godot and pinned in `check_settings.py`;
       `LPC_LAYOUT_FILE` honoured and exported by the harness; the web
       download half behind the platform check (M8 smoke exercises it).
- [x] 4. A2 and A3 recorded resolved (register details + CONSTRAINTS §5
       Conformance to the specification mirror); the §7 Testing save-file row
       updated to name the layout seam.
- [x] 5. `godot/tools/test.sh` green (suite registered); `openspec validate
       --strict`; archive checklist run.

Notes: task 1 ran RED first. The byte-identity promise took two rounds of
float discipline to land honestly: export quantizes at nine decimals with
the height derived FROM the quantized scale (deriving both from the raw
value leaked the scale's quantization error into the height's last digit),
and the test asserts the scenario's actual property — cycles CONVERGE to
byte-identity (N vs N+1), with the first re-export allowed to differ from
scatter's own arithmetic by observed 6e-8 float dust, far inside the stated
tolerance and separately asserted at 1e-3 on every transform.
