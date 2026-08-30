# Proposal: add-lap-gate-and-timing

## Why

The race now starts; nothing scores it. The design document's lap gate is the
game's entire objective — cross the band under power, bank the time, chase the
best — and it is M4's remaining half.

**Design-document features implemented:** *Lap Detection and Best-Time
Tracking* entire (six scenarios, the whole of M4's remaining deferral), plus
the two Heads-Up Display scenarios the lap loop makes real and observable —
*Running the race timer* and *Displaying an unset best time*. The needle and
the minimap stay M5's.

**Acceptance-checklist items advanced:** item **10** (valid northbound
crossing banks; southbound-under-power banks nothing), completing M4's
acceptance set with item 1.

**The trap this time is the crossing test.** The document spends a paragraph
on what the +Z test is *not*: not the sign of the scalar velocity (driving
forward while heading south must not bank), and not net position change per
tick (the boundary clamp and the collision push-out both move the kart without
the player driving — a kart pinned against a prop's south side is shoved
+0.3 wu north every tick, thirty times the threshold). The only correct
observable is **step 5's own +Z displacement**, `v × (forward · +Z)`, captured
where it happens.

## What Changes

- **`scripts/core/lap_gate.gd`** — the lap clock, the banked-time hold window
  (`lapRestartDelay`, during which the clock is stopped and detection stays
  suppressed), session best-time tracking, and the best-flash countdown. Pure,
  tuned by injection, stepped only from the tick's stage 8.
- **`Sim`** — stage 5 records its own +Z displacement as an observable; stage 8
  stops being a placeholder and drives the gate — last in the tick, observing
  only, so a push-out can never satisfy it. Lap clock, banked time, and best
  join the determinism summary.
- **Tuning** — the core object gains the four timing constants and the three
  gate-geometry rows (already transcribed in `data/tuning.json`).
- **View** — the overlay grows the `TIME` and `BEST` readouts: two decimal
  places, the hold on a banked time, `--.--` before a first lap, yellow base
  with the green flash for `bestFlashDuration` on a new best. Colours come
  from data (V23).
- **Tests** — `lap_gate_test.gd` (written RED first) drives real laps and every
  rejection row; the coverage gate's M4-deferred count reaches zero.
- **Visual proof** — the second half of M4's mandate: `TIME` frozen on a banked
  lap with the `BEST` readout flashing green, captured deterministically.

## What is deliberately excluded

- The speedometer needle and the minimap — M5.
- Reset Kart (M7) and durable best-time storage (explicitly session-only; a
  fresh session starts with no best).
- Any change to the countdown, the states, or the kart pipeline's stages 1–7.
