# Chase camera — the thresholds, fixed before anything was measured

This file was written and committed **before** the camera was measured, and is not
edited afterwards except to append the measured values. That ordering is the whole
defence: the design document says the camera "settles behind the kart within
roughly half a second", and "roughly" invites a tolerance chosen after seeing the
answer. The same discipline carried the A9 exposure work through three adversarial
reviews.

Every number below is **derived from the design document's own `chaseSmoothing`**,
not chosen to fit an observation.

## What "settled" means

The camera is settled when the angle between

- the direction from the kart to the camera, and
- the direction directly behind the kart (its reversed heading)

has fallen to **10% or less of the peak angle reached during the turn**.

Ten percent is a round fraction of the disturbance, not a number of degrees. A
fixed angle would be wrong here: how far the camera swings wide depends on how hard
the kart turned, so a threshold in degrees would be strict for a gentle turn and
lax for a hard one. A fraction of the peak is the same test in both cases.

## What that predicts

The easing is `position += (target − position) × chaseSmoothing` per tick, so the
residual after *n* ticks is `(1 − chaseSmoothing)^n`.

With `chaseSmoothing = 0.08` at 60 ticks per second:

| quantity | derivation | value |
|---|---|---|
| Per-tick retention | `1 − 0.08` | 0.92 |
| Time constant τ | `−1 / (60 × ln 0.92)` | **0.1999 s** |
| Ticks to reach 10% | `ln 0.10 / ln 0.92` | 27.6 |
| Settling time | `27.6 / 60` | **0.460 s** |

The document states the time constant as "≈ 0.2 s" and the settling as "roughly
half a second". The derivation gives 0.1999 s and 0.460 s. **Both fall out of
`chaseSmoothing`; neither was measured to produce them.**

## The assertions, stated now

1. **Time constant** within **5%** of the document's stated 0.2 s. The derived
   value is 0.1999 s, so this passes with room — the tolerance exists to catch a
   changed easing factor, not to accommodate one.
2. **Settling time ≤ 0.500 s**, the document's own number read as an upper bound
   ("within roughly half a second"). The derivation predicts 0.460 s. The measured
   value is printed on every run whether it passes or fails.
3. **The lag is real**: while the kart is turning, the offset angle must exceed
   **5°**. A camera that tracks perfectly would satisfy assertions 1 and 2
   trivially — it is always settled — so this is what stops "settles behind the
   kart" from being met by never leaving.
4. **Field of view** at the document's own anchors: `fovBase` at rest, and within
   **0.2°** of 89.4° at the achievable steady-state speed ratio. Not a restatement
   of the interpolation formula, which would only prove the test can multiply.

## Measured

*Appended after the thresholds above were committed.*

| quantity | predicted | measured |
|---|---|---|
| Time constant | 0.1999 s | **0.200 s** (12 ticks) |
| Settling time | 0.460 s | **0.450 s** (27 ticks), limit 0.500 |
| Peak offset during the turn | — | **24.67°**, against a 5° floor |
| Field of view at steady state | 89.4° | **89.40°** |

The settling prediction was made from `chaseSmoothing` alone and landed within
0.01 s of the measurement. That is the point of writing it down first: the number
is a consequence of the design document's easing factor, not a description of what
this implementation happened to do.

**Both thresholds were verified by breaking what they guard.** With
`chaseSmoothing` at 1.0 — a camera that tracks perfectly and is therefore always
settled — the time-constant check fails at 0.0167 s and the lag check fails at a
0.00° peak. That is a **production** mutation: an edit to `data/tuning.json` that
the shipped game would carry.

The tick-grouping check in `camera_test.gd` is **not** evidence of the same kind,
and an earlier version of this file listed it as though it were. That check drives
the camera itself, stepping it inside its own tick loop, so no edit to
`chase_camera.gd` or `main.gd` can make it fail — it holds by construction, and to
break it you have to edit the test. What it guards is a later change moving the
ease into a per-frame call; it does not demonstrate that the running game eases per
tick today.

`tests/driver_test.gd` carries that half, and it is a production mutation: stepping
the camera in `_process` as well gives "17 vs 5", and not stepping it at all gives
"0 vs 4". Both fail by name.
