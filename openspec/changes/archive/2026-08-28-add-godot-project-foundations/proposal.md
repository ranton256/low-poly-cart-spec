## Why

The roadmap's M0 exists so the project can verify itself before there is
anything to verify. Every later milestone leans on a standing suite that runs
headless in seconds and on a Godot configuration whose determinism-critical
settings cannot drift — M1 proves the tick order to ±0.05 s, and M6 captures
visual baselines that are worthless if the renderer or the physics rate changed
underneath them.

Doing this first is not diligence for its own sake. `physics_jitter_fix`
defaults to 0.5 and silently drifts the race clock against wall time; a Godot
re-import silently reverts texture import settings. Both are cheap to pin now
and expensive to discover in M8 when acceptance item 14 fails for a reason
nobody can localise.

## What Changes

- Create the Godot project at `godot/`, seeded from the `godot-game-skeleton`
  starter, developed against Godot **4.6.1** — recorded in `godot/.godot-version`,
  with `config/features` carrying the `4.6` series.
- Pin the determinism-critical project settings named in
  `CONSTRAINTS §6 Determinism and the reference frame`:
  `physics_ticks_per_second = 60` and `physics_jitter_fix = 0`.
- Pin the renderer to **Compatibility** on every target, per
  `CONSTRAINTS §2 Tech stack`. Recorded as provisional: the
  `spike-compatibility-renderer-shadows` change may reverse it, and this change
  deliberately does not depend on the outcome.
- Establish `godot/data/tuning.json` as the single transcription of the GDD's
  Tuning Constants tables — every constant named exactly as the GDD names it.
  Nothing in the *game* reads it until M1; a checker verifies the transcription.
- Record the engine version in one authoritative file, and gate every restatement
  of it against that file — `config/features` cannot be the source of truth
  because Godot stores only the major.minor series there.
- Stand up `godot/tools/test.sh` as the standing suite: headless, display-free,
  refusing to run against system Python or an incomplete `.venv`.
- Repoint the inherited documentation checkers (`check_links.py`,
  `check_section_refs.py`) at the repository root, since `CONSTRAINTS.md` and
  `ROADMAP.md` live one level above the Godot project. Left unadjusted they pass
  by finding nothing, which is the worst failure mode a gate has.
- Install a committed pre-commit hook running the cheap checks on staged files.
  **No continuous integration** — see the design's D5.
- Resolve how the Godot project reaches the shared `assets/` directory at the
  repository root — the open item in `CONSTRAINTS §9 Assets`. `res://` cannot
  traverse above the project root, and the usual answer (a symlink) needs
  Developer Mode on Windows, which is a shipping target.

Not in this change, though both are M0: the four project-specific greps
(`add-architecture-and-tuning-gates`) and the renderer spike
(`spike-compatibility-renderer-shadows`). Both need this project to exist first.

## Capabilities

### New Capabilities

- `godot/project-configuration`: what the Godot project must guarantee about
  itself — engine version, renderer, the determinism-critical physics settings,
  the language restriction, how the shared assets are reached, and where the
  tuning constants live.
- `godot/build-verification`: what the standing suite must do and must refuse to
  do — headless and display-free, no system Python, no real save file, no
  network, a bounded wall time, and documentation gates that actually fail on
  the rot they guard.

Both are namespaced under `godot/` because `CONSTRAINTS §1 Repository shape`
states that multiple ports may coexist as sibling directories with none
privileged. These specs describe *this port*, not the game — the game is already
specified by the GDD, and restating it here would create a second normative
document.

### Modified Capabilities

None. No existing specs.

## Impact

- **New**: `godot/` (project, skeleton, `data/tuning.json`, `tools/`, `tests/`,
  `docs/`), `godot/.venv` (git-ignored), `godot/requirements.txt`, `.att/`.
- **Modified**: `CONSTRAINTS.md` §9, to record the resolved asset-path mechanism
  and close its open item. `.gitignore` — the repository has none today, and the
  Godot project brings `.godot/`, `.venv/`, and export artifacts.
- **Unmodified**: the game design document. This change alters nothing about the
  game.
- **Risk**: the Compatibility renderer pin is provisional pending the spike. It
  is recorded as a decision with an owner rather than a silent default, and
  nothing in this change or M1 depends on the answer.
- **Verification criteria touched**: V1, V2, V8 (partially — the settings are
  pinned here, the gate that enforces the pinning lands in
  `add-architecture-and-tuning-gates`), V10, V11, V12, and new criteria V16–V20 for the
  tuning transcription, placeholders, engine version, static typing, and asset
  import.
