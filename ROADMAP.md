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
  Backlog line
- ✅ **Visual proof:** an empty Godot window at the pinned renderer, plus the
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

## M2 — First drive ✅ COMPLETE

Shipped by `add-world-presentation-layer`, `add-kart-view-orientation-and-input`
and `add-chase-camera`. Acceptance items **3**, **8** and **11** pass as named
tests; the coverage gate reports **zero** M2 scenarios deferred. Ambiguities
**A6**, **A9** and **A10** were settled, each with committed evidence; **A11** was
opened and belongs to M6.

Every done-when clause below carries ✅ where it shipped and ⚠️ where it did not,
rather than the milestone being marked complete over a list nobody checked off.

One clause is ⚠️ and is disclosed rather than waived: *Keeping the boundary
invisible* requires that no edge of the ground be visible, and the design
document's own ±100 wu plane, ±90 drivable extent and 50 wu fog start cannot
jointly deliver it. The register records it as `unmet`, the coverage gate prints
it on every run, and A11 owns the decision. Through the specified chase camera at
the boundary the transition reads as a plain horizon, which is the most favourable
evidence so far — and still M6's call.

**Goal.** You can drive the kart across a sunlit green field with a camera behind
it. The thinnest end-to-end slice: input reaching the simulation, the simulation
reaching the view, and a gate proving it.

The kart asset arrives here — it is the one model whose orientation is a known
hazard, and the acceptance item that catches it (3) cannot be proven without it.
Props wait for M3.

**Done when**
- ✅ Ground plane, reference grid, start/finish band, sky colour, linear fog, and
  the three lights are all present at their specified values
- ✅ The kart drives in the direction it visually faces, **at every heading**,
  forward and reverse (**acceptance 3**)
- ✅ The kart's yaw correction has its **axis derived from the imported bounds** and
  its **sign fixed by a committed capture**, held in one named constant, with a
  vertex-centroid measurement as a second witness — the GDD's "+90°" is never
  transcribed as a literal. The 16-heading test proves travel/facing *consistency*;
  it passes on a 180° error, so it is not what settles the sign (**A6**)
- ✅ The view interpolates between simulation states with
  `Engine.get_physics_interpolation_fraction()` and advances nothing itself. The
  **composition root** owns the accumulator and is the only caller of `step()`
- ✅ The three light intensities are settled against Godot's units (**A9**) by a
  committed measurement, not by eye: ratios preserved exactly, tonemapping left
  linear, and one shared scale chosen as **the value making the specified ground
  albedo render as itself**, verified to saturate nothing. "The largest scale that
  clips nothing" was the original rule and it is not this one — it parks the scene
  as bright as saturation allows rather than as bright as the
  specification asks, which the captures in `godot/docs/progress/` record
- ✅ The chase camera is a **pure module in `scripts/core/`**, stepped once per tick
  by the composition root immediately after `sim.step()` — so acceptance 8's
  "settles behind the kart" is a numeric test rather than a judgement (**A10**)
- ✅ The chase camera trails, lags through turns, settles behind the kart, and its
  field of view visibly widens with speed (**acceptance 8**)
- ⚠️ Driving to the boundary produces a soft rebound with grass still visible
  beyond, and no wall or ground edge is drawn (**acceptance 7**)
- ✅ Releasing window focus mid-throttle clears every held input and the kart coasts
  to a stop rather than driving away (**acceptance 11**)
- ✅ **Visual proof:** the kart mid-turn at speed, and a capture at the boundary
  showing grass beyond it

> **This is the milestone where a port most often goes quietly wrong.** A kart
> that crabs sideways passes every headless test in M1 and looks almost right in
> motion. The 16-heading test is cheap and it is the difference between finding
> that now and finding it in M8.

**Likely changes**
- `add-world-presentation-layer` — ground, grid, band, sky, fog, lights; settles
  **A9**; adds the §5/§6 art constants to `tuning.json` and gives that file its
  first reader in the running game, through a new `art_tuning.gd` rather than the
  simulation's loader, with the simulation-loader wiring deferred (since closed); ships a **static camera** so this
  milestone's first two changes have any visual proof at all
- `add-kart-view-orientation-and-input` — the composition root and its accumulator,
  the kart mesh, the derived yaw constant, render interpolation, start-line
  placement, and real input with focus handling
- `add-chase-camera` — `scripts/core/chase_camera.gd` eased per tick, the FOV
  curve, and the replacement of the static camera

> **Input moved in with driving, and the camera moved into the core.** Input and
> the camera were originally bundled as "the player-facing loop", but they share no
> dependency: input is what makes the kart drivable and belongs with the kart.
> The camera went into `scripts/core/` because the design document eases it *per
> tick*, which makes it a fixed-step recurrence like the physics — implemented in a
> `Node` it would ease per frame and converge 2.4× too fast on a 144 Hz display.
> As a pure module it is also testable with no renderer, which is what turns
> acceptance 8 into a real test. Both decisions come from M2 exploration.

---

## M3 — The field ✅ COMPLETE

Shipped by `add-seeded-world-scatter` and `add-aabb-collision-response`.
Acceptance items **2** and **6** pass as named tests; the coverage gate reports
**zero** M3 scenarios deferred. Ambiguity **A12** was opened and settled here.

Every done-when clause below carries ✅ where it shipped and ⚠️ where it did not,
rather than the milestone being marked complete over a list nobody checked off.

One clause is ⚠️ and is disclosed rather than waived: the pin between two
near-touching props is reproduced, and driving it showed the design document's
"cannot drive out" is not producible by the response the same document specifies.
The kart is stopped dead on every tick of contact and is never carried past the
pair — but the push is radial from the prop's centre, so the centred state is an
unstable equilibrium and the kart is squeezed out sideways: after about 125 ticks
driving along the pair's axis, and 15–20 across it. `collision_test.gd` sweeps all
sixteen headings and asserts both what survives and that the pin **ends**, so
neither a "fix" that resolves both overlaps nor one that makes the pin permanent
passes.

Unlike M2's ⚠️, this one has **no marker in the coverage gate** — the scenario it
touches is genuinely verified, and the defect is in a paragraph of the design
document rather than in a scenario. Its mechanical owners are ambiguity **A12**,
which is Open, and the Backlog's GDD-proposal line, which raises it against the document.
M3 is complete; that proposal is not part of it.

**Goal.** The obstacle course exists, it is different every time, and hitting a
tree feels like hitting a tree.

**Done when**
- ✅ Scatter places 15 trees, 10 rocks, 12 cones, 8 crates, 6 tyre stacks, and 3
  cottages under the clearance, separation, and attempt-budget rules, from a
  named seed, in a deterministic registration order
- ✅ Every prop stands exactly on the ground — none floating, none sunk — at every
  random scale (**acceptance 2**)
- ✅ Cottages appear only as distant landmarks, and the ring beyond `scatterExtent`
  is empty grass with no grid and no visible boundary
- ✅ Collision recomputes the kart's world AABB from its current yaw each tick,
  contracts it by `hitboxContraction` per side, resolves **the first intersecting
  prop in registration order only**, pushes `pushDistance`, and sets velocity to
  exactly zero
- ✅ Hitting a tree stops the kart dead, shoves it clear, and shakes the camera —
  and the kart can always reverse back out of a **single** prop at any approach
  angle (**acceptance 6**), swept at 16 headings rather than sampled at one
- ⚠️ Being pinned between two near-touching props is reproduced as specified, not
  fixed — the GDD keeps the placement rule and names Reset Kart as the escape.
  Reproduced, and **not permanent at any heading**: see the note above and **A12**
  (GDD proposal, in the Backlog)
- ✅ Regenerating the world leaves the kart's position, heading, velocity, and the
  running clock untouched
- ✅ Prop textures are 1024² per
  [CONSTRAINTS §8 Performance and size budgets](CONSTRAINTS.md); the kart stays 2048²
- ✅ **Visual proof:** a seeded field from the chase camera, and a capture of the
  kart pushed clear of a tree

**Likely changes**
- `add-seeded-world-scatter` — placement rules, variation, regeneration, registration order
- `add-aabb-collision-response` — detection, push-out, velocity kill, camera shake event

---

## M4 — The race ✅ COMPLETE

**Goal.** The game boots on its own into a countdown, hands over control on the
GO! frame, and banks lap times.

**Done when**
- ✅ The game boots to a countdown with **no user interaction and no configuration**
  and hands over control **4.0 s ± 0.1 s** later, on the GO! frame
  (**acceptance 1**)
- ✅ Exactly three states — LOADING, STARTING, RACING — with transitions taken once
  each and no path out of RACING
- ✅ The countdown advances READY → 3 → 2 → 1 → GO! on the **simulation clock**
  (60 ticks per step), while the kart pipeline stays gated on RACING
- ✅ The GO! overlay lingers `goLinger` after control is released, then hides and
  resets to white
- ✅ Inputs held through GO! take effect on the first racing tick
- ✅ Crossing the band northbound after 5 s banks a lap, freezes `TIME` on it for
  0.5 s, flashes a new best in green for 1.0 s, then restarts the clock. Crossing
  it southbound under power banks nothing (**acceptance 10**)
- ✅ The lap gate runs **last** in the tick and observes only; a push-out can never
  satisfy it
- ⚠️ A failed asset load leaves the game in LOADING with a visible error, never a
  countdown into a broken world — implemented and tested at the race-state level;
  the driver-level broken-model injection is a disclosed deviation (Backlog: the
  PropField load seam), the same ⚠️ treatment M2 and M3 used
- **Visual proof:** the countdown at GO!, and `TIME` frozen on a banked lap with
  a green best

**Changes:** `add-race-state-and-countdown` and `add-lap-gate-and-timing`,
both archived.

**Completed 2026-08-29.** Critic pass (fresh reviewer, CONSTRAINTS §12 Review):
**[APPROVED]**, zero blocking findings — gate green across 18 suites, every M4
scenario claim judged against its test, tolerances asserted tighter than the
acceptance slack (GO! at tick 240 exactly), the crossing-test traps each
tested, the harness mutation check on record, both mandated captures verified
against what they claim. Human playtest the same day: smooth, no issues. The
review's should-fix findings are Backlog lines tagged M5 below.

---

## M5 — The instruments ✅ COMPLETE

**Goal.** The player can read their speed, their time, and where they are.

**Done when**
- ✅ Speedometer half-dial with a red→yellow needle, ~0.1 s eased, reading
  `floor(ratio × speedoMax)`, topping out at **115** as specified — not "fixed"
  to reach 120
- ✅ Timer block: `TIME` in green to two decimals, `BEST` in yellow, `--.--` until a
  lap is banked
- ✅ Countdown overlay and loading indicator to their specified colours and sizes
- ✅ Minimap: a 200×200 px inset, parallel projection from 100 wu up, half-extent
  50 wu, **orientation-fixed regardless of kart heading** (the GDD's own frame:
  world +X toward the right edge, +Z toward the bottom — this bullet once said
  "north-up", a paraphrase the normative document does not), tracking the kart,
  with a marker and a heading arrow showing **true heading** — not the reference
  build's 90°-offset arrow (**acceptance 9**)
- ✅ Minimap markers are invisible in the main view
- ✅ Every HUD element reads **post-physics state**, so the kart's visible position,
  the needle, and the minimap marker always agree within a frame
- ✅ The HUD design resolution is chosen, recorded, and entered in the ambiguity
  register as **A1**
- ✅ No developer instrumentation is present in the player-facing HUD; the reference
  grid stays, because it is part of the intended look
- ✅ **Visual proof:** a full-frame capture with every HUD element live at speed

**Changes:** `add-heads-up-display` and `add-minimap-viewport`, both archived.

**Completed 2026-08-29.** Critic pass (fresh reviewer, CONSTRAINTS §12 Review):
**[REJECTED] twice, then [APPROVED]** — and the two rejections are the pass
earning its keep. It caught the speedometer's readout and unit label rendered
off screen (the committed proof showed the dial with no text while the suite
asserted the labels' contents), then caught the fix half-landed (min-width
labels parked at the dial's left edge, passing a containment-only assertion).
Both times the remedy included pinning the property that actually failed: the
hud suite now asserts child labels centred about the dial's midline. Its
review also surfaced a tautological assertion, an unpinned A1 foundation (the
design viewport now sits in check_settings.py's pins, mutation-verified), the
countdown's missing heavy weight, and a §7 self-tension recorded in the
register as a disclosed deviation. Final state verified by the reviewer's own
rect probe, its own eyes on the capture, and the full gate: 20 suites, 11
pins, 57 scenarios verified, only M7's four deferrals remaining.

---

## M6 — The look ✅ COMPLETE

**Goal.** The game looks the way the spec says, and a gate notices when it stops.

This is deliberately late: it is the only part that improves by iteration and is
safe to leave unfinished until the game underneath it is right. It is not
optional — the GDD calls shadows "a load-bearing part of the look".

**Done when**
- ✅ Sun shadows at 2048², soft/PCF filtering, ±60 wu orthographic volume, near 0.5
  / far 200, ≈ −0.0001 depth bias. Every supplied model casts and receives
- ✅ Linear fog from 50 wu to 150 wu in the sky colour, so distant props dissolve
  rather than pop
- ⚠️ Anisotropic filtering (16× where available) on base-colour maps — pinned
  project-wide in `check_settings.py` and present in the gallery baselines;
  a dedicated grazing-angle-past-a-cone state was not composed (disclosed)
- ✅ Viewport resize recomputes aspect, resizes the surface, clips no HUD element,
  and keeps `minimapSize` and `minimapInset`
- ✅ Render scale capped at **2×** on displays reporting a device pixel ratio above 2
- ✅ The visual gate runs windowed with measured thresholds on all three criteria —
  mean, percentage changed, percentage changed strongly — with the noise floor
  recorded beside each number (**V9**)
- ✅ Every scenario in G1's visual register has a baseline capture covering it
- ⚠️ Web payload measured **20.5 MB** gzip-9 against the 25 MB budget (from
  89.2 before the texture stamp); cold-load-to-countdown needs a served
  browser session and lands with M8's web smoke (disclosed split, Backlog)
- ✅ **Visual proof:** the committed baseline set itself

> **Measure the thresholds, never guess them.** Capture twice with nothing
> changed and diff; that is the floor. If the floor is not near zero the harness
> is non-deterministic — fix the harness rather than raising the threshold.

**Changes:** `add-render-pipeline-and-web-budget` and
`add-visual-conformance-gate`, both archived.

**Completed 2026-08-29.** Critic pass (fresh reviewer, CONSTRAINTS §12 Review):
**[REJECTED], then [APPROVED]** — the rejection caught two claims whose pinned
property was weaker than the specification's: the anisotropic *level* pinned
while no material requested the anisotropic sampler (probed: 55/55 materials
now request it), and a DPI cap on the 2D canvas knob while the 3D surface
rendered at native density (moved to the viewport's 3D scale; the test asserts
effective density ≤ 2). Its review also registered A13 (props at 512 below the
blessed 1024 — a port decision the register's charter owns), extended the
resize test to every HUD element at a changed aspect, and drove the §8 budget
rows to honest statuses — the step-cost budget is now a standing suite gate.
On the record as residuals: >2-DPR behaviour is asserted by property, not
hardware; and the step bench is a wall-clock bound in a suite whose own §8
advice prefers work-counting (~87× headroom makes the flake risk negligible).
Milestone highlights: A11 settled with the last UNMET scenario met, the web
payload measured 89.2 → 20.5 MB against 25, the visual gate live over five
baselines at a ~zero measured floor, capture staleness closed.

---

## M7 — Persistence and tuning ✅ COMPLETE

**Goal.** A lucky procedural arrangement becomes a repeatable track, and the feel
can be dialled in without a restart.

**Done when**
- ✅ **Save Layout** (`P`) produces human-readable, indented `track_layout.json`
  with one record per prop: asset id, target height, full position, yaw, full
  scale — and delivers it to the player by a mechanism chosen per platform and
  recorded as ambiguity **A2**
- ✅ Loading a layout releases every existing prop first, instantiates each record
  at exactly the recorded transform, and registers each as a solid obstacle
- ✅ Saving and reloading reproduces the identical world, repeatably — the restored
  scale is the **absolute final world scale**, never a factor re-applied on top of
  normalisation, so repeated cycles do not shrink or grow props (**acceptance 12**)
- ✅ **Registration order survives the round trip**, so a reloaded track collides
  identically to the one that was saved — recorded as ambiguity **A3**
- ✅ Changing `accel`, `friction`, `turnRate`, or `maxSpeed` at runtime alters
  handling **on the next tick**, with no restart and no disturbance to position,
  heading, velocity, or the clock (**acceptance 13**)
- ✅ **Reset Kart** (`R`) returns the kart to the origin facing +Z with zero
  velocity, leaving the timer, the best time, and the world untouched — and frees
  a kart pinned between two props
- ✅ Whatever tuning surface the port provides is **not** part of the player-facing
  HUD
- ✅ **Visual proof:** the same seeded field before saving and after reloading

**Changes:** `add-layout-persistence` and `add-runtime-tuning-and-reset`,
both archived.

**Completed 2026-08-30.** Critic pass (fresh reviewer, CONSTRAINTS §12 Review):
**[REJECTED], then [APPROVED]** — the rejection's headline was the port's own
delta spec promising cycle-zero byte-identity while the test asserted the
weaker N-vs-N+1 convergence; a one-line probe disproved the spec as written.
Remediated the strong way in `07e8e77` (the code up to the spec): 5-decimal
export quantization plus the recorded Y applied verbatim on import — the
probe's root cause, a re-derivation whose grounding dust broke identity — and
the reviewer's re-run probe now reports first-cycle A==B and B==C true. Its
other findings: the pin escape re-staged against the document's REAL two-prop
pin (held hit-after-hit before R frees it), the mtime watch given cadence and
detection coverage, the KEY_L pin's mutation check run and recorded, import
validation covering all five GDD fields. Verified by its own hands besides:
restored props genuinely collide, the restored capture is the same SHA-256 as
the original, reset is surgical with best and banked persisting through it.
Coverage: 63 verified + 1 visual-with-baseline, ZERO deferred — every
scenario in the document is owned. Residuals on the record: the archived
tasks notes tell the superseded convergence story (history, not truth — this
note is the pointer); the reset's racing-only gate is undocumented in the
delta (behaviour-equivalent pre-race); A2's web-download half waits for M8's
smoke, as registered.

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

## Backlog

Work no accepted change covers: deferred scope, issues found in passing, and
cross-document proposals. One line each — a pointer, not a memo; the analysis
belongs in the change that does the work. Milestone tags say where each most
plausibly lands. (Numbered items migrated from the retired `att` tracker;
their full histories are in git at `streamline-process`'s parent commit.)

- Extend `check_static_typing.py` to member variables; V19 stays ⚠️ until
  then. *(was att 18)*
- **M8** — Cold-load-to-countdown ≤ 5 s on the web build, measured in a
  served browser session at the web smoke; the payload half of §8's table is
  measured (20.5 MB gzip-9 vs 25) by add-render-pipeline-and-web-budget.
  *(disclosed split)*

---

## Not on this roadmap

Absent by decision. The full list with reasoning is in
[CONSTRAINTS §15 Not applicable](CONSTRAINTS.md); the ones most likely to be
asked about:

- **All ten Optional Features** — audio, particles, boost, drifting, checkpoints,
  ghost replay, persistent best times, time-of-day, an end-of-session flow, kart
  customisation. The GDD is explicit that these "should not be implemented until
  if and when they are specifically requested." Each waits for a specific
  request; none is a milestone or a Backlog line.
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
outside an accepted change is a one-line entry in the **Backlog** above. See
[CONSTRAINTS §11 Work tracking](CONSTRAINTS.md).

Change names above are **indicative, not committed** — they are how the work
looks from here, and each still needs its own `/opsx:propose`.

A change's delta specs describe **the port's decisions**, not the game's rules.
The GDD already specifies the game; restating its scenarios into
`openspec/changes/*/specs/` would create a second normative document, which is
the one outcome this repository exists to avoid.

Roadmap changes by proposal, like everything else. A milestone that grows a
seventh bullet is usually two milestones.
