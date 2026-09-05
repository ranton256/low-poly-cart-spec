# Proposal: amend-gdd-for-audio-cues

## Why

The game is silent, and silence is the missing continuous feedback channel:
a collision destroys all momentum and reports it with a 0.15 wu camera
shake; speed is legible only from a dial the player is not looking at; M9
left the gate-pass and medal cues as explicitly reserved slots. Optional
Feature 1 names the fix, and the architecture has been decided since M0
without ever being used: `data/banned_symbols.json` bans `AudioStreamPlayer`
from the core with the recorded reason "the sim publishes effects as data;
the view plays them," and `templates/av_cues.template.gd` is a complete,
unused suite for exactly that shape. This change promotes OF-1 into the
GDD's Feature/Scenario form; implementation follows in separate changes.

**This feature has no reference build** (the JS reference is silent too).
Like the circuit, it is specified fresh, every decision on the record here.

## What changes in the GDD (full text in `gdd-amendment.md`)

- A new **Feature: Audio Feedback** after Checkpoint Circuit: the cue
  contract (core publishes cues as data, views play them), the engine note
  as a continuous function of the speed ratio, impact one-shots scaled by
  the velocity destroyed, the countdown/lap/best/gate/medal/rebound cue
  vocabulary, spatialisation against the 100 wu field, the mute toggle,
  and — the part the template argues is the point — the **negative
  promises**: what must NOT sound.
- **Tuning Constants** gains an Audio table (pitch curve, volumes, the
  impact full-scale velocity, spatial distances, master volume).
- **Input Handling / control hints**: `M` mutes; the hint line gains
  `· M mute`.
- **Acceptance item 16**: the cue stream — ids, order, tick timestamps,
  volumes — is identical at 30, 60, and 144 fps, extending item 14 into a
  channel it has never covered.
- **Optional Features item 1** marked promoted.

## Decisions made here, on the record

1. **Cues are core data.** `sim` accumulates an ordered per-tick cue list
   (id, volume, optional world position); views drain it each frame and
   play; the core never touches an audio API (the standing ban becomes the
   feature's floor, not just a hygiene rule). Every cue is thereby
   assertable headlessly, and the determinism story extends to audio for
   free.
2. **The engine note is a curve, not a sample choice**: pitch scales
   linearly with the speed ratio between named endpoints, volume likewise —
   the GDD specifies the function; what waveform carries it is the port's.
3. **Sound sourcing is a port decision, not GDD text** (recommended:
   SYNTHESIZED — a committed generator tool renders the cue set to small
   WAVs deterministically; zero licensing, ~zero payload against the 6 MB
   gzip headroom, reproducible like every other asset in this repo, and the
   chiptune-adjacent character suits the low-poly look). Recorded in the
   implementation change, mirrored in the register if it proves
   contentious.
4. **Mute is a key, not a settings screen.** `M` toggles all audio, pinned
   like every other binding. CONSTRAINTS §15 Not applicable excludes "a
   menu, a pause state, a settings screen" — a single key is none of those,
   and the exclusion list is amended to say audio shipped rather than
   quietly contradicting the build.
5. **The negative promises are normative**: a boundary rebound must never
   play the impact cue; an ignored out-of-order gate pass is silent; no cue
   fires in LOADING; losing focus mid-throttle does not spam; Reset Kart is
   silent (it is specified as "the start pose and NOTHING else", and a
   sound is not nothing).

## What is deliberately excluded

- Implementation (the sim cue list, the audio view, the generator tool, the
  suites, acceptance 16's conformance case) — the follow-up changes.
- Music. The engine note is the soundtrack; a composed loop is OF-territory
  for another day and is not requested.
- Any volume UI beyond mute. The tuning file remains the knob.
