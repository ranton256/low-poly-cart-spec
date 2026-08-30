# Tasks: add-export-and-release-pipeline

- [x] 1. macOS / Windows / Linux presets in `export_presets.cfg`;
       `tools/export_all.sh` (clean-tree check, four builds, sizes,
       SHA-256s).
- [x] 2. The `LPC_SMOKE` seam in `main.gd` (with `LPC_SMOKE_SHOT`): scripted
       boot → GO → lap bank → screenshot → clean exit; RED-checked (a smoke
       that cannot bank must exit nonzero); suites stay green with the seam
       unset.
- [x] 3. Phase 1 run: all four artifacts from one commit, recorded.
- [x] 4. Phase 2 run where this machine can: macOS artifact smoke (banked
       lap + capture), web build served and smoked on a cold cache with the
       cold-load-to-countdown seconds recorded; §8's cold-load row flipped
       to measured. Windows/Linux smoke documented, disclosed unexecuted.
- [x] 5. Phase 3: codesign (Developer ID, hardened runtime, timestamp),
       `codesign --verify` recorded; notarize/staple/clean-machine steps
       documented for the credential holder, disclosed unexecuted.
- [x] 6. Phase 4: `config/version` 1.0.0; the annotated `v1.0.0` tag is cut
       as the milestone's final act, AFTER the Critic's verdict, so a
       remediation cannot orphan it (recorded deviation from this task's
       original wording), release
       notes with the register; CONSTRAINTS §8 Performance and size budgets
       and §14 Release and packaging rows updated; ROADMAP M8 notes.
- [x] 7. Gate green; `openspec validate --strict`; archive checklist run.
