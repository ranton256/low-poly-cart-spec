# Proposal: add-render-pipeline-and-web-budget

## Why

M6's first half: the look's remaining mechanics, the debts the milestone owns,
and the one UNMET scenario in the whole document. Five distinct items, grouped
because they all touch the render pipeline and the capture harness the second
change (the visual gate) will stand on:

1. **Capture determinism** (Backlog, twice-bitten): the capture tools can
   return a frame hundreds of ticks stale — the M5 review reproduced it, and
   the M5 proof re-capture rolled it again. A visual gate built on a lottery
   is a lottery. Root cause and measured settle floor, not a bigger guess.
2. **A11, the ground's visible edge** — the register's own fourth option: a
   distant ground skirt in the same albedo beyond the fog's end, leaving §5's
   200×200 Ground, the ±90 boundary, and 50→150 fog all exactly as stated.
   The chase camera now exists to judge it; judged, implemented, resolved.
3. **The minimap-fog decision** (Backlog): the ortho camera at 100 wu looks
   down through fog that starts at 50 wu and washes the map out. Decision: the
   minimap camera carries its own Environment with fog disabled — the GDD
   asks for "a live top-down view", and a map's job is legibility.
4. **Filtering, DPI, resize**: anisotropic filtering per §5; the render-scale
   cap at 2× (its scenario becomes a verified claim — the cap is arithmetic);
   the resize scenario claimed by a real resize test (stretch mode does the
   work; the test proves the HUD and minimap survive it).
5. **The web payload, measured**: a web export preset, a release export, and
   the compressed size against the 25 MB budget. The cold-load-to-countdown
   half of the budget needs a served browser session and lands with M8's web
   smoke — a disclosed split, Backlog-lined.

**Design-document features implemented:** *Frame Loop and Render Pipeline /
Adapting to a resized viewport* and */ Limiting render resolution on
high-density displays* (both currently visual-register entries, both becoming
verified claims); the *Keeping the boundary invisible* scenario moves from
UNMET to met-by-skirt with its capture. **Acceptance items advanced:** 7 (the
boundary look) and the §8 web budget row.

## What Changes

- `tools/drive_capture.gd` (and the capture path generally): grab only after
  `RenderingServer.frame_post_draw`, and verify the frame corresponds to the
  reported sim state; settle floor measured by double-capture diff and
  recorded where the guessed constants were.
- `world_builder.gd`: the ground skirt (same albedo, beyond fog's end, no
  grid, receives no shadows, outside the drivable and scatter extents).
- `minimap_view.gd`: a fog-free Environment on the minimap camera.
- Project settings: anisotropic filtering level pinned; `main.gd` caps the
  content/render scale at 2× on high-DPI displays.
- `export_presets.cfg`: a Web preset; the export runs and the payload is
  measured against 25 MB compressed.
- Tests: capture-freshness check, skirt geometry, minimap environment, DPI
  cap arithmetic, resize survival; register entries for resize/DPI retired in
  favour of claims; A11 resolved in the register.

## What is deliberately excluded

- The windowed gallery gate, thresholds, and baselines — the second change.
- Cold-load timing (M8's web smoke, with the payload number carried forward).
- Any GDD edit: the skirt is a port decision that leaves every stated number
  intact — that is exactly why the register's fourth option wins.
