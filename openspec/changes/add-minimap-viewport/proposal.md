# Proposal: add-minimap-viewport

## Why

The last M5 instrument: the player can read speed and time but not where they
are. The design document's Minimap feature — five scenarios, all of M5's
remaining deferral — and **acceptance item 9**: a north-fixed inset tracking
the kart with a marker and a **true-heading** arrow, explicitly not the
reference build's 90°-offset arrow (a listed deviation the port must not
reproduce).

## What Changes

- **`scripts/view/minimap_view.gd`** — a `SubViewportContainer` at the §7
  inset (200×200, 10 px from bottom-left, no border), whose `SubViewport`
  shares the main world and renders it through an **orthographic** camera
  looking straight down from `minimapAltitude`, framing `minimapHalfExtent`
  each way, `minimapNear`/`minimapFar` clip planes. The camera's basis is
  fixed: world **+X to the right, +Z to the bottom edge** — the map never
  rotates with the kart. A separate viewport is what "depth cleared first,
  never occluded, no distortion of the main view" means in Godot terms.
- **Markers in the world, masked by render layer**: a flat red unshaded disc
  (~2.4 wu) and a yellow unshaded triangle pointing along the kart's true
  heading, both on render layer 2 — the minimap camera sees layers 1+2, the
  chase camera's cull mask drops layer 2. Never moved off-screen or toggled.
- **Tracking reads the post-physics snapshot**, re-centred while RACING (the
  Suspending scenario already pins that minimap tracking does not run outside
  it).
- Marker geometry values join `unnamed_in_spec`; the arrow's yaw is the
  simulation's — the true heading, by construction.
- **Tests**: `minimap_test.gd` (RED first) — inset, framing, fixed
  orientation under a turning kart, marker tracking and true heading, and the
  layer-mask isolation, all headless.

## What is deliberately excluded

- The milestone's full-frame capture (after this change, with every element
  live) and the M5 Critic pass — milestone close-out, not this change.
- Minimap content styling beyond the specification: it is a live top-down
  view of the world, not a stylised map.
