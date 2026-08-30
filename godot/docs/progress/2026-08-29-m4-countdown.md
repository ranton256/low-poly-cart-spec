# M4 — the countdown, first half of the milestone's visual proof

`2026-08-29-m4-countdown-go.png` — the GO! frame, captured by
`tools/drive_capture.gd --ticks 250` (inside the 30-tick `goLinger` window):
the overlay in the design document's green `#00FF00` with the 4 px drop
shadow, the kart at the start band with zero velocity and nothing held, the
chase camera engaged by the RACING transition.

Deterministic: seed 20260829, fixed tick counts, no wall-clock anywhere in
the countdown — re-run the command and the frame comes back byte-comparable.

The other half of M4's mandated proof (TIME frozen on a banked lap with a
green best) arrives with `add-lap-gate-and-timing`.
