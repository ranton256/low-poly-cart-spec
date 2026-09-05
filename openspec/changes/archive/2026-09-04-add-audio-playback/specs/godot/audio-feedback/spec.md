# godot/audio-feedback — delta for add-audio-playback

## ADDED Requirements

### Requirement: The audio view is a pure consumer of the cue stream

`scripts/view/audio_view.gd` SHALL drain the core's cue list **once per
simulation tick**, on the tick that produced it, and play it: spatial ids from
their world positions with attenuation reaching silence by `audioMaxDistance`,
race moments non-spatial, and the engine loop's pitch and volume set from the
Audio table's curves on the speed ratio, on that same clock — silent in
LOADING and through the countdown. Every parameter the view sets SHALL be a
function of core state and the data layer, asserted headlessly. The Mute
action (pinned to M) SHALL gate output only: the cue stream is unaffected, and
a fresh boot is unmuted.

**The tick, not the rendered frame, is the clock** — a correction made in the
doing, and not a detail. `sim.cues` holds ONE tick's records and is cleared at
the top of the next `Sim.step()`, so a per-frame drain plays a tick's cues
twice at 144 fps and drops every other tick's entirely at 30 fps, a countdown
beep included. The composition root therefore drives this view from
`_physics_process`, immediately after the step, rather than from the per-frame
callback every other view uses, and the view holds a tick guard so that a
second call inside one tick is a no-op.

#### Scenario: The view's parameters at a tick are computable without ears

- **WHEN** the audio view is bound to a simulation snapshot at any tick
- **THEN** the engine player's pitch and volume equal the table curves at
  the snapshot's ratio, and each drained cue maps to the right player,
  position, and volume — all asserted from state, no sound card involved

#### Scenario: Mute gates the speakers, not the simulation

- **WHEN** M is pressed mid-race and the drive continues
- **THEN** output is silenced while the cue stream and determinism summary
  keep recording exactly as before, and a second M restores output

### Requirement: The cue set is synthesized, committed, and reproducible

A committed generator tool SHALL render every cue and the engine loop to
WAVs in `assets/audio/` deterministically — two runs byte-identical — and
the shipped set SHALL be the tool's output, verified by a test the same way
the shipped circuit is.

#### Scenario: The cue set regenerates byte-identically

- **WHEN** the generator runs twice on a clean tree
- **THEN** every WAV matches the committed file, byte for byte
