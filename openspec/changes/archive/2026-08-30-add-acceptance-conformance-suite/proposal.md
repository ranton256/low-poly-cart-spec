# Proposal: add-acceptance-conformance-suite

## Why

The Acceptance Checklist is the contract, and G2 is its gate: *one named
conformance test per item, asserting the stated tolerance as a literal* —
planned since M0 (V7), owed by M8. The machinery behind every item already
exists across twelve suites; what G2 adds is the one place a reviewer reads
fourteen names against fourteen items and sees the document's own numbers.

Also owed here: **acceptance 14b** (the real game at three refresh rates —
the half of item 14 the standing suite cannot carry), the last two Backlog
gates (the lap-gate ordering discriminator; the grazing-angle gallery state),
and **A12's GDD amendment** — the register's only open entry, a defect in the
document itself that M3 measured and the Backlog has carried since.

## What Changes

- **`tests/conformance_test.gd`** — fourteen named cases, `_item_01` through
  `_item_14`, each quoting its checklist sentence and asserting its literal
  tolerance; the suite fails if any case is missing. Item 14's case runs the
  14a harness (three batchings, byte-agreement) and names the windowed 14b
  tool as the other half. **V7 flips ✅.**
- **`tools/refresh_probe.gd`** (windowed) — the same scripted ~60 s input
  sequence run at 30, 60, and 144 fps caps through the real game; end
  positions within **0.5 wu**, lap times within **0.05 s**. Run, recorded.
- **The ordering discriminator** (Backlog, M8): a case where a collision
  push-out carries the kart *into* the band on the very tick its legitimate
  stage-5 displacement qualifies — the lap banks only because the gate runs
  after collision; a gate moved before stage 7 fails it.
- **The grazing-angle state** (Backlog, M8): a staged camera low over a
  receding row of cones joins the gallery set and baselines — the dedicated
  verification the anisotropic requirement deferred at M6.
- **A12 resolved by GDD amendment** (by proposal, per CONSTRAINTS §16 Changing this document): the
  pin sentence's "cannot drive out" becomes the measured truth — held with
  velocity zeroed every tick, squeezed free by the radial push's instability
  within roughly a second or two depending on heading, Reset Kart the
  immediate escape. The placement rule and the response are untouched; only
  the false sentence changes. The register's last entry moves to Resolved.

## What is deliberately excluded

- Exports, smoke, signing, tagging — `add-export-and-release-pipeline`.
- Any behaviour change: this change asserts and documents; the one normative
  edit is to the sentence A12 proved false, in the GDD's own change process.
