## Context

See `proposal.md` — Why. Starting state: `add-godot-project-foundations` is
committed. `godot/tools/pre-commit` carries a hardcoded physics-symbol list and
checks staged blobs only; `godot/tools/test.sh` runs nine checks; `CONSTRAINTS.md`
marks V3 and V5 as 📋 and V4 and V8 as ⚠️.

Two facts from that change shape everything here.

**`rng.gd` defines `randf01()`, and both `rng.gd` and `sim.gd` carry comments
mentioning `randi()` precisely to say not to use it.** A substring grep for the
banned symbol `randf` flags the very file the constraint exists to mandate. This was found during
review and is recorded in CONSTRAINTS §4 Architectural boundaries under "Match
whole words".

**The project has been bitten twice by gates that inspected less than they
appeared to** — a documentation checker rooted at a directory that did not exist,
and a commit hook whose filter excluded renames. Both passed cleanly while
examining nothing relevant.

## Goals / Non-Goals

**Goals**

- V3, V4, V5, V8 enforced, so they become ✅ honestly
- The commit hook and the standing suite share one definition of what is banned
- Every gate refuses to pass when it inspected nothing
- The tuning-literal gate is useful rather than merely noisy

**Non-Goals**

- G1 scenario coverage (V6) — M1
- The renderer spike — its own change
- Any game code. This change should not need to edit `scripts/` or `scenes/`
- Enforcing static typing on *members*, which V19 currently marks ⚠️

## Decisions

### D1 — Banned symbols live in data, not in each tool

`godot/data/banned_symbols.json` holds two named lists — `core_purity` and
`physics_engine` — each entry with the symbol and a one-line reason. Both the
suite gate and the commit hook read it.

*Alternative rejected:* a list in each tool. That is how the two drift, and the
hook already carries a private copy today. A shared file also makes the reason for
each ban reviewable, which a bare regex is not.

The file lives under `data/` because CONSTRAINTS §4 Architectural boundaries calls `data/` values-not-logic,
and a banned-symbol list is a value.

### D2 — Match whole words, and only calls

Symbols are matched with word boundaries, and for function-shaped symbols a
following `(` is required. `randf01()` therefore does not match `randf`, and
`# do not use randi()` in a comment does not match either, because comments are
stripped before matching.

*Alternative rejected:* substring matching with an exclusion list for the known
false positives. That inverts the burden — every new legitimate identifier
containing a banned substring becomes a bug report against the gate.

**Comments are stripped, strings are not.** A banned symbol inside a string literal
is still a finding: `get_node("...")` style dynamic access is exactly what the core
purity rule exists to prevent.

### D3 — The tuning-literal gate: distinctive values, in game logic only

The gate reads `godot/data/tuning.json` and searches for its values written as
literals. Two narrowings, both forced by evidence rather than chosen up front.

**The first version searched every value in every `.gd` and `.tscn`, and produced
20 hits on a tree containing no game code at all.** `format=3` in a scene header
matched `minPropSeparation=3`; loop bounds and array indices in `smoke_test.gd`
matched `startClearance=8`, `groundSize=200`, `speedoMax=120`. Allowlisting twenty
entries on day one would have proved the gate was being worked around — which this
design says a growing allowlist means — before M1 had written a line.

So:

- **Scope: `godot/scripts/` only.** That is where game logic lives and where a
  hardcoded constant actually forks the contract. Tests legitimately contain magic
  numbers as expected values, scenes carry format versions and node counts, and
  tools are not the game.
- **Values: integers with magnitude below 10 are not searched.** The original
  exclusion was `0`, `1`, `-1`, `2`; the run showed that is far too narrow —
  *every* small integer collides with indices, counts and loop bounds. Seventeen
  constants fall out, and all seventeen are printed by name and value on each run.

What survives is 35 values including the ones that matter and would be genuinely
damaging to hardcode: `accel` 0.008, `friction` 0.96, `turnRate` 0.04,
`steerThreshold` 0.01, and the world extents.

A hit must be removed or exempted in
`godot/data/tuning_literal_allowlist.json` with file, value and a written reason.
An entry without a reason fails; so does a **stale** entry that matches nothing, so
an exemption cannot outlive its reason. Counts are printed every run.

*Alternative rejected:* keep the broad search and allowlist the twenty hits.
Honest to the original design and it discredits the gate immediately.

**Documented limits of the value match.** Numeric tokens are parsed and compared
numerically, so `0.960`, `.96` and `9.6e-1` are all caught for `friction`. An
*expression* that evaluates to a tuning value — `96.0 / 100.0` — is not, and
neither is a value assembled at runtime. Catching those needs evaluation, not
matching, and the gate says what it does rather than implying more.

*Alternative rejected:* a name-proximity heuristic — flag a literal only when a
constant's name appears nearby. Cleverer, much easier to fool, and hard to state as
a requirement.

**Two exemptions exist today**, both instructive and both in the inherited
placeholder `sim.gd`: `emit_sfx("bump", 0.3)`, a sound volume colliding with
`pushDistance`; and `DT_MS := 1000.0 / 60.0`, milliseconds-per-second colliding
with `farClip` and `minimapFar`. The second only surfaced once the match became
numeric rather than textual. M1 replaces that file wholesale, at which point both
go stale and the gate says so — the staleness rule doing its job.

### D3a — The physics rule walks `godot/`, not a list of directories

The core-purity rule is scoped to `godot/scripts/core/`; the physics rule is not
scoped at all, and the walk reflects that — `godot/` itself, skipping only
`.godot/`, `.venv/` and `__pycache__`, which are caches rather than authored
files. It follows symlinked directories, and compares suffixes
case-insensitively.

**Which file types.** Every text format Godot can name a node or resource type
in: `.gd`, `.tscn`, `.tres`, `.escn`, `.godot`, `.cfg`, `.import`. An earlier
version scanned only `.gd` and `.tscn` while V4 claimed "anywhere under
`godot/`" — a saved `CollisionShape3D` lives in a `.tres`, and that is an
ordinary artefact rather than a contrivance. Restricting the suffix list is the
same over-claim as enumerating directories, one level down. **Binary scenes
(`.scn`, `.res`) are genuinely out of reach** of a text gate; the project does
not author them, and that limit is stated here rather than implied away.

This is a correction, not a first draft. An earlier version enumerated four roots
(`scripts`, `scenes`, `tests`, `tools`). The result was that `godot/addons/` — the
one directory a third-party addon carrying a `CharacterBody3D` would land in — and
any script at the top of `godot/` were unscanned, and **the staged-only commit
hook caught a violation the "full tree" gate missed**. Renaming any of the four
roots also shrank coverage silently, because the zero-inspection guard only fired
when *all* of them were empty.

`templates/` is scanned too. It ships deliberately incomplete example suites, but
they are committed files that a reader could copy, and they contain no physics
symbols today — so excluding them buys nothing and costs the word "anywhere".

### D4 — The settings gate reads the file, not a running engine

`check_settings.py` parses `godot/project.godot` as text and asserts the pinned
values, then checks that each of the seven models has a committed `.glb.import`
preset that does not record `valid=false`.

*Alternative rejected:* booting Godot and dumping `ProjectSettings`. More faithful —
it would catch a setting overridden at runtime — but it costs seconds per run and
the failure mode being guarded against is the *editor rewriting the file*, which
text inspection catches exactly.

Note `sync_assets.sh` already refuses a poisoned preset. The settings gate also
checks presence, so a deleted preset is caught even when sync is skipped.

### D5 — Gates fail when they inspect nothing

Every gate prints what it examined and exits non-zero on a zero count. This is a
direct response to two incidents in the previous change rather than a general
principle applied speculatively.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| The tuning-literal gate produces false positives once M1 writes real code | Already happened once, at design time rather than in M1, and the response was to tighten what is searched (D3) rather than widen the allowlist. The same response applies if it recurs |
| Excluding small integers means a real violation using one passes — `minPropSeparation`, `startClearance` and 15 others are unguarded | Accepted and made visible: all 17 are printed with their names on every run. The alternative is a gate nobody trusts |
| Scoping to `scripts/` means a hardcoded constant in a scene or a test is not caught | Accepted. Scenes are authored data and tests assert against expected values; neither is the game's logic. M1 puts the simulation in `scripts/`, which is what this guards |
| Stripping comments could hide a violation inside a commented-out block | Intended. Commented-out code is not code; if it is reinstated, the gate sees it |
| A shared banned-symbol file becomes a place to quietly delete an inconvenient entry | The file carries a reason per symbol, so a deletion is a reviewable diff rather than a regex edit |
| The gates slow the suite past its budget | Measured before and after; the suite is 6.2 s against 60 s. These are greps over a small tree |
| The hook grows slow enough to be bypassed | It already reads staged blobs into a temp dir; the greps run on those. Re-measure against the recorded figure in CONSTRAINTS §13 Automation and gates |

## Migration Plan

No migration; nothing depends on these gates yet. Ordering that matters:

1. The shared symbol data and the two boundary gates land before anything else, so
   the rest of M0 and all of M1 are written under them.
2. `CONSTRAINTS.md` marker updates come **last**, after each gate has been verified
   by deliberate breakage — the previous change's rejections were largely markers
   claiming more than the tooling delivered.

Rollback is `git revert`; no state outside the repository is touched.

## Open Questions

None outstanding. The tuning-literal false-positive policy was the one real
uncertainty; it was settled empirically during implementation rather than by
argument — the first version's 20 false positives are recorded in D3. Whether the
narrowed rule is right is answerable once M1 has written the core, and the gate
reports enough on each run to tell.
