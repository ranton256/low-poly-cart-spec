## Context

See `proposal.md` — Why. The state this design starts from: a repository holding
a normative game design document, the seven supplied models at `assets/`, and no
code. `CONSTRAINTS.md` and `ROADMAP.md` live at the repository root; the Godot
project will live at `godot/`.

Two external things shape the approach. `godot-game-skeleton` already provides a
headless suite, a windowed capture tool, documentation checkers, and the
simulation/view split this port needs — but it assumes the Godot project root and
the repository root are the same directory, which here they are not. And the
supplied models sit outside the Godot project, which Godot's `res://` cannot
reach.

## Goals / Non-Goals

**Goals**

- A single command that verifies the project, trustworthy from a clean clone
- Determinism-critical configuration pinned before anything depends on it
- The shared `assets/` directory reachable from `godot/` on every shipping target
- Every documentation checker demonstrated to fail on what it guards, not assumed to

**Non-Goals**

- The four project-specific greps — `add-architecture-and-tuning-gates`
- Resolving the renderer question — `spike-compatibility-renderer-shadows`
- Anything that reads `data/tuning.json`; M1 owns the first consumer
- Any simulation, scene, or gameplay code

## Decisions

### D1 — Seed from `godot-game-skeleton`, adapt paths, prove the adaptation

Copy the skeleton into `godot/` and repoint its documentation checkers at the
repository root so they see `CONSTRAINTS.md` and `ROADMAP.md`.

The adaptation is the risk, not the copy. A checker pointed at a directory that
does not exist passes by examining nothing, and reports success. So each
repointed checker is verified by the mutation procedure in
`CONSTRAINTS §7 Testing`: deliberately break a link and a section reference,
confirm the right checker fails with the right message, restore. That procedure
is a task, not a note.

*Alternative rejected:* keep the checkers scoped to `godot/docs/`. Cheaper, and
it would leave the two documents that govern the project ungoverned.

### D2 — Reach the shared assets by a tracked copy, not a symlink

`godot/assets/` is a real directory. The `.glb` files are copied into it from
`../assets/` by an idempotent sync script and are **git-ignored**; the `.import`
files Godot generates beside them are **committed**.

This is the decision most worth scrutiny, so the alternatives in full:

| Option | Why not |
|---|---|
| **Symlink** `godot/assets → ../assets` | Git only materialises symlinks on Windows with `core.symlinks=true` *and* Developer Mode; otherwise the checkout produces a text file containing a path, and the project silently has no art. Windows is a shipping target per `CONSTRAINTS §14 Release and packaging`. |
| **Godot project root = repository root** | Works immediately, and dissolves the multi-port framing in `CONSTRAINTS §1 Repository shape`: `.godot/` and export presets land at the top level, and a second port could not sit beside the first. |
| **Copy, ignoring the whole directory** | Import presets would live inside an ignored directory, so they could not be committed — which defeats the requirement that a re-import cannot silently revert them. |
| **Chosen: copy, ignore `*.glb`, track `*.glb.import`** | Cross-platform with no symlink support required, import presets committed and gateable, and the models stay single-sourced in git. |

The cost is 39 MB duplicated in the working tree, which is not duplicated in
history. The sync script verifies content hashes rather than timestamps, so a
stale copy is detected rather than silently used, and it is idempotent so it can
run from both the setup path and the front of the standing suite.

### D3 — Tuning constants as JSON, transcribed but unread

`godot/data/tuning.json`, one key per constant, named exactly as the design
document names it.

JSON over a Godot resource because the transcription must be checkable by tools
that never load the engine — the coverage checker in M1 and the tuning-literal
gate in `add-architecture-and-tuning-gates` both read it as text. A `.tres`
resource would be idiomatic Godot and opaque to both.

Nothing reads the file in this change. Landing it now means M1 opens against a
transcription that has already been reviewed against the design document's
tables, rather than transcribing under pressure while also writing the tick.

### D4 — Pin the renderer now, provisionally, and record the owner

`CONSTRAINTS §2 Tech stack` selects Compatibility on every target, marked open
pending the spike. This change writes that into the project settings.

Pinning a provisional choice beats leaving the engine default, because a default
is invisible: nobody reviews it, and if the spike never runs the project ships on
whatever the editor picked. A pinned value with a named owner is a decision
someone will come back to. Nothing in this change or in M1 depends on the
outcome, so a reversal costs one settings edit.

### D5 — No continuous integration; a committed pre-commit hook instead

There is no hosted CI. The automated gates are a pre-commit hook running the
cheap checks on staged files, and `tools/test.sh` run by hand.

*Alternative rejected:* GitHub Actions running the suite on every push. It was
built and then removed. For a single-developer project it adds a second
environment to keep in step with `requirements.txt` and the pinned Godot
version, and it buys enforcement that a solo contributor already gets from the
hook plus the habit of running the suite.

**Name the cost plainly.** Nothing now *forces* the standing suite to run before
work is shared. The hook covers only staged files and only the cheap checks — it
will not catch a broken smoke suite, a stale link, or a drifted tuning table.
`tools/test.sh` remains the gate that decides whether work is done, and it is
carried by review rather than by a machine. `CONSTRAINTS §12 Review` already
makes a non-green suite rejection criterion R1; that is the enforcement.

The hook is committed at `tools/pre-commit` and installed by
`tools/install-hooks.sh`, rather than living only in `.git/hooks/`, so it is
reviewable like source and identical for everyone.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| A repointed checker passes by examining nothing | The mutation procedure is a required task per checker, not an optional sanity check |
| The asset copy drifts from `assets/` | The sync script compares content hashes, not timestamps, and runs at the front of the standing suite |
| 39 MB duplicated in every working tree | Accepted. It is not duplicated in history, and the alternatives each cost something structural |
| Committed `.import` files reference git-ignored sources, so a fresh clone has presets but no models until sync runs | Sync runs from setup and from the suite; a missing source is an explicit failure, not a silent empty import |
| The Compatibility pin is reversed by the spike | Nothing depends on it yet; the reversal is one settings edit and a constraints amendment |
| The skeleton carries assumptions beyond the paths we noticed | Its own smoke suite must pass unmodified before any adaptation, so a later failure is attributable to the adaptation rather than the inheritance |
| With no CI, nothing forces the standing suite to run before work is shared | Accepted deliberately (D5). The suite stays the definition of done, carried by review criterion R1 rather than by a machine |
| A contributor never runs `tools/install-hooks.sh`, so the hook silently does nothing | The hook is not the gate — `tools/test.sh` is. A missed hook costs a noisier diff, not a wrong build |

## Migration Plan

Nothing to migrate; the repository has no code today. Two ordering constraints:

1. The skeleton's own suite passes before any adaptation, so the adaptation's
   failures are separable from the inheritance's.
2. `.gitignore` lands before the Godot project, so `.godot/`, `.venv/`, and the
   copied `*.glb` are never staged. The repository has no `.gitignore` today,
   which makes this the one step that is genuinely hard to undo.

Rollback is `git revert`; no state outside the repository is touched.

## Open Questions

None outstanding.

*(The question of how the tuning transcription is verified was open when this
design was written and is now settled: by a committed checker,
`tools/check_tuning_transcription.py`, run in the standing suite. It verifies
names and values, and reports what it cannot attribute. `CONSTRAINTS §7 Testing` requires a
verification used to justify work to be committed as a tool, which review alone
would not have satisfied. (This was mis-cited as rejection criterion R6 in an
earlier draft; R6 is about recording ambiguities.))*
