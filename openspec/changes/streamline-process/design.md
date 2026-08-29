# Design: streamline-process

## D1 — Drop the att layer rather than streamline it

**Decision.** Remove `.att/` and fold its jobs into ROADMAP.md (backlog) and
change `tasks.md` (execution), the two layers the sibling course builds use.

**Alternative considered: keep att with lighter rules** (shorter tasks, review
only at close). Rejected: the cost that matters is the layer itself — a third
place to look, a CLI to teach, a boundary rule that demonstrably eroded within
two days — not the length of its entries. The layer's one distinct job, "a
backlog outside any change," is a Markdown section, not a tool.

**Alternative considered: keep att for cross-port work only** (GDD proposals
like att 20). Rejected: one item does not justify a layer; the ambiguity
register already owns A12 and can carry its proposal pointer.

## D2 — Review at two moments, adversarial at one

**Decision.** Archive-time review becomes an author-run four-item checklist.
The Writer/Critic adversarial pass with an explicit [APPROVED]/[REJECTED]
verdict is kept only at milestone completion.

**Alternative considered: drop adversarial review entirely.** Rejected: the
Critic pass has a real track record here (it caught the overstated coverage
claims and the wrongly-parked deferrals recorded in §5, and found att 19).
Milestone boundaries are where its yield concentrates and its cost amortizes.

**Alternative considered: keep per-change Critic, drop per-task.** Rejected:
changes land every few hours in this repo; the archive backlog (five changes)
shows per-change ceremony already exceeds capacity. The mechanical gates carry
per-change quality; R1–R8's non-mechanical residue is what the milestone pass
is for.

## D3 — Trim CONSTRAINTS in place; move nothing to a rationale doc

**Decision.** Rewrite CONSTRAINTS.md keeping every normative row, list, and
status marker, cutting narrative to at most a sentence. No companion
RATIONALE.md.

**Alternative considered: move the prose to a non-normative doc.** Rejected:
it relocates the reading cost instead of removing it, and the long form
survives in git history at the commit this change lands on. Where a narrative
carried an operational lesson (the grep word-boundary trap, the symlink
rejection, the G1 count-drift lesson), the lesson stays as a one-liner.

**Constraint on the trim:** section numbers **and titles** are frozen —
`check_section_refs.py` (V11) validates `CONSTRAINTS §N Title` references
across the repo, and archived changes cite sections that must stay accurate.

## D4 — Triage of the ten open att tasks

| att | Title (short) | Disposition |
|---|---|---|
| 5 | Per-texture import settings for the web budget | **Backlog** (M6 web payload; §8 row updated to point there) |
| 8 | Record: two CI tasks deleted with CI | **Closed** — it exists to preserve a record, and git history of `.att/` preserves it better than a live task |
| 9 | Track V6/V7/V9/V13 to closure | **Absorbed** — §10's own status column and ROADMAP milestones already track each; a task tracking the trackers is the duplication §11 forbids |
| 10 | Kart reset action | **Backlog** (M7, where CONSTRAINTS §4 Architectural boundaries already points) |
| 15 | Decide A11 (ground edge at boundary) | **Absorbed** — ambiguity register owns A11, "settled in M6" |
| 16 | Capture input re-press → shared helper | **Backlog** (fold into a helper when M5/M6 adds captures; GOTCHAS already documents the behavior) |
| 17 | drive_capture settle frames: measure the floor | **Backlog** (M6, alongside the visual gate's threshold-measurement rule) |
| 18 | V19 covers signatures, not members | **Backlog** (extend `check_static_typing.py`; V19 stays ⚠️ until then) |
| 19 | Runtime script error leaves suite green | **Fixed by this change** (implementation task 6; pattern proven in the sibling repos) |
| 20 | GDD proposal: the pin is not producible as specified | **Absorbed** — A12 owns it; the register's owner column now names "a GDD proposal (backlog)" and the backlog carries the line |

The nine `done` tasks need no new home; their record is git history.

## Risks

- **Lost rigor at change scale.** Mitigated: every mechanical gate (V1–V26
  table) is untouched, and tasks.md discipline plus the archive checklist keep
  per-change verification; what is removed is ceremony, not checks.
- **Backlog rot in ROADMAP.md.** A Markdown list has no CLI nagging. Accepted:
  at this project's scale the list is a dozen lines, reviewed at every
  milestone pass.
- **Velocity claim unproven.** The before/after is measurable on this very
  repo: M0–M3 under the old process, M4–M8 under the new, same game, same
  author. That comparison is part of why the correction lands mid-project
  rather than in a restart.
