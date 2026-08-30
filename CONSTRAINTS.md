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

```
  low-poly-cart-spec/
    low-poly-cart-game-design-document.md   the spec — normative, engine-agnostic
    assets/                                 the seven supplied models — SHARED, not the port's
    CONSTRAINTS.md   ROADMAP.md             this port's rules and order
    openspec/                               proposals, designs, delta specs, tasks
    godot/                                  ONE implementation of the spec
      project.godot  scripts/  scenes/  data/  tests/  tools/  docs/
```

The models sit at the repository root because the GDD's §1 inventory references
them; they belong to every port equally. The port lives in-repo so the spec and
its implementations share one commit history — the drift between them is the
thing this repository exists to observe.

| | Status |
|---|---|
| **No engine, framework, or language name enters the GDD's normative sections.** Godot-specific facts live here or under `godot/`, never in the spec | 📐 |
| The spec is edited only when the *design* changes, never to match what the port happened to do | 📐 |
| `godot/tools/test.sh` runs the whole standing suite from a clean clone of the **repository** — it reads `../assets/`, `../CONSTRAINTS.md` and `../ROADMAP.md`, and needs `.venv` created first | ✅ verified from a simulated fresh clone |
| Multiple ports may coexist as sibling directories; none of them is privileged | 📐 |

---

## 2. Tech stack

Settled choices. Changing one requires a proposal that names what broke.

| | | Status |
|---|---|---|
| **Engine** | Godot **4.6.1**, recorded in `godot/.godot-version` — the single source of truth. `config/features` carries only the `4.6` series | ✅ `check_engine_version.py` |
| **Language** | **GDScript only.** No C#, no GDExtension, no native modules — the web target forces one language, so the one simulation that must produce identical numbers everywhere has one implementation | 📐 |
| **Renderer** | **Compatibility (WebGL 2 / GLES3)**, on every target — one renderer, one baseline set, one look. Spiked in M0: passes all five shadow criteria at the specified 2048² map, provided `shadow_normal_bias` is lowered from Godot's 2.0 default (A8); light intensities need the A9 scale factor. Evidence: `godot/docs/progress/2026-08-28-renderer-spike.md`. The web target itself is untested until M8's export smoke | ✅ pin gated by `check_settings.py` |
| **Addons** | **None.** No third-party Godot addons in the shipped project | 📐 |
| **Physics engine** | **Not used.** No `PhysicsBody3D`, no `Area3D`, no collision shapes, no `move_and_slide` — see §4 *Architectural boundaries* | ✅ `check_boundaries.py`, every text file under `godot/` |
| **Python environment** | **`.venv` always. Never system Python.** Pinned by `godot/requirements.txt`; `test.sh` refuses to run without it | ✅ all three refusal paths verified |
| **Work tracking** | Two layers: `ROADMAP.md` (milestones + backlog) and a change's `tasks.md` — see §11 *Work tracking*. (`att` was a third layer; retired by `streamline-process`) | 📐 |
| **Network** | **The game never opens a socket.** No telemetry, no analytics, no crash reporting, no asset streaming | 📐 |
| **Runtime dependencies** | Nothing beyond the Godot export template and the game's own assets | 📐 |

---

## 3. Language and style

| | Status |
|---|---|
| Static typing on every function signature **and member** | ⚠️ `check_static_typing.py` covers signatures — parameters and return types. **Members are not yet checked** (backlog). **Not** `gdlint`, which ships no typing rules |
| Tabs for indentation; Godot / `gdformat` defaults elsewhere | ✅ `gdformat --check` |
| `snake_case` files and functions, `PascalCase` node and class names | 📐 |
| Test and tool scripts **`preload` by path**, never rely on `class_name` — the class-name cache is written by the *editor*, so an unopened clone fails at parse time under `godot --headless -s` | 📐 |
| No trailing whitespace; newline at end of file | ✅ pre-commit (staged files) |
| Every tuning constant is referred to **by the GDD's `name`**, never by its literal value, outside `godot/data/tuning.json` — that file is the single transcription of the GDD's constant tables | ✅ `check_tuning_literals.py` for distinctive values in `godot/scripts/`; small integers excluded and reported |

---

## 4. Architectural boundaries

The load-bearing structure — cheap to violate, expensive to unwind, so gated.

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

`Vector3`, `AABB`, `Transform3D`, and `Basis` are permitted — Variant math types
with no engine dependency — subject to §6 *Determinism and the reference frame*,
"Numeric precision".

The gate matches **whole words** (anchored, comment-stripped): `rng.gd`'s own
`randf01()` contains the banned substring `randf`, and a naive grep flags the
very file the constraint mandates. Verify the gate by breaking it.

### The physics engine plays no part in this game ✅ `check_boundaries.py` (every text file under `godot/`) and the commit hook (staged)

The GDD's tick order is a scalar recurrence, not a dynamics simulation.
`move_and_slide()` cannot reproduce it and `RigidBody3D` is not close.

- **Props are visuals plus an AABB record** — a `MeshInstance3D` in the view and
  a `{asset_id, position, yaw, scale, aabb}` row in the simulation's registry.
  Never a `StaticBody3D`, never a `CollisionShape3D`.
- **The kart is a `Node3D` with a mesh.** Not a body of any kind.
- **Collision is the GDD's own AABB test** — kart volume recomputed from current
  yaw, contracted by `hitboxContraction` per side, first intersecting prop in
  registration order wins, push out `pushDistance`, velocity to exactly zero.
- **The boundary is a coordinate clamp**, not a wall, not an `Area3D`.

Banned **anywhere** under `godot/` — every text format that can name a type
(`.gd`, `.tscn`, `.tres`, `.escn`, `.godot`, `.cfg`, `.import`):

```
RigidBody3D  StaticBody3D  CharacterBody3D  Area3D  CollisionShape3D
CollisionObject3D  move_and_slide  move_and_collide  PhysicsServer3D
```

### Registration order is observable behaviour 📐

Collision resolves *the first intersecting prop in registration order*, so prop
array order changes what the game does:

- Scatter must append in a deterministic order for a given seed —
  `scripts/core/scatter.gd` emits **asset by asset in the GDD's own table
  order** (`tree`, `rock`, `cone`, `crate`, `tires`, `cottage`), and within an
  asset in acceptance order; `scripts/world/prop_field.gd` preserves it. The
  GDD gives a table, not an ordering rule; this is the rule, recorded here
  because it is a contract *between* changes.
- **Layout save/load must preserve registration order** — a reloaded track that
  collides differently has failed acceptance item 12 even with every prop in
  the right place. (Ambiguity A3.)

### Other boundaries 📐

- The view reads the simulation and never writes to it
- The view never contains a game rule, a tuning number, or a state transition
- `godot/data/` holds values, not logic
- One-shot effects (collision shake, lap banked, best beaten) are **published by
  the simulation as data** and drained by the view — never played from the core

### One collision per tick, and the pin it produces 📐

At most **one** collision is resolved per tick — the first intersecting prop in
registration order — however many props the kart overlaps. Consequence, which
the GDD states and the port reproduces: two cottages at `minPropSeparation`
leave a 0.09 wu gap against the 1.80 × 1.96 wu contracted hitbox; a kart
between them is held with velocity zeroed. **Do not "fix" this by resolving
more than one collision per tick** — the GDD names placement as the remedy, and
`godot/tests/collision_test.gd` asserts the pin (the multi-resolve "fix" fails
it). **Reset Kart is the specified escape** (M7, backlog).

Driving it revealed the pin is a **transient** — the radial push makes the
centred state an unstable equilibrium, ejection in 15–125 ticks depending on
heading — which contradicts the GDD's "cannot drive out". That is a defect in
the design document, raised by GDD proposal: ambiguity **A12**, open.
Measurements: `godot/docs/progress/2026-08-29-m3-collision.md`.

### `scripts/core/` holds one piece of cosmetic state, deliberately 📐

The chase camera lives in `scripts/core/chase_camera.gd`. The rule this
directory enforces is **fixed-step and engine-free**, not **gameplay only** —
the camera is a per-tick recurrence with no engine types, and this is the only
directory the boundary gate polices, which is why it is here. Nothing else
cosmetic follows: the HUD, minimap, and collision shake are per-frame
presentation and belong to the view. If one of them asks for this directory,
the answer is no and the camera stops being a precedent. (Decided in
`add-chase-camera` design D1.)

## 5. Conformance to the specification

This port is **strict**: the GDD's Acceptance Checklist is the contract, its
tolerances are literal, and a deviation is a proposal rather than a judgment
call.

### The two coverage gates

| | Status |
|---|---|
| **G1** — Every `### Scenario:` in the GDD is claimed exactly once: by a named test (`# @covers`), by the visual register with a stated reason, or by a deferral naming the milestone that owns it | ✅ `check_spec_coverage.py` |
| **G2** — Each of the 14 Acceptance Checklist items is one named conformance test carrying its stated tolerance as a literal | 📋 M8 |

```
   every scenario in the design document — the gate counts them on every run
   ├── verified by a named test, claimed by a "# @covers" line beside it
   ├── visual — cannot be checked headlessly, each with a stated reason and
   │        the committed capture or the milestone that will produce one
   ├── UNMET — specified, reachable, and not currently met; printed every run
   └── deferred, each naming the milestone that owns it
```

**The exact counts are deliberately not written here** — the gate prints them
per milestone on every run, and a copy in this document went stale three times
before this rule was adopted. Read the gate's output.

**A milestone cannot be called complete while it owns a deferred scenario.**

**What G1 cannot do** — three things, and they are review's: it cannot tell
whether a claim's test really tests that scenario; it cannot tell whether a
deferral names the right milestone; and it counts a claim that never runs (a
`# @covers` line in a function nothing calls). It raises the floor from "nobody
knows" to "every scenario has a named owner and status" — no further.

### Tolerances are normative

The GDD says so outright: *"where a criterion gives a tolerance, that tolerance
is normative — 'approximately' is not a defence."* Conformance tests assert the
stated bound. Widening a tolerance is a spec change.

### Known Deviations are not licence

The GDD lists eleven places the reference build departs from the spec. The port
follows **the specification**: it must *not* reproduce frame-rate dependence,
the offset minimap arrow, compounding layout scale, the post-GO! delay, the
undirected lap test, on-screen instrumentation, or the dead free-look hint. It
**must** reproduce the two deviations the spec keeps: the speedometer topping
out at 115, and the two-prop pin (see §4 and ambiguity A12).

### The ambiguity register 📋 M8

`godot/docs/AMBIGUITIES.md` records every place the spec did not decide
something the port had to. It is a **deliverable** — the output the README says
this exercise exists to produce. Every entry is mirrored here; that file
carries the reasoning:

| # | Ambiguity | Port's decision |
|---|---|---|
| A1 | HUD sizes are in px with no design resolution named | Resolved in M5: px are literal at the 1280×720 design viewport; `canvas_items` stretch scales other sizes |
| A2 | Layout file delivery mechanism unspecified; differs desktop/web | ❓ settled in M7 |
| A3 | Prop registration order after a layout reload — unstated, but it changes collision outcomes | ❓ settled in M7 |
| A4 | The countdown must advance while "the physics update is skipped entirely" | Resolved: `Sim.step()` runs every tick in every state; the kart pipeline is gated on RACING |
| A5 | Whether the lap gate and minimap read the stepped or interpolated position | Resolved: the stepped position; the view may lag it by up to one tick |
| A6 | The kart's "+90° yaw correction" is stated in the reference build's frame | Resolved in M2: derived from the imported bounds and a committed capture, never copied |
| A7 | The sun's orthographic shadow volume has no direct Godot equivalent | Resolved in `spike-compatibility-renderer-shadows` |
| A8 | Godot has two shadow bias parameters; the GDD specifies one | Resolved in `spike-compatibility-renderer-shadows` |
| A9 | Light intensities are in the reference build's units | Resolved: the ratios are normative, the scale is not; one shared `lightScale` = 0.2809; tonemapping linear |
| A10 | The camera eases per tick but frame ordering updates per frame | Resolved in M2: per tick. Time constant measured 0.200 s, settling 0.450 s, both predicted before measuring |
| A11 | The GDD requires no ground edge be visible, and specifies numbers that make it visible from the boundary | Resolved in M6: a ground skirt in the same albedo past fog's end — every stated number untouched; capture + geometry test |
| A12 | The two-prop pin is stated as permanent, but the specified radial push ejects the kart in 15–125 ticks | ❓ a GDD proposal (backlog) |

---

## 6. Determinism and the reference frame

Determinism is what makes headless suites and screenshot baselines possible,
and it is **acceptance item 14**. A non-reproducible result is a defect, never
a threshold to relax.

### The fixed step

| Rule | Status |
|---|---|
| The simulation never reads frame `delta`; `Sim.step()` advances exactly one 1/60 s tick | 📋 M1 |
| `physics/common/physics_ticks_per_second = 60` | ✅ `check_settings.py` |
| `physics/common/physics_jitter_fix = 0` — the default 0.5 perturbs the physics delta and drifts the race clock | ✅ `check_settings.py` |
| Elapsed race time is **tick count ÷ 60**, never `Time.get_ticks_msec()`. `countdownStep` is 60 ticks | 📋 M1 |
| The view interpolates between the last two simulation states using `Engine.get_physics_interpolation_fraction()`, and never advances anything itself | 📐, 📋 M2 |
| All gameplay randomness comes from `godot/scripts/core/rng.gd` with an explicit seed | ⚠️ `check_boundaries.py` bans the engine RNG from the core; that a seed is supplied is not checked |
| The engine RNG may be used for **view cosmetics only** | 📐 |
| Identical seed and identical inputs produce identical state summaries | 📋 M1 |

**A seed cannot fix a non-deterministic call count.** Scatter draws candidates
in a fixed order and consumes exactly one draw per attempt, including rejected
ones — the attempt budget is part of the stream.

**Acceptance item 14 splits in two**, because the engine's frame pacing
(`max_physics_steps_per_frame`) would make a through-the-engine test flaky for
reasons that are not the simulation's fault:

- **14a, standing suite** — the harness calls `Sim.step()` 3600 times from
  three differently-constructed drivers and compares summaries byte for byte.
- **14b, windowed gate** — the game runs at three refresh rates with scripted
  input; the ±0.5 wu / ±0.05 s bounds are asserted.

### Numeric precision

| Rule | Status |
|---|---|
| Velocity, yaw, and the elapsed clock are **`float` (64-bit) scalars** in the core | 📐 |
| `Vector3`/`AABB` (32-bit `real_t`) appear at the view boundary and in the AABB registry, never in the velocity recurrence — item 4's ±0.05 s tolerance cannot spare the precision | 📐 |

### The reference frame

Both frames are right-handed and Y-up, so **positions map one to one** — the
start band at Z = +5, the drivable extent ±90, nothing mirrored. What differs
is facing:

```
   Spec forward          +Z          the kart spawns facing +Z
   Godot convention      -Z          look_at, Camera3D, most imported meshes

   With rotation.y = ψ, a Node3D's local +Z points at (sin ψ, 0, cos ψ)
   ⇒ the simulation's forward vector IS the node's +basis.z
   ⇒ increasing ψ turns left, CCW viewed from above — matching the spec exactly
```

| Rule | Status |
|---|---|
| The simulation is expressed in the **spec's frame**, verbatim. No conversion layer | 📐 |
| Simulation forward is `+basis.z`. Any π offset to point a mesh or camera the Godot way lives in the **view**, in one named constant | 📐 |
| The kart's authored yaw correction is **derived from the imported bounds and pinned by a test**, never transcribed from the spec's "+90°" (stated in the reference build's frame — A6) | 📋 M2 |

---

## 7. Testing

| | Status |
|---|---|
| `godot/tools/test.sh` green before any change is considered done | ✅ |
| The standing suite is **headless and display-free** | ✅ verified with no display available |
| No test touches the network or a real save file | ⚠️ `LPC_SAVE_FILE` is exported by every harness but nothing reads it until M7; the network half has no check |
| Every suite is deterministic; a flaky test is a defect in the test | 📐 |
| A runtime script error inside a suite fails the run — Godot exits 0 after a mid-test `SCRIPT ERROR`, and the suite still prints its own success line, so `test.sh`'s `run_suite` wrapper scans each suite's output for the error markers | ✅ verified by mutation (former att 19) |
| Visual checks live in a separate windowed gate, never in `test.sh` — headless Godot has no renderer | 📐 by construction |
| ~~Test names encode the GDD scenario~~ — **withdrawn** for `# @covers` declarations; see `add-determinism-and-coverage-harness` design D1 | ⊘ |

**Coverage** is G1 and G2 in §5, not a percentage.

**Mutation checking** 📐. Whenever the harness itself changes, deliberately
break what each gate guards and confirm the right gate fails with the right
message — a `check()` turned no-op leaves everything green and verifies nothing.

**Image diffs use three criteria, never a mean alone** 📋 M6 — mean, percentage
of pixels changed, and percentage changed strongly; a local band obvious to a
reviewer can average under a whole-frame threshold.

**Thresholds are measured, never guessed** 📐. Capture twice unchanged, diff;
that is the noise floor. Set the limit a small multiple above it and record the
measurement beside the number.

---

## 8. Performance and size budgets

**Reference machine.** Apple M3 Ultra, 96 GB RAM, macOS 26.6.

### Hard constraints — must hold on any target

| | Budget | Status |
|---|---|---|
| Frame budget while racing | 16.7 ms (60 fps) on the reference machine | 📋 M6 |
| Simulation step cost | The full 8-step tick over 54 props inside one 60 Hz slice at 144 fps, i.e. ≤ 2.3 ms for 2–3 steps | 📋 M6 |
| Input to visible response | One simulation tick. Never gated on a render frame | 📐 |

### Web target — the binding constraint

The supplied assets are **39 MB of raw `.glb`** — unremarkable on desktop,
hostile on the web.

| | Budget | Status |
|---|---|---|
| Total web payload, compressed | ≤ 25 MB | ✅ measured 20.5 MB — see the measured row below |
| Prop textures | Downsampled to **512** — the GDD blesses 1024 for "the texture set" and states a floor only *for the kart*; props carry none and are seen at gameplay distances | ✅ `stamp_texture_imports.py --check` in the standing suite |
| Kart textures | **1024 floor** — an earlier row here read "2048² retained", a misreading of the GDD's "do not go below that [1024] for the kart"; the qualifier is the kart's floor, not a retention rule | ✅ same stamp check |
| Texture compression | Basis Universal on import (transcodes on load), stamped by `tools/stamp_texture_imports.py` — the project-level decision the old att-5 row asked for | ✅ `--check` in the suite |
| Total web payload, measured | **20.5 MB gzip-9** against the 25 MB budget (wasm 9.4 + pck 11) — from 89.2 MB before the stamp | ✅ measured in add-render-pipeline-and-web-budget |
| Cold load → countdown, web, warm cache | ≤ 5 s | 📋 M8's web smoke (needs a served browser session; the payload number above carries forward) |

### Design targets — measured on the reference machine

| | Target | Status |
|---|---|---|
| Cold start → countdown, desktop | ≤ 2 s | 📋 M6 |
| `godot/tools/test.sh` wall time | ≤ 60 s. Measured 8.4 s warm, 10.9 s cold; re-measure whenever a check is added | 📐 |

A gate slow enough to skip stops being run, and a gate that is not run is not a
gate. If a budget is enforced at runtime, prefer a machine-independent bound —
count work done, not milliseconds.

---

## 9. Assets

The seven supplied models are **provided and committed separately by the
repository owner**. No change, task, or tool copies, generates, or commits a
`.glb`.

| | Status |
|---|---|
| Assets live at **`assets/`** in the repository root, shared by every port | ✅ committed |
| `godot/tools/sync_assets.sh` copies the models into `godot/assets/` by content hash, at the front of the standing suite | ✅ |
| The copied `.glb` files and Godot's extracted textures are git-ignored; only `godot/assets/*.glb.import` is committed | ✅ `.gitignore` |
| The normalisation contract (GDD §3) is implemented in **`scripts/core/`** and unit-tested against synthetic boxes, with no `.glb` present | ✅ `normalise_test.gd` |
| Bounding boxes are **re-measured after scaling**, never reused from before it | ✅ `normalise_test.gd`, verified by mutation |
| `sync_assets.sh` refuses a preset recording a failed import, which Godot never repairs | ✅ |
| Anisotropic 16×, mipmaps, Basis compression, per-asset texture size — project-wide via a pinned setting and one committed stamp tool, never 21 generated files | ✅ `check_settings.py` (filtering) + `stamp_texture_imports.py --check` (the rest) |
| Every supplied model both casts and receives shadows | 📋 M6 |
| Materials are physically-based and lit. No unlit substitute | 📐 |
| No prop is authored in the scene tree; every instance is placed by scatter or a loaded layout | 📐 |

Operational notes, each learned the hard way: the sync is a **copy, not a
symlink** (git materialises symlinks on Windows only under conditions a
checkout cannot assume, and Windows ships); it compares **content hashes, not
mtimes**; only `*.glb.import` is committed because extracted textures are
derived data (committing their presets without the images produced ~40 load
errors on a fresh clone); and import settings are a gate because a re-import
silently reverts them.

---

## 10. Verification criteria

Deterministic acceptance conditions — pass/fail with no judgment.

| # | Condition | Status |
|---|---|---|
| V1 | `godot/tools/test.sh` exits 0 | ✅ |
| V2 | Two runs at the same seed produce byte-identical state summaries | ✅ `determinism_test.gd`, 3000 ticks of scripted input |
| V3 | No banned symbol from §4 appears under `godot/scripts/core/` | ✅ `check_boundaries.py` |
| V4 | No physics-body symbol from §4 appears anywhere under `godot/` | ✅ `check_boundaries.py` + the commit hook on staged content |
| V5 | No **distinctive** tuning value appears as a literal in `godot/scripts/` | ✅ `check_tuning_literals.py` |
| V6 | **G1** — every GDD scenario claimed exactly once; a claim on a scenario the document lacks also fails | ✅ `check_spec_coverage.py` |
| V7 | **G2** — every Acceptance Checklist item has a named conformance test asserting its literal tolerance | 📋 M8 |
| V8 | Pinned project settings match §6, and every model has a valid committed import preset | ✅ `check_settings.py` |
| V9 | Gallery diffs within recorded thresholds on all three criteria | 📋 M6 |
| V10 | Every relative link in every Markdown file resolves | ✅ `check_links.py` |
| V11 | Every `CONSTRAINTS §N Title` reference names the section it points at | ✅ `check_section_refs.py` — bare `docs/CONSTRAINTS.md §N` forms are invisible to it; stale prose stays review's job |
| V12 | `openspec validate <change> --strict` passes | ✅ |
| V13 | The change's `tasks.md` has no unchecked box | 📋 via `/opsx:apply` |
| V14 | A milestone has committed visual proof in `godot/docs/progress/` | 📐 |
| V15 | Every ambiguity discovered during a change is in `godot/docs/AMBIGUITIES.md` before it is archived | 📐 |
| V16 | `godot/data/tuning.json` matches the GDD's constant tables — every name present, none renamed, no derived values | ✅ `check_tuning_transcription.py` |
| V17 | No placeholder marker remains in a shipped document | ✅ `check_placeholders.py --strict` |
| V18 | Every governing document states the same engine version as `godot/.godot-version` | ✅ `check_engine_version.py` |
| V19 | Every GDScript function signature carries parameter and return types | ⚠️ `check_static_typing.py`; members not yet covered (backlog) |
| V20 | The seven supplied models import and load | ✅ `tests/assets_test.gd` |
| V21 | The commit hook and the standing suite derive their banned symbols from one shared definition | ✅ both read `godot/data/banned_symbols.json` |
| V22 | The rendered environment satisfies the exposure criteria | 📐 `measure_exposure.py`, windowed, against a committed capture |
| V23 | The GDD's specified colours are not written as literals in scripts | ✅ `check_tuning_literals.py`, hex-string pass |
| V24 | The built kart matches the GDD's own figures — authored box, dimensions, footprint, yaw correction | ✅ `check_kart_conformance.py`; expectations come from the GDD, sharing no ancestor with `tuning.json` |
| V25 | The kart's contact shadow survives — the cue the GDD calls primary | 📐 `measure_contact_shadow.py`, windowed |
| V26 | A generated field matches the GDD's population table, clearance radii, grounding and asset ordering | ✅ `check_scatter_conformance.py`, reading the GDD's own tables |

---

## 11. Work tracking

Two layers. Duplicating between them is the failure mode to avoid.

```
   ROADMAP.md          milestones — where we are going, in what order
     ## Backlog        everything outside an accepted change: future work,
        │              issues found in passing, deferred scope
        ▼
   openspec/changes/   one unit of work: why, design, specs, tasks
```

| Layer | Owns | Lifetime |
|---|---|---|
| `ROADMAP.md` | Milestones and their order; the **Backlog** section for work no accepted change covers | Long-lived; revised deliberately |
| `openspec/changes/<name>/` | A single change: proposal, design, specs, tasks — `tasks.md` is that change's execution checklist, archived with it | Until archived |

**Nothing leaves scope untracked** 📐. Every item deferred out of a change gets
a Backlog line (one line — a pointer, not a memo) before that change is
archived. If an item needs a page of analysis, that page belongs in the change
that will do the work, when it is proposed.

**Delta specs describe the port, not the game.** The GDD already specifies the
game. A change's `specs/` say what *this implementation* must do that the GDD
does not settle. Restating GDD scenarios into delta specs creates a second
normative document — the one outcome this repository exists to avoid.

*(A third layer, the `att` backlog CLI, was retired by `streamline-process`:
its backlog jobs moved to ROADMAP's Backlog section, and its per-task review
ceremony was absorbed into §12's two moments. History: `.att/` at that change's
parent commit.)*

---

## 12. Review

Every gate in this document is mechanical. Review catches what no grep can:
work that passes its tests and still does not do what was specified. It happens
at **two moments**.

### Archiving a change — the author's checklist

Before `/opsx:archive`, the author verifies, and the archive commit asserts:

1. `godot/tools/test.sh` is green (V1), `openspec validate --strict` passes
   (V12), no unchecked task box (V13).
2. Scenario coverage is current (V6) and honest — each claim's test actually
   tests its scenario.
3. Documentation is current per the drift table below; every deferral has a
   Backlog line; every resolved ambiguity is registered (V15).
4. Tolerances were met, not widened (§5).

### Completing a milestone — the adversarial pass

A milestone is called complete only after a **Critic pass**: a review conducted
adversarially, against the specification rather than against taste, by a fresh
pass that did not produce the work. The verdict is explicit — **[APPROVED]** or
**[REJECTED]** with findings; silence is not approval. The Critic checks the
archive checklist above across the milestone's changes, ROADMAP's "done when"
items, and the two things G1 cannot see: claims that overstate, and deferrals
parked on the wrong milestone. Any harness change since the last milestone must
have its mutation check (§7) on record.

### Visual proof

| When | Requirement |
|---|---|
| Completing a **milestone** | **Mandatory.** A committed capture showing what it delivered |
| Anything else | At the author's discretion |

Captures come from `godot/tools/capture.sh`, never from dragging a window — a
screenshot that cannot be re-run is a memory of a verification. Committed proof
lives in `godot/docs/progress/`. **Windowed, never in `test.sh`** (headless
Godot has no renderer). **Captures must be deterministic**: wait a fixed frame
count, seed the world explicitly, name the seed.

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

Inherited from `godot-game-skeleton` at M0 (paths adjusted — the skeleton
expects the Godot project at the repo root; left unadjusted its checkers pass
by finding nothing):

```
tools/test.sh                the standing gate — headless, run on every change
tools/check_links.py         every relative Markdown link resolves (V10)
tools/check_section_refs.py  every "CONSTRAINTS §N Title" reference is accurate (V11)
tools/capture.sh             windowed scene capture — visual proof (V14). NOT in test.sh
tools/check_placeholders.py  placeholder markers left in shipped documents
openspec validate --strict   planning artifacts are well-formed (V12)
```

Added by this project:

| Gate | Mechanism | Milestone |
|---|---|---|
| Scenario coverage G1 (V6) | `tools/check_spec_coverage.py` parses the GDD | M1 |
| GDScript lint and format | `gdtoolkit` — `gdlint`, `gdformat --check` | M0 |
| Whitespace, EOF newline, large files | the hand-rolled `godot/tools/pre-commit` | ✅ M0 |
| Visual gate (V9) | `tools/gallery.sh` + `gallery_compare.py` — windowed | M6 |
| Acceptance conformance G2 (V7) | `tests/conformance_test.gd`, 14 named cases | M8 |
| Commit-time gate | `godot/tools/pre-commit`, installed by `tools/install-hooks.sh`; checks **staged blobs**, bash-3.2-portable | ✅ M0 |
| Asset sync and import | `godot/tools/sync_assets.sh` + `tests/assets_test.gd` — content-hash sync, poisoned-preset refusal, load assertion | ✅ M0 |
| Tuning transcription | `godot/tools/check_tuning_transcription.py` | ✅ M0 |
| Engine version | `godot/tools/check_engine_version.py` | ✅ M0 |
| Static typing | `godot/tools/check_static_typing.py` — signatures only | ⚠️ M0 |
| Architectural boundaries | `godot/tools/check_boundaries.py`, from `godot/data/banned_symbols.json`, which the commit hook reads too | ✅ M0 |
| Tuning literals | `godot/tools/check_tuning_literals.py`, with a justified-exemption allowlist that fails on stale entries | ✅ M0 |
| Pinned settings | `godot/tools/check_settings.py` | ✅ M0 |
| Kart conformance | `godot/tools/check_kart_conformance.py` — against the GDD's own figures | ✅ M2 |
| Field conformance | `godot/tools/check_scatter_conformance.py` — against the GDD's own tables | ✅ M3 |
| Suite registration | `godot/tools/check_suites_registered.py` — every `tests/*.gd` runs in `test.sh`; exists because three suites once were not | ✅ M2 |
| Exposure (A9) | `godot/tools/measure_exposure.py`, `find_light_scale.py` — windowed | 📐 M2 |
| Contact shadow | `godot/tools/measure_contact_shadow.py` — windowed | 📐 M2 |
| Staged collision capture | `godot/tools/collision_capture.sh` — windowed, stages an arrangement and measures the shudder against an unjolted twin | 📐 M3 |

**Reference sections by number *and* title** — `CONSTRAINTS §8 Performance and
size budgets`, never a bare `§8`; a bare number survives a renumber while
silently pointing elsewhere.

**Keep the pre-commit hook fast** (measured 0.4 s) — a slow hook gets bypassed
with `--no-verify`, which is worse than no hook. **The hook is not the gate**:
it sees staged files and cheap checks only. `godot/tools/test.sh` decides
whether work is done, and with no CI, running it is carried by §12's archive
checklist.

---

## 14. Release and packaging

**Targets.** macOS (Apple Silicon), Windows, Linux, and Web — one commit, one
language, one renderer.

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

**macOS signing is a hazard, not a formality** — anything bundled beside the
binary must be signed with the same certificate under the hardened runtime, and
it fails only on a *clean* machine. Validate on one that has never seen the
certificate. **The web build is smoke-tested on a cold cache** — the 39 MB
payload is the whole risk and it is invisible on the second load.

---

## 15. Not applicable

Absent by decision, not by oversight:

- **Continuous integration.** No hosted CI. A committed pre-commit hook runs
  the cheap checks; `godot/tools/test.sh` is run by hand, enforced by §12's
  archive checklist. A workflow was built during M0 and deliberately removed —
  for a single-developer project it is a second environment to keep in step,
  buying enforcement the hook and the habit already provide.
- **Networking of any kind** — no multiplayer, leaderboards, telemetry, crash
  reporting, or analytics.
- **Accounts, auth, API contracts, SLAs, database schemas** — there is no server.
- **Persistent storage.** The best time is session-only in the GDD;
  `track_layout.json` is player-initiated export, not a save system.
- **Audio** — Optional Feature 1, unimplemented. No `AudioStreamPlayer` ships.
- **2D sprite tooling** — the inherited skeleton's sprite auditor was deleted;
  this is a 3D project with no sprites.
- **Particles, boost, drifting, checkpoints, ghost replay, time-of-day,
  end-of-session flow, kart customisation** — Optional Features 2–10; the GDD
  is explicit they wait to be "specifically requested."
- **A menu, a pause state, a settings screen, a fail state, an end condition.**
  Load → countdown → drive forever.
- **A fourth game state.** The spec defines three.
- **Free-look, orbit camera, or any mouse control** — a listed deviation.
- **On-screen developer instrumentation in the shipped build.** The reference
  grid is not instrumentation — it is part of the intended look.

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
