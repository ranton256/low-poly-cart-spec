# Proposal: add-heads-up-display

## Why

The race is scored but barely readable: M4 shipped minimal TIME/BEST text in
the wrong corner. The design document's §7 HUD art specification makes every
listed element **player-facing and required** — the speedometer half-dial, the
top-right timer block, the title and control hints, and the specified faces,
sizes and colours for the countdown and loading overlays.

**Design-document features implemented:** *Heads-Up Display / Driving the
speedometer needle* (the last HUD scenario); §7's art table for the title,
timer block, speedometer, countdown, and loading elements (normative prose,
not scenarios). The minimap is the milestone's second change.

**Acceptance-checklist items advanced:** none directly (item 9 is the
minimap); this change is §7 conformance plus M5 "done when" bullets 1–3.

**Also carried, from the M4 Critic review:** the two M5-tagged Backlog debts —
countdown-overlay label assertions in the standing suite (findings 1 and 4),
and the `PropField` load seam so the broken-model boot is proven through the
real driver, including the developer-log clause (finding 3).

**Ambiguity A1 is settled here:** HUD px values are literal at the project's
1280×720 design resolution (`window/size/viewport_*`), with Godot's
`canvas_items` stretch scaling the whole canvas for other window sizes.
Recorded in the register as part of this change.

## What Changes

- **Timer block** moves to its specified home: top-right, labels above values,
  TIME in green at 24 px over a 12 px 70%-opacity label, BEST in yellow with
  the `--.--` placeholder and the green flash — behaviour unchanged from M4
  (its claims and tests stand), styling now to §7.
- **Speedometer**: a 160×90 half-dial Control — 8 px `#444444` rim, bottom
  half clipped, a 4×70 px red→yellow needle pivoting at bottom centre sweeping
  `(ratio × 180°) − 90°`, ~0.1 s eased **on the simulation clock**, `KM/H` in
  grey and the integer readout in white beneath. Reads `speedo_readout()` —
  the arithmetic already lives in the core.
- **Title & controls**: top-left, title in the green at ~20 px, hints beneath
  in white at 14 px, 80% opacity.
- **Countdown and loading** conform to §7's faces and sizes (monospace via
  `SystemFont` — the repo ships no font asset, and a system-mono request is
  the lightest conforming choice).
- Every colour and px value joins `data/tuning.json`'s `unnamed_in_spec`
  (several would collide with named constants as literals — 90 alone matches
  `drivableExtent` and `fovMax`); no HUD element intercepts pointer input.
- **Tests**: a `hud_test.gd` suite (RED first) reading the labels and dial
  through the running scene; countdown-overlay assertions and the load-seam
  failure boot join `driver_test.gd`.

## What is deliberately excluded

- The minimap (`add-minimap-viewport`) and the milestone's full-frame capture,
  which needs both changes live.
- Developer instrumentation of any kind — §7 deliberately specifies none.
- Any change to core arithmetic: `speedo_readout()` and the lap counters are
  already specified and tested; this change draws them.
