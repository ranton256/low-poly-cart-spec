# Tasks: add-export-and-release-pipeline

- [ ] 1. macOS / Windows / Linux presets in `export_presets.cfg`;
       `tools/export_all.sh` (clean-tree check, four builds, sizes,
       SHA-256s).
- [ ] 2. The `LPC_SMOKE` seam in `main.gd` (with `LPC_SMOKE_SHOT`): scripted
       boot → GO → lap bank → screenshot → clean exit; RED-checked (a smoke
       that cannot bank must exit nonzero); suites stay green with the seam
       unset.
- [ ] 3. Phase 1 run: all four artifacts from one commit, recorded.
- [ ] 4. Phase 2 run where this machine can: macOS artifact smoke (banked
       lap + capture), web build served and smoked on a cold cache with the
       cold-load-to-countdown seconds recorded; §8's cold-load row flipped
       to measured. Windows/Linux smoke documented, disclosed unexecuted.
- [ ] 5. Phase 3: codesign (Developer ID, hardened runtime, timestamp),
       `codesign --verify` recorded; notarize/staple/clean-machine steps
       documented for the credential holder, disclosed unexecuted.
- [ ] 6. Phase 4: `config/version` 1.0.0, annotated `v1.0.0` tag, release
       notes with the register; CONSTRAINTS §8 Performance and size budgets
       and §14 Release and packaging rows updated; ROADMAP M8 notes.
- [ ] 7. Gate green; `openspec validate --strict`; archive checklist run.
