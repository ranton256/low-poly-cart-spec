# Low Poly Cart — Godot port

A single-player arcade go-kart time trial: an open green field scattered with
low-poly props, momentum-based handling, a chase camera, a minimap, and a
stopwatch. No opponents, no fail state. Load → countdown → drive forever.

This directory is **one implementation** of the normative design document at the
repository root, in Godot 4.6 and GDScript, shipping to macOS, Windows, Linux,
and the web. The design document is engine-agnostic and wins over anything here.

**Specifications are the source of truth for behavior. Code implements them and
is expected to be rewritten when a better implementation appears.**

> Note the limit of that claim. Specs here describe *observable behavior*;
> implementation choices live in per-change `design.md` files instead, so code
> cannot be regenerated from specs alone. What holds: when code and spec
> disagree, the spec wins or the spec gets changed — never a silent divergence.

## Read these before doing anything

| File | What it governs |
|---|---|
| `../low-poly-cart-game-design-document.md` | **The specification. Normative, engine-agnostic, and it wins over every other document.** 14 features, 64 scenarios, the constant tables, and the 14-item acceptance checklist |
| `../CONSTRAINTS.md` | Toolchain, boundaries, budgets, testing, work tracking, review, release. §10 *Verification criteria* is the definition of done; §12 *Review* is how it is judged |
| `../ROADMAP.md` | Milestones M0–M8 and what "done when" means for each |
| `docs/GLOSSARY.md` | Every project, architecture, process, and verification term, defined once |
| `GOTCHAS.md` | Symptom-first debugging notes. Read before debugging anything |
| `../openspec/config.yaml` | Standing constraints injected into every planning artifact |
| `docs/testing_toolkit.md` | The harness, the two gates, the suite templates |

> **The design document specifies the GAME; it never mentions an engine.** A
> change's `specs/` describe what *this port* must do that the design document
> does not settle — never a restatement of its scenarios, which would create a
> second normative document. Architecture is deliberately not in one file:
> intent lives in the design document, enforced boundaries in
> `../CONSTRAINTS.md` §4 *Architectural boundaries*, and the reasoning behind
> each decision in that change's `openspec/changes/<name>/design.md`.

## Toolchain

| | |
|---|---|
| Engine | Godot **4.6.1** (`godot` on PATH), recorded in `.godot-version`. `config/features` carries only the `4.6` series — Godot stores nothing finer |
| Language | **GDScript only.** No C#, no GDExtension, no third-party addons — the web target forces one language, so the simulation has one implementation everywhere |
| Renderer | **Compatibility** on every target, confirmed by `spike-compatibility-renderer-shadows`. Note ambiguities A8 (shadow normal bias) and A9 (light intensity units) in `docs/AMBIGUITIES.md` |
| Gate | `./tools/test.sh` — headless, display-free, must be green before anything is done |
| Python | **`.venv` always — never system Python.** Pinned by `requirements.txt` |
| Planning | `openspec` — see below |
| Tasks | `att` — see below |

```sh
./tools/test.sh                            # the standing gate
./tools/capture.sh <scene> <out.png>       # windowed visual proof — NEVER in test.sh
.venv/bin/python tools/check_links.py      # every relative Markdown link resolves
.venv/bin/python tools/check_section_refs.py   # every CONSTRAINTS §N reference is accurate
.venv/bin/python tools/check_placeholders.py   # placeholder markers in shipped docs
.venv/bin/python tools/check_tuning_transcription.py  # tuning.json matches the GDD tables
.venv/bin/python tools/measure_exposure.py <capture.png>   # the A9 exposure criteria
.venv/bin/python tools/find_light_scale.py # re-derive the light scale (windowed)
./tools/check_sky_ambient.sh                # regenerate design D2a's evidence (windowed)
./tools/sync_assets.sh                     # copy the shared models in from ../assets/
godot --headless -s tests/<suite>.gd       # one suite directly
```

Every Python invocation uses `.venv/bin/python`. `tools/test.sh` exits with
instructions rather than falling back to system Python, so the package versions
gating a change are the ones in `requirements.txt`. If the environment is
missing:

```sh
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
```

Godot's headless mode has **no renderer**, so it cannot screenshot. Visual checks
live in a separate windowed gate and must never enter `test.sh`.

## Vocabulary

`docs/GLOSSARY.md` is canonical. Read it before writing specs; add to it when a
change introduces a term.

> **The word that bites hardest here is "forward".** The design document's world
> forward is **+Z**; Godot's convention is **−Z** (`look_at`, `Camera3D`, most
> imported meshes). Both frames are right-handed and Y-up, so *positions* map one
> to one and nothing is mirrored — but a node's facing does not. The simulation's
> forward vector is the node's **`+basis.z`**. Any π offset needed to point a mesh
> or camera the Godot way lives in the view, in one named constant.
>
> The second is **"physics"**. This game has none in Godot's sense: no bodies, no
> shapes, no solver, no `move_and_slide`. "Physics" here means the design
> document's eight-step scalar tick, and `_physics_process` is used only because
> it is the fixed-rate callback.

## Planning a change: openspec

Behavior is specified before it is built. Planning artifacts are committed
alongside the code they describe.

```sh
/opsx:explore    think through a problem — no code written
/opsx:propose    create a change: proposal, design, specs, tasks
/opsx:apply      implement it, task by task
/opsx:archive    fold its specs into openspec/specs/ when done
```

```sh
openspec list --json                          # active changes
openspec status --change <name> --json        # artifact state and next step
openspec instructions <artifact> --change <name> --json
openspec validate <name> --strict             # must pass
```

A change lives in `openspec/changes/<name>/`:

```
  proposal.md   why, scope, and what is deliberately excluded
  design.md     how — decisions, alternatives considered, risks
  specs/        one spec per capability; ADDED/MODIFIED requirements
  tasks.md      the ordered execution checklist for THIS change
```

Rules that apply when writing them, enforced by `openspec/config.yaml`:

- Requirements state **observable behavior**. Constants fixed by the domain may
  appear; values chosen to tune feel or difficulty live in `data/`
- Every requirement has at least one scenario; scenarios use exactly four hashes
- Record the alternatives considered for each design decision, and why they lost
- Every change ends with `./tools/test.sh` green

Never hand-create a change directory — `openspec new change "<name>"` scaffolds
required metadata. Use `skip_specs: true` only when behavior genuinely does not
change (tooling, docs).

## Working on a task: att

Detailed work lives in `att`, not in this file and not in ad-hoc lists. That is
the installed CLI name of `https://github.com/ranton256/agent-task-tracker`.

```sh
att list --ready            # what can be worked now — dependencies satisfied
att list --blocked          # what is waiting, and on what
att show <id>               # exit criteria + ROADMAP references
att start <id>
att status <id> in-review   # hand to the Critic — never skip
att done <id>               # only after [APPROVED] + doc drift check
```

### Which tracker owns this work

Three layers. Duplicating between them is the failure mode.

| Layer | Owns |
|---|---|
| `../ROADMAP.md` | Milestones — where we are going, in what order |
| `openspec/changes/<name>/tasks.md` | The execution checklist for one **accepted** change; archived with it |
| `.att/` via `att` | Everything else — backlog, issues found in passing, scope deferred out of a change |

**Work is tracked in exactly one of `att` or an accepted change's `tasks.md` —
never both.** Do not mirror `tasks.md` into `att`. Do not use `att` as a second
planning system; proposing, designing, and specifying stay in openspec.

Nothing leaves scope untracked: every item deferred out of a change gets an `att`
task before that change is archived.

## Five rules that erode first under pressure

Full detail in `../CONSTRAINTS.md`. These are process gates carried by review
and status transitions, not by a linter, which is exactly why they need saying.

1. **Keep the tracker current, always.** `att start` when you begin, log the RED
   failure to the description, `att status <id> in-review` when green, `att done`
   only after approval. For work inside an accepted change, the equivalent is
   checking off `tasks.md` as each task completes. No code is committed against
   work that appears in neither. Commit `.att/` alongside the code it describes.

2. **Every completed task or milestone gets an adversarial review pass
   (Critic).** The Writer never approves their own work, and `in-review` is never
   skipped. Work is **REJECTED** on any of eight criteria — suite not green, a
   specified scenario with no test, work not matching its specification, a
   constraint violated, a tolerance widened rather than met, an ambiguity
   resolved without being recorded, documentation drifted, or visual proof
   missing. Full criteria and verdict format in CONSTRAINTS §12 Review.

3. **Show the work, do not just assert it.** Visual proof is **mandatory** for a
   milestone and **expected** for any task that changes what the player sees or
   how the game plays. `tools/capture.sh` produces it; committed proof lives in
   `docs/progress/`. A green suite proves behaviour and says nothing about
   whether what is on screen looks right. Never hand-cropped: a screenshot that
   cannot be re-run is a memory of a verification, not one.

4. **Check the docs for drift and gaps before marking anything done.** Behavior
   changed → the change's `specs/` change in the *same commit*. New term →
   `docs/GLOSSARY.md`. New gate → `../CONSTRAINTS.md`, with its enforcement
   status. New or changed milestone → `../ROADMAP.md`. Remove references to files,
   flags, and commands that no longer exist — the link and section-reference
   gates catch structural rot, but not stale prose. Documentation gaps are review
   findings, not follow-up work.

5. **A green suite is not evidence on its own.** A `check()` accidentally turned
   into a no-op leaves everything green and verifies nothing. When the harness
   itself changes, deliberately break what each gate guards and confirm the right
   gate fails with the right message. And if you verified something to sign off
   work, commit the method as a tool before calling the work done — a number in a
   commit message is a memory of a verification, not a verification.

## Non-negotiables worth repeating here

- `scripts/core/` touches **no engine types** — no `Node`, no `get_tree()`, no
  `_process`, no `randi()`. It is constructible and steppable with no scene loaded.
- The view **reads** state and never writes it.
- All gameplay randomness comes from `scripts/core/rng.gd`. The engine RNG is for
  view cosmetics only, precisely so it can never perturb the gameplay stream.
- The simulation never reads frame `delta`. View animation is a function of the
  simulation clock, never wall time.
- Test scripts `preload` by path and never rely on `class_name`, which is
  invisible to `godot -s` on a fresh clone.
- Never `git add -A` or `git add .`. Stage files explicitly.

**This project's own non-negotiables:**

- **The Godot physics engine plays no part.** No `RigidBody3D`,
  `CharacterBody3D`, `StaticBody3D`, `Area3D`, `CollisionShape3D`, or
  `move_and_slide` anywhere. Props are meshes plus an AABB record; collision is
  the design document's own axis-aligned test.
- **No tuning literal outside `data/tuning.json`.** Refer to constants by the
  name the design document gives them.
- **Tolerances are met, never widened.** The acceptance checklist's numbers are
  literal. Widening one is a specification change, not a judgment call.
- **`physics_jitter_fix` stays 0** and the tick rate stays 60. Both are pinned in
  `project.godot` with comments saying why; Godot strips those comments if the
  editor rewrites the file, so restore them if they vanish.
- **A gate added or changed is verified by deliberately breaking what it
  guards.** A gate that has never failed is not known to work.
- **Every spec ambiguity resolved in code goes in `docs/AMBIGUITIES.md`** before
  the change is archived. That register is a deliverable, not a complaint file.

**Git workflow:** branch per change, named for the change. Never commit to
`main` directly. Stage files explicitly.
