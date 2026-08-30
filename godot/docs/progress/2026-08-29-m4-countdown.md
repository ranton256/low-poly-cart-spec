# M4 — the countdown, first half of the milestone's visual proof

`2026-08-29-m4-countdown-go.png` — the GO! frame, captured by
`tools/drive_capture.gd --ticks 250` (inside the 30-tick `goLinger` window):
the overlay in the design document's green `#00FF00` with the 4 px drop
shadow, the kart at the start band with zero velocity and nothing held, the
chase camera engaged by the RACING transition.

Deterministic: seed 20260829, fixed tick counts, no wall-clock anywhere in
the countdown — re-run the command and the frame comes back byte-comparable.

`2026-08-29-m4-lap-banked.png` — the other half, captured by
`tools/lap_capture.gd`, which replays the lap suite's own scripted drive
(north through the band too soon — rejected; two u-turns; back through
northbound at 15.05 s): `TIME` holding the banked 15.05 through the
`lapRestartDelay` window, `BEST 15.05` flashing the data layer's green, the
kart just north of the band. Reported by the tool: hold 19 ticks and flash 49
ticks remaining at the grab. Deterministic — same seed, same phase table,
same frame.
