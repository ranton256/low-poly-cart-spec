# Roadmap — the Godot port

Milestones for a **strict Godot 4.6 port** of
[`low-poly-cart-game-design-document.md`](low-poly-cart-game-design-document.md),
built under [`CONSTRAINTS.md`](CONSTRAINTS.md) and living in `godot/`.

Each milestone is a **demonstrable state of the product**, not a bucket of tasks
— you can sit down at the build and see what changed. If a milestone cannot be
demonstrated, it is a task list wearing a milestone's clothes.

No dates; sizes are relative and uncalibrated.

**Every milestone requires committed visual proof** — a capture in
`godot/docs/progress/` produced by `godot/tools/capture.sh` — with one deliberate
exception, M1, which has no window and says so. A milestone whose "Done when" is
all green suites and no picture is not done unless it explains why. See
[CONSTRAINTS §12 Review](CONSTRAINTS.md).

---

## The shape

```
  M0 ── M1 ── M2 ── M3 ── M4 ── M5 ── M6 ── M7 ── M8
   │     │     │     │     │     │     │     │     │
 gates  core  drive field race  HUD   look  save  ship
         ▲     ▲                                   ▲
   no engine   first playable            the checklist, all 14
```

| | Milestone | Goal | Acceptance items | Size |
|---|---|---|---|---|
| **M0** | Foundations | The project can verify itself | — | S |
| **M1** | The core | The rules are right, with nothing on screen | 4, 5, 14a | M |
| **M2** | First drive | You can drive the kart across the field | 3, 7, 8, 11 | M |
| **M3** | The field | The obstacle course exists and hurts | 2, 6 | M |
| **M4** | The race | Countdown, clock, laps, best time | 1, 10 | M |
| **M5** | The instruments | Speedometer, timer, minimap | 9 | M |
| **M6** | The look | Shadows, fog, and a gate that guards them | visual set | S |
| **M7** | Persistence and tuning | Save a lucky track; dial in the feel live | 12, 13 | S |
| **M8** | Conformance and ship | All 14, on four platforms | 14b, all | M |

**Acceptance item numbers** are the GDD's own Acceptance Checklist. Item 14
splits: **14a** is the headless determinism harness, **14b** is the real
three-refresh-rate run. See
[CONSTRAINTS §6 Determinism and the reference frame](CONSTRAINTS.md).

---

## M0 — Foundations

**Goal.** The project can verify itself before there is anything to verify.

`godot-game-skeleton` is copied into `godot/` and adapted. Almost none of this
milestone is invention; nearly all of it is filling in a worked template and
adjusting it for a Godot project that lives one directory down from the
documents that describe it.

**Done when**
- `godot/tools/test.sh` is green (**V1**), and a committed pre-commit hook runs
  the cheap checks on staged files. **No CI** — see
  [CONSTRAINTS §15 Not applicable](CONSTRAINTS.md)
- The two boundary greps fail the build: engine types under `scripts/core/`
  (**V3**), and any physics-body symbol anywhere under `godot/` (**V4**)
- A tuning-literal gate fails when a GDD number appears outside
  `godot/data/tuning.json` (**V5**)
- A settings gate pins `physics_ticks_per_second=60`, `physics_jitter_fix=0`,
  the renderer, and the glTF import presets (**V8**)
- `check_links.py` and `check_section_refs.py` are repointed at the repository
  root and demonstrably fail on a broken link and a stale `§N Title` (**V10, V11**)
- `gdlint` / `gdformat --check` and a pre-commit hook pass
- Every verification criterion in
  [CONSTRAINTS §10 Verification criteria](CONSTRAINTS.md) is ✅ or has a tracked
  `att` task
- **Visual proof:** an empty Godot window at the pinned renderer, plus the
  renderer spike's shadow comparison — both committed in `godot/docs/progress/`

> **The boundary greps are the highest-value item here and the cheapest.** Land
> them *before* the first line of `scripts/core/`, because that is exactly when
> the boundary is easiest to violate by accident — and the physics-body gate is
> the one that stops the port from quietly becoming a `CharacterBody3D` game.

> **The renderer spike was M0 work, not M6 work, and it paid.** Compatibility
> passes all five criteria at the specified 2048² map — but only after the spike
> caught that Godot's default `shadow_normal_bias` erases the kart's contact
> shadow, the cue the design document calls primary (ambiguity A8). It also found
> that the document's light intensities clip 67% of the frame under Compatibility,
> which M2 must settle (A9). Both would have shipped into M6's visual baselines.

**Likely changes**
- `add-godot-project-foundations` — skeleton in, project settings pinned, suite green
- `add-architecture-and-tuning-gates` — the four project-specific greps
- `spike-compatibility-renderer-shadows` — settles the open renderer decision

---

## M1 — The core

**Goal.** The rules of the game are right, proven, and reproducible — with
nothing on screen at all.

Everything in the GDD's tick order, the boundary, the input model, and the
normalisation arithmetic, as a plain object a test can construct and step with no
scene loaded. This is the milestone that makes every later one fast.

**Done when**
- `Sim.step()` executes the GDD's eight steps in the normative order, with the
  clamp before friction and the steering threshold tested post-clamp, pre-friction
- Holding accelerate from rest passes 90% of steady state at **0.94 s ± 0.05 s**,
  first reads dial **115** at **2.60 s ± 0.05 s** and stays there; coasting falls
  below `steerThreshold` in **1.21 s ± 0.05 s** (**acceptance 4**)
- Steering is impossible below the threshold and reverses sense in reverse
  (**acceptance 5**)
- The boundary clamps to `±drivableExtent` and applies `bounceFactor` **exactly
  once per tick**, however many axes clamped
- The normalisation contract is implemented and tested against synthetic bounding
  boxes — **re-measured after scaling**, lowest point at Y = 0, centred on X and Z
  — with no `.glb` present
- All tuning values are read from `godot/data/tuning.json`, transcribed once from
  the GDD's tables and named exactly as the GDD names them
- Two runs at the same seed produce byte-identical state summaries (**V2**)
- 3600 direct `step()` calls from three differently-constructed drivers agree
  byte for byte (**acceptance 14a**)
- **G1 is live**: `check_spec_coverage.py` parses all 64 `### Scenario:` headings
  out of the GDD and fails when one has neither a test nor a visual-register
  entry (**V6**). Every scenario in this milestone's scope is covered; the rest
  are registered as pending against their milestone
- **No visual proof** — this milestone deliberately renders nothing. The evidence
  is the suite

> **G1 is what makes the rest of the roadmap honest.** Once it exists, a
> milestone cannot be called done while a scenario it owns is silently untested,
> and the register of what is *not* unit-testable has to be written down rather
> than assumed.

**Likely changes**
- `add-simulation-tick-core` — the eight steps, input model, boundary, tuning table
- `add-asset-normalisation-contract` — bounds → scale, ground offset, AABB
- `add-determinism-and-coverage-harness` — 14a, V2, and the G1 gate

---

## M2 — First drive

**Goal.** You can drive the kart across a sunlit green field with a camera behind
it. The thinnest end-to-end slice: input reaching the simulation, the simulation
reaching the view, and a gate proving it.

The kart asset arrives here — it is the one model whose orientation is a known
hazard, and the acceptance item that catches it (3) cannot be proven without it.
Props wait for M3.

**Done when**
- Ground plane, reference grid, start/finish band, sky colour, linear fog, and
  the three lights are all present at their specified values
- The kart drives in the direction it visually faces, **at every heading**,
  forward and reverse (**acceptance 3**)
- The kart's yaw correction is **derived from the imported bounds**, held in one
  named constant, and pinned by a test that samples 16 headings — the GDD's
  "+90°" is never transcribed as a literal
- The view interpolates between simulation states with
  `Engine.get_physics_interpolation_fraction()` and advances nothing itself
- The chase camera trails, lags through turns, settles behind the kart, and its
  field of view visibly widens with speed (**acceptance 8**)
- Driving to the boundary produces a soft rebound with grass still visible
  beyond, and no wall or ground edge is drawn (**acceptance 7**)
- Releasing window focus mid-throttle clears every held input and the kart coasts
  to a stop rather than driving away (**acceptance 11**)
- **Visual proof:** the kart mid-turn at speed, and a capture at the boundary
  showing grass beyond it

> **This is the milestone where a port most often goes quietly wrong.** A kart
> that crabs sideways passes every headless test in M1 and looks almost right in
> motion. The 16-heading test is cheap and it is the difference between finding
> that now and finding it in M8.

**Likely changes**
- `add-world-presentation-layer` — ground, grid, band, sky, fog, lights
- `add-kart-view-and-orientation-calibration` — the mesh, the derived constant, interpolation
- `add-chase-camera-and-input` — camera behaviour, FOV curve, real input with focus handling

---

## M3 — The field

**Goal.** The obstacle course exists, it is different every time, and hitting a
tree feels like hitting a tree.

**Done when**
- Scatter places 15 trees, 10 rocks, 12 cones, 8 crates, 6 tyre stacks, and 3
  cottages under the clearance, separation, and attempt-budget rules, from a
  named seed, in a deterministic registration order
- Every prop stands exactly on the ground — none floating, none sunk — at every
  random scale (**acceptance 2**)
- Cottages appear only as distant landmarks, and the ring beyond `scatterExtent`
  is empty grass with no grid and no visible boundary
- Collision recomputes the kart's world AABB from its current yaw each tick,
  contracts it by `hitboxContraction` per side, resolves **the first intersecting
  prop in registration order only**, pushes `pushDistance`, and sets velocity to
  exactly zero
- Hitting a tree stops the kart dead, shoves it clear, and shakes the camera —
  and the kart can always reverse back out of a **single** prop at any approach
  angle (**acceptance 6**)
- Being pinned between two near-touching props is reproduced as specified, not
  fixed — the GDD keeps the placement rule and names Reset Kart as the escape
- Regenerating the world leaves the kart's position, heading, velocity, and the
  running clock untouched
- Prop textures are 1024² per
  [CONSTRAINTS §8 Performance and size budgets](CONSTRAINTS.md); the kart stays 2048²
- **Visual proof:** a seeded field from the chase camera, and a capture of the
  kart pushed clear of a tree

**Likely changes**
- `add-seeded-world-scatter` — placement rules, variation, regeneration, registration order
- `add-aabb-collision-response` — detection, push-out, velocity kill, camera shake event

---

## M4 — The race

**Goal.** The game boots on its own into a countdown, hands over control on the
GO! frame, and banks lap times.

**Done when**
- The game boots to a countdown with **no user interaction and no configuration**
  and hands over control **4.0 s ± 0.1 s** later, on the GO! frame
  (**acceptance 1**)
- Exactly three states — LOADING, STARTING, RACING — with transitions taken once
  each and no path out of RACING
- The countdown advances READY → 3 → 2 → 1 → GO! on the **simulation clock**
  (60 ticks per step), while the kart pipeline stays gated on RACING
- The GO! overlay lingers `goLinger` after control is released, then hides and
  resets to white
- Inputs held through GO! take effect on the first racing tick
- Crossing the band northbound after 5 s banks a lap, freezes `TIME` on it for
  0.5 s, flashes a new best in green for 1.0 s, then restarts the clock. Crossing
  it southbound under power banks nothing (**acceptance 10**)
- The lap gate runs **last** in the tick and observes only; a push-out can never
  satisfy it
- A failed asset load leaves the game in LOADING with a visible error, never a
  countdown into a broken world
- **Visual proof:** the countdown at GO!, and `TIME` frozen on a banked lap with
  a green best

**Likely changes**
- `add-game-state-and-countdown` — the three states, the countdown clock, bootstrap and failure
- `add-lap-gate-and-timing` — the gate, the 5 s minimum, best-time tracking and flash

---

## M5 — The instruments

**Goal.** The player can read their speed, their time, and where they are.

**Done when**
- Speedometer half-dial with a red→yellow needle, ~0.1 s eased, reading
  `floor(ratio × speedoMax)`, topping out at **115** as specified — not "fixed"
  to reach 120
- Timer block: `TIME` in green to two decimals, `BEST` in yellow, `--.--` until a
  lap is banked
- Countdown overlay and loading indicator to their specified colours and sizes
- Minimap: a 200×200 px inset, parallel projection from 100 wu up, half-extent
  50 wu, **north-up regardless of kart heading**, tracking the kart, with a
  marker and a heading arrow showing **true heading** — not the reference build's
  90°-offset arrow (**acceptance 9**)
- Minimap markers are invisible in the main view
- Every HUD element reads **post-physics state**, so the kart's visible position,
  the needle, and the minimap marker always agree within a frame
- The HUD design resolution is chosen, recorded, and entered in the ambiguity
  register as **A1**
- No developer instrumentation is present in the player-facing HUD; the reference
  grid stays, because it is part of the intended look
- **Visual proof:** a full-frame capture with every HUD element live at speed

**Likely changes**
- `add-heads-up-display` — speedometer, timer block, countdown, loading indicator
- `add-minimap-viewport` — the inset viewport, framing, markers, layer isolation

---

## M6 — The look

**Goal.** The game looks the way the spec says, and a gate notices when it stops.

This is deliberately late: it is the only part that improves by iteration and is
safe to leave unfinished until the game underneath it is right. It is not
optional — the GDD calls shadows "a load-bearing part of the look".

**Done when**
- Sun shadows at 2048², soft/PCF filtering, ±60 wu orthographic volume, near 0.5
  / far 200, ≈ −0.0001 depth bias. Every supplied model casts and receives
- Linear fog from 50 wu to 150 wu in the sky colour, so distant props dissolve
  rather than pop
- Anisotropic filtering (16× where available) on base-colour maps, verified at a
  grazing angle past a cone
- Viewport resize recomputes aspect, resizes the surface, clips no HUD element,
  and keeps `minimapSize` and `minimapInset`
- Render scale capped at **2×** on displays reporting a device pixel ratio above 2
- The visual gate runs windowed with measured thresholds on all three criteria —
  mean, percentage changed, percentage changed strongly — with the noise floor
  recorded beside each number (**V9**)
- Every scenario in G1's visual register has a baseline capture covering it
- Web payload is within the 25 MB compressed budget, cold-load to countdown
  within 5 s
- **Visual proof:** the committed baseline set itself

> **Measure the thresholds, never guess them.** Capture twice with nothing
> changed and diff; that is the floor. If the floor is not near zero the harness
> is non-deterministic — fix the harness rather than raising the threshold.

**Likely changes**
- `add-render-pipeline-and-web-budget` — shadows, fog, filtering, resize, DPI cap, payload
- `add-visual-conformance-gate` — the windowed gallery, thresholds, baselines

---

## M7 — Persistence and tuning

**Goal.** A lucky procedural arrangement becomes a repeatable track, and the feel
can be dialled in without a restart.

**Done when**
- **Save Layout** (`P`) produces human-readable, indented `track_layout.json`
  with one record per prop: asset id, target height, full position, yaw, full
  scale — and delivers it to the player by a mechanism chosen per platform and
  recorded as ambiguity **A2**
- Loading a layout releases every existing prop first, instantiates each record
  at exactly the recorded transform, and registers each as a solid obstacle
- Saving and reloading reproduces the identical world, repeatably — the restored
  scale is the **absolute final world scale**, never a factor re-applied on top of
  normalisation, so repeated cycles do not shrink or grow props (**acceptance 12**)
- **Registration order survives the round trip**, so a reloaded track collides
  identically to the one that was saved — recorded as ambiguity **A3**
- Changing `accel`, `friction`, `turnRate`, or `maxSpeed` at runtime alters
  handling **on the next tick**, with no restart and no disturbance to position,
  heading, velocity, or the clock (**acceptance 13**)
- **Reset Kart** (`R`) returns the kart to the origin facing +Z with zero
  velocity, leaving the timer, the best time, and the world untouched — and frees
  a kart pinned between two props
- Whatever tuning surface the port provides is **not** part of the player-facing
  HUD
- **Visual proof:** the same seeded field before saving and after reloading

**Likely changes**
- `add-layout-persistence` — export, import, round-trip fidelity, registration order
- `add-runtime-tuning-and-reset` — live tuning path, Reset Kart, Regenerate World binding

---

## M8 — Conformance and ship

**Goal.** All fourteen acceptance items pass as named tests, on four platforms,
and the ambiguity register is published.

**Done when**
- **G2 is live**: `tests/conformance_test.gd` holds fourteen named cases, one per
  Acceptance Checklist item, each asserting the GDD's literal tolerance (**V7**)
- A scripted 60-second input sequence replayed at 30, 60, and 144 frames per
  second ends within **0.5 wu** of the same position and **0.05 s** of the same
  lap time, in the real game (**acceptance 14b**)
- G1 reports every one of the 64 scenarios covered — no pending entries left
  against any milestone
- `godot/docs/AMBIGUITIES.md` is complete: every place the spec did not decide
  something, with what the port decided and why. **This is the deliverable the
  repository exists to produce**, not a postscript
- All four targets exported from one commit, each smoke-tested on its own OS —
  boots to countdown, drives, banks a lap, exits clean — with the web build
  tested on a **cold** cache
- macOS build signed, notarised, stapled, and validated on a machine that has
  never seen the certificate
- Annotated tag matching `config/version`, release notes
- **Visual proof:** a capture from each exported target

**Likely changes**
- `add-acceptance-conformance-suite` — the fourteen named cases, 14b, the ambiguity register
- `add-export-and-release-pipeline` — four targets, smoke procedure, signing, tagging

---

## Not on this roadmap

Absent by decision. The full list with reasoning is in
[CONSTRAINTS §15 Not applicable](CONSTRAINTS.md); the ones most likely to be
asked about:

- **All ten Optional Features** — audio, particles, boost, drifting, checkpoints,
  ghost replay, persistent best times, time-of-day, an end-of-session flow, kart
  customisation. The GDD is explicit that these "should not be implemented until
  if and when they are specifically requested." Each is an `att` backlog entry,
  not a milestone.
- **Networking of any kind**, including leaderboards and telemetry.
- **A menu, a pause, a settings screen, a fail state, or an end condition.** The
  session shape is load → countdown → drive forever.
- **Reproducing the reference build's eleven known deviations.** The
  specification wins.
- **Generating or committing art.** The seven models are supplied and committed
  separately by the repository owner; see
  [CONSTRAINTS §9 Assets](CONSTRAINTS.md).

---

## How this connects to the other layers

Milestones here group **changes**; a change carries its own `tasks.md`; anything
outside an accepted change lives in the `att` backlog. See
[CONSTRAINTS §11 Work tracking](CONSTRAINTS.md).

Change names above are **indicative, not committed** — they are how the work
looks from here, and each still needs its own `/opsx:propose`.

A change's delta specs describe **the port's decisions**, not the game's rules.
The GDD already specifies the game; restating its scenarios into
`openspec/changes/*/specs/` would create a second normative document, which is
the one outcome this repository exists to avoid.

Roadmap changes by proposal, like everything else. A milestone that grows a
seventh bullet is usually two milestones.
