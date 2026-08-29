## Context

See `proposal.md` — Why. Starting state: M0 is complete and archived, M1 has the
tick core and the normalisation contract. Eleven suites, 43 test functions, and the
design document has **64** scenarios across 14 features.

Most of those 64 belong to milestones that do not exist yet. A rough count: around
a dozen are claimable by tests today, eight or so are the visual set
`CONSTRAINTS §5 Conformance to the specification` already anticipates, and the
remainder are M2–M8. Any design that ignores this produces a gate that fails on
day one for forty reasons and gets disabled.

`att` 14 records the immediate obstacle: no existing test name maps to a design
document scenario heading.

## Goals / Non-Goals

**Goals**

- A gate that fails when a specified behaviour is verified by nothing
- Deferral that is a schedule, with an owner, rather than an excuse
- A claim mechanism that survives renaming a test
- Proof that the tick is indifferent to batching, which is what a frame loop varies

**Non-Goals**

- Acceptance 14b — a real frame loop at real refresh rates (M8)
- The visual gallery gate itself (M6); this change only records which scenarios
  belong to it
- Renaming existing tests to match scenario headings — D1 makes that unnecessary
- Any game behaviour

## Decisions

### D1 — A test claims a scenario by declaration, not by its name

A test file carries an explicit claim next to the function, naming the feature and
the scenario heading verbatim. The function may be called anything.

`att` 14 proposed renaming every test to encode its scenario. That fails on
mechanics and on principle. Mechanically, GDScript identifiers cannot carry the
document's punctuation, so the mapping would be lossy and a matcher would have to
guess. In principle, it couples a test's name to a document heading, so rewording
the heading breaks the name — and the useful name for a reader
(`_test_offset_comes_from_the_scaled_box`) is not the heading
(`Normalising a supplied model to its target height`).

An explicit claim is greppable, survives renames in both directions, and lets one
test claim more than one scenario when it genuinely covers both.

*Alternative rejected:* a central mapping file from scenario to test name. Nothing
keeps it honest — the previous reviewer said exactly this about hand-maintained
mappings, and they were right. A claim beside the code it describes moves with that
code.

### D2 — Three claim kinds, and the register holds only two of them

`verified` lives beside the test. `visual` and `deferred` live in one committed
register, because they describe absence and there is no code to put them next to.

The register is data, not prose: each entry names the scenario, its kind, and either
the milestone that will cover it or the reason it cannot be covered headlessly plus
the capture that does. A `deferred` entry without a milestone fails; a `visual`
entry without a reason fails.

### D3 — The gate matches on the scenario heading, exactly

Claims quote the design document's `### Scenario:` text verbatim. The checker
extracts headings from the document and requires a bijection: every heading claimed
once, every claim matching a heading.

This is what makes renaming a scenario in the design document *visible*. A fuzzy
match would absorb the rename silently, which is the failure the whole gate exists
to prevent — and it is the same reasoning that made CONSTRAINTS §13 Automation and gates require
section references carry their titles.

The cost is that rewording a heading breaks every claim on it. That is the intended
cost: the design document is normative, and a change to it should require someone
to look at what depended on it.

### D4 — The register must be honest, and mostly cannot be gated

The gate can check that every scenario is claimed, that deferrals name a milestone,
and that visual claims name a reason plus either a capture or the milestone that
will produce one. It **cannot** check that a `verified` claim's
test actually tests that scenario, or that a `deferred` scenario genuinely belongs
to the milestone named.

So the honest framing: this gate raises the floor from "nobody knows" to "every
scenario has a named owner and a named status". It does not prove the coverage is
good. Two things follow, and both are process rather than code:

- **A milestone cannot be called complete while it owns a deferred scenario.** The
  count is reported per milestone on every run, so the number is visible as it
  falls rather than only at zero.
- **Moving a scenario from `deferred` to `verified` is a reviewable diff**, in the
  same commit as the test that justifies it.

**A third limit, found by this change's own review:** the gate counts a claim whose
test never runs. A `# @covers` line on a function no longer called by `_init()` still
reads as coverage. Disclosed in `CONSTRAINTS §5 Conformance to the specification`
rather than left for someone to discover during a refactor.

Stating the limit here because a gate that reads as stronger than it is would be
worse than none — that has already been this project's recurring defect.

### D5 — The replay harness varies batching, not wall time

Three drivers step the same scripted sequence: one tick at a time; in groups of two,
as a 30 fps frame loop would; and in a repeating 0-1-1 pattern, as 144 fps would.
All must end byte-identical.

This is the headless half of acceptance 14. The item is stated in frames per second,
but what a frame rate *does* to a fixed-step simulation is change how many ticks a
frame consumes — so batching is the property under test, and it can be tested with
no frame loop at all. 14b, at M8, checks the real loop.

The sequence must turn, reverse and release input rather than just accelerate: a
straight-line run is symmetric under batching almost by construction and would pass
against a broken implementation.

*Alternative rejected:* run the real `_physics_process` at three refresh rates.
That is 14b, needs a window, and cannot be a headless gate.

### D6 — The harness proves it discriminates, which needed a seam

A task deliberately makes the simulation batch-dependent and confirms the harness
fails. Without that, three drivers agreeing proves only that they are the same code
path.

**Implementing that revealed the harness could not fail.** `Sim.step()` receives no
frame information whatsoever, so batch-independence is true *by construction* —
there is no surface through which grouping could affect the result, and every
mutation inside `step()` affects all three drivers identically. A harness that
cannot fail is decorative, and the spec scenario *The comparison would notice a
difference* would have been unreachable.

So the core gained a `begin_frame()`, called once per frame by the drivers —
including frames that consume no ticks — and empty. It is the seam through which
frame-dependence would enter the core if it ever did, and it is what a real
composition root will call in M2 anyway. With it, a mutation that decays velocity
per *frame* rather than per tick fails the replay harness and is invisible to the
single-driver determinism test, which is precisely the division of labour these two
suites are meant to have.

Recording it because it is a change to the simulation core made by a change whose
proposal says it implements no game behaviour. It implements none — an empty method
is not behaviour — but it is a real edit to `sim.gd` and should not arrive
unexplained.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| **The register is filled with `deferred` and the gate becomes theatre** | The honest answer is D4: partly unmitigable. What helps is that deferrals are counted per milestone on every run, and a milestone's completion claim has to answer to its own count |
| Rewording a design document heading breaks every claim on it | Intended (D3). The alternative absorbs renames silently |
| Registering 64 scenarios is tedious enough to be done carelessly | It is done once, and carelessness shows up as a scenario deferred to a milestone that does not own it — visible in review, not to the gate |
| The replay harness passes because all three drivers share a code path | D6 mutates the simulation to be batch-dependent and requires the harness to notice |
| The gate's own file list drifts from the test tree | It discovers claims by scanning the test directory rather than from a list |

## Migration Plan

Nothing to migrate. Ordering that matters: the claim mechanism and the checker land
before the register is populated, so the register is written against a gate that
already runs — rather than a gate written to accept whatever the register happens to
say.

Rollback is `git revert`.

## Open Questions

None. The one genuine uncertainty — whether `deferred` becomes a dumping ground — is
a property of how the project uses the gate, not of the gate's design, and D4 states
it rather than pretending the code can settle it.
