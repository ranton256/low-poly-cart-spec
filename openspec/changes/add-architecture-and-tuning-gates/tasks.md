## 1. Shared definition of what is banned

- [x] 1.1 Create `godot/data/banned_symbols.json` with two named lists, `core_purity` and `physics_engine`, each entry carrying the symbol and a one-line reason (design D1)
- [x] 1.2 Transcribe the symbols from CONSTRAINTS §4 Architectural boundaries into it, and mark which are function-shaped (matched with a following `(`) versus type-shaped (design D2)
- [x] 1.3 Confirm `Vector3`, `AABB`, `Transform3D` and `Basis` are absent from both lists — they are value types with no engine dependency (spec: *Math types remain available*)

## 2. Boundary gates

- [x] 2.1 Write `godot/tools/check_boundaries.py` reading `banned_symbols.json`, matching whole words with a required `(` for function-shaped symbols, and stripping comments before matching (design D2)
- [x] 2.2 Apply `core_purity` to `godot/scripts/core/` and `physics_engine` to the whole of `godot/`, reporting file, line and symbol (spec: *The simulation core stays free of the engine*, *The Godot physics engine plays no part, anywhere*)
- [x] 2.3 Confirm it does NOT flag `rng.gd`'s `randf01()` (the one function whose name contains a banned substring), nor the `randi()` mentions in `sim.gd` and `rng.gd` comments — the trap recorded in CONSTRAINTS §4 Architectural boundaries (spec: *Mentioning a banned symbol in prose is not a violation*)
- [x] 2.4 Confirm a banned symbol inside a **string literal** IS flagged — dynamic `get_node("...")` access is what the rule exists to prevent (design D2)
- [x] 2.5 Report a non-zero count of files and symbols inspected, and fail when it is zero (spec: *Every gate reports what it inspected*)
- [x] 2.6 **Mutation check** — add `get_tree()` to a core file; confirm failure naming file, line and symbol; restore
- [x] 2.7 **Mutation check** — add `CharacterBody3D` to a file outside `scripts/core/`; confirm the full-tree rule catches it where the staged-only hook would not; restore
- [x] 2.8 **Mutation check** — point the gate at an empty directory; confirm it fails saying it found nothing, rather than passing (spec: *A gate that would inspect nothing fails loudly*)

## 3. Tuning literal gate

- [x] 3.1 Write `godot/tools/check_tuning_literals.py` reading values from `godot/data/tuning.json` and searching `.gd` under `godot/scripts/` for them, comparing numerically rather than by string form so `0.960` and `.96` cannot evade it (design D3)
- [x] 3.2 Narrow on both axes after the first run produced 20 false positives: scope the search to `godot/scripts/`, and exclude integers with magnitude below 10. Print every excluded constant by name and value each run (design D3; spec: *Values indistinguishable from ordinary code are not searched*, *The search is scoped to where a literal would fork the contract*)
- [x] 3.3 Support `godot/data/tuning_literal_allowlist.json`, each entry carrying file, value and a written reason; an entry without a reason fails (spec: *An unavoidable coincidence can be recorded rather than removed*)
- [x] 3.4 Fail on a stale allowlist entry that no longer matches anything (spec: *An exemption that is no longer needed is reported*)
- [x] 3.5 Print counts every run: values searched, values unsearchable, hits, exemptions
- [x] 3.6 **Mutation check** — write `0.96` as a literal into a `.gd` file; confirm failure naming file, line, value and the constant `friction`; restore
- [x] 3.7 **Mutation check** — add an allowlist entry with no reason; confirm failure. Add a stale entry; confirm failure. Restore
- [x] 3.8 Confirm the gate passes on the current tree with **two** justified exemptions, both in the inherited placeholder `sim.gd` and both going stale when M1 replaces it: `emit_sfx("bump", 0.3)` colliding with `pushDistance`, and `DT_MS := 1000.0 / 60.0` colliding with `farClip`/`minimapFar`

## 4. Project settings gate

- [x] 4.1 Write `godot/tools/check_settings.py` parsing `godot/project.godot` and asserting `physics_ticks_per_second`, `physics_jitter_fix`, and both renderer keys against their pinned values (design D4)
- [x] 4.2 Assert each of the seven models has a committed `.glb.import` preset that does not record `valid=false` (spec: *A model import preset is missing or records a failure*)
- [x] 4.3 Report the count of settings and presets checked; fail on zero (spec: *Every gate reports what it inspected*)
- [x] 4.4 **Mutation check** — set `physics_jitter_fix` to 0.5; confirm failure naming the setting, the value found and the value required; restore
- [x] 4.5 **Mutation check** — delete a `.glb.import` preset; confirm failure naming the model; restore

## 5. Wiring

- [x] 5.1 Add all three gates to `godot/tools/test.sh`
- [x] 5.2 Replace the commit hook's hardcoded physics list with a read of `banned_symbols.json`, so the hook and the suite cannot disagree (spec: *One definition of what is banned*)
- [x] 5.3 Confirm the hook still refuses a staged physics symbol in both `.gd` and `.tscn`, still catches the rename-plus-edit and cleaned-worktree cases, and still passes a clean commit
- [x] 5.4 **Mutation check** — remove a symbol from `banned_symbols.json`; confirm both the suite gate and the hook stop flagging it, proving they share one definition; restore
- [x] 5.5 Re-measure suite wall time and hook time; update the recorded figures in CONSTRAINTS §8 Performance and size budgets and §13 Automation and gates if they moved (the previous change shipped a stale measurement)

## 6. Close-out

- [x] 6.1 Update CONSTRAINTS §10 Verification criteria: V3, V4, V5, V8 to ✅, and add a criterion for the hook and suite sharing one banned-symbol definition
- [x] 6.2 Update the §2, §3 and §4 markers that referenced these gates as planned, and add the three tools to the §13 inventory
- [x] 6.3 Confirm no marker claims more than its gate delivers — re-read each ✅ against what was actually verified in groups 2–5
- [x] 6.4 Close `att` 1 and 7
- [x] 6.5 Run `openspec validate add-architecture-and-tuning-gates --strict`
- [x] 6.6 `godot/tools/test.sh` green
- [x] 6.7 Critic review against CONSTRAINTS §12 Review criteria R1–R8, by a reviewer who did not write the change — **two independent passes, both [REJECTED]**: round 1 found the four-roots physics gap and the hook's unanchored matching; round 2 found the space-in-filename bypass and the suffix over-claim. Both remediated and re-verified. **[APPROVED]** by the repository owner
