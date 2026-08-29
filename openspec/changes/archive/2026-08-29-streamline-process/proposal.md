# Proposal: streamline-process

## Why

The process is producing good work too slowly to serve its purpose. Across the
21 commits on this branch, lines touched in process documents (~12,900) exceed
lines touched in game code and tests (~12,000), and two days of work delivered
four of nine milestones. The comparable course builds (Brick Smasher, Cave
Runner) ship at roughly twice this pace on a two-layer process. Three drags,
compounding:

1. **Review cadence.** CONSTRAINTS §12 Review mandates an adversarial Critic pass at
   three tiers — every backlog task, every change, every milestone — each judged
   against eight rejection criteria including a full-document constraint scan.
   Nineteen backlog tasks in two days meant a review ceremony every couple of
   hours of work. Evidence that the cadence exceeds capacity: five completed
   changes from M2/M3 sit unarchived behind the review-before-archive gate.
2. **A third tracking layer.** `att` owns nothing the other two layers cannot:
   its backlog fits in ROADMAP.md, and its in-flight state duplicates a change's
   `tasks.md`. In practice the "not a second planning system" rule eroded —
   the backlog holds 350-word memos with candidate-fix analyses, exactly the
   planning writing the rule forbids. Each memo was real time spent.
3. **A 906-line CONSTRAINTS.md.** Every agent turn loads it; criterion R4 makes
   every review re-scan it; its drift matrix requires synchronized edits across
   five documents. Much of its bulk is battle-history narrative ("an earlier
   version of this section…"), not constraint.

This change implements **no design-document feature** and advances **no
acceptance-checklist item**. It changes how the remaining five milestones will
be built, and it is recorded as a change — rather than done quietly — because
CONSTRAINTS §16 Changing this document requires amendment by proposal, and
because a deliberate mid-project process correction is itself worth having on
the record.

## What Changes

- **Work tracking collapses to two layers.** ROADMAP.md gains a `## Backlog`
  section and owns everything `.att/` owned; a change's `tasks.md` is unchanged.
  The ten open att tasks are triaged (see `design.md`): two are absorbed by
  registers that already track them, one is closed as met, one becomes an
  implementation task of this change, six become backlog lines. `.att/` is
  removed; the nine done tasks and the full task texts remain in git history.
- **Review collapses to two moments.** The archive-time check becomes a
  four-item checklist (gate green, coverage current, docs current, ambiguities
  recorded) run by the author. The adversarial Writer/Critic pass with an
  explicit verdict survives at exactly one tier: milestone completion. Visual
  proof stays mandatory for milestones and becomes discretionary elsewhere.
- **CONSTRAINTS.md is trimmed to its enforceable core** — every enforcement-
  status row, banned-symbol list, gate table, and operational trap note kept;
  narrative rationale cut to a sentence or removed (git history keeps the long
  form). Section numbers and titles are stable, so every existing
  `CONSTRAINTS §N Title` reference stays valid under V11.
- **The satellite documents follow**: `openspec/config.yaml`, `godot/CLAUDE.md`,
  `godot/docs/testing_toolkit.md`, `godot/docs/GLOSSARY.md`,
  `godot/docs/AMBIGUITIES.md`, and ROADMAP's att references.
- **The test.sh hole att 19 documents gets fixed** (implementation task): a
  runtime script error inside a test currently leaves the suite green; the
  fix pattern (fail the run on `SCRIPT ERROR` in a suite's output) is already
  proven in the sibling course repos.

## What is deliberately excluded

- No game behavior changes; no delta specs (`skip_specs` — this is process and
  tooling).
- The five unarchived M2/M3 changes are archived under the new checklist as a
  follow-up task, not silently.
- `add-game-state-and-countdown` (proposed, uncommitted, by a prior session) is
  left untouched; it proceeds under the new process when implementation resumes.
- The GDD, its tolerances, and all mechanical gates are untouched. Nothing in
  this change relaxes what any script enforces.
