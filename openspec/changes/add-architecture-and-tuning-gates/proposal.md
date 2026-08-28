## Why

Four constraints in `CONSTRAINTS.md` are still carried by habit rather than by a
gate: core purity (**V3**), the physics-engine ban across the whole tree
(**V4**), tuning literals (**V5**), and the pinned project settings (**V8**).
`add-godot-project-foundations` pinned the settings and put a physics-body check
in the commit hook, but the hook sees only *staged* files — a violation already in
the tree passes, which is why V4 and V8 are marked ⚠️ rather than ✅.

The roadmap is emphatic about the timing: land these **before `scripts/core/` has
any of the game in it**. M1 is the milestone that fills that directory, so this is
the last moment the boundary is free to enforce. A `CharacterBody3D` introduced in
M1 and caught in M6 is a rewrite; caught on the commit that introduces it, it is a
typo.

This change implements **no game behaviour**. It advances **no acceptance
checklist item**. It exists so that the milestones which do cannot silently drift
off the architecture the design document's tick order depends on.

## What Changes

- Add a **core purity** gate: nothing under `godot/scripts/core/` may reference
  engine node types, the scene tree, engine time, or engine randomness (**V3**).
- Add a **physics-engine** gate covering the **whole tree**, not just staged
  files, so V4 can become ✅ (**V4**).
- Add a **tuning literal** gate: a *distinctive* value defined in
  `godot/data/tuning.json` may not appear as a numeric literal in the game-logic
  scripts under `godot/scripts/` (**V5**). Scope and value selection are design
  decisions — see `design.md` D3.
- Add a **project settings** gate asserting the determinism-critical settings and
  the presence and validity of the seven `.glb.import` presets (**V8**).
- Extend the commit hook to run the same greps on staged content, so a violation
  is refused at the commit that introduces it rather than at the next suite run.
- Update `CONSTRAINTS §10 Verification criteria`: V3, V4, V5 and V8 move from
  📋/⚠️ to ✅, and §2/§3/§4 markers follow.

**Every gate must be verified by deliberately breaking what it guards**, and each
must report a non-zero count of what it inspected — a gate that passes by
examining nothing is the failure mode this project has already hit once.

Not in this change: the renderer spike (`spike-compatibility-renderer-shadows`),
and G1 scenario coverage (**V6**), which is M1's.

## Capabilities

### New Capabilities

- `godot/architecture-enforcement`: what the project mechanically refuses to let
  into the tree — engine dependencies in the simulation core, the Godot physics
  engine anywhere, tuning values written as literals, and project settings
  drifting from their pinned values.

### Modified Capabilities

None. `godot/build-verification` would be the natural candidate — the standing
suite and the commit hook both grow — but `add-godot-project-foundations` is not
yet archived, so `openspec/specs/` does not exist and there is no main spec to
delta against. The suite-and-hook integration is therefore specified inside
`godot/architecture-enforcement`, which is self-contained: it defines what is
refused, and where the refusal happens.

*(Worth noting for sequencing: deltas accumulate while changes stay unarchived.
Archiving `add-godot-project-foundations` — now complete, approved and committed —
would let later changes modify its capabilities properly.)*

## Impact

- **New**: `godot/tools/check_boundaries.py`, `godot/tools/check_tuning_literals.py`,
  `godot/tools/check_settings.py`, and a shared symbol-list data file so the hook
  and the suite cannot disagree about what is banned.
- **Modified**: `godot/tools/test.sh`, `godot/tools/pre-commit`, `CONSTRAINTS.md`
  (§2, §3, §4, §10, §13), `godot/data/` gains the banned-symbol lists.
- **Unmodified**: the game design document; `godot/scripts/`, `godot/scenes/`.
  This change adds no game code and should not need to edit any.
- **Risk**: the tuning-literal gate is the one that can be either useless or
  obstructive. Its false-positive policy is a design decision — see `design.md`.
- **Backlog closed**: `att` 1 and 7.
- **Verification criteria touched**: V3, V4, V5, V8 to ✅; a new criterion for the
  hook and suite sharing one definition of what is banned.
