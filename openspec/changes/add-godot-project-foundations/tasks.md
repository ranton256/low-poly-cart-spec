## 1. Repository hygiene

- [x] 1.1 Add `.gitignore` at the repository root covering `.godot/`, `.venv/`, `godot/assets/*.glb`, export output, and `gallery/` — before any Godot file is created, so generated artifacts are never staged (design D2, Migration Plan)
- [x] 1.2 Confirm `godot/assets/*.glb.import` is NOT ignored, by staging a dummy `.import` file and checking `git status` sees it, then unstaging

## 2. Skeleton, inherited unmodified

- [x] 2.1 Copy `godot-game-skeleton` into `godot/`, dropping its own `.git`, its `ROADMAP.md`, and `docs/CONSTRAINTS.md` (this repository has its own at the root)
- [x] 2.2 Create `godot/.venv` and install `godot/requirements.txt` with pinned versions
- [x] 2.3 Run `godot/tools/test.sh` unmodified and confirm it passes before any adaptation, so later failures are attributable to our changes rather than the inheritance (design D1)
- [x] 2.4 Initialise `att` and record the M0 backlog items that fall outside this change

## 3. Project configuration

- [x] 3.1 Set `config/name`, `config/description`, and `config/version` in `godot/project.godot`
- [x] 3.2 Record the full engine version in `godot/.godot-version` as the single source of truth, and pin `config/features` to its series — Godot stores only major.minor there (spec: *Pinned engine version*)
- [x] 3.8 Add `tools/check_engine_version.py` asserting every governing document agrees with `.godot-version`, and verify it by deliberately disagreeing (spec: *A document disagreeing about the version is caught*)
- [x] 3.3 Set `physics/common/physics_ticks_per_second = 60` (spec: *Fixed simulation rate*)
- [x] 3.4 Set `physics/common/physics_jitter_fix = 0` and leave a comment naming why the 0.5 default is wrong here (spec: *Fixed simulation rate*)
- [x] 3.5 Pin the renderer to Compatibility on every target, with a comment naming `spike-compatibility-renderer-shadows` as the owner that may reverse it (spec: *One renderer on every target*; design D4)
- [x] 3.6 Configure a 3D main scene and window size appropriate to a 3D game, replacing the skeleton's 2D-oriented display defaults
- [x] 3.7 Verify the project opens in the editor and runs headless with no errors or warnings

## 4. Shared asset reachability

- [x] 4.1 Write `godot/tools/sync_assets.sh` copying `assets/*.glb` into `godot/assets/`, comparing content hashes rather than timestamps, idempotent, failing explicitly when a source is missing (design D2)
- [x] 4.2 Call it from the front of `godot/tools/test.sh`
- [x] 4.3 Run it and confirm all seven models import in Godot with no errors (spec: *Shared assets are reachable from the project*)
- [x] 4.4 Commit the generated `.glb.import` files and confirm the `.glb` files themselves are absent from `git status`
- [x] 4.5 Verify recovery from a fresh clone: clone to a temporary directory, run sync, confirm the models import from committed presets
- [x] 4.6 Amend `CONSTRAINTS.md` §9 Assets — replace the open ❓ on asset reachability with the chosen mechanism and its Windows caveat (spec: *The mechanism is written down, not inferred*)

## 5. Tuning constants

- [x] 5.1 Transcribe every constant from the design document's Physics, World, Camera and HUD, and Timing tables into `godot/data/tuning.json`, under the design document's own names (design D3)
- [x] 5.2 Review the transcription against all four tables — every named constant present exactly once, no renamed keys, no derived values transcribed as if they were tunable (spec: *Tuning constants have exactly one home*)
- [x] 5.3 Confirm nothing in the *game* reads the file yet — only the transcription checker does (spec: *Transcription alone changes no behavior*)
- [x] 5.4 Commit the transcription verification as `tools/check_tuning_transcription.py` and wire it into the suite, per CONSTRAINTS §7 Testing: a verification used to justify work must be committed as a tool (spec: *Single-source facts are asserted, not maintained by hand*)
- [x] 5.5 Verify the checker catches a wrong **value**, not only a renamed key, and reports constants it cannot attribute (spec: *The check covers values, not only names*)

## 6. Documentation gates

- [x] 6.1 Repoint `check_links.py` and `check_section_refs.py` at the repository root so `CONSTRAINTS.md` and `ROADMAP.md` are in scope (spec: *The checks cover the documents that live above the project*)
- [x] 6.2 Confirm each checker reports a non-zero count of files examined, so neither can pass by finding nothing
- [x] 6.3 **Mutation check** — break a relative link in `CONSTRAINTS.md`, confirm the suite fails naming the file and link, restore (design D1; spec: *A broken document link is caught*)
- [x] 6.4 **Mutation check** — change a `CONSTRAINTS §N Title` reference to a wrong title, confirm the suite fails naming the mismatch, restore (spec: *A stale section reference is caught*)
- [x] 6.5 Fill in the skeleton's remaining document placeholders under `godot/docs/`, or delete the documents this project does not use, then enable `check_placeholders.py --strict` in `test.sh`

## 7. Environment and suite guarantees

- [x] 7.1 Confirm `test.sh` exits non-zero with actionable instructions when `.venv` is absent (spec: *No virtual environment present*)
- [x] 7.2 Confirm it exits non-zero naming the missing package when `.venv` exists but is incomplete (spec: *Virtual environment present but incomplete*)
- [x] 7.3 Confirm every Python invocation in `test.sh` uses `.venv/bin/python` and never a system interpreter (spec: *System tooling is never silently substituted*)
- [x] 7.4 Set the save-path override environment variable in `test.sh` and every harness, and confirm no check writes to a real save location (spec: *A real save file is never used*)
- [x] 7.5 Confirm the suite runs to completion with no display available and captures no images (spec: *The standing suite is headless and display-free*)
- [x] 7.6 Measure the suite's wall time on the reference machine and record it; confirm it is within the 60 s budget (spec: *The suite is fast enough to be run every time*)

## 8. Lint and formatting

- [x] 8.1 Add `gdtoolkit` to `godot/requirements.txt` with a pinned version
- [x] 8.2 Configure `gdlint` and `gdformat --check`, and get them passing on the skeleton's inherited scripts
- [x] 8.4 Add `tools/check_static_typing.py` to enforce CONSTRAINTS §3 Language and style's static-typing rule — gdlint ships no typing rules, so naming it as the gate left the constraint unenforced
- [x] 8.3 Add a pre-commit hook running lint, format, whitespace, and EOF-newline checks — fast enough that nobody reaches for `--no-verify`

## 9. Commit-time gate

- [x] 9.1 Install a committed pre-commit hook via `godot/tools/install-hooks.sh`, so it is reviewable like source rather than living only in `.git/hooks/` (spec: *The hook is reviewable like source*; design D5)
- [x] 9.2 Confirm the hook refuses a commit for each violation it guards — trailing whitespace, missing EOF newline, unformatted GDScript, a lint error, a physics-body symbol, an oversized file — naming the file and the violation. **Cover all three staging shapes**: a plain add, a staged violation whose worktree copy is clean, and a rename-plus-edit (spec: *A commit with staged violations is refused*)
- [x] 9.3 Confirm a deliberately failing check makes `test.sh` exit non-zero, suppresses the success line, and surfaces the failing check's own message (spec: *A failing check is visible as a failure*)
- [x] 9.4 Confirm the hook passes on a clean tree and is fast enough that bypassing it offers no saving (spec: *A clean commit is not delayed*)

## 10. Close-out

- [x] 10.1 Capture visual proof — an empty scene rendering at the pinned renderer — via `godot/tools/capture.sh` into `godot/docs/progress/`
- [x] 10.2 Update `CONSTRAINTS.md` §10 Verification criteria: move V1, V10, V11, V12 to ✅ and confirm V8's split status (settings pinned here, gate lands in `add-architecture-and-tuning-gates`)
- [x] 10.3 File `att` tasks for everything deferred out of this change, so nothing leaves scope untracked
- [x] 10.4 Run `openspec validate add-godot-project-foundations --strict`
- [x] 10.6 Second Critic pass: fix the pre-commit hook to check staged blobs rather than the working tree, and make it portable to bash 3.2 — an earlier version could be bypassed by staging a violation then cleaning the worktree
- [x] 10.7 Second Critic pass: make the tuning checker detect a constant transcribed into two groups, which a set-based lookup made invisible
- [x] 10.8 Second Critic pass: correct the false suite wall-time measurement, the mis-cited rejection criterion, the overstated ✅ markers, the narrowed static-typing constraint, and the missing V18–V20
- [x] 10.9 Second Critic pass: extend `check_section_refs.py` beyond Markdown to code, project files and the backlog, then fix the 18 stale references it found
- [x] 10.10 Second Critic pass: create `godot/docs/AMBIGUITIES.md`, which six documents referenced and which did not exist
- [x] 10.11 Third Critic pass: close the rename bypass — `--diff-filter=ACM` excluded `R`, so a staged rename-plus-edit was checked by nothing. Now `ACMRT`, with rename and typechange regression cases
- [x] 10.12 Third Critic pass: make a failed staged-blob extraction fail loudly instead of leaving an empty file that every later check passes
- [x] 10.5 Critic review against CONSTRAINTS §12 Review rejection criteria R1–R8, with an explicit [APPROVED] or [REJECTED] verdict — **three independent adversarial passes**, each by a reviewer with no context on the implementation. Rounds 1 and 2 returned [REJECTED] (12 findings each, remediated in groups 10.6–10.10); round 3 returned [REJECTED] on one defect, the rename bypass, remediated in 10.11–10.12. **[APPROVED]** by the repository owner
