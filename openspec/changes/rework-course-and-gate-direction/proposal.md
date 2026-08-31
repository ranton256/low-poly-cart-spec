# Proposal: rework-course-and-gate-direction

## Why

The owner's first playtest of the circuit found two things (2026-08-30):

1. **Underspecified — you cannot tell which way a gate faces.** The mechanic
   is directional (a backwards pass counts for nothing), but the specified
   furniture was symmetric. That is a spec gap, fixed by GDD amendment
   869893e (its own backportable commit): the chevron points along
   gate-forward, the stripe is an arrow, the back of a gate reads as a back.
2. **The course is a hairpin, not a circuit** — straight out, U-turn,
   straight back. A consequence of authoring the gates on the LAP_PHASES
   trajectory to keep the harness alive. The course must spread across the
   field, which means the harness drive can no longer be the historical
   phase table: the dependency has to be inverted.

## What Changes

- **The drive is derived from the course, not the course from the drive.**
  A small deterministic waypoint pilot (bang-bang steering toward the next
  gate's centre, per physics tick, pure function of sim state) is added to
  the authoring tool, which BAKES its input sequence into a phase table —
  runs of identical held inputs, exactly the shape every consumer already
  eats. `tests/lap_gate_test.gd`'s LAP_PHASES, `main.gd`'s SMOKE_PHASES,
  the captures, and the refresh probe all keep their current form; their
  tables are regenerated content. Re-authoring the course ever again is
  now: move gates, re-bake, re-record.
- **first-light spreads into a touring course**: six-to-eight gates
  visiting distinct regions of the field (not two parallel corridors),
  still finishing northbound through the band, mouths curated clear, every
  gate inside the boundary — the standing content test unchanged in shape.
  Targets re-derived from the baked drive's lap time and recorded; the
  owner re-judges them at the next playtest.
- **Gate direction visuals** per the amendment: the overhead chevron
  becomes an arrowhead oriented along gate-forward, the ground stripe an
  arrow in the same direction; from behind, the arrow points away — the
  back reads as a back. Direction asserted headlessly (mesh orientation vs
  gate yaw) and visually (baselines).
- **The bookkeeping that follows**: circuit_content_test's pinned
  pass-ticks and bank tick regenerated; conformance `_item_15` untouched in
  shape; the 14b probe re-run and its record regenerated; the gallery
  re-blessed (gate visuals and course both changed) with the noise floor
  re-measured; **A15** filed in the ambiguity register — the directional
  furniture gap, found by playtest, resolved by amendment — with the
  CONSTRAINTS §5 Conformance to the specification mirror row.

## What is deliberately excluded

- New mechanics, new constants beyond what the arrow rendering needs, any
  change to gate-pass semantics, targets tuning beyond the re-derivation
  (the owner's judgement at the next playtest), sound (M10).
