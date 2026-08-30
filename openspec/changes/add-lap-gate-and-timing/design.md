# Design: add-lap-gate-and-timing

## D1 — The crossing observable is captured at stage 5, tested at stage 8

**Decision.** `Sim._stage_5_integrate()` records the +Z displacement it
actually applied (`velocity × forward_z()`) in an observable field; stage 8
hands that, with the post-everything position, to the gate.

**Alternative: recompute `v × cos(yaw)` inside stage 8.** Rejected: by
stage 8 a collision may have zeroed `velocity` (stage 7), so the recomputation
sees a different value than the integration used. The document names *step 5's
own displacement* as the test precisely because the later stages move the kart
without the player driving; the observable must be captured where it happens
or it is a different observable.

**Alternative: compare positions across the tick.** Rejected by the document
itself — the pinned-kart paragraph: a push-out is +0.3 wu of net +Z per tick,
thirty times the threshold, banking laps for a kart that is stopped dead.

## D2 — The lap clock is the lap module's own tick counter, not the race clock

**Decision.** `lap_gate.gd` owns `clock_ticks`, advanced by stage 8 while no
hold is pending; the race state's `ticks_in_state` is untouched.

**Alternative: derive the lap clock from `race.ticks_in_state`.** Rejected:
the clock restarts on every banked lap and stops for `lapRestartDelay`, so it
diverges from time-since-RACING after the first lap; deriving it would need a
growing ledger of subtractions. A counter that is the thing itself cannot
disagree with it. The hold window's "dead time belonging to no lap" falls out:
the counter simply does not run during the hold.

## D3 — The view derives the flash and the hold; the core stores counters

**Decision.** The core exposes `display_seconds()` (the running clock, or the
banked time during the hold), `best_seconds` (−1.0 until a first lap), and
`best_flash_ticks` (armed to `bestFlashDuration` × 60 on a new best, counting
down). The overlay formats text and picks colours from data; it holds no
timing state of its own — same shape as the countdown overlay (race-state D4).

**Alternative: publish one-shot events (lap banked, best beaten).** Rejected
for now: CONSTRAINTS §4 Architectural boundaries reserves the event channel
for one-shot *effects*, and the readouts are continuous state — nothing here
needs an edge, and the M5 instruments will read the same counters. If M6 adds
a lap sound, the event lands then, beside its consumer.

## D4 — TIME and BEST ship now, in the overlay, and claim their scenarios

**Decision.** The minimal readouts (top-left, small face, exact behaviour)
land with the lap loop, and `# @covers` claims *Running the race timer* and
*Displaying an unset best time*.

**Alternative: keep the core headless until M5's instruments.** Rejected: M4's
mandated visual proof is "`TIME` frozen on a banked lap with a green best" —
unshowable without a readout — and shipping an unclaimed readout would be
behaviour the coverage gate cannot see. The claims move to the tests that
actually assert the behaviour; M5 restyles, it does not respecify.

## Risks

- **Threshold units.** `lapCrossingThreshold` (0.01) is per-tick displacement
  in wu — steady forward speed is ~0.19 wu/tick, twenty times it; a kart
  barely creeping still banks. The rejection tests pin both sides.
- **First lap always flashes.** An unset best (−1.0) must compare as "any lap
  beats it" without the sentinel leaking into the readout — the placeholder
  test covers the seam.
- **Hold vs GO! linger overlap.** Both draw through the overlay; they touch
  different labels and cannot collide, but the capture shows them together on
  a first lap, which is the intended proof frame.
