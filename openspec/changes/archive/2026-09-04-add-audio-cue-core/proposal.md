# Proposal: add-audio-cue-core

## Why

The GDD now specifies Audio Feedback (amendment 8265a0a); the port owes the
behaviour. This change builds the half with **no sound in it**: the core cue
list, every emission at its exact stage, the rate limit, the negative
promises as tests, and determinism-summary membership. The game stays
silent after this change — a cue is a record, and every record is
assertable headlessly — which is precisely the architecture's claim. The
audio view, the synthesized cue set, mute, and item 16 are
`add-audio-playback`.

## What Changes

- **`scripts/core/audio_cues.gd`** (pure): the per-tick ordered cue list —
  records of id, volume, and optional world position — cleared at tick
  start, appended by the stages, drained by callers. Volumes from the
  tuning Audio table by name; `tuning.gd` grows the typed fields.
- **Emissions, each at its specified stage**: countdown_tick on the 3/2/1
  boundaries and countdown_go on the GO tick (race state); impact at stage
  7 with volume `min(1, |v destroyed| / impactFullScale)` at the struck
  prop's position, under the `impactRateLimit` window so a pin is one
  event; rebound at stage 6 (its own id, never impact's); gate_passed at
  stage 8 only when the cursor advances; lap_banked, new_best, and medal at
  the bank. The engine note is NOT a cue — it is the view reading the
  ratio, and stays out of this change entirely.
- **The negative promises as named tests**: rebound tick emits no impact;
  ignored/backwards/repeat gate passes emit nothing; LOADING emits nothing
  (including a failed boot); focus loss emits nothing; Reset Kart emits
  nothing. Each RED-verifiable by deliberately emitting where the promise
  forbids.
- **Determinism**: the cue stream (ids, tick timestamps, volumes) joins
  `stats_line()`; the standing replay/batching suites therefore cover it
  for free, and a dedicated case replays the baked LAP_SCRIPT twice and
  byte-compares the full stream.
- **Coverage**: claims 4 of the 8 M10 deferrals (publishes-as-data,
  impact, race-moments, must-NOT) and the headless half of
  cue-stream-determinism — register updated honestly for the split
  (engine-note, space, mute, and the cross-rate half stay deferred to
  playback).

## What is deliberately excluded

- Anything audible: AudioStreamPlayer nodes, WAVs, the generator tool,
  mute, the hint line, item 16's conformance case, the probe extension —
  all `add-audio-playback`.
