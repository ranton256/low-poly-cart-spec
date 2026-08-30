# Proposal: add-visual-conformance-gate

## Why

M6's second half: a green suite proves behaviour and says nothing about what
is on screen — this milestone alone produced three layout bugs the headless
suites passed over, every one caught by looking at a capture. The look now
matches the spec; V9 is the gate that notices when it stops.

**Advances:** V9 (gallery diffs within recorded thresholds on all three
criteria), the §7 Testing image-diff row, and the M6 "done when" bullets for
the windowed gate, measured thresholds, and the baseline set as the
milestone's visual proof.

## What Changes

- **`tools/gallery.sh`** — the windowed capture set, every state deterministic
  (named seed, fixed tick counts, the post-draw capture path): the READY boot,
  the GO! frame, the HUD at speed, the pinned boundary through the skirt, and
  the banked lap with its green flash. Never part of `test.sh` — headless has
  no renderer.
- **Thresholds calibrated, not guessed**: the capture set runs twice, the
  diff of the two runs is the noise floor, the limits sit a small multiple
  above it, and both numbers are recorded in `gallery_config.json`.
- **Baselines committed** under `tests/baselines/` via the compare tool's
  `--bless` — the milestone's mandated visual proof.
- CONSTRAINTS rows flip: V9 ✅, the §7 image-diff row ✅ with the calibration
  recorded.

## What is deliberately excluded

- Running the gallery in `test.sh` — the windowed/headless split is a
  standing constraint.
- New scenario claims: the gate guards the look; the scenarios were claimed
  by the changes that built it.
