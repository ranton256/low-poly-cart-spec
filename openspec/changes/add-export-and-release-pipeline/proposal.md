# Proposal: add-export-and-release-pipeline

## Why

M8's second half is §14's ladder: gate → export → smoke → sign → tag. The
Web preset and its measured 20.5 MB payload exist; the other three targets,
the smoke procedure, signing, versioning, and the tag do not.

## What Changes

- **Presets** for macOS (Apple Silicon), Windows, and Linux beside the Web
  preset; `tools/export_all.sh` builds all four from HEAD into `build/`,
  refuses a dirty tree, and prints sizes and SHA-256 checksums.
- **The smoke seam**: `LPC_SMOKE=1` makes the shipped game smoke itself —
  boot unaided, reach the countdown, take control on GO, replay the lap
  suite's phase table through the real input path, bank a lap, write a
  screenshot beside the artifact when `LPC_SMOKE_SHOT` names one, and exit 0;
  any miss exits nonzero. This is what "boots to countdown, drives, banks a
  lap, exits clean" means when a human isn't at the keyboard, and it runs
  against the *exported artifact*, not the editor.
- **Phase 2 on this machine**: the macOS artifact smoked natively; the web
  build served and cold-loaded in a real browser session with the ≤ 5 s
  countdown measurement recorded (§8's last 📋 row). **Windows and Linux
  artifacts are built and checksummed but cannot be launched on this Mac** —
  their smoke is documented as the release ladder's standing instruction and
  disclosed as unexecuted, not claimed.
- **Phase 3, half-executed and disclosed**: codesign with the Developer ID
  Application certificate under the hardened runtime with timestamp;
  notarization and stapling documented step-for-step but requiring the
  user's Apple ID credentials, which this machine does not hold. The
  clean-machine validation likewise falls to the user.
- **Phase 4**: `config/version` → 1.0.0, annotated tag `v1.0.0`, release
  notes citing the complete ambiguity register as the deliverable.

## What is deliberately excluded

- No behaviour change outside the env-gated smoke path; `LPC_SMOKE` unset is
  the whole game, unchanged, and the standing suites stay green to prove it.
- No new gallery states, no CI, no store packaging.
