# Constraints and standards

The non-negotiables for the **Godot port** of Low Poly Cart.

[`low-poly-cart-game-design-document.md`](low-poly-cart-game-design-document.md)
says *what* the game is and is **normative**. This document says what the port
may be built with, how it must behave, and how each of those is enforced.
[`ROADMAP.md`](ROADMAP.md) says in what order.

A constraint that nothing checks is a preference. Every entry below carries its
enforcement status:

| | |
|---|---|
| ✅ | **Enforced** — an automated gate fails when this is violated |
| 📋 | **Planned** — agreed, not yet automated; the named milestone adds the gate |
| 📐 | **Convention** — human-enforced by review; not mechanically checkable |
| ⊘ | **Withdrawn** — decided against; the row records what replaced it |
| ⚠️ | **Partial** — something real is enforced, but not the whole criterion; the gap is named |
| ❓ | **Open** — deliberately undecided; the named change settles it |

---

## 1. Repository shape

This repository was created to hold a specification and no code. That property
is now deliberately relaxed, not lost:

```
  low-poly-cart-spec/
    low-poly-cart-game-design-document.md   the spec — normative, engine-agnostic
    assets/                                 the seven supplied models — SHARED, not the port's
    CONSTRAINTS.md   ROADMAP.md             this port's rules and order
    openspec/                               proposals, designs, delta specs, tasks
    godot/                                  ONE implementation of the spec
      project.godot  scripts/  scenes/  data/  tests/  tools/  docs/
```

**The models sit at the repository root, not inside `godot/`.** They are
referenced by the GDD's own §1 inventory and normalisation contract, so they
belong to the specification and to every port equally — a second port must not
have to reach into the first one's directory to find its art.

| | Status |
|---|---|
| **No engine, framework, or language name enters the GDD's normative sections.** Godot-specific facts live here or under `godot/`, never in the spec | 📐 |
| The spec is edited only when the *design* changes, never to match what the port happened to do | 📐 |
| `godot/tools/test.sh` runs the whole standing suite from a clean clone of the **repository** — it reads `../assets/`, `../CONSTRAINTS.md` and `../ROADMAP.md`, and needs `.venv` created first | ✅ verified from a simulated fresh clone |
| Multiple ports may coexist as sibling directories; none of them is privileged | 📐 |

**Why in-repo rather than a sibling repository.** The interesting question this
repo exists to ask — how much do two independent implementations of one spec
agree on, and where was the spec quietly ambiguous — only stays answerable while
the spec and the port share a commit history. A port in another repository
drifts from the spec it was built against and nobody sees the diff.

---

## 2. Tech stack

Settled choices. Changing one requires a proposal that names what broke.

| | | Status |
|---|---|---|
| **Engine** | Godot **4.6.1**, recorded in `godot/.godot-version` — the single source of truth. `config/features` carries only the `4.6` series, because Godot stores nothing finer there | ✅ `check_engine_version.py` |
| **Language** | **GDScript only.** No C#, no GDExtension, no native modules | 📐 — no compiled-language or extension file exists; not mechanically gated |
| **Renderer** | **Compatibility (WebGL 2 / GLES3)**, on every target including desktop | ✅ the pin is gated by `check_settings.py`. The *choice* is evidenced by `spike-compatibility-renderer-shadows` — see `godot/docs/progress/2026-08-28-renderer-spike.md`; no gate checks shadow quality |
| **Addons** | **None.** No third-party Godot addons in the shipped project | 📐 |
| **Physics engine** | **Not used.** No `PhysicsBody3D`, no `Area3D`, no collision shapes, no `move_and_slide` — see §4 *Architectural boundaries* | ✅ `check_boundaries.py`, every text file under `godot/` |
| **Python environment** | **`.venv` always. Never system Python.** Pinned by `godot/requirements.txt`; `test.sh` refuses to run without it | ✅ all three refusal paths verified |
| **Task tracking** | [`att`](https://github.com/ranton256/agent-task-tracker) — local-first CLI, backlog in `.att/`, committed | 📐 initialized; nothing gates its use |
| **Network** | **The game never opens a socket.** No telemetry, no analytics, no crash reporting, no asset streaming from a server | 📐 — no gate exists; no networking API is used anywhere today |
| **Runtime dependencies** | Nothing beyond the Godot export template and the game's own assets | 📐 |

**GDScript only is forced by the web target.** Godot's C# export to the web is
not dependable, and a language split between targets would mean the simulation —
the one part that must produce identical numbers everywhere — has two
implementations. One language, one simulation, every platform.

**Compatibility renderer everywhere is a look decision, not a web concession.**
The spec calls shadows "a load-bearing part of the look". Running Forward+ on
desktop and Compatibility on the web produces two different looks from one
specification and doubles the visual baseline set in §7 *Testing*. One renderer,
one set of baselines, one look — at the cost of desktop fidelity we are not
being asked for. **M0 spiked this, and the answer is yes — with two caveats worth carrying.**
At the specified 2048² map, Compatibility passes all five criteria: contact shadow
attached, soft edge, no acne (lit-ground std 0.14), no peter-panning, and shadowed
ground retaining 49% of open-ground luminance. Evidence and method are committed
at `godot/docs/progress/2026-08-28-renderer-spike.md`.

The caveats. First, the contact shadow only appears once `shadow_normal_bias` is
lowered from Godot's default of 2.0 — the design document specifies one bias and
Godot has two, and the default erases the cue the document calls primary
(ambiguity A8). Second, at the document's stated light intensities Compatibility
saturates 66.8% of the spike's probe scene against Forward+'s 0.05%. Both figures
are re-measured with `measure_exposure.py`, which counts every pixel; the spike's
own "67% / 0.0%" came from a region measure. The shadow verdict survives that; the
*exposure* question did not, and was settled by `add-world-presentation-layer`
(ambiguity A9, now resolved).

**Not tested: the web target itself.** Every capture is desktop Metal-backed
OpenGL. The platform that motivated this whole decision has never been rendered.
M8's export smoke tests are where that gets closed.

---

## 3. Language and style

| | Status |
|---|---|
| Static typing on every function signature **and member** | ⚠️ `check_static_typing.py` covers signatures — parameters and return types. **Members are not yet checked.** **Not** `gdlint`, which ships no typing rules at all |
| Tabs for indentation; Godot / `gdformat` defaults elsewhere | ✅ `gdformat --check` |
| `snake_case` files and functions, `PascalCase` node and class names | 📐 |
| Test and tool scripts **`preload` by path**, never rely on `class_name` | 📐 |
| No trailing whitespace; newline at end of file | ✅ pre-commit (staged files) |
| Every tuning constant is referred to **by the GDD's `name`**, never by its literal value, outside `godot/data/tuning.json` | ✅ `check_tuning_literals.py` for distinctive values in `godot/scripts/`; small integers excluded and reported |

**Why `preload` instead of `class_name`:** global class-name registrations live
in a cache the *editor* writes. A class added without opening the editor is
invisible to `godot --headless -s`, so every suite referencing it dies at parse
time — it works on the machine with a stale cache and fails on a fresh clone.

**Why constants by name.** The GDD's central discipline is that every number
lives in exactly one table row and scenarios refer to it by name. A literal
`0.96` in a script silently forks that contract. `godot/data/tuning.json` is the
single transcription of those tables, and it is the only file allowed to contain
the numbers.

---

## 4. Architectural boundaries

The load-bearing structure. These are the constraints most worth automating,
because violations are cheap to introduce and expensive to unwind.

```
   ┌──────────────────────────────────────────────────────────────┐
   │  godot/scenes/   the VIEW — draws state, never decides        │
   │    KartView · ChaseCam · Minimap · HUD · Countdown · Loading  │
   │    Ground · Grid · StartBand · Lights · Fog                   │
   └────────▲────────────────────────────────────┬────────────────┘
       reads│ snapshot + interpolation alpha     │ drains sim.events
            │                                    │ (shake, lap banked)
   ┌────────┴────────────────────────────────────▼────────────────┐
   │  godot/scripts/core/   the SIMULATION                         │
   │    no engine nodes · seeded · fixed step · pure               │
   │    tick · scatter · normalise · collide · lapgate · layout    │
   └───────────────────────────────────────────────────────────────┘

   godot/data/     tuning values only, no logic
   godot/tests/    headless, deterministic, display-free
```

### Core purity ✅ `check_boundaries.py`

Nothing under `godot/scripts/core/` may reference the scene tree, engine node
types, engine time, or engine randomness. Banned symbols:

```
Node  Node3D  Node2D  MeshInstance3D  Camera3D  Control  CanvasLayer
PackedScene  SubViewport  AudioStreamPlayer  Environment  DirectionalLight3D
get_tree  get_node  add_child  $  _ready  _process  _physics_process
Input.  Engine.  Time.  OS.  DisplayServer.  RenderingServer.
randi  randf  randomize  randi_range  randf_range
```

`Vector3`, `AABB`, `Transform3D`, and `Basis` are permitted — they are Variant
math types with no engine dependency — subject to §6 Determinism and the reference frame, "Numeric precision".

This is a grep, which is exactly why it should be a gate rather than a habit,
and the best time to land it is before `scripts/core/` has any of the game in it.

**Match whole words.** `rng.gd` defines `randf01()`, which contains the banned
substring `randf` — a naive grep flags the very file this constraint exists to
mandate. The same trap applies to `randi` inside the comments in `rng.gd` and
`sim.gd` that exist precisely to say not to use it. Anchor on word boundaries and
a following `(`, strip comments before matching, and verify the gate by breaking
it rather than by observing that it is quiet.

### The physics engine plays no part in this game ✅ `check_boundaries.py` (every text file under `godot/`) and the commit hook (staged)

The GDD's tick order is a scalar recurrence, not a dynamics simulation: no mass,
no impulse, no restitution, no solver. `CharacterBody3D.move_and_slide()` cannot
reproduce it and `RigidBody3D` is not close. Specifically:

- **Props are visuals plus an AABB record.** A prop is a `MeshInstance3D` in the
  view and a `{asset_id, position, yaw, scale, aabb}` row in the simulation's
  registry. It is never a `StaticBody3D` and never has a `CollisionShape3D`.
- **The kart is a `Node3D` with a mesh.** Not a body of any kind.
- **Collision is the GDD's own AABB test** — kart volume recomputed from current
  yaw, contracted by `hitboxContraction` per side, tested against every
  registered prop, first hit in registration order wins, push out `pushDistance`,
  velocity to exactly zero.
- **The boundary is a coordinate clamp**, not a wall, not an `Area3D`.

Banned **anywhere** under `godot/` — every text format that can name a type (`.gd`, `.tscn`, `.tres`, `.escn`, `.godot`, `.cfg`, `.import`); binary scenes are out of a text gate's reach:

```
RigidBody3D  StaticBody3D  CharacterBody3D  Area3D  CollisionShape3D
CollisionObject3D  move_and_slide  move_and_collide  PhysicsServer3D
```

### Registration order is observable behaviour 📐

Collision resolves *the first intersecting prop in registration order*. Prop
array order therefore changes what the game does, and:

- Scatter must append in a deterministic order for a given seed
- **Layout save/load must preserve registration order** — a reloaded track that
  collides differently from the one that was saved has failed acceptance item 12
  even if every prop is in the right place

The GDD's round-trip scenario does not state this. It is recorded in the
ambiguity register (§5 *Conformance to the specification*).

### Other boundaries 📐

- The view reads the simulation and never writes to it
- The view never contains a game rule, a tuning number, or a state transition
- `godot/data/` holds values, not logic
- One-shot effects (collision shake, lap banked, best beaten) are **published by
  the simulation as data** and drained by the view — never played from the core

---

## 5. Conformance to the specification

This port is **strict**: the GDD's Acceptance Checklist is the contract, its
tolerances are literal, and a deviation is a proposal rather than a judgment
call.

### The two coverage gates

| | Status |
|---|---|
| **G1** — Every `### Scenario:` in the GDD is claimed exactly once: by a named test, by the visual register with a stated reason, or by a deferral naming the milestone that owns it | ✅ `check_spec_coverage.py` |
| **G2** — Each of the 14 Acceptance Checklist items is one named conformance test carrying its stated tolerance as a literal | 📋 M8 |

The GDD has **14 features and 64 scenarios** — 62 `### Scenario:` headings and 2
`### Scenario Outline:`, which the gate treats alike. G1 extracts every heading and
requires each to be claimed **exactly once**: by a `# @covers` declaration beside a
test, or by an entry in `godot/data/scenario_register.json`. It fails for the reason
line coverage never does — a specified behaviour that nobody verified — and it fails
equally on a scenario claimed twice, or a claim on a scenario the document no longer
contains.

```
   64 scenarios, as claimed today — the gate reports these on every run
   ├── 13  verified by a named test
   │        the tick order, the boundary, the input state model, runtime
   │        tuning, and the normalisation contract
   ├──  5  visual — cannot be checked headlessly, each with a stated reason
   │        grass beyond the boundary · the loading indicator · minimap
   │        markers absent from the main view · viewport resize · the DPI cap
   └── the rest deferred, each naming the milestone that owns it
```

**The exact counts are deliberately not written here.** `check_spec_coverage.py`
prints them, per milestone, on every run — and a copy in this document is a second
source that drifts. It did: an earlier version of this section guessed
"~40 core, ~16 headless-scene, ~8 visual" before anything measured them, and the
version after that restated a per-milestone split that was already stale by the time
it was committed. Read the gate's output.

**A milestone cannot be called complete while it owns a deferred scenario.** That is
what the per-milestone count is for.

**What G1 cannot do.** Three things, and they are review's:

1. It cannot tell whether a verified claim's test really tests that scenario. Two
   claims were found overstating during this change's own review — a test asserting
   the turn rate was *constant* while claiming a scenario that also fixes its
   magnitude, and one asserting a speed stayed below a clamp when arithmetic
   guaranteed that whether the clamp existed or not.
2. It cannot tell whether a deferred scenario belongs to the milestone named. Four
   were parked wrongly in the same review.
3. **It counts a claim that never runs.** A `# @covers` line reads as coverage
   wherever it sits: on a function `_init()` no longer calls, in a file `test.sh`
   does not run, or in a helper with no test body at all.

It raises the floor from "nobody knows" to "every scenario has a named owner and a
named status" — no further.

Each of the 5 visual scenarios carries a written reason it cannot be checked
headlessly, and either the capture that covers it or the milestone that will produce
one — today all five name a milestone, because the captures do not exist yet. "Not
unit-testable" is a claim that must be written down, not an omission.

### Tolerances are normative

The GDD says so outright: *"where a criterion gives a tolerance, that tolerance
is normative — 'approximately' is not a defence."* Conformance tests assert the
stated bound, not a comfortable one. Widening a tolerance is a spec change.

### Known Deviations are not licence

The GDD lists eleven places where the reference build departs from the spec. The
port follows **the specification**, not the reference. In particular the port
must *not* reproduce: frame-rate dependence, the offset minimap heading arrow,
compounding layout scale, the extra one-second delay after GO!, the undirected
lap test, on-screen developer instrumentation, or the dead free-look hint.

Two documented behaviours the port **must** reproduce, because the spec keeps
them: the speedometer topping out at 115 rather than 120, and a kart that can be
pinned between two near-touching props with Reset Kart as the specified escape.

### The ambiguity register 📋 M8

`godot/docs/AMBIGUITIES.md` records every place the spec did not decide something
the port had to. This is a **deliverable**, not a complaint file — it is the
output the repository's README says the exercise exists to produce. Every entry
in `AMBIGUITIES.md` is mirrored here; that file carries the reasoning:

| # | Ambiguity | Port's decision |
|---|---|---|
| A1 | HUD sizes are in px (200×200 minimap, 160×90 speedo, ~120 px countdown) with no design resolution named | ❓ settled in M5, the milestone that builds the HUD |
| A2 | "A layout file … delivered to the player" — mechanism unspecified, and it differs between desktop and web | ❓ settled in M7 |
| A3 | Prop registration order after a layout reload — unstated, but it changes collision outcomes | ❓ settled in M7 |
| A4 | The countdown must advance while "the physics update is skipped entirely" outside RACING | Resolved: `Sim.step()` runs every tick in every state; the kart pipeline is gated on RACING |
| A5 | Whether the lap gate and minimap read the stepped position or the interpolated render position | Resolved: the stepped position. The view may lag it by up to one tick |
| A6 | The kart's "+90° yaw correction" is stated in the reference build's frame, not Godot's | Resolved: the *axis* is derived from the imported bounds; the *sign* comes from a committed capture, because bounds are symmetric and a 16-heading test passes on a 180° error. Never copied as a literal |
| A7 | The sun's orthographic shadow volume has no direct Godot equivalent | Resolved in `spike-compatibility-renderer-shadows` |
| A8 | Godot has two shadow bias parameters; the design document specifies one | Resolved in `spike-compatibility-renderer-shadows` |
| A9 | Light intensities are in the reference build's units, not Godot's — at face value Compatibility saturates 59.75% of the frame | Resolved: the ratios are normative, the scale is not. One shared factor `lightScale` = 0.2809, chosen as the value minimising the ground's deviation from its specified albedo; tonemapping stays linear |
| A10 | The camera eases **per tick** but the frame ordering updates it **per frame**; identical at 60 fps, different at every other rate | ❓ settled in M2 |
| A11 | The design document requires that no edge of the ground be visible, and specifies a ±100 wu plane, a ±90 drivable extent and fog from 50 wu — which make the edge visible from the boundary | ❓ settled in M6 |

---

## 6. Determinism and the reference frame

Determinism is not a testing nicety — it is what makes headless suites and
screenshot baselines possible at all, and here it is also **acceptance item 14**.
Treat a non-reproducible result as a defect in the code, never as a threshold to
relax.

### The fixed step

| Rule | Status |
|---|---|
| The simulation never reads frame `delta`; `Sim.step()` advances exactly one 1/60 s tick | 📋 M1 |
| `physics/common/physics_ticks_per_second = 60` | ✅ `check_settings.py` |
| `physics/common/physics_jitter_fix = 0` — the default 0.5 perturbs the physics delta and drifts the race clock against wall time | ✅ `check_settings.py` |
| Elapsed race time is **tick count ÷ 60**, never `Time.get_ticks_msec()`. `countdownStep` is 60 ticks | 📋 M1 |
| The view interpolates between the last two simulation states using `Engine.get_physics_interpolation_fraction()`, and never advances anything itself | 📐, 📋 M2 |
| All gameplay randomness comes from `godot/scripts/core/rng.gd` with an explicit seed | ⚠️ `check_boundaries.py` bans the engine RNG from the core; that a seed is actually supplied is not checked |
| The engine RNG may be used for **view cosmetics only**, precisely so it can never perturb the gameplay stream | 📐 |
| Identical seed and identical inputs produce identical state summaries | 📋 M1 |

**A seed cannot fix a non-deterministic call count.** If the *number* of random
draws depends on timing, seeding is not enough. Scatter draws candidates in a
fixed order and consumes exactly one draw per attempt, including rejected ones —
the attempt budget is part of the stream.

**Acceptance item 14 splits in two.** The claim "identical at 30, 60 and 144 fps"
cannot be proven through the engine's frame pacing, because
`max_physics_steps_per_frame` discards time debt under a hitch and would make the
test flaky for a reason that is not the simulation's fault. So:

- **14a, in the standing suite** — the harness calls `Sim.step()` 3600 times
  directly from three differently-constructed drivers and compares state
  summaries byte for byte. Deterministic, display-free, milliseconds.
- **14b, in the windowed gate** — the game is actually run at three refresh
  rates with a scripted input sequence and the ±0.5 wu / ±0.05 s bounds are
  asserted.

### Numeric precision

| Rule | Status |
|---|---|
| Velocity, yaw, and the elapsed clock are **`float` (64-bit) scalars** in the core | 📐 |
| `Vector3`/`AABB` (32-bit `real_t`) appear at the view boundary and in the AABB registry, never in the velocity recurrence | 📐 |

The spin-up curve settles at `accel × friction / (1 − friction)` = 0.192 wu/tick
and acceptance item 4 asserts three timings to ±0.05 s. Accumulating that
recurrence in `real_t` throws away precision the tolerance cannot spare.

### The reference frame

The GDD's world frame and Godot's world frame are both right-handed and Y-up, so
**positions map one to one** — the start band sits at Z = +5, the drivable extent
is ±90, nothing is mirrored or swapped. What differs is the *facing convention*:

```
   Spec forward          +Z          the kart spawns facing +Z
   Godot convention      -Z          look_at, Camera3D, most imported meshes

   With rotation.y = ψ, a Node3D's local +Z points at (sin ψ, 0, cos ψ)
   ⇒ the simulation's forward vector IS the node's +basis.z
   ⇒ increasing ψ turns left, CCW viewed from above — matching the spec exactly
```

| Rule | Status |
|---|---|
| The simulation is expressed in the **spec's frame**, verbatim. No conversion layer, no transposed axes | 📐 |
| Simulation forward is `+basis.z`. Any π offset needed to point a mesh or a camera the Godot way lives in the **view**, in one named constant | 📐 |
| The kart's authored yaw correction is **derived from the imported bounds and pinned by a test**, never transcribed from the spec's "+90°" — that figure is stated in the reference build's frame | 📋 M2 |

The AABB math confirms the mapping is right: at yaw 0 the kart's world extent is
2.20 on X and 2.36 on Z, and contracting by `hitboxContraction` per side gives
1.80 × 1.96 wu — exactly the contracted hitbox the GDD's collision feature cites.

---

## 7. Testing

| | Status |
|---|---|
| `godot/tools/test.sh` green before any change is considered done | ✅ |
| The standing suite is **headless and display-free** | ✅ verified with no display available |
| No test touches the network or a real save file | ⚠️ `LPC_SAVE_FILE` is exported by every harness, but **nothing reads it yet** — there is no save system until M7. The network half has no check at all |
| Every suite is deterministic; a flaky test is a defect in the test | 📐 |
| Visual checks live in a separate windowed gate, never in `test.sh` | 📐 by construction |
| ~~Test names encode the GDD scenario they cover~~ — **withdrawn**. G1 matches an explicit `# @covers` declaration beside the test instead: GDScript identifiers cannot carry the document's punctuation, and coupling a test's name to a heading means rewording the heading breaks the name. See `add-determinism-and-coverage-harness` design D1 | ⊘ withdrawn |

**Coverage** is G1 and G2 in §5 *Conformance to the specification*, not a
percentage. GDScript has no mature line-coverage tooling and a percentage would
be a poor proxy for "every specified behaviour is verified" anyway.

**Mutation checking** 📐. A green suite after a harness change is not evidence: a
`check()` accidentally turned into a no-op leaves everything green and verifies
nothing. Whenever the harness itself changes, deliberately break what each gate
guards and confirm the right gate fails with the right message.

**Image diffs use three criteria, never a mean alone** 📋 M6. A whole-frame mean
dilutes local change — a band over 3% of the screen shifted by 40/255 is obvious
to a reviewer and averages to ~0.4, slipping under a 0.5 threshold. Gate on mean,
percentage of pixels changed, and percentage changed strongly.

**Thresholds are measured, never guessed** 📐. Capture twice with nothing changed
and diff; that is the noise floor. Set the limit a small multiple above it and
record the measurement beside the number. If the floor is not near zero, the
harness is non-deterministic — fix it rather than raising the threshold.

---

## 8. Performance and size budgets

**Reference machine.** Apple M3 Ultra, 96 GB RAM, macOS 26.6. Every time-based
figure below is measured there and re-measured when it changes.

### Hard constraints — must hold on any target

| | Budget | Status |
|---|---|---|
| Frame budget while racing | 16.7 ms (60 fps) on the reference machine | 📋 M6 |
| Simulation step cost | The full 8-step tick over 54 registered props runs well inside one 60 Hz slice at 144 fps, i.e. ≤ 2.3 ms for 2–3 steps | 📋 M6 |
| Input to visible response | One simulation tick. Never gated on a render frame | 📐 |

### Web target — the binding constraint

The supplied asset set is **39 MB of raw `.glb`** across seven models carrying
21 textures at 2048². That is an unremarkable desktop load and a hostile web one.

| | Budget | Status |
|---|---|---|
| Total web payload, compressed | ≤ 25 MB | 📋 M6 |
| Prop textures | Downsampled to **1024²**, which the GDD explicitly permits and calls "visually near-identical at gameplay distances" | 📋 M3 |
| Kart textures | **2048² retained** — the GDD names the kart as the one asset not to reduce | 📐 |
| Texture compression | VRAM-compressed on import, not raw | 📋 M3 — `check_settings.py` asserts the presets exist and are well-formed, not their compression mode. Tracked as `att` 5 |
| Cold load → countdown begins, web, on a warm cache | ≤ 5 s | 📋 M6 |

### Design targets — measured on the reference machine

| | Target | Status |
|---|---|---|
| Cold start → countdown begins, desktop | ≤ 2 s | 📋 M6 |
| `godot/tools/test.sh` wall time | ≤ 60 s. **Measured 8.4 s warm** (3 runs, 8.42–8.45 s) and **10.9 s cold**, on a first import with no `.godot/`. Re-measure whenever a check is added — an earlier 1.32 s figure was taken before the asset import and three checkers existed and was left stale | 📐 |

The suite budget is a real constraint, not a nicety: a gate slow enough to skip
stops being run, and a gate that is not run is not a gate.

> **If any budget is enforced at runtime, prefer a machine-independent bound.**
> A wall-clock budget makes results differ between machines and destroys
> reproducibility. Count work done — steps, nodes, iterations — not milliseconds.

---

## 9. Assets

The seven supplied models are **provided and committed separately by the
repository owner**. No change proposal, task, or tool in this project copies,
generates, regenerates, or commits a `.glb` file.

| | Status |
|---|---|
| Assets live at **`assets/` in the repository root**, shared by every port, and are referenced by the GDD's §1 inventory | ✅ committed |
| `godot/tools/sync_assets.sh` copies the models into `godot/assets/` by content hash, and runs at the front of the standing suite | ✅ |
| The copied `.glb` files and the textures Godot extracts from them are git-ignored; only `godot/assets/*.glb.import` is committed | ✅ `.gitignore` |
| The normalisation contract (GDD §3) is implemented in **`scripts/core/`** and unit-tested against synthetic bounding boxes, with no `.glb` present | ✅ `normalise_test.gd` |
| Bounding boxes are **re-measured after scaling**, never reused from before it | ✅ `normalise_test.gd` — an adversarial box on which the two orderings differ by 3.0 wu, verified by mutation |
| The model import contract lives in the committed `godot/assets/*.glb.import` presets; `sync_assets.sh` refuses a preset recording a failed import, which Godot never repairs | ✅ |
| Anisotropic filtering 16×, mipmaps, VRAM compression, and per-asset texture size are set project-wide, not per generated texture file | 📋 M3 (web budget), M6 (filtering) |
| Every supplied model both casts and receives shadows | 📋 M6 |
| Materials are physically-based and lit. No unlit or flat substitute | 📐 |
| No prop is authored in the scene tree; every instance is placed by the simulation's scatter or by a loaded layout | 📐 |

**Reaching assets outside the project root is a copy, not a symlink.** Godot
will not import a file above `godot/`, so `godot/tools/sync_assets.sh` copies the
seven models in and the standing suite runs it first. A symlink at `godot/assets`
is the usual answer and was rejected: git materialises symlinks on Windows only
with `core.symlinks=true` *and* Developer Mode, and without both, a checkout
produces a text file containing a path and the project silently has no art.
Windows is a shipping target. The script compares content hashes rather than
timestamps, because a checkout, a rebase, and `touch` all move mtimes without
changing bytes.

**Only `*.glb.import` is committed.** Godot's glTF importer extracts each model's
textures as sibling files, and those extractions plus their own `.import` presets
are derived data. Committing a preset without the image it describes makes a
fresh clone reference sources that do not exist yet — measured at ~40 load errors
on first import before this was corrected. Per-texture settings for the web
payload budget in §8 *Performance and size budgets* are therefore a project-level
or re-import decision in M3, not twenty-one generated files.

**Import settings are a gate because a re-import silently reverts them.** The
anisotropy requirement in particular is invisible until someone drives past a
cone at a grazing angle, which is exactly the situation the visual gate exists
for and the standing suite cannot see.

**Placing the normalisation contract in the core is what unblocks M1.** It is
pure arithmetic on a bounding box, a target height, and a scale factor — it needs
no mesh to be written or tested, so the milestone that proves it does not wait on
the milestone that supplies the art.

---

## 10. Verification criteria

Deterministic acceptance conditions — the checks a reviewer, human or automated,
runs to decide whether a change is done. Each is pass/fail with no judgment.

| # | Condition | Status |
|---|---|---|
| V1 | `godot/tools/test.sh` exits 0 | ✅ |
| V2 | Two runs at the same seed produce byte-identical state summaries | ✅ `determinism_test.gd` over 3000 ticks of scripted input against the real simulation, plus the smoke suite |
| V3 | No banned symbol from §4 *Architectural boundaries* appears under `godot/scripts/core/` | ✅ `check_boundaries.py` |
| V4 | No physics-body symbol from §4 *Architectural boundaries* appears anywhere under `godot/` | ✅ `check_boundaries.py` over every text file under `godot/`, plus the commit hook on staged content. Binary scenes (`.scn`, `.res`) are beyond a text gate; the project authors none |
| V5 | No **distinctive** tuning value appears as a literal in `godot/scripts/` | ✅ `check_tuning_literals.py`. Small integers are excluded and reported each run — see §3 *Language and style* |
| V6 | **G1** — every `### Scenario:` in the GDD is claimed exactly once, and a claim on a scenario the document does not contain also fails | ✅ `check_spec_coverage.py` |
| V7 | **G2** — every Acceptance Checklist item has a named conformance test asserting its literal tolerance | 📋 M8 |
| V8 | Pinned project settings match §6 *Determinism and the reference frame*, and every model has a valid committed import preset | ✅ `check_settings.py` |
| V9 | Gallery diffs are within recorded thresholds on all three criteria | 📋 M6 |
| V10 | Every relative link in every Markdown file resolves | ✅ `check_links.py`, rooted at the repository root |
| V11 | Every `CONSTRAINTS §N Title` reference names the section it points at | ✅ `check_section_refs.py`. Note it matches only `CONSTRAINTS §N`, so `docs/CONSTRAINTS.md §N` is invisible to it — stale prose stays the Critic's job |
| V12 | `openspec validate <change> --strict` passes | ✅ |
| V13 | The change's `tasks.md` has no unchecked box | 📋 via `/opsx:apply` |
| V14 | A milestone has committed visual proof in `godot/docs/progress/`; a task changing what the player sees has a capture or a stated reason it would show nothing | 📐 |
| V15 | Every ambiguity discovered during the change is in `godot/docs/AMBIGUITIES.md` before the change is archived | 📐 |
| V16 | `godot/data/tuning.json` matches the design document's constant tables — every named constant present, none renamed, no derived values | ✅ `check_tuning_transcription.py` |
| V17 | No placeholder marker remains in a shipped document | ✅ `check_placeholders.py --strict` |
| V18 | Every governing document states the same engine version as `godot/.godot-version` | ✅ `check_engine_version.py` |
| V19 | Every GDScript function signature carries parameter and return types | ⚠️ `check_static_typing.py`; members not yet covered |
| V20 | The seven supplied models import and load | ✅ `tests/assets_test.gd` |
| V21 | The commit hook and the standing suite derive their banned symbols from one shared definition | ✅ both read `godot/data/banned_symbols.json`; verified by removing a symbol and confirming both stop flagging it |
| V22 | The rendered environment satisfies the exposure criteria: nothing saturated, the unlit sky exact, the ground at its specified albedo | 📐 `measure_exposure.py`, windowed — it needs a renderer, so it cannot join `test.sh`. Run it against a committed capture |
| V23 | The design document's specified colours are not written as literals in scripts | ✅ `check_tuning_literals.py` scans quoted hex strings as a separate pass; the numeric pass cannot see them, because it cuts each line at the first `#` |

---

## 11. Work tracking

Three layers, each owning something the others do not. Duplicating between them
is the failure mode to avoid.

```
   ROADMAP.md          milestones — where we are going, and in what order
        │
        ▼
   openspec/changes/   one unit of work: why, design, specs, tasks
        │
        ▼
   .att/  (att)        the backlog — future work, issues found, deferred items
```

| Layer | Owns | Lifetime |
|---|---|---|
| `ROADMAP.md` | Milestones and their order | Long-lived; revised deliberately |
| `openspec/changes/<name>/` | A single change: proposal, design, specs, tasks | Until archived |
| `.att/` via `att` | Detailed tasks outside any active change | Long-lived |

**The boundary that matters.** A change's `tasks.md` is the execution checklist
for *that accepted change* — worked through by `/opsx:apply` and archived with
it. `att` holds everything else: work discovered but not yet proposed, issues
found in passing, scope deliberately deferred.

- Do **not** mirror `tasks.md` into `att`. One work item, one home.
- Do **not** use `att` as a second planning system.

**Nothing leaves scope untracked** 📐. Every item deferred out of a change gets
an `att` task before that change is archived.

**Delta specs describe the port, not the game.** The GDD already specifies the
game. A change's `specs/` say what *this implementation* must do that the GDD
does not settle — the tick source for the countdown, the layout file's delivery
mechanism, the derived yaw constant. Restating GDD scenarios into delta specs
creates a second normative document, which is the one outcome this repository
exists to avoid.

---

## 12. Review

Every gate in this document is mechanical. Review is what catches the things no
grep can: work that passes its tests and still does not do what was specified.

| Role | Does |
|---|---|
| **Writer** | Produces the work — code, specs, documents |
| **Critic** | Reviews it adversarially, against the specification rather than against taste |

**The Writer never approves their own work.** This is the rule most likely to be
skipped when a change looks obviously fine, which is exactly when a second pass
is cheapest and most often finds something.

### When review is mandatory

- Every `att` task, before `att done`
- Every change, before `/opsx:archive`
- Every milestone, before it is called complete
- Any change to the test harness itself — see the mutation requirement in §7 *Testing*

### What the Critic checks

Work is marked **REJECTED** if any of the following holds:

| | Rejection criterion |
|---|---|
| R1 | `godot/tools/test.sh` is not green |
| R2 | A GDD scenario in scope has no test and no visual-register entry |
| R3 | The work does not match its specification — the GDD for behaviour, the change's `specs/` for port decisions, `ROADMAP.md` for a milestone |
| R4 | Any constraint in this document is violated |
| R5 | A tolerance was widened rather than met |
| R6 | An ambiguity was resolved in code without being recorded in `AMBIGUITIES.md` |
| R7 | Documentation has drifted |
| R8 | Visual proof is missing where it is required |

The verdict is explicit: **[APPROVED]** or **[REJECTED]** with findings. Silence
is not approval, and "looks good" is not a verdict.

### Visual proof

A green suite proves behaviour. It says nothing about whether the kart's shadow
lands under the kart, whether the fog reads, or whether the needle sweeps.
Different failures, different evidence.

| When | Requirement |
|---|---|
| Completing a **milestone** | **Mandatory.** A committed capture showing what it delivered |
| A task changing **what the player sees or how the game plays** | **Expected**, unless there is a stated reason a capture would show nothing |
| Anything else | Not required |

Captures come from `godot/tools/capture.sh`, never from dragging a window — a
screenshot that cannot be re-run is a memory of a verification, not one.
Committed proof lives in `godot/docs/progress/`.

**Windowed, never in `test.sh`.** Godot's headless mode has no renderer and
returns no image. The moment a capture enters the standing suite, that suite
stops running over SSH and needs a virtual framebuffer.

**Captures must be deterministic.** Wait a fixed frame count rather than a
duration, and seed the world explicitly. Every capture of a scattered field names
its seed.

### Documentation drift is a review finding

| Changed | Must change in the same commit |
|---|---|
| Game behaviour as designed | The **GDD** — by proposal, deliberately |
| A port decision | The change's `specs/` |
| A gate or constraint | This document, with its enforcement status |
| A milestone or its exit criteria | `ROADMAP.md` |
| A spec question the port had to answer | `godot/docs/AMBIGUITIES.md` |

---

## 13. Automation and gates

Inherited from `godot-game-skeleton` at M0:

```
tools/test.sh                the standing gate — headless, run on every change
tools/check_links.py         every relative Markdown link resolves (V10)
tools/check_section_refs.py  every "CONSTRAINTS §N Title" reference is accurate (V11)
tools/capture.sh             windowed scene capture — visual proof (V14). NOT in test.sh
tools/check_placeholders.py  placeholder markers left in shipped documents
openspec validate --strict   planning artifacts are well-formed (V12)
```

The skeleton expects `docs/CONSTRAINTS.md` and a project root that is also the
Godot root. Here the two documents live at the repository root and the Godot
project lives under `godot/` — **M0 adjusts the checkers' paths**. Left
unadjusted they pass by finding nothing, which is the worst failure mode a gate
has.

Added by this project, in order of value:

| Gate | Mechanism | Milestone |
|---|---|---|
| Scenario coverage G1 (V6) | `tools/check_spec_coverage.py` parses the GDD | M1 |
| GDScript lint and format | `gdtoolkit` — `gdlint`, `gdformat --check` | M0 |
| Whitespace, EOF newline, large files | the hand-rolled `godot/tools/pre-commit` — not the `pre-commit` framework, which this project does not use | ✅ M0 |
| Visual gate (V9) | `tools/gallery.sh` + `gallery_compare.py` — windowed | M6 |
| Acceptance conformance G2 (V7) | `tests/conformance_test.gd`, 14 named cases | M8 |
| Commit-time gate | `godot/tools/pre-commit`, installed by `tools/install-hooks.sh`. Checks the **staged blobs**, not the working tree, and is portable to bash 3.2 | ✅ M0 |
| Asset sync and import | `godot/tools/sync_assets.sh` + `godot/tests/assets_test.gd` — content-hash sync, poisoned-preset refusal, and a load assertion (`--import` exits 0 even on failure, so it cannot be the gate) | ✅ M0 |
| Tuning transcription | `godot/tools/check_tuning_transcription.py` — names, values, duplicates, derived-value leakage | ✅ M0 |
| Engine version | `godot/tools/check_engine_version.py` — every governing document agrees with `.godot-version` | ✅ M0 |
| Static typing | `godot/tools/check_static_typing.py` — signatures only; members not yet covered | ⚠️ M0 |
| Architectural boundaries | `godot/tools/check_boundaries.py` — core purity and the physics ban, from `godot/data/banned_symbols.json`, which the commit hook reads too | ✅ M0 |
| Tuning literals | `godot/tools/check_tuning_literals.py` — distinctive values in `godot/scripts/`, with a justified-exemption allowlist that fails on stale entries | ✅ M0 |
| Pinned settings | `godot/tools/check_settings.py` — determinism-critical settings and the seven import presets | ✅ M0 |

**Reference sections by number *and* title** — `CONSTRAINTS §8 Performance and
size budgets`, never a bare `§8`. A bare number survives a renumber while
silently pointing at a different section, and no link checker can see it because
the file still resolves.

**Keep the pre-commit hook fast.** It runs on every commit, and a slow hook gets
bypassed with `--no-verify`, which is worse than no hook. Lint, formatting,
whitespace, and the boundary greps belong there; the full suite belongs in
`test.sh`. Measured at **0.4 s** on a clean staged set (M0).

**The hook is not the gate.** It sees only staged files and only the cheap
checks — it will not catch a broken smoke suite, a stale link, or a drifted
tuning table. `godot/tools/test.sh` decides whether work is done, and with no
continuous integration nothing runs it automatically. That enforcement is
§12 *Review* criterion R1, carried by a person rather than a machine.

---

## 14. Release and packaging

**Targets.** macOS (Apple Silicon), Windows, Linux, and Web — all from one
commit, one language, and one renderer.

**Versioning.** `godot/project.godot` `config/version` is the source of truth;
annotated tags match it.

**Phases.** A release advances only when the prior phase passes.

```
  0  gate        test.sh green · visual gate green · G1 and G2 green · no unchecked tasks
  1  export      all four targets built from the same commit
  2  smoke       each artifact launched on its own OS: boots to countdown, drives,
                 banks a lap, exits clean. The web build tested on a cold cache
  3  sign        macOS codesign + notarize + staple
  4  tag         annotated tag, release notes, ambiguity register published
```

**macOS signing is a hazard, not a formality.** Anything bundled beside the game
binary must be signed with the same certificate under the hardened runtime, or
Gatekeeper kills it at launch — and it fails only on a *clean* machine, never on
the one that built it. Validate on a machine that has never seen the certificate.

**The web build is smoke-tested on a cold cache.** A warm-cache test measures
nothing: the 39 MB asset payload in §8 *Performance and size budgets* is the
whole risk, and it is invisible on the second load.

---

## 15. Not applicable

Absent by decision, not by oversight:

- **Continuous integration.** No hosted CI, no GitHub Actions. A committed
  pre-commit hook runs the cheap checks on staged files, and `godot/tools/test.sh`
  is run by hand and enforced by review. A workflow was built during M0 and
  deliberately removed: for a single-developer project it is a second environment
  to keep in step with `requirements.txt` and the pinned Godot version, buying
  enforcement the hook and the habit already provide. The cost is stated in
  §13 *Automation and gates* rather than hidden.
- **Networking of any kind** — no multiplayer, no leaderboards, no telemetry, no
  crash reporting, no analytics. §2 *Tech stack* makes this checkable.
- **Accounts, auth, API contracts, SLAs, database schemas** — there is no server.
- **Persistent storage.** The best time is explicitly session-only in the GDD;
  `track_layout.json` is player-initiated file export, not a save system. Durable
  best times are an Optional Feature and stay unimplemented.
- **Audio.** Engine and impact sound is Optional Feature 1 and stays
  unimplemented. No `AudioStreamPlayer` in the shipped project.
- **2D sprite tooling.** The inherited skeleton shipped a sprite palette
  auditor with envelopes from a different game. This is a 3D project with no
  sprites; it was deleted rather than carried as decoration.
- **Particles, boost, drifting, checkpoints, ghost replay, time-of-day, an
  end-of-session flow, kart customisation** — Optional Features 2–10. The GDD is
  explicit that these "should not be implemented until if and when they are
  specifically requested."
- **A menu, a pause state, a settings screen, a fail state, an end condition.**
  The session shape is load → countdown → drive forever.
- **A fourth game state.** The spec defines three.
- **Free-look, orbit camera, or any mouse control.** The reference build's dead
  affordance is a listed deviation.
- **On-screen developer instrumentation in the shipped build.** The port may
  build whatever tuning surface it likes; none of it is player-facing, and the
  reference grid is *not* instrumentation — it is part of the intended look.

---

## 16. Changing this document

These constraints are meant to outlive the arguments that produced them, and to
be changed deliberately rather than eroded quietly.

Amend by proposal. A change that relaxes a constraint names what it costs and
what evidence justifies it. A change that adds one names the gate that will
enforce it — a constraint added without a gate is a preference with formatting.

**The GDD is amended by its own proposal, separately.** Changing this document
never changes the game; changing the game never happens here.

**Related:** [`low-poly-cart-game-design-document.md`](low-poly-cart-game-design-document.md) ·
[`ROADMAP.md`](ROADMAP.md) · [`README.md`](README.md) ·
[`openspec/config.yaml`](openspec/config.yaml)
