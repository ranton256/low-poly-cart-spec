# The testing toolkit

How this project verifies itself: a headless test harness, the standing suite,
and the windowed visual gate.

Inherited from `godot-game-skeleton` and adapted for this repository. The
inherited tools were in live use in a shipped game before being generalised;
`sync_assets.sh`, `check_tuning_transcription.py`, `check_engine_version.py`,
`check_static_typing.py` and `tests/assets_test.gd` were written for this
project. Every one of them, inherited or new, has been verified by deliberately
breaking what it guards — a requirement this project keeps
(CONSTRAINTS §7 Testing).

**Where things live.** The Godot project is `godot/`; the documents that govern
it — the design document, `CONSTRAINTS.md`, `ROADMAP.md` — are one level above at
the repository root, and every checker here is rooted there rather than at
`godot/`. Paths in this file are relative to `godot/` unless they start with
`../`.

```bash
python3 -m venv .venv                      # tooling env — required
.venv/bin/pip install -r requirements.txt
./tools/test.sh                            # prints "All suites passed."
./tools/install-hooks.sh                   # the commit-time gate
```

The standing suite runs `sync_assets.sh`, imports the models, then a seeded RNG /
fixed-timestep / determinism / event-channel smoke suite, the asset suite, lint
and format, and five documentation gates. It is headless, display-free, and
takes a few seconds. There is no CI — see `CONSTRAINTS §15 Not applicable`.

---

## The one decision to make first

Two properties are nearly free at the start and expensive to retrofit. This
project is set up on the right side of both, and `CONSTRAINTS §4 Architectural
boundaries` is what keeps it there.

```
  ① The simulation is separable from the view
       a plain object · no engine dependencies · fixed step · seeded
       the view READS it each frame and never writes back

  ② View animation runs on the simulation clock, not wall time
       position = f(sim.time_ms)       not     position += speed * delta
```

Everything downstream follows:

| Because… | You get… |
|---|---|
| the sim has no engine dependencies | headless suites that run anywhere, in milliseconds |
| the step is fixed | a bot that plays the whole game deterministically |
| it is seeded | reproducible runs, and screenshots that diff to zero |
| effects are published as data | audio/cue assertions with no sound device |
| animation is on the sim clock | motion tests with no renderer, and a sharp visual gate |

`scripts/core/sim.gd` is a worked skeleton of all five. Keep its shape; replace
its contents.

If you are porting an existing project whose gameplay lives in
`_physics_process` on nodes, do that separation first. Everything else here is
cheap once it exists and awkward until it does.

---

## The process, already set up

The spec-driven workflow is set up rather than described. `openspec/` at the
repository root and `.att/` are initialized and committed.

```
  ROADMAP.md          milestones — where you are going, in what order
       │
  openspec/changes/   one unit of work: proposal, design, specs, tasks
       │
  .att/  (att)        the backlog — future work, issues found, deferred items
```

**Three layers, and duplicating between them is the failure mode.** A change's
`tasks.md` is the execution checklist for that accepted change and is archived
with it. [`att`](https://github.com/ranton256/agent-task-tracker) holds
everything else — work discovered but not yet proposed, issues found in passing,
scope deliberately deferred. Never mirror one into the other.

```bash
/opsx:explore    think through a problem — no code written
/opsx:propose    create a change: proposal, design, specs, tasks
/opsx:apply      implement it, task by task
/opsx:archive    fold its specs into openspec/specs/ when done

att list --ready        # what can be worked now
att start <id>
att status <id> in-review   # the Critic pass is not skippable
att done <id>
```

`../CONSTRAINTS.md` §12 Review carries the Writer/Critic split: the Writer never
approves their own work, and there are eight explicit rejection criteria. That is
the part most likely to be skipped and most likely to catch something.

Commit `.claude/commands/`, `.claude/skills/`, and `.att/` — they are project
state, not personal. The repository-root `.gitignore` excludes `.venv/`,
`godot/.godot/`, the synced `*.glb` working copies and the textures Godot
extracts from them.

Use `skip_specs: true` for changes that add tooling or documentation. Specs
describe behavior; if behavior does not change, no spec should.

---

## As the game grows

Add each piece when the thing it verifies exists — not before. Copy the template
into `tests/` or `tools/`, fill in the marked parts, and uncomment its line in
`tools/test.sh`.

| When you have… | Copy from `templates/` | Cost |
|---|---|---|
| tuning data (levels, costs, curves) | `balance_invariants.template.gd` | 1 h — **highest value** |
| menus, shop, save/load | `scene_flow.template.gd` | 1 h |
| a seeded sim and a bot | `rng_differential.template.gd` | 30 min |
| sound effects | `av_cues.template.gd` | 1 h |
| parallax or timed animation | `motion_timing.template.gd` | 30 min |
| several levels and a bot | `difficulty_probe.template.gd` | 1 h |
| screens worth freezing | `gallery.template.sh` + the two Python tools | 2 h |

### Why balance invariants are worth the first hour

They assert your **tuning data**, not your code: difficulty never dips
level-over-level, incoming pressure stays bounded, the intro level is actually
gentle, and a simulated player at a given collection rate finishes the upgrade
curve *where you intended*. This is the suite that catches a generous-looking
number change three months after someone makes it.

Write one the moment a tuning intent becomes a sentence you could say out loud.

---

## The two gates

```
  tools/test.sh      headless · no display · every change · safe to run on every change
  tools/gallery.sh   windowed · needs a display · when the picture could change
```

Godot's headless mode **has no renderer**, so it cannot screenshot. That forces
the split — and the split is worth keeping deliberately. The moment a capture
lands in `test.sh`, the suite stops running over SSH and needs a virtual
framebuffer.

### Standing up the visual gate

1. Write capture scripts (`tests/capture_scene.gd`, `tests/capture_game.gd`)
   that instantiate a scene, step it a fixed number of ticks, and save
   `get_viewport().get_texture().get_image()`.
2. Copy `templates/gallery.template.sh` to `tools/gallery.sh` and list your
   states. **Name them, do not number them** — inserting a state later renumbers
   everything after it and churns every baseline.
3. **Capture twice without changing anything and diff the two captures.** That
   is your noise floor. If it is not near zero, something is non-deterministic;
   fix the harness before setting any threshold.
4. Set `tools/gallery_config.json` limits a small multiple above the measured
   floor, and record the measurement next to the numbers.
5. `tools/gallery.sh --bless` to accept the first baselines, then commit them.

`tests/baselines/` already contains a `.gdignore` so Godot never imports your
reference images and they never enter an export.

## What is in here

| Path | |
|---|---|
| `scripts/core/sim.gd` | worked skeleton of the sim/view split — replace contents, keep shape |
| `scripts/core/rng.gd` | seeded mulberry32; reproducible and state-comparable |
| `tests/harness.gd` | the entire test framework: assert, count, exit code |
| `tests/smoke_test.gd` | passing example suite; four reusable assertion shapes |
| `tools/test.sh` | the standing suite runner |
| `tools/gallery_compare.py` | image-diff gate — copy verbatim, configure via JSON |
| `tools/check_links.py` | every relative Markdown link resolves — copy verbatim |
| `tools/check_section_refs.py` | every `CONSTRAINTS §N Title` reference is accurate |
| `tools/check_placeholders.py` | placeholder markers left in shipped documents |
| `tools/capture.sh` | windowed scene capture — the visual-proof tool, never in `test.sh` |
| `tools/collision_capture.sh` | windowed capture of a staged collision, driven through the shipped game — never in `test.sh` |
| `templates/` | skeletons for every suite type, game-specific parts marked |
| `../CONSTRAINTS.md` `../ROADMAP.md` `CLAUDE.md` | the governing documents |
| `../CONSTRAINTS.md` | the non-negotiables and how each is enforced |
| `docs/GLOSSARY.md` | one definition per term, linked from everywhere else |
| `openspec/` `.att/` | the planning and tracking layers, initialized |
| `GOTCHAS.md` | **read before debugging anything** |

The Python tools carry no game knowledge; everything project-specific lives in
their JSON config or is an unfilled placeholder in a document. They need only what
`requirements.txt` pins, and they run from `.venv` — never system Python, so the
versions gating a change are the recorded ones.

`tools/check_links.py` and `tools/check_section_refs.py` are worth taking
seriously despite being trivial: they catch a class of rot no diff review
reliably does. Both were written *after* a real break got through.

The tools under `tools/` were copied in from `godot-game-skeleton` rather than
referenced, so they are a fork from the moment they land here — and several have
since been adapted for this repository's layout, notably the checkers, which are
rooted at the repository root rather than at `godot/`. If you improve one, port
the change or accept the divergence knowingly.

---

## Read this before you debug anything

**[GOTCHAS.md](../GOTCHAS.md)** — symptom-first, every entry paid for once already.
Deferred autoload seeding, `class_name` invisible to `godot -s`, wall-clock
tweens hanging headless runs, a stray keypress burning 300 RNG draws, wiped save
files, why a seed cannot fix a non-deterministic call count, why a mean-only
image diff misses obvious regressions, and why a green suite after a test
refactor is not evidence.

---

## The rule that motivated all of this

> **If you verify something to sign off work, commit the method as a tool before
> calling the work done.**

Three audio-visual verification methods in the project this came from were used
to approve shipped work and then lost, because they ran in a shell session
instead of living in `tools/`. One had to have its parameters reverse-engineered
by grid-fitting against its own output. A number in a commit message is not a
verification — it is a memory of one.
