# Tasks: add-audio-cue-core

- [ ] 1. `scripts/core/audio_cues.gd` + tuning fields; wired into the tick
       per stage; banned-symbols clean; stream in `stats_line()`.
- [ ] 2. Emissions RED-first in `tests/audio_cue_test.gd` (adapt
       `templates/av_cues.template.gd` — it has waited since M0): volumes
       by name, exact ticks for countdown/GO, impact scaling + rate limit,
       gate/lap/best/medal, rebound id.
- [ ] 3. The negative promises, each RED-verified by deliberately emitting
       where forbidden, then restored.
- [ ] 4. Determinism: stream in the summary; LAP_SCRIPT double-replay
       byte-compare; standing replay/batching suites still green untouched.
- [ ] 5. Coverage: 4 deferrals + the headless determinism half claimed;
       register updated for the split, honestly.
- [ ] 6. Gate green; `openspec validate --strict`; archive checklist run.
