# Tasks: amend-gdd-for-checkpoint-circuit

- [ ] 1. The amendment reviewed and approved by the project owner — a
       normative-document change does not land on one agent's judgement.
- [ ] 2. `gdd-amendment.md` applied verbatim to
       `low-poly-cart-game-design-document.md` (edits 1–7).
- [ ] 3. G1's scenario universe re-counted (the checker reads the GDD; the
       new feature's scenarios enter it) and `scenario_register.json`
       annotated for any scenario that is visual or deferred to the
       implementation changes — honestly marked pending, not claimed.
- [ ] 4. CONSTRAINTS §5 Conformance to the specification told the truth
       about the interim: G1 will read "pending" for the circuit scenarios
       until the implementation changes land; the §5 note names the
       follow-up changes that owe them.
- [ ] 5. ROADMAP gains the M9 section (this change, then
       `add-checkpoint-circuit-core` and `add-circuit-presentation` or
       equivalent split decided at implementation-proposal time).
- [ ] 6. `openspec validate --strict`; archive checklist run.
