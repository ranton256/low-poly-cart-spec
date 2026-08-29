# Glossary

The canonical home for project vocabulary. Other documents link here rather than
restate, so there is one definition to keep correct.

Add a term the moment it appears in a spec, a commit message, or a conversation
where two people could reasonably mean different things by it.

> The architecture, verification, and process terms below describe the structure
> this project inherited and is bound to by CONSTRAINTS §4 Architectural
> boundaries. The project vocabulary table comes first because it is the one that
> settles arguments.

---

## Project vocabulary

Words two people could reasonably mean differently, each pinned to exactly one
meaning. The ones that cause arguments are those denoting something in Godot,
something in the design document, *and* something in this codebase.

| Term | Means |
|---|---|
| **the spec** | `low-poly-cart-game-design-document.md` at the repository root. Normative. Never a change's `specs/`, which are called *delta specs* |
| **delta spec** | A change's `openspec/changes/<name>/specs/**/spec.md`. Describes what *this port* must do that the spec does not settle. Never a restatement of the spec |
| **physics** | The design document's eight-step scalar tick. **Never** Godot's physics engine, which this project does not use. `_physics_process` is used only because it is the fixed-rate callback |
| **forward** | The design document's world forward, **+Z** — a node's `+basis.z`. Godot's own convention is −Z; that difference lives in the view as one named constant, never in the simulation |
| **tick** | One fixed 1/60 s simulation step. Never a rendered frame — at 144 fps most frames advance no tick, and at 30 fps one frame advances two |
| **prop** | A scattered obstacle: a mesh in the view plus an AABB record in the simulation. Never a physics body |
| **the field** | The scattered play area, ±`scatterExtent`. Distinct from the *drivable* area, ±`drivableExtent`, which is larger and empty at its edge |
| **lap** | A banked time: a northbound crossing of the start band at least `minLapTime` after the clock started. There is no circuit and no checkpoint |
| **the band** | The white start/finish quad at Z = +5. The only track furniture in the game, and the timing gate |
| **the grid** | The wireframe reference overlay on the ground. Part of the intended look, **not** developer instrumentation, and it ships |
| **speed** | Ambiguous on its own — say *velocity* (wu/tick, signed, what the simulation carries) or *the dial* (the cosmetic 0–120 readout, which tops out at 115 and is not calibrated) |
| **normalisation** | Scaling a supplied model to its target height, re-measuring, and grounding it at Y = 0. Never vector normalisation |
| **registration order** | The order props enter the collision registry. Observable behaviour: the first intersecting prop wins, so save/load must preserve it |
| **the hit volume** | The kart's collision box: its world-axis-aligned extent, recomputed from its current heading every tick, then contracted by `hitboxContraction` on every side. 1.80 × 1.96 wu at rest. Larger when the kart is diagonal, which is accepted, not corrected |
| **the pin** | The kart held between two props whose gap is smaller than its hit volume. Specified behaviour, not a defect: one collision is resolved per tick, so the push out of one drives it into the other and the kart is stopped dead on every tick of contact. **Not permanent** — the radial push makes it an unstable equilibrium and the kart is ejected sideways within 15–125 ticks depending on heading, which is ambiguity A12, open against the design document |
| **the jolt** | The one-shot camera displacement on collision, within `±shakeHorizontal` and `±shakeVertical`. It has no decay of its own — the chase camera's ordinary easing absorbs it, which is what makes it a shudder |

## Architecture terms

These describe the architecture this project inherited and is bound to by
`../CONSTRAINTS.md` §4 Architectural boundaries.

| Term | Means |
|---|---|
| **simulation** (sim) | The plain, seeded, engine-free object in `scripts/core/` that the view reads. No Godot node types, fixed timestep, never reads `delta`. |
| **view** | `scenes/` — draws simulation state and reads only. Never writes back. |
| **effect event** | A one-shot occurrence the sim *publishes as data* rather than playing. The view drains them each frame and turns them into sound and particles — which is what makes audio assertable with no sound device. |
| **simulation clock** | `sim.time_ms`, advanced by fixed ticks. View animation is a function of it, never of wall time — the single property that makes motion tests and reproducible screenshots possible. |
| **tuning data** | Values in `data/` chosen to shape feel or difficulty, as opposed to constants fixed by the domain. Assertable by balance invariants. |

## Process terms

| Term | Means |
|---|---|
| **gate** | An automated check that fails a change. `tools/test.sh` is the standing gate; the visual gate is separate and windowed. |
| **change** | One unit of planned work under `openspec/changes/<name>/` — proposal, design, specs, tasks. |
| **capability** | A behavior area with its own spec file. |
| **backlog** | Work tracked in `.att/` that no accepted change covers. |
| **visual proof** | A capture from `tools/capture.sh`, committed to `docs/progress/`, showing what the game actually looked like. Mandatory for a milestone, expected for anything changing what the player sees. |
| **Writer / Critic** | The two review roles. The Writer produces work; the Critic reviews it adversarially, and never in the same pass. See [CONSTRAINTS §12 Review](../../CONSTRAINTS.md). |

## Verification terms

| Term | Means |
|---|---|
| **determinism** | Same inputs and same seed produce the same result on every run and any machine. A violation is a defect, never a threshold to relax. |
| **self-play** | A bot playing the game to completion with no human input and no rendering. The cheapest fuzzer a seeded simulation gives you. |
| **noise floor** | The difference between two captures taken with nothing changed. Thresholds are set a small multiple above it — and it should be near zero. |
| **blessing a baseline** | Accepting the current capture as the reference for future comparisons. |
| **balance invariants** | Assertions about *tuning data* rather than code — that difficulty never dips between levels, that a curve lands where intended. The highest-value suite in this skeleton. |
| **mutation check** | Deliberately breaking what a gate guards to confirm it fails, with the right message. Green after a harness change is not evidence. |
| **oracle** | An independent source of expected values, with no shared lineage with your implementation. Expectations generated from your own code agree with it by construction and verify nothing. |
| **light scale** | The single factor converting the design document's light intensities into Godot's units. It multiplies all three together, so the document's ratios — which ARE normative — survive by construction. Ambiguity A9; the value is `port_decisions.lightScale`. |
| **saturated pixel** | A pixel at 255 in any channel. On a surface with no specular highlight, saturation is exposure, not brightness — the information is gone and no tone curve gets it back. |
| **falsification test** | A cheap check that runs first and voids everything after it if it fails. Here: the unlit sky must render exactly its specified colour, because if the pipeline is reshaping colour then no other measurement means anything. |
| **composition root** | The one place that owns the simulation and advances it. Godot's `_physics_process` is the fixed-step accumulator; the root steps exactly once per call and never in the per-frame callback. |
| **nose sign** | Which end of the kart's authored long axis is its front. The imported bounds give the axis and cannot give this, because an axis-aligned box is symmetric — see ambiguity A6. |
| **consistency test** | A check that two things agree, which is not a check that either is right. The 16-heading travel test is one: it derives the kart's nose from the constant it is testing, so a sign error makes both sides wrong together and it passes. |
| **registration order** | The sequence scatter emits placements in, preserved by the prop field. Collision resolves against the first intersecting prop in this order, so it is a contract between changes rather than an implementation detail — see CONSTRAINTS §4 Architectural boundaries. |
| **placement** | What the scatter generator produces: an asset name, a position, a yaw, a scale and a grounding offset. Data, not a node — the view instantiates from it, which is what lets every placement rule be tested with no scene loaded. |
| **eased per tick** | A smoothing recurrence advanced once per simulation step, never once per rendered frame. Per frame the same factor gives a different time constant at every display rate — ambiguity A10. |
| **settling time** | How long the chase camera takes to return behind the kart after a turn, measured as the angle decaying to 10% of its peak. A camera that never leaves is always settled, which is why the lag is asserted separately. |

---

**Related:** [CONSTRAINTS.md](../../CONSTRAINTS.md) · [ROADMAP.md](../../ROADMAP.md) ·
[GOTCHAS.md](../GOTCHAS.md)
