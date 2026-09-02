# Proposal: retune-handling-and-line-clearance

## Why

First outside-user feedback on the 1.1.0 distribution (relayed by the
owner, 2026-08-31): (A) the collision on a tree near the course is wonky,
(B) steering feels jerky, and the owner added (C) top speed feels sedate.

Diagnosis, on the record:

- **(A)** is the tree at (44.40, −10.79) — scattered at 48° yaw, 2.34 wu
  off the gate-3→4 leg. The spec's collision is the world-axis-aligned box
  of the rotated prop, which at that yaw inflates to 2.64 wu against a
  ~1.86 wu visible canopy: effective clearance to the racing line is
  **0.12 wu**. Players visually pass the tree and hit an invisible wall.
  The collision model is faithful to the spec; the *placement* is the bug —
  curation guaranteed clear gate mouths and said nothing about the line
  between them.
- **(B)** is onset, not rate: `yaw += turnRate` arrives in full the tick
  the key goes down. A step function feels like a jerk because it is one.
- **(C)** top speed is friction-and-clamp limited at 11.52 wu/s.

## What Changes

- **The ×1.25 retune with ease-in** (GDD amendment 3e0c98c, its own
  backportable commit): `accel` 0.010, `maxSpeed` 0.25, `turnRate` 0.05,
  `steerThreshold` 0.0125, new `steerEaseSeconds` 0.12. The uniform scale
  is the load-bearing insight: the speedometer is ratio-based and the
  recurrence linear, so **every dial anchor, every acceptance timing, and
  the turning radius are unchanged** — the world is 25% faster, and the
  ease turns steering onset into a 0.12 s linear ramp that resets on
  release or reversal. Tuning stays a named value in `data/tuning.json`
  (live-tunable through the existing file watch — no new adjustment
  feature, per the owner).
- **The racing-line clearance rule** in the authoring curation
  (`tools/author_first_light.gd`): every prop's **worst-case collision
  AABB** (the yawed box's world-axis expansion — the thing that actually
  collides, not the visual) must clear the baked drive's path by a named
  margin (`lineClearanceWu`, port_decisions, ~1.5 wu); offenders are
  dropped or nudged by the tool and reported by name. The wonky tree goes;
  the rule holds for every future course. Since the retune changes speeds,
  the drive re-bakes anyway; pilot, clearance, and bake iterate to a fixed
  point (clearance is measured against the FINAL baked path).
- **The bookkeeping that follows**: sim ease state in the determinism
  summary; suites for the ramp (RED first: linear climb, reset on release
  and reversal, threshold gating unmodified, peak equals turnRate);
  re-pinned content test; re-derived targets from the faster baked lap;
  refresh-probe record regenerated; gallery re-blessed (every drive-timed
  state shifts); conformance item 5's steering case adapted to hold
  through the ramp window.

## What is deliberately excluded

- Any change to the collision model itself (trunk-vs-canopy footprints,
  rotated-box collision) — the spec's AABB model stays; if line clearance
  proves insufficient, that is a future amendment with its own physics
  ripple.
- A steering-tuning UI or any adjustment feature: the tuning file is the
  knob, as it already is for everything else.
- Version bump/tag/distribution — after the owner plays the retune.
