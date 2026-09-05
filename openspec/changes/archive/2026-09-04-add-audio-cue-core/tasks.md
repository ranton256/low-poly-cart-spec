# Tasks: add-audio-cue-core

- [x] 1. `scripts/core/audio_cues.gd` + tuning fields; wired into the tick
       per stage; banned-symbols clean; stream in `stats_line()`.
- [x] 2. Emissions RED-first in `tests/audio_cue_test.gd` (adapt
       `templates/av_cues.template.gd` — it has waited since M0): volumes
       by name, exact ticks for countdown/GO, impact scaling + rate limit,
       gate/lap/best/medal, rebound id.
- [x] 3. The negative promises, each RED-verified by deliberately emitting
       where forbidden, then restored.
- [x] 4. Determinism: stream in the summary; LAP_SCRIPT double-replay
       byte-compare; standing replay/batching suites still green untouched.
- [x] 5. Coverage: 4 deferrals + the headless determinism half claimed;
       register updated for the split, honestly.
- [x] 6. Gate green; `openspec validate --strict`; archive checklist run.

## Deviations, stated

1. **The summary carries a DIGEST, not the whole stream.** Task 1 and the
   proposal say "the cue stream (ids, tick timestamps, volumes) joins
   `stats_line()`". What actually joins it is *this tick's* cues verbatim —
   fixed format, emission order — plus a running count, a running FNV-1a
   digest over every record emitted so far, and the rate-limit window's
   remaining ticks. A cumulative list would make `determinism_test.gd`
   quadratic (it builds `stats_line()` twice per tick for 3000 ticks, and a
   boundary rebound alone emits on hundreds of them) and would grow without
   bound in a running game. The property the change needs is unaffected and
   was mutation-verified: a cue-stream-only divergence fails
   `determinism_test`, `replay_test` and conformance item 14. The full stream
   is recovered the way a view recovers it — by reading the list every tick —
   and `audio_cue_test.gd` does exactly that for the byte-compare.

2. **Task 5's wording, corrected in the doing.** The task line says the
   headless determinism half is "claimed". It is not, and must not be: a
   `@covers` claim is on a whole scenario, and "The cue stream is
   deterministic" also says *across render rates*, which needs the probe
   extension `add-audio-playback` owns. The register entry is therefore
   UPDATED — kind still `deferred`, with its reason rewritten to record
   exactly which half is now tested and where — as the proposal's coverage
   plan and the implementation brief both describe. Coverage moved 73 → 77
   verified and 8 → 4 M10 deferrals, as planned.

3. **Only nine of the fifteen Audio rows reach `tuning.gd`.** The four engine
   curve endpoints, `audioMaxDistance` and `masterVolume` are the view's and
   are not read by anything in this change; adding them would put them in
   `missing_fields()` and fail a loader over values no simulation needs. This
   follows the precedent the circuit block in the same file records.

4. **The rebound cue is spatial.** Neither task 2 nor the delta spec says so
   explicitly; the GDD's "Space is audible" lists `rebound` among the spatial
   cues, so the record carries the kart's post-clamp position. No claim is
   made on that scenario — it stays deferred to playback with the attenuation.
