# Tasks: amend-gdd-for-checkpoint-circuit

- [x] 1. The amendment reviewed and approved by the project owner — a
       normative-document change does not land on one agent's judgement.
- [x] 2. `gdd-amendment.md` applied verbatim to
       `low-poly-cart-game-design-document.md` (edits 1–10, plus the two
       consequential sites found at application and recorded as edits
       11–12: the collision prop-on-kart scenario and the Game Overview).
       The GDD↔tuning lockstep checker then required two data edits, both
       recorded: the Circuit table mirrored into `tuning.json` (read by
       nothing until M9), and `minLapTime` moved to `port_decisions` as the
       operative interim farming defence — deleting it would have silently
       zeroed the lap gate's only guard before the gates exist to replace
       it. The loader reads it from there; the M9 change deletes both the
       key and the read.
- [x] 3. G1's scenario universe re-counted (the checker reads the GDD; the
       new feature's scenarios enter it) and `scenario_register.json`
       annotated for any scenario that is visual or deferred to the
       implementation changes — honestly marked pending, not claimed.
- [x] 4. CONSTRAINTS §5 Conformance to the specification told the truth
       about the interim: G1 will read "pending" for the circuit scenarios
       until the implementation changes land; the §5 note names the
       follow-up changes that owe them.
- [x] 5. ROADMAP gains the M9 section (this change, then
       `add-checkpoint-circuit-core` and `add-circuit-presentation` or
       equivalent split decided at implementation-proposal time).
- [x] 6. `openspec validate --strict`; archive checklist run.
