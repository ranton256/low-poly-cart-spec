# Proposal: add-audio-playback

## Why

With the cue stream landed and silent, this change makes it audible and
pays off every interim: the synthesized cue set, the audio view, the M mute
key, acceptance item 16's conformance case, and the probe extension. It
ends at the one gate no suite in this repo can run — the owner listening.

## What Changes

- **The synthesized cue set** (proposal decision 3, owner-approved): a
  committed generator tool renders each one-shot (impact, rebound,
  countdown_tick, countdown_go, lap_banked, new_best, gate_passed, medal)
  and the engine loop to small WAVs in `assets/audio/`, deterministically
  (fixed seeds; run-twice byte-compare). Committed like every asset;
  regenerable; payload re-measured against the web budget.
- **`scripts/view/audio_view.gd`**: drains the core cue list each frame;
  spatial cues (impact, gate_passed, rebound) through positioned 3D
  players with `audioMaxDistance` attenuation; race moments non-spatial;
  the engine loop's pitch/volume driven by the ratio curves on the sim
  clock, silent in LOADING and through the countdown. A pure consumer:
  every parameter it sets is a function of core state and the data layer,
  asserted headlessly the way the speedo needle is.
- **Mute**: the `mute` action pinned to M (check_settings REQUIRED_ACTIONS
  grows to 9), toggling output only — the cue stream keeps flowing;
  session-only. Hint line updated to the amended GDD text (which re-blesses
  the gallery: the hint shows in every capture).
- **G2 re-completed**: `_item_16` — cue-stream identity across the three
  rates (the probe grows a per-pass cue-stream hash; the recorded run
  regenerated), the engine-pitch-tracks-ratio assertion, full-scale
  impact, and the rebound-is-not-impact promise, at the checklist's own
  wording. §5's G2 row back to ✅ at sixteen items.
- **Coverage**: the remaining M10 deferrals claimed (engine-note, space,
  mute, the cross-rate determinism half); the register's M10 count to zero.

## What is deliberately excluded

- Music, volume UI beyond mute, any new cue beyond the specified set.
- The judgement of whether it SOUNDS GOOD — the owner's listen test closes
  the milestone, after the Critic.
