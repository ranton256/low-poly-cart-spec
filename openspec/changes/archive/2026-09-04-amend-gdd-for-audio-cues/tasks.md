# Tasks: amend-gdd-for-audio-cues

- [x] 1. The amendment reviewed and approved by the project owner — a
       normative-document change does not land on one agent's judgement.
       The two decisions most worth their eyes: synthesized sound sourcing
       (proposal decision 3) and the M mute key (decision 4).
- [x] 2. `gdd-amendment.md` applied verbatim (edits 1–6) as its own
       GDD-only commit, backportable to main like its siblings.
- [x] 3. G1's universe re-counted; the new feature's scenarios registered
       as deferred to the M10 implementation changes with reasons.
- [x] 4. Port-side truth: the Audio table mirrored into
       `godot/data/tuning.json` (read by nothing until implementation);
       `check_settings.py` REQUIRED_ACTIONS gains `mute` {KEY_M} when the
       binding lands (implementation, not here — recorded deviation: the
       pin follows the action); CONSTRAINTS §15 Not
       applicable amended — the Audio line becomes a pointer to the
       feature, and the stale "checkpoints" word in the Optional Features
       2–10 line (missed at M9) is corrected in the same edit; §5 G2 row
       marked ⚠️ interim for the amended checklist (item 16 owed).
- [x] 5. ROADMAP gains the M10 section (this change, then the
       implementation split proposed after it archives).
- [x] 6. `openspec validate --strict`; archive checklist run.
