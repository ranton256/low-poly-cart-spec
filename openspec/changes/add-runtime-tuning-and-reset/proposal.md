# Proposal: add-runtime-tuning-and-reset

## Why

M7's last scenario and its last "done when" bullets. **Reset Kart** is the
document's own escape hatch for the two-prop pin (the §4 note has pointed at
it since M3), and the *Adjusting handling without a restart* scenario needs a
real surface — the core has taken live tuning since M1 (the shared tuning
object is read every tick, and the determinism suite has claimed that
scenario since M4), but nothing in the running game lets a person change a
value.

**Design-document features implemented:** *Runtime Tuning and Player Actions
/ Resetting the kart* — M7's final deferral; the coverage gate reaches 64/64
owned. **Acceptance items advanced:** 13 completes.

## What Changes

- **`Sim.reset_kart()`** (core): position to the origin, heading to +Z,
  velocity to exactly zero — and nothing else: the lap clock, the banked
  time, the best, the race state, and the world are untouched. The M4
  review's standing note is honoured: the suite asserts best-time
  persistence *through the reset*, closing the half of the persistence
  scenario that only covered regeneration.
- **`R` acts**: the long-bound `reset_kart` action calls it while racing —
  and frees a kart pinned between two props, which the suite proves by
  staging the pin from the collision suite's own geometry.
- **The tuning surface** (port's choice, deliberately not a HUD): the
  composition root polls `data/tuning.json`'s modification time once a
  second on the simulation clock and, on change, re-applies the table into
  the *same shared tuning object* — so an edit in any text editor is in
  force on the next tick, no restart, no state disturbed. Not player-facing;
  nothing draws it.
- Visual proof for the milestone: the before/save/regenerate/restore capture
  pair, plus this change's reset assertions.

## What is deliberately excluded

- Any tuning UI — §7's instrumentation prohibition stands; the file IS the
  surface.
- Durable storage of any kind.
