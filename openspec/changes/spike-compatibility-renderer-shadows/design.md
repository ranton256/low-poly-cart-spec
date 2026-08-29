## Context

See `proposal.md` — Why. `CONSTRAINTS §2 Tech stack` pins `gl_compatibility` on
every target, marked ❓ and owned by this change. `godot/project.godot` carries the
pin with a comment naming this change as the owner that may reverse it. Nothing in
M0 or M1 depends on the outcome, which is exactly why now is the cheap moment.

The design document specifies the sun precisely: 2048 × 2048 shadow map,
soft/percentage-closer filtering, an orthographic volume spanning ±60 wu in X and
Y, near 0.5 / far 200, and a depth bias of about −0.0001. It also says what the
shadow is *for* — the kart's contact shadow is the primary cue for where the kart
actually is on the ground.

## Goals / Non-Goals

**Goals**

- A defensible, re-runnable answer to whether Compatibility carries that lighting
- The ❓ in CONSTRAINTS §2 Tech stack settled either way
- Evidence committed, so the decision can be re-examined rather than re-argued

**Non-Goals**

- Changing the renderer. If the answer is negative this change reports it; the
  alternatives are a product decision (see D4)
- Tuning the look, adding an environment, or building anything M6 will own
- Any game code, any gate, any acceptance item

## Decisions

### D1 — Criteria are written down before the captures are looked at

The pass criteria go into the progress note **first**, in the same commit or an
earlier one, and the captures are judged against them afterwards.

This is the one decision that makes the spike worth running. Compatibility is
already pinned, in a document I wrote, and a spike whose bar is set after the
images are on screen will find whatever it needs to find. Fixing the bar first is
the cheapest available defence against that, and it costs nothing.

The criteria, stated now:

1. **The kart casts a contact shadow that reads as contact** — the shadow is
   attached to the wheels, not floating or detached.
2. **A prop's shadow has a soft edge**, not a hard aliased staircase, at the
   specified 2048 map size and filtering.
3. **No shadow acne** on lit surfaces at the specified bias.
4. **No peter-panning severe enough to break criterion 1** — a small gap is
   acceptable, a shadow visibly separated from its caster is not.
5. **Shadowed faces are not black** — the ambient and hemisphere fills read, which
   is what the design document asks them for.

A criterion is met or not; "close enough" is not a verdict. If Compatibility fails
one, the finding names which.

**What the first run proved about this decision.** The criteria were fixed first
and an independent reviewer confirmed it — but the run was still rejected, because
the *scene beneath the bar* was under-built and the renderer configured more
generously than the specification: a 4096² shadow map where 2048² was specified,
two fill lights aimed sideways, a sun off by 4.68°, and a C5 measurement from an
unnamed patch. D1 is necessary and is not sufficient. **Auditing the scene against
the specification, setting by setting, belongs beside it** — and is now task 2.6.

### D2 — Compare against Forward+, on the same scene, same frame count

Both captures come from one probe scene through `tools/capture.sh`, differing only
in the renderer. Forward+ is the reference not because it is a candidate — the web
target rules it out — but because it shows what the specified lighting is *supposed*
to look like. Without it, "the shadow looks a bit rough" has nothing to be rough
against.

*Alternative rejected:* judge Compatibility alone against the design document's
prose. Prose does not have a penumbra.

### D3 — The probe scene is committed as evidence, and marked as superseded

**This decision was wrong as first written and is corrected here.** The original
said the probe scene is scaffolding and gets deleted once the captures exist, on
the reasoning that a probe left behind becomes a second, stale definition of the
lighting that nobody updates.

That reasoning is sound, and it directly contradicts this change's own spec
scenario *The comparison can be re-run*, which requires the captures be
regenerable **from a committed scene** and the committed capture tool. Deleting
the scene made that scenario false the moment it was written. A decision nobody
can re-check is an anecdote, and this spike exists precisely to replace an
anecdote with evidence.

So the scene is committed, at `scenes/renderer_probe.tscn`, with a header that
says what it is: spike evidence, not a live definition, superseded by M2's
environment, referenced by nothing. The staleness risk is handled by saying so in
the file rather than by deleting the file — and the header also carries the two
findings that would otherwise be lost with it (the ±60 wu shadow distance, and
the two-light hemisphere substitution).

Verified: re-capturing from the committed scene reproduces the committed image
pixel for pixel (max diff 0).

*Alternative rejected:* keep the deletion and weaken the spec scenario to "can be
rebuilt from the note". That trades a checkable property for a promise, in the one
change whose entire output is meant to be checkable.

### D4 — A negative result is reported, not acted on

If Compatibility fails a criterion, this change records the finding and leaves the
renderer pinned. It does not switch.

The alternatives all cost something outside a spike's authority: drop the web
target, accept a worse look on web only, or run two renderers and maintain two sets
of visual baselines. Each trades away something the constraints document commits
to, so each is a proposal with the owner's decision behind it.

### D5 — Determinism, so the comparison is evidence rather than an anecdote

Captures use the committed `tools/capture.sh` with a fixed frame count, and the
note records the exact commands. `CONSTRAINTS §12 Review` already requires this —
a screenshot that cannot be re-run is a memory of a verification, not one — and M0
measured this capture path as byte-identical across runs.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| **Confirmation bias** — the choice is already pinned by the person spiking it | D1: criteria fixed before the images are seen, and each one pass/fail rather than a judgment of overall quality |
| The probe scene does not represent M2's real world, so the answer does not transfer | The probe uses the design document's specified lights, ground and shadow settings verbatim, and the kart, which is the asset whose shadow the document names. It is not a guess at M2's scene |
| Godot's Compatibility renderer improves in a later version and the finding goes stale | The note records the engine version, and `.godot-version` is gated. A version bump is a proposal that can re-run this |
| A negative result stalls the roadmap | It does not: nothing in M0–M5 depends on the answer, and M6 is where it would bite. Reporting early is the point |
| Judging shadow quality from a static capture misses motion artefacts (shimmer, swimming) | Accepted for this spike and stated in the note. Shadow stability under a moving camera is M6's, when there is a camera |

## Migration Plan

Nothing to migrate. Ordering that matters: criteria are committed **before** the
captures (D1), and the probe scene is committed as evidence rather than deleted (D3, corrected during implementation).

Rollback is `git revert`; the only durable outputs are two images, a note, and a
marker change in `CONSTRAINTS.md`.

## Open Questions

None. What the spike cannot answer — shadow behaviour in motion — is named in the
risks and assigned to M6 rather than left implicit.
