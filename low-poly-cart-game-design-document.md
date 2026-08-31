# LowPolyCartJS — Game Design Document

## How to read this document

This document is a build specification for re-implementing **LowPolyCartJS** from its art assets alone, on any engine, in any language. It is deliberately **engine-agnostic and language-agnostic**: no framework, renderer, library, or language is named anywhere in the normative sections, and none should be inferred. Where a behaviour depends on a runtime facility (render layers, shadow maps, file download), it is described by its *effect*, and the implementer chooses the mechanism.

The document is organised as:

1. **Game Overview** — what the experience is.
2. **Reference Frame, Units, and Tick** — the conventions every number in this document is expressed in.
3. **Art & Asset Specification** — the supplied meshes and textures, their normalisation contract, and the art that lives in code (environment, lighting, HUD).
4. **Functional Requirements** — features specified as BDD (behaviour-driven development) scenarios in Gherkin format. These are the contract.
5. **Tuning Constants** — the canonical numeric tables. Every constant has a `name`, and the scenarios refer to constants by name rather than restating values, so each number lives in exactly one place.
6. **Acceptance Checklist** — what a finished port must demonstrate.
7. **Known Deviations in the Reference Build** — places where the original implementation differs from the design specified above. The specification wins; these are listed so a porter is not surprised when the original is compared side by side.
8. **Optional Features** — additional features for the developer to consider, but which **should not be implemented** until if and when they are specifically requested.

---

## Game Overview

LowPolyCartJS is a single-player, arcade-style 3D go-kart time-trial set in an open, sunlit green field scattered with low-poly props. The player drives a stylised kart with momentum-based "tank drive" handling — hold forward to build speed, steer while rolling, coast to a stop — through an authored obstacle field of trees, rocks, cones, crates, tyre stacks, and cottages, threading an ordered course of checkpoint gates. There is no opponent and no fail state: the entire game is the pleasure of driving plus a stopwatch. A 3-2-1-GO countdown starts the clock; crossing the start/finish band northbound under power, with every gate passed in order, banks a lap time, holds it on screen for half a second, then restarts the clock for the next attempt. A best time persists for the session.

The design goal is **feel over content**: a responsive chase camera that widens its field of view with speed, a needle speedometer, a live minimap, and chunky physical collisions that shove the kart aside and kill its momentum. Handling is tunable at runtime so the feel can be dialled in without restarting. Worlds are authored as layout files — a curated scatter plus its gates — and the game ships with one; saving and loading layouts turns any arrangement into a repeatable track.

**Session shape:** load → countdown → drive forever. The player is never ejected to a menu, never loses, and never runs out of anything.

---

## Reference Frame, Units, and Tick

Every number in this document uses these conventions. A port must either adopt them or apply a consistent transform.

### Coordinate system

* **Right-handed, Y-up.** X is lateral, Y is vertical (up positive), Z is depth.
* **World forward is +Z.** The kart spawns at the origin facing **+Z**; the start/finish band lies ahead of it at Z = +5.
* **Yaw** is rotation about Y. Increasing yaw turns the kart **left** (counter-clockwise viewed from above).
* **Ground plane is Y = 0.** Every object rests with its lowest point at Y = 0.

### Units

* Distances are **world units (wu)**. The scale anchor is the kart: **2.36 wu long, 2.20 wu wide, 1.20 wu tall.** Treat 1 wu ≈ 0.75 m if a physical scale is needed.
* Angles are radians in the constants table, degrees in prose.
* Times are seconds.

### Reference tick

The original simulation is a fixed-step integrator with **no delta-time compensation**, tuned at **60 ticks per second**. All per-tick constants in this document are stated at that rate, together with their frame-rate-independent equivalents.

**A port MUST be frame-rate independent, and MUST achieve it with a fixed 60 Hz accumulator**: accumulate real elapsed time, run the simulation in fixed 1/60 s steps, and interpolate the render between steps. A naive per-frame port will drive at double speed on a 120 Hz display and is non-conformant.

The **Continuous** column in the Tuning Constants table is **informative only** — it characterises the behaviour, it is not a permitted alternative implementation. The two do not agree. The discrete recurrence settles at `accel × friction / (1 − friction)` = 0.192 wu/tick (11.52 wu/s, speedometer **115**); the corresponding continuous system `v' = 28.8 − 2.4493·v` settles at 11.76 wu/s (speedometer **117**). A 2% difference in top speed makes lap times non-comparable between ports, so the fixed step is the contract and the discrete values are the ones that must be reproduced.

---

## Art & Asset Specification

### 1. Supplied model inventory

Seven models are supplied as binary glTF (`.glb`), one mesh and one material each, generated in a stylised low-poly / "chunky geometric" style with baked photographic-style texture detail.

| Asset | Role | Triangles | Native bounding box (X × Y × Z) |
|---|---|---|---|
| `kart` | Player vehicle | 17,326 | 2.000 × 1.019 × 1.868 |
| `tree` | Tall scenery | 7,032 | 0.786 × 2.000 × 0.794 |
| `rock` | Boulder obstacle | 4,220 | 2.000 × 1.503 × 1.840 |
| `cone` | Small traffic cone | 3,752 | 0.990 × 2.000 × 0.982 |
| `crate` | Wooden box obstacle | 9,017 | 2.000 × 1.844 × 1.819 |
| `tires` | Stacked tyre barrier | 15,193 | 2.000 × 1.573 × 2.000 |
| `cottage` | Distant landmark building | 4,943 | 1.540 × 2.000 × 1.618 |

Every model is delivered **centred on its own origin** (the origin sits at the centre of the bounding box, *not* at the base) and normalised so its largest axis spans −1 → +1. Native bounds are therefore not authored world sizes; the runtime rescales all of them (see §3).

### 2. Material and texture specification

Each model carries a **single material** with three 2048 × 2048 textures:

* **Base colour** map — carries all of the model's colour, including baked shading and detail.
* **Metallic-roughness** map.
* **Normal** map.

Material factors as authored: base colour tint white (1,1,1,1), metallic factor 1.0, roughness factor 1.0 — meaning the metallic and roughness values come entirely from the texture, not the factors. There is **no emissive** and **no transparency** on any asset.

Requirements for the renderer:

* Use a **physically-based, lit** material for all supplied models. Do not substitute an unlit/flat material; the assets rely on lighting to read as three-dimensional.
* Enable **anisotropic filtering** (16× where available) on the base-colour maps. Without it, ground-level props smear badly at grazing angles.
* Every supplied model both **casts and receives** shadows.
* If the target platform is memory-constrained, downsampling the texture set to 1024 × 1024 is acceptable and visually near-identical at gameplay distances; do not go below that for the kart.

### 3. Asset normalisation contract

The supplied models arrive at arbitrary authored scale and with their origin at their centre. Every instance placed in the world MUST pass through the following normalisation, in this order:

1. Measure the model's bounding box.
2. Compute `scale = targetHeight / boundingBox.height` and apply it uniformly.
3. **Re-measure** the bounding box after scaling. (Measuring once and reusing pre-scale numbers is the single most common porting error; it buries props halfway into the ground.)
4. Offset the instance so its **lowest point sits exactly at Y = 0** and its bounding box is **centred on X and Z**.

Result: an instance's transform position is a ground-contact point in X/Z, with a Y offset that puts its wheels/base on the grass.

Per-asset target heights and the resulting world dimensions:

| Asset | Target height | Random scale variation | Final height range | Final footprint range (X × Z) |
|---|---|---|---|---|
| `kart` | 1.20 | none (exact) | 1.20 | 2.36 × 2.20 |
| `tree` | 4.00 | ×0.8 – ×1.2 | 3.20 – 4.80 | 1.26–1.89 × 1.27–1.91 |
| `rock` | 1.50 | ×0.8 – ×1.2 | 1.20 – 1.80 | 1.60–2.40 × 1.47–2.21 |
| `cone` | 0.80 | ×0.8 – ×1.2 | 0.64 – 0.96 | 0.32–0.48 × 0.31–0.47 |
| `crate` | 1.00 | ×0.8 – ×1.2 | 0.80 – 1.20 | 0.87–1.30 × 0.79–1.18 |
| `tires` | 1.20 | ×0.8 – ×1.2 | 0.96 – 1.44 | 1.22–1.83 × 1.22–1.83 |
| `cottage` | 3.00 | ×0.8 – ×1.2 | 2.40 – 3.60 | 1.85–2.77 × 1.94–2.91 |

**The `kart` row is stated in mesh-local axes, before the yaw correction of §4.** The kart's authored long axis is its local X. Once the +90° correction is applied, the kart standing at the start line measures **2.20 wu across world X and 2.36 wu along world Z** — that is, 2.36 wu long in the direction it faces, as the vehicle dimensions elsewhere in this document describe it. Collision uses a world-axis-aligned box recomputed from the kart's current yaw every tick, so these world extents change continuously as it turns; only the vehicle-relative 2.36 long × 2.20 wide × 1.20 tall is fixed.

Note the intentional scale comedy: cottages are shorter than one and a half karts. This is the established look — do not "correct" it.

### 4. Kart orientation contract

The kart mesh's nose is **not** aligned with world forward as authored. A fixed **+90° yaw correction about the vertical axis** must be baked into the kart's presentation transform so the driver and steering wheel face world **+Z**.

Critically, **the movement solver must use the same corrected heading as the visual**. Whichever way this is expressed — baking the correction into the mesh at import, or carrying a constant offset between "visual yaw" and "travel yaw" — driving forward must move the kart in the direction the driver is looking, at every yaw angle. A port that gets this wrong produces a kart that crabs sideways, which is the classic failure of this asset.

### 5. Environment art (authored in code, not supplied as files)

| Element | Specification |
|---|---|
| **Sky / clear colour** | Flat sky blue `#87CEEB`. No skybox, no gradient, no clouds. |
| **Fog** | Linear fog, colour `#87CEEB` (matching sky), starting at 50 wu, fully opaque at 150 wu. Distant props dissolve into the horizon rather than popping. |
| **Ground** | A single flat plane, 200 × 200 wu, centred on the origin, at Y = 0. Grass green `#3D8C40`, roughness 0.9, metalness 0.0. Receives shadows; does not cast. |
| **Reference grid** | A wireframe grid overlay covering the central 100 × 100 wu, **20 divisions** (5 wu cells), drawn 0.01 wu above the ground to avoid depth fighting. Centre-axis lines `#555555`, minor lines `#333333`. This is deliberately visible in normal play — it reads as a track-testing pad and gives the eye a speed reference. |
| **Start/finish band** | A flat unlit white quad, **10 wu wide (X) × 2 wu deep (Z)**, centred at (0, 0.02, **+5**), 80% opaque, visible from both sides. This is the timing gate and the only track furniture in the game. |

### 6. Lighting

Three lights, fixed, no day/night cycle:

| Light | Colour | Intensity | Notes |
|---|---|---|---|
| Ambient | white | 0.60 | Base fill so shadowed faces never read black. |
| Hemisphere | sky `#87CEEB` → ground `#228B22` | 0.40 | Outdoor colour bounce; tints undersides green. |
| Directional ("sun") | white | 1.00 | Positioned at (30, 50, 30) aiming at the origin. **Casts shadows.** |

Shadow configuration for the sun: 2048 × 2048 shadow map, soft/percentage-closer filtering, orthographic shadow volume spanning **±60 wu** in X and Y with near 0.5 / far 200, and a small negative depth bias (≈ −0.0001) to suppress acne. Shadows are a load-bearing part of the look — the kart's contact shadow is the primary cue for where it actually is on the ground.

### 7. HUD art specification

All HUD elements are screen-space overlays that do not receive world lighting and do not intercept pointer input. Every element listed here is **player-facing and required**. Developer instrumentation — a state/velocity readout, an origin gizmo, a tuning panel — is deliberately not specified: see the Runtime Tuning feature for what must be adjustable, not how.

| Element | Anchor | Specification |
|---|---|---|
| **Title & controls** | Top-left | Game title in bright green `#00FF00` at ~20 px; control hints beneath in white at ~14 px, 80% opacity. The hints name the objective: `W/S drive · A/D steer · G restart · follow the gates`. Soft black drop shadow on all text. Light sans-serif face. |
| **Timer block** | Top-right | Monospace. Label `TIME` (12 px, 70% opacity) above the running time in green `#00FF00` at 24 px, formatted to **two decimal places**. Below it, label `BEST` above the best time in yellow `#FFFF00`, same size, showing `--.--` until a lap is banked. |
| **Gate counter** | Top-right | Within the timer block, `GATE n/N` in the timer label style. When the next gate is off-screen, a chevron at the screen edge points along the shortest turn toward it. |
| **Speedometer** | Bottom-right | A 160 × 90 px half-dial: a 160 px circle with an 8 px `#444444` rim, bottom half clipped away. A 4 px × 70 px needle pivoting at the dial's bottom centre, filled with a vertical red→yellow gradient (`#FF0000` at base → `#FFFF00` at tip), with ~0.1 s eased motion. Beneath the pivot: the unit label `KM/H` in grey `#888888` at 10 px, and the integer speed readout in white at 18 px. |
| **Countdown overlay** | Screen centre | Heavy black sans face at ~120 px with a strong 4 px black drop shadow. White for `READY`, `3`, `2`, `1`; switches to green `#00FF00` for `GO!`. Hidden outside the start sequence. |
| **Loading indicator** | Screen centre | Monospace white 18 px, `Loading assets...`. Replaced in place by an error message on failure. |
| **Minimap** | Bottom-left | A 200 × 200 px viewport inset 10 px from the bottom-left corner, rendered as a live top-down view over the main image with no border or frame. |

### 8. Art bible for producing additional assets

New props must match the supplied set:

| Property | Kart | Props |
|---|---|---|
| Triangle budget | 2,000 – 18,000 | 500 – 10,000 |
| Style | Stylised / low poly | Stylised / low poly |
| Texture | 1024–2048 px, flat-shaded feel | 1024–2048 px, flat-shaded feel |

Generation prompt suffix: *"…stylized low-poly game asset, chunky geometric shapes, vibrant solid colors, clean topology, mobile game aesthetic."*
Negative prompt: *"photorealistic, hyper-detailed, metallic reflections, glass, blurry textures, messy geometry."*

Any new prop must be delivered centred on its own origin, largest axis normalised to −1 → +1, single material, so it flows through the normalisation contract in §3 unchanged.

---

# Functional Requirements

The remainder of this document specifies behaviour as Gherkin scenarios. Numeric values in **bold** are normative.

---

## Feature: Session Bootstrap and Asset Normalisation

As a player,
I want the game to come up on its own with everything correctly sized and standing on the ground,
So that I can start driving without configuring anything.

The world built at boot is the **shipped circuit layout** (see Track Layout
Persistence, version 2), not a seeded scatter. The bootstrap verdict is
unchanged in shape: a circuit that fails to load or validate is a terminal
**LOADING** state with a visible message, never a countdown into a broken
world. *(Amended by `amend-gdd-for-checkpoint-circuit`.)*

### Scenario: Presenting a loading state while assets stream in

* **Given** the application has just started
* **When** the world has not yet finished loading
* **Then** the game state is **LOADING**
* **And** a centred loading indicator reading "Loading assets..." is displayed
* **And** no countdown, no timer activity, and no kart control are available

### Scenario: Normalising a supplied model to its target height

* **Given** a supplied model whose authored bounding box height is **2.0** units
* **And** a target height of **4.0** world units for that asset type
* **When** the asset loader prepares the model
* **Then** the model is scaled uniformly by **2.0**
* **And** the bounding box is re-measured **after** scaling
* **And** the instance is offset so its lowest point rests exactly at **Y = 0**
* **And** the instance is centred on the X and Z axes about its transform origin

### Scenario: Placing the kart at the start line

* **Given** all assets have loaded successfully
* **When** the kart is added to the world
* **Then** the kart stands at world position **X = 0, Z = 0** with its wheels touching **Y = 0**
* **And** the kart's final dimensions are **2.36 wu long × 2.20 wu wide × 1.20 wu tall**
* **And** because it faces **+Z**, its world-axis-aligned extent at the start line is therefore **2.20 wu on X and 2.36 wu on Z**
* **And** the kart faces world **+Z**, toward the start/finish band at **Z = +5**
* **And** the kart's velocity is **0**

### Scenario: Completing bootstrap and handing off to the start sequence

* **Given** the kart and all scenery have been placed
* **When** world generation completes
* **Then** the loading indicator is hidden
* **And** the race start sequence begins automatically without player input

### Scenario: Failing to load an asset

* **Given** one or more supplied model files cannot be retrieved or parsed
* **When** the bootstrap sequence attempts to continue
* **Then** the loading indicator is replaced with a visible error message
* **And** the underlying error is written to the developer log
* **And** the game remains in the **LOADING** state rather than starting a countdown into a broken world

---

## Feature: Procedural World Generation

As a player,
I want a differently arranged field of obstacles each time,
So that the open field stays interesting and the start area is always clear.

This feature's rules are **normative for authoring**: they produced the
shipped circuit's prop field, layout authoring starts from a scatter, and a
port's tools and tests continue to pin them. Since
`amend-gdd-for-checkpoint-circuit`, the game itself always plays an authored
circuit — the player-facing action this feature used to carry is re-bound
below.

### Scenario: Scattering the standard prop population

* **Given** the world is being populated
* **When** generation runs
* **Then** the following populations are requested, each at its specified target height:

  | Asset | Count | Target height | Clearance radius |
  |---|---|---|---|
  | `tree` | 15 | 4.0 | 8 |
  | `rock` | 10 | 1.5 | 8 |
  | `cone` | 12 | 0.8 | 8 |
  | `crate` | 8 | 1.0 | 8 |
  | `tires` | 6 | 1.2 | 8 |
  | `cottage` | 3 | 3.0 | 20 |

* **And** candidate positions are drawn from a uniform distribution over `±scatterExtent` on both X and Z

### Scenario Outline: Rejecting a candidate placement

* **Given** a candidate position has been generated for an asset
* **When** \<Condition>
* **Then** the candidate is rejected without placing a prop
* **And** another candidate is attempted

  **Examples:**

  | Rule | Condition |
  |---|---|
  | Start clearance | the candidate's distance from the world origin is less than the asset's clearance radius (`startClearance`, or `cottageClearance` for `cottage`) |
  | Prop crowding | the candidate lies within `minPropSeparation` of any previously placed prop's position |

Because `cottageClearance` is more than twice `startClearance`, cottages only ever appear as distant landmarks near the edges of the scattered field.

### Scenario: Giving up gracefully when placements cannot be found

* **Given** a request to place **N** instances of an asset
* **When** `attemptBudget` × N candidate positions have been attempted
* **Then** placement for that asset stops
* **And** the world is considered generated with however many instances succeeded
* **And** the achieved count versus the requested count is reported to the developer log

### Scenario: Varying repeated instances so the field does not look tiled

* **Given** a candidate position has been accepted
* **When** the instance is placed
* **Then** it is rotated by a uniformly random yaw in **[0, 360°)**
* **And** it is scaled by a uniformly random factor within `scaleVariation`, applied on top of its target-height normalisation
* **And** its lowest point is re-grounded to **Y = 0** after that scaling
* **And** it is registered as a solid collision obstacle

### Scenario: Leaving an empty outer ring

* **Given** props are scattered only within `±scatterExtent` while the kart may drive to `±drivableExtent`
* **When** the player drives past `scatterExtent` from the origin on any axis
* **Then** they enter an empty expanse of grass with no props, no grid lines, and no boundary wall visible
* **And** the world continues to render correctly out to the drivable limit

### Scenario: Restarting the circuit

* **Given** the player invokes the **Restart Circuit** action (the binding formerly known as Regenerate World)
* **When** the restart runs
* **Then** every prop is removed and its resources released, and the world is rebuilt from the loaded circuit layout — the same authored arrangement, not a fresh scatter
* **And** the kart returns to the start pose, the gate cursor returns to gate 1, and the lap clock restarts from **0.00**
* **And** the session's per-circuit best time is kept
* **And** the race state does not leave **RACING** — no fresh countdown; the restart is instant

---

## Feature: Race Start Sequence and Game State Machine

As a player,
I want a familiar countdown before the clock starts,
So that I know exactly when my time begins.

### Scenario: Enumerating the game states

* **Given** the game is running
* **Then** it is in exactly one of the states **LOADING**, **STARTING**, or **RACING** at any moment
* **And** the transitions are **LOADING → STARTING → RACING**, taken once each; there is no transition out of **RACING**

### Scenario: Running the countdown

* **Given** world generation has completed and the state has become **STARTING**
* **When** the countdown begins
* **Then** the centred overlay shows **READY** immediately
* **And** the overlay then advances to **3**, **2**, **1**, and **GO!** at `countdownStep` intervals
* **And** the **GO!** frame is therefore reached **4.0 s** after the countdown began
* **And** the **GO!** frame is rendered in green `#00FF00` while the preceding frames are white

### Scenario: Releasing control on the GO frame

* **Given** the countdown has reached the **GO!** frame
* **When** that frame is presented
* **Then** the state becomes **RACING** on the same frame — the player has control the instant they read **GO!**
* **And** the elapsed timer is reset to **0.00** and starts running
* **And** the lap-completion flag is cleared
* **And** the overlay stays on screen for a further `goLinger` while the kart is already drivable, then hides and resets its colour to white for the next use
* **And** the total delay from world-ready to control is therefore **4.0 s**, not 5.0 s

### Scenario: Freezing the kart during the countdown

* **Given** the state is **STARTING**
* **When** the player holds any drive or steer input
* **Then** the kart does not accelerate, move, or rotate
* **And** the accumulated velocity remains **0**
* **And** the inputs are still tracked, so a key held through **GO!** takes effect on the first racing tick

### Scenario: Viewing the kart before the start

* **Given** the state is **LOADING** or **STARTING**
* **When** a frame is rendered
* **Then** the camera holds a fixed inspection position behind and above the kart at approximately **(0, 5, −10)** looking toward the origin
* **And** the chase camera does not engage until the state is **RACING**

---

## Feature: Kart Driving Physics

As a player,
I want the kart to carry momentum and steer like a light arcade vehicle,
So that driving feels physical rather than like moving a cursor.

### Tick order of operations

**This ordering is normative.** Every simulation tick executes exactly these steps, in this order. Several scenarios below are only meaningful in terms of it — in particular, the speed clamp is applied *before* friction, and the steering threshold is tested against the **post-clamp, pre-friction** velocity.

1. **Accelerate.** `v += accel` while forward is held; `v −= accel` while reverse is held. Both held: the two terms cancel.
2. **Clamp.** `v = clamp(v, −maxSpeed × reverseFactor, +maxSpeed)`.
3. **Steer.** If `|v| > steerThreshold`: `yaw += turnRate × sign(v)` while left is held, `yaw −= turnRate × sign(v)` while right is held. The `sign(v)` term is what reverses the steering sense in reverse.
4. **Apply friction.** `v *= friction`.
5. **Integrate position.** Displace the kart along its own forward axis by `v`.
6. **Enforce the boundary.** Clamp X and Z to `±drivableExtent`. If **either or both** axes clamped, apply `v *= bounceFactor` exactly **once** for the tick — never once per axis, which would square the factor and leave a corner impact accelerating *into* the corner at +9% speed instead of rebounding.
7. **Resolve collision.** Test for overlap; on contact, push out and set `v = 0`.
8. **Evaluate the lap gate**, against the position and the step-5 integration of this tick. It runs last, so a kart that clips a prop inside the band has already been stopped and displaced before the gate is tested — and, per step 5 above, the push-out itself can never satisfy the gate.

Steps 1–4 settle the velocity for the tick; steps 5–7 are position work and run only once it is final; step 8 observes the result and changes nothing. Two consequences worth stating outright: the velocity tested at step 3 is always slightly larger than the velocity that moves the kart at step 5, and a collision at step 7 discards the entire tick's acceleration.

### Scenario: Accumulating forward speed

* **Given** the state is **RACING** and the kart is stationary
* **When** the player holds the forward input
* **Then** `accel` is added to the velocity on every simulation tick
* **And** the velocity is then multiplied by `friction` each tick
* **And** the kart approaches a steady-state speed of `accel × friction / (1 − friction)` = **0.192 wu/tick**, i.e. **≈11.5 wu/s**
* **And** it reaches 90% of that speed after approximately **0.94 seconds** of held input

### Scenario: Clamping to the configured speed limits

* **Given** the kart is under power
* **When** velocity is updated on a tick
* **Then** forward velocity is clamped to at most `maxSpeed`
* **And** reverse velocity is clamped to at most `maxSpeed × reverseFactor` in magnitude
* **And** because friction is applied after the clamp (tick order steps 2 then 4), the achievable steady speeds are **≈0.192 wu/tick** forward and **≈0.096 wu/tick** in reverse

### Scenario: Reversing

* **Given** the state is **RACING**
* **When** the player holds the reverse input
* **Then** `accel` is subtracted from the velocity each tick
* **And** the kart travels backwards along its own heading at up to **≈0.096 wu/tick**
* **And** applying reverse while rolling forward acts as a brake, bleeding speed before motion reverses

### Scenario: Coasting to a stop

* **Given** the kart is at steady-state forward speed
* **When** the player releases all drive inputs
* **Then** velocity decays by a factor of `friction` per tick with no further input
* **And** the kart drops below `steerThreshold` after approximately **1.2 seconds**
* **And** it asymptotically approaches zero without ever snapping to a halt

### Scenario: Steering while rolling

* **Given** the kart's post-clamp speed magnitude is greater than `steerThreshold`
* **When** the player holds the left input
* **Then** the kart's heading rotates by `+turnRate` per tick (**2.4 rad/s**, ≈**137.5°/s**)
* **And** holding the right input rotates the heading by the same magnitude in the opposite direction
* **And** the turn rate is constant regardless of how fast the kart is travelling above the threshold

### Scenario: Refusing to steer while stationary

* **Given** the kart's post-clamp speed magnitude is `steerThreshold` or less
* **When** the player holds a steering input
* **Then** the kart's heading does not change
* **And** the kart cannot be spun in place

### Scenario: Reversing the steering sense when driving backwards

* **Given** the kart is travelling with negative velocity (reversing)
* **When** the player holds the left input
* **Then** the kart's heading rotates in the **opposite** direction to the equivalent forward-travel input
* **And** the resulting motion matches the intuition of reversing a real vehicle: the rear end swings toward the held direction

### Scenario: Translating heading into motion

* **Given** the kart has a heading and a non-zero velocity
* **When** the position is integrated for the tick
* **Then** the kart is displaced along its own forward axis by the current velocity
* **And** the direction of travel matches the direction the kart's nose visually points, at every heading
* **And** there is no lateral slip, drift, or sideways velocity component

---

## Feature: World Boundary Containment

As a player,
I want the kart to stay in the world,
So that I cannot drive off the edge of the ground plane.

### Scenario: Bouncing off the invisible boundary

* **Given** the drivable area extends to `±drivableExtent` on both the X and Z axes
* **When** the kart's position exceeds `drivableExtent` in magnitude on either axis
* **Then** that axis of the position is clamped back to exactly `±drivableExtent`
* **And** the velocity is multiplied by `bounceFactor`, reversing it and removing 70% of its magnitude
* **And** the kart therefore rebounds gently rather than sticking to or passing through the limit

### Scenario: Keeping the boundary invisible

* **Given** the ground plane spans **±100 wu**
* **When** the kart is held against the boundary at `±drivableExtent`
* **Then** there is still visible grass beyond the kart in every direction
* **And** no wall, fence, or edge of the ground is drawn or visible

---

## Feature: Collision Detection and Response

As a player,
I want hitting a tree to feel like hitting a tree,
So that the obstacle field actually matters.

### Scenario: Detecting an overlap with a prop

* **Given** the kart is racing
* **When** collision is evaluated for the tick
* **Then** the kart's world-axis-aligned bounding volume is recomputed from its current transform
* **And** that volume is contracted by `hitboxContraction` on every side before testing, to make near misses forgiving
* **And** it is tested for intersection against the world-axis-aligned bounding volume of every registered prop
* **And** the **first intersecting prop in registration order** is treated as the collision for this tick, and testing stops there
* **And** at most one collision is therefore resolved per tick, however many props overlap

### Scenario: Responding to an impact

* **Given** the kart's contracted bounding volume intersects a prop's bounding volume
* **When** the collision response runs
* **Then** a push direction is computed as the horizontal unit vector from the **prop's bounding-volume centre** to the **kart's position**
* **And** if that horizontal vector is degenerate — the kart's position and the prop's centre coincide within floating-point tolerance — the kart's **backward** axis is used as the push direction instead, ejecting it the way it came in; using the forward axis would drive it further into the prop and walk it out the far side
* **And** the kart is displaced `pushDistance` along the push direction
* **And** the kart's velocity is set to exactly **0** — not reflected, not damped
* **And** the camera is jolted by a random offset of up to `±shakeHorizontal` and `±shakeVertical`, which the camera's normal smoothing then absorbs over the following fraction of a second

### Scenario: Not becoming trapped inside an obstacle

* **Given** the kart has collided with a prop and been pushed away with zero velocity
* **When** the player immediately holds forward again into the same prop
* **Then** each subsequent contact repeats the push-out and velocity-kill
* **And** the kart never becomes wedged inside, jitters through, or tunnels past the prop
* **And** the kart can always be freed by reversing away

**This guarantee covers one prop at a time, which is what one resolution per tick can deliver.** `minPropSeparation` is measured centre-to-centre and does not subtract footprints, so two cottages placed at the minimum 3 wu leave a gap of **0.09 wu** — against a contracted kart hitbox of 1.80 × 1.96 wu. A kart that reaches such a pair overlaps both, only the first in registration order is resolved, and the push-out drives it into the second; it oscillates in place with its velocity zeroed every tick and cannot make forward progress through the gap. The pin is transient, not permanent: the push is radial, so it multiplies any transverse offset on every bounce — the centred state is an unstable equilibrium, and the oscillation squeezes the kart out sideways within a fraction of a second at most headings and inside a couple of seconds at the worst. **Reset Kart is the specified immediate escape.** A port that wants the stronger guarantee should raise `minPropSeparation` to clear the largest pair of footprints rather than resolve multiple collisions per tick — the placement rule is the root cause, not the collision response.

### Scenario: Passing close to a prop without contact

* **Given** the kart passes a prop with a clearance greater than the contracted bounding volume
* **When** collision is evaluated
* **Then** no collision is registered
* **And** the velocity, heading, and position are entirely unaffected

### Scenario: Growing hit volume when driving diagonally

* **Given** collision uses world-axis-aligned volumes recomputed from the kart's current rotation
* **When** the kart is oriented at 45° to the world axes
* **Then** its effective hit volume is larger than when it is axis-aligned
* **And** this is accepted behaviour: the design favours the cheap, predictable axis-aligned test over an oriented-volume test

### Scenario: Colliding with the kart's own start position after regeneration

* **Given** a circuit is loaded while the kart sits away from the start
* **When** the loaded arrangement was authored with only the origin-based clearance rule
* **Then** a prop may be placed overlapping the kart's current position
* **And** the collision response pushes the kart clear on the following tick rather than trapping it

---

## Feature: Chase Camera

As a player,
I want the camera to trail the kart and sell the sensation of speed,
So that fast driving feels fast.

### Scenario: Trailing the kart

* **Given** the state is **RACING**
* **When** a frame is rendered
* **Then** the camera's target position is `chaseBack` behind and `chaseUp` above the kart, in the kart's own frame of reference
* **And** the camera aims at a point `aimAhead` ahead of the kart and `aimUp` above it
* **And** the camera position eases toward its target by `chaseSmoothing` per tick (a time constant of ≈ **0.2 s**)
* **And** the camera aim is applied without smoothing, so the horizon stays locked while the position lags

### Scenario: Lagging through a turn

* **Given** the kart is turning at full steering rate
* **When** the camera follows
* **Then** the camera swings wide behind the turn rather than snapping to the new heading
* **And** it settles behind the kart within roughly half a second of the turn ending

### Scenario: Widening the field of view with speed

* **Given** the kart's speed ratio is defined as `min(|velocity| / maxSpeed, 1)`
* **When** the camera is updated
* **Then** the vertical field of view is set to `fovBase + speedRatio × (fovMax − fovBase)`
* **And** at rest the field of view is `fovBase`
* **And** at steady-state top speed (ratio ≈ 0.96) it is approximately **89.4°**
* **And** the change is continuous, producing a subtle tunnelling effect as the kart accelerates

### Scenario: Absorbing a collision jolt

* **Given** a collision has displaced the camera by a random shake offset
* **When** subsequent frames are rendered
* **Then** the normal camera easing pulls the camera back to its trailing position
* **And** the visible result is a brief shudder rather than a permanent camera offset

---

## Feature: Minimap

As a player,
I want a top-down overview of the field,
So that I can see obstacles and the start line that are outside my view.

### Scenario: Rendering the minimap inset

* **Given** the main view has been drawn for this frame
* **When** the minimap is drawn
* **Then** it occupies a `minimapSize` region inset `minimapInset` from the bottom-left corner of the screen
* **And** it is drawn over the main image with its depth information cleared first, so it is never occluded by the main scene
* **And** it does not scale or distort the main view

### Scenario: Framing the minimap view

* **Given** the minimap uses a parallel (non-perspective) top-down projection
* **When** it is positioned
* **Then** it looks straight down from `minimapAltitude` above the ground
* **And** it frames a square of the world of `minimapHalfExtent` in each direction
* **And** it centres on the kart's current X and Z position, following it continuously

### Scenario: Keeping the minimap orientation fixed

* **Given** the kart is turning
* **When** the minimap is drawn
* **Then** the map does not rotate with the kart
* **And** world **+X** remains toward the right edge of the map and world **+Z** remains toward the bottom edge, at all times

### Scenario: Marking the kart on the minimap

* **Given** the kart is being tracked
* **When** the minimap is drawn
* **Then** a flat red disc of approximately **2.4 wu** radius marks the kart's position
* **And** a yellow triangular arrow adjacent to the disc indicates the kart's current heading
* **And** both markers are drawn without lighting so they read as flat symbols, not objects

### Scenario: Hiding minimap markers from the main view

* **Given** the minimap marker and heading arrow exist in the world
* **When** the main chase-camera view is rendered
* **Then** neither marker is visible in it
* **And** the separation is achieved by render-layer masking rather than by moving or toggling the markers each frame

---

## Feature: Heads-Up Display

As a player,
I want continuous readouts of my speed and time,
So that I can judge my runs.

### Scenario: Driving the speedometer needle

* **Given** the speed ratio is `min(|velocity| / maxSpeed, 1)`
* **When** the HUD updates
* **Then** the needle is rotated to **(speed ratio × 180°) − 90°**, sweeping from pointing left at rest to pointing right at the clamp
* **And** the numeric readout shows `floor(speedRatio × speedoMax)`, labelled `KM/H`
* **And** at steady-state forward speed the readout settles at approximately **115**
* **And** at steady-state reverse speed it reads approximately **57**, since the dial shows speed magnitude and not direction

### Scenario: Running the race timer

* **Given** the state is **RACING**
* **When** each frame is presented
* **Then** the `TIME` readout shows the seconds elapsed since the clock started, to **two decimal places**
* **And** the timer runs continuously regardless of whether the kart is moving
* **And** the only interruption is the `lapRestartDelay` window after a banked lap, during which the clock itself is stopped and the readout holds the banked time (see Lap Detection)

### Scenario: Displaying an unset best time

* **Given** no lap has been completed this session
* **When** the HUD is drawn
* **Then** the `BEST` readout shows the placeholder **`--.--`**

---

## Feature: Lap Detection and Best-Time Tracking

As a player,
I want crossing the start/finish band to bank a time and start the next attempt,
So that I can chase a personal best.

### Scenario: Completing a valid lap

* **Given** the state is **RACING**
* **And** every gate has been passed in order — the progress cursor is past the final gate (see *Checkpoint Circuit*)
* **And** no lap has already been banked for this clock
* **When** the kart's position is within the finish band — **Z ∈ (4, 6)** and **|X| < 5** —
* **And** the **+Z component of the tick's step-5 integration** — that is, `v × (forward axis · +Z)` — exceeds `lapCrossingThreshold`, i.e. the kart is under its own power crossing the band in the direction the band is meant to be crossed
* **Then** the lap is recorded and further lap detection is suppressed until the clock restarts

Two things this test is deliberately **not**: it is not the sign of the scalar velocity — a kart driving forward under power but *heading south* is going the wrong way through the gate and must not bank a lap — and it is not the net change in position over the tick. Net position also moves at step 6 (boundary clamp) and step 7 (`pushDistance` push-out); a kart sitting motionless in the band against a prop on its south side is shoved +0.3 wu on +Z every tick, thirty times the threshold, and would otherwise bank a lap without the player driving anywhere.

### Scenario: Setting a new best time

* **Given** a lap has just been recorded with an elapsed time lower than the current best
* **When** the best time is updated
* **Then** the `BEST` readout shows the new time to two decimal places
* **And** the readout flashes green `#00FF00` for `bestFlashDuration` before returning to yellow `#FFFF00`

### Scenario: Recording a lap slower than the best

* **Given** a lap has just been recorded with an elapsed time greater than or equal to the current best
* **When** the result is processed
* **Then** the `BEST` readout is unchanged and does not flash
* **And** the lap still counts for the purpose of restarting the clock

### Scenario: Restarting the clock after a lap

* **Given** a lap has just been recorded
* **When** the lap is banked
* **Then** the clock **stops**, and the `TIME` readout holds the banked lap time for `lapRestartDelay`, so the player can read what they scored
* **And** when `lapRestartDelay` has passed, the clock restarts from **0.00** and lap detection is re-armed
* **And** the next lap's clock therefore begins `lapRestartDelay` **after** the crossing — the held window is dead time belonging to no lap
* **And** the kart's position, heading, and velocity are untouched throughout: only the clock pauses, never the simulation, and the player drives straight on into the next lap

### Scenario Outline: Rejecting a crossing

* **Given** the state is **RACING** and lap detection runs
* **When** \<Condition>
* **Then** no lap is recorded and the clock keeps running
* **And** the lap is banked only once every condition of a valid lap is satisfied simultaneously

  **Examples:**

  | Rule | Condition |
  |---|---|
  | Course not threaded | the progress cursor has not passed the final gate — the player cannot farm times by shuttling across the line, because the line alone is never enough |
  | Wrong way | the kart's **+Z** displacement is `lapCrossingThreshold` or less, including reversing and including driving forward while heading south |
  | Outside the band | the kart passes the plane **Z = 5** at a lateral offset of **\|X\| ≥ 5** — it must go through the visible white band, not around it |
  | Already banked | a lap has already been recorded for this clock and detection has not yet been re-armed |

### Scenario: Persisting the best time for the session

* **Given** a best time has been set
* **When** the circuit is restarted or the kart is reset
* **Then** the best time is retained for the remainder of the session
* **And** it is not written to durable storage; a fresh session starts with no best time

---

## Feature: Checkpoint Circuit

As a player,
I want an ordered course of visible gates that my lap must thread,
So that a lap time measures driving, not proximity to the finish line.

The game always plays a circuit. The shipped circuit is the default world,
other circuits load through Track Layout Persistence, and there is no
gateless mode: a layout the game will play always carries gates.
*(Added by `amend-gdd-for-checkpoint-circuit`; this feature has no reference
build — it is specified fresh, and Known Deviations does not apply to it.)*

### Scenario: Defining a gate

* **Given** a loaded circuit
* **Then** each gate is a directed segment on the ground: a centre **(X, Z)**, a yaw, and a width, in world units
* **And** a gate is **passed** on a tick when, in the gate's own frame, the kart's position lies within half the width of the centre laterally and inside a slab `gateDepth` deep ahead of the segment, while the component of the tick's **step-5 integration** along gate-forward exceeds `gateCrossingThreshold`
* **And** the test runs at the same stage as lap detection, observes only, and therefore shares the band's immunities: a push-out or boundary shove cannot pass a gate, and a kart heading backwards through one cannot either

### Scenario: Progress is a cursor, not a checklist

* **Given** gates numbered **1..N** in file order and a progress cursor starting at **1**
* **When** the kart passes the gate the cursor names
* **Then** the cursor advances by one
* **And** passing any *other* gate — already passed, not yet due, or the right gate backwards — changes **nothing**: no reset, no voided lap, no message; the only cure for a missed gate is to go and pass it
* **And** banking a lap returns the cursor to **1**

### Scenario: The band banks only a threaded lap

* **When** the kart crosses the start/finish band satisfying every other condition of *Completing a valid lap*
* **Then** the lap banks **only if the cursor has passed the final gate**; otherwise the crossing changes nothing and the clock keeps running
* **And** there is no minimum lap time: the ordered gates are the farming defence, and `minLapTime` is retired

### Scenario: Reset Kart and circuit progress

* **Given** a lap in progress with some gates passed
* **When** the player uses Reset Kart
* **Then** the cursor is untouched — Reset Kart restores the start pose and **nothing else**, exactly as Runtime Tuning and Player Actions states; a full fresh attempt is Restart Circuit's job
* **And** no shortcut results: the band still refuses to bank until the remaining gates are passed

### Scenario: Best times belong to their circuit

* **Given** laps banked on more than one circuit during a session
* **Then** each session best is kept per circuit `name`, and the `BEST` readout always shows the best of the circuit being played
* **And** medal targets are compared only against laps of their own circuit

### Scenario: Medal targets

* **Given** a circuit whose file declares `bronze`, `silver`, and `gold` target times
* **When** a lap banks at or under a target
* **Then** the held `TIME` readout is joined, for the hold window, by the name of the best target met, in that medal's colour (`medalGoldColour`, `medalSilverColour`, `medalBronzeColour`)
* **And** a circuit may omit targets, in which case nothing extra is shown

### Scenario: What a gate looks like

* **Given** a loaded circuit
* **Then** each gate is drawn as generated geometry in the band's visual family — two unlit pylons of height `gatePylonHeight` at the segment's ends, a translucent ground stripe between them, and an overhead chevron — never as a scatterable prop, so course furniture and obstacles cannot be confused
* **And** gates are **not** collision obstacles: the kart drives through pylons unimpeded, as it does through the band
* **And** the gate the cursor names is shown in `gateNextColour` with a pulse animated on the **simulation clock**; gates already passed this lap show `gatePassedColour`; gates not yet due show `gateIdleColour`
* **And** each gate shows its number above the chevron, facing the camera
* **And** the gate's **pass direction is readable at a glance from either side**: the overhead chevron points along gate-forward, the ground stripe is an arrow in the same direction, and a gate approached from behind visibly reads as the back of a gate rather than an oncoming one *(added after the first playtest: the mechanic is directional, so the furniture must be)*

### Scenario: Finding the next gate

* **Then** the HUD timer block gains a `GATE n/N` line
* **And** when the next gate is off-screen, a chevron at the screen edge points along the shortest turn toward it — fog ends at `fogEnd` and the playfield is wider than that; the player must never need to memorise the course to find it
* **And** the minimap shows every gate as a marker on the marker layer, the next gate emphasised (larger and in `gateNextColour`), with the same invisibility-in-the-main-view guarantee the kart markers carry

---

## Feature: Input Handling

As a player,
I want responsive, forgiving controls that never stick,
So that the kart always does what I am asking.

### Scenario: Mapping the control scheme

* **Given** the game is accepting input
* **Then** the following bindings are active, with both sets equivalent:

  | Action | Primary | Alternate |
  |---|---|---|
  | Accelerate | `W` | Up |
  | Reverse | `S` | Down |
  | Steer left | `A` | Left |
  | Steer right | `D` | Right |
  | Reset Kart | `R` | — |
  | Save Layout | `P` | — |

* **And** a **Restart Circuit** action (formerly Regenerate World; renamed by `amend-gdd-for-checkpoint-circuit`) exists but has no required binding — how a port exposes it is unspecified

### Scenario: Tracking held inputs as continuous state

* **Given** the player presses and holds an input
* **When** simulation ticks run
* **Then** the input is treated as held on every tick until release, independent of any key-repeat behaviour of the host system
* **And** releasing the input clears the held state on the same tick it is observed

### Scenario: Combining simultaneous inputs

* **Given** the player holds accelerate and steer left together
* **When** the tick is simulated
* **Then** both acceleration and rotation are applied in the same tick
* **And** holding accelerate and reverse together results in the two acceleration terms cancelling, leaving only friction to act

### Scenario: Clearing stuck inputs on focus loss

* **Given** the player is holding one or more inputs
* **When** the application loses input focus
* **Then** every held input is cleared immediately
* **And** the kart coasts to a stop under friction rather than driving away unattended

### Scenario: Ignoring unbound keys

* **Given** the player presses a key with no binding
* **When** the input is processed
* **Then** no game state changes
* **And** the input log is not polluted with the event

---

## Feature: Runtime Tuning and Player Actions

As a developer tuning the game,
I want handling to be adjustable while the game runs,
So that I can dial in the feel without restarting.

This specification defines **what must be adjustable and what the actions do**. It deliberately does not specify a tuning UI — panels, sliders, gizmos, and state readouts are developer instrumentation, and how a port surfaces them is its own business.

### Scenario: Adjusting handling without a restart

* **Given** the game is running in any state
* **When** `accel`, `friction`, `turnRate`, or `maxSpeed` is changed by whatever means the port provides
* **Then** the new value is in force on the very next simulation tick
* **And** no reload, reset, or state transition is required
* **And** the kart's current position, heading, velocity, and the running clock are unaffected by the change itself

### Scenario: Resetting the kart

* **Given** the player triggers the **Reset Kart** action
* **When** the reset runs
* **Then** the kart returns to **X = 0, Z = 0** with its wheels on the ground
* **And** its heading is restored to facing world **+Z**
* **And** its velocity is set to **0**
* **And** the elapsed timer, the best time, and the world layout are all left unchanged

---

## Feature: Track Layout Persistence

As a player who found a good arrangement,
I want to save and restore the scattered world,
So that a lucky procedural layout becomes a repeatable track.

### Scenario: Exporting the current layout

* **Given** a world has been generated
* **When** the player triggers the **Save Layout** action
* **Then** a layout file named `track_layout.json` is produced and delivered to the player
* **And** it contains one record per placed prop, holding: the source asset identifier, the asset's target height, the full position (X, Y, Z), the yaw rotation, and the full scale (X, Y, Z)
* **And** the file is human-readable, indented text

### Scenario: Restoring a saved layout

* **Given** a previously exported layout file
* **When** the layout is loaded
* **Then** every existing prop is removed and its resources released first
* **And** each record is instantiated from its named asset at exactly the recorded position, rotation, and scale
* **And** each restored prop is registered as a solid collision obstacle

### Scenario: Round-tripping a layout without drift

* **Given** a world has been exported and then re-imported
* **When** the restored world is compared with the original
* **Then** every prop occupies the same position, heading, and size as before, within floating-point tolerance
* **And** in particular the restored scale is the **absolute final world scale**, not a factor re-applied on top of the asset's normalisation
* **And** repeated export/import cycles produce identical layouts rather than progressively shrinking or growing props

### Scenario: A layout is a circuit

* **Given** a layout file with `"version": 2`
* **Then** it carries, beside `props`, a `circuit` object: a `name`, an ordered `gates` list — each `{ "position": [X, Z], "yaw": r, "width": w }` — and an optional `targets` object with `bronze`, `silver`, and `gold` times in seconds
* **And** the file is the guarantee that no prop blocks a gate mouth, which is why gates and props travel together
* **And** a file without a `circuit` object — version 1 included — is **refused on load with a named error**: such files remain valid authoring artifacts for building circuits from, but the game does not play them
* **And** saving writes the loaded circuit object back out unchanged, so the round-trip guarantees extend to it

---

## Feature: Frame Loop and Render Pipeline

As a developer,
I want a defined update and draw order,
So that a frame is always internally consistent.

### Scenario: Ordering the work within a frame

* **Given** a new frame begins
* **When** the frame is processed
* **Then** the physics update runs first — input is applied, velocity is integrated, position is updated, the boundary is enforced, and collision is resolved
* **And** the camera is then updated from the kart's post-physics transform
* **And** the minimap view is then re-centred on the kart's post-physics position
* **And** the HUD is then updated from the post-physics state
* **And** only then is the main view rendered, followed by the minimap inset
* **And** the kart's visible position, the speedometer reading, and the minimap marker therefore always agree within a single frame

### Scenario: Suspending the simulation outside the racing state

* **Given** the state is not **RACING**
* **When** a frame is processed
* **Then** the physics update is skipped entirely
* **And** the chase camera and minimap tracking do not run
* **And** the HUD and rendering still update every frame, so the countdown and loading views remain live

### Scenario: Adapting to a resized viewport

* **Given** the game is running
* **When** the display surface changes size
* **Then** the main camera's aspect ratio is recomputed from the new dimensions
* **And** the render surface is resized to match
* **And** no HUD element is clipped, stretched, or left anchored to a stale corner
* **And** the minimap keeps its `minimapSize` and `minimapInset`

### Scenario: Limiting render resolution on high-density displays

* **Given** the display reports a device pixel ratio greater than **2**
* **When** the render surface is configured
* **Then** the effective render scale is capped at **2×**
* **And** the game does not attempt to render at the full native density of very high-DPI displays

---

# Tuning Constants

The canonical tables.

## Physics

**These tables are the single source of truth for every number in this document.** Each constant has a `name`; the scenarios above refer to constants by name rather than restating their values, so retuning the game means editing one row here. Values written in bold in a scenario are ones with no constant behind them.

The **Per tick** column is the authored value at the **60 Hz** reference rate and is the value a port must implement. The **Continuous** column is **informative only** — see *Reference tick*.

| `name` | Per tick (60 Hz) | Continuous | Notes |
|---|---|---|---|
| `accel` | 0.008 wu/tick added to velocity | 28.8 wu/s² | Same magnitude forward and reverse |
| `maxSpeed` | 0.2 wu/tick | 12.0 wu/s | Forward clamp, applied *before* friction |
| `reverseFactor` | 0.5 | same | Reverse clamp is `maxSpeed × reverseFactor` = 0.1 wu/tick |
| `friction` | ×0.96 per tick | `v *= exp(−2.4493 · dt)` | Time constant ≈ 0.41 s |
| `turnRate` | 0.04 rad/tick | 2.4 rad/s (137.5°/s) | Constant above `steerThreshold` |
| `steerThreshold` | 0.01 wu/tick | 0.6 wu/s | Tested post-clamp, pre-friction |
| `bounceFactor` | ×−0.3 on velocity | same | Applied at most once per tick, however many axes clamp |
| `pushDistance` | 0.3 wu | same | Instantaneous collision displacement |
| `hitboxContraction` | 0.2 wu per side | same | Applied to the kart only, not props |

Derived, for reference — not independently tunable:

| Quantity | Value | Notes |
|---|---|---|
| Steady-state forward speed | 0.192 wu/tick (≈11.5 wu/s) | `accel × friction / (1 − friction)`. The post-friction speed never reaches `maxSpeed`, though the pre-friction value converges on it exactly |
| Steady-state reverse speed | 0.096 wu/tick (≈5.8 wu/s) | Half the above |
| Collision velocity result | 0 | Full stop, no reflection |

## World

| `name` | Value |
|---|---|
| `scatterExtent` | 50 wu — props are scattered over ±50 on X and Z |
| `drivableExtent` | 90 wu — the kart is confined to ±90 on X and Z |
| `groundSize` | 200 × 200 wu, centred on the origin |
| `gridSize` / `gridDivisions` | 100 wu across / 20 divisions (5 wu cells) |
| `startClearance` | 8 wu from the origin |
| `cottageClearance` | 20 wu from the origin, for `cottage` only |
| `minPropSeparation` | 3 wu between placed props |
| `attemptBudget` | 3 × requested count |
| `scaleVariation` | ×0.8 – ×1.2 |
| Start/finish band | 10 wu (X) × 2 wu (Z), centred at Z = +5, height 0.02 wu |

## Camera and HUD

| `name` | Value |
|---|---|
| `chaseBack` / `chaseUp` | 8 wu behind, 4 wu above, in the kart's own frame |
| `aimAhead` / `aimUp` | 4 wu ahead, 1 wu above, in the kart's own frame |
| `chaseSmoothing` | factor 0.08/tick ⇒ time constant ≈ 0.2 s |
| `fovBase` / `fovMax` | 75° at rest → 90° at the speed clamp (≈89.4° in practice) |
| Near / far clip | 0.1 / 1000 wu |
| `shakeHorizontal` / `shakeVertical` | ±0.15 wu / ±0.10 wu, one-shot on collision |
| `minimapHalfExtent` / `minimapAltitude` | Parallel projection, half-extent 50 wu, from 100 wu up, near 1 / far 1000 |
| `minimapSize` / `minimapInset` | 200 × 200 px, inset 10 px bottom-left |
| `speedoMax` | 120 — needle is (ratio × 180°) − 90°, readout is floor(ratio × `speedoMax`) |

The speedometer is **cosmetic, not calibrated**. Top speed is 11.5 wu/s ≈ 8.6 m/s ≈ 31 km/h against the 1 wu ≈ 0.75 m anchor, but the dial reads ~115 KM/H. This is deliberate arcade exaggeration — do not "fix" the units.

## Timing

| `name` | Value |
|---|---|
| `countdownStep` | 1.0 s |
| Countdown sequence | READY → 3 → 2 → 1 → **GO! = control released** |
| Total pre-race delay | **4.0 s** from world-ready to control |
| `goLinger` | 0.5 s — the GO! overlay stays up this long *after* control is released |
| `lapRestartDelay` | 0.5 s — `TIME` freezes on the banked lap for this long, then resets |
| `bestFlashDuration` | 1.0 s green, then yellow |
| `lapCrossingThreshold` | 0.01 wu/tick of **+Z** displacement |
| Lap gate | Z ∈ (4, 6), \|X\| < 5, +Z displacement > `lapCrossingThreshold` |

`minLapTime` (5.00 s) was **retired** by `amend-gdd-for-checkpoint-circuit`:
the ordered checkpoint gates replaced it as the farming defence.

## Circuit

| `name` | Value | Notes |
|---|---|---|
| `gateDepth` | 2 wu | Slab thickness, matching the band's depth |
| `gateCrossingThreshold` | 0.01 wu/tick | Same defence as `lapCrossingThreshold`, in gate-forward terms |
| `gatePylonHeight` | 6 wu | Above every prop's normalised height |
| `gateNextColour` | `#FFFF00` | The BEST/needle-tip family |
| `gatePassedColour` | `#00FF00` | The timeValue family |
| `gateIdleColour` | `#888888` | The speedoUnit family |
| `medalGoldColour` | `#FFD700` | |
| `medalSilverColour` | `#C0C0C0` | |
| `medalBronzeColour` | `#CD7F32` | |

Gate widths, positions, and targets are **content**, not tuning — they live
in each circuit's layout file.

---

# Acceptance Checklist

A port is considered faithful when all of the following are demonstrable:

Where a criterion gives a tolerance, that tolerance is normative — "approximately" is not a defence.

1. The game boots into the shipped circuit, to a countdown with no user interaction and no configuration, and hands over control **4.0 s ± 0.1 s** later, on the GO! frame.
2. Every prop stands exactly on the ground — none floating, none sunk — at every random scale.
3. The kart drives in the direction it visually faces, at all headings, forward and reverse.
4. Holding accelerate from rest passes 90% of steady-state speed — dial **103** — within **0.94 s ± 0.05 s**, and the dial first reads **115** at **2.60 s ± 0.05 s** and stays there. Coasting from steady state falls below `steerThreshold` in **1.21 s ± 0.05 s**.
5. Steering is impossible from a standstill and reverses sense when reversing.
6. Hitting a tree stops the kart dead, shoves it clear, and shakes the camera — and the kart can always reverse back out of a **single** prop, at any approach angle. Being pinned between two near-touching props is accepted; Reset Kart frees it.
7. Driving to the boundary produces a soft rebound with grass still visible beyond.
8. The camera lags through turns and settles behind the kart, and the field of view visibly widens with speed.
9. The minimap tracks the kart, stays north-up, shows the marker and heading arrow, and those markers are invisible in the main view.
10. Crossing the white band northbound banks a lap **only when every gate has been passed in order** — with no minimum lap time — freezes `TIME` on it for 0.5 s, flashes a new best in green when appropriate, then restarts the clock. Crossing it southbound under power, or without the course threaded, banks nothing.
11. Releasing focus mid-throttle stops the kart from driving away.
12. Saving and reloading a layout reproduces the identical world, repeatably.
13. Changing `accel`, `friction`, `turnRate`, or `maxSpeed` at runtime alters handling on the next tick, with no restart.
14. A scripted 60-second input sequence replayed at 30, 60, and 144 frames per second ends with the kart **within 0.5 wu** of the same position and **within 0.05 s** of the same lap time.
15. The shipped circuit loads at boot with numbered gates; the next gate is indicated on the gate itself, the HUD counter, and the minimap; a lap that skips any gate refuses to bank; Restart Circuit rebuilds the authored world, returns the kart to the start, and keeps the session best.

---

# Known Deviations in the Reference Build

The specification above is normative. These are places where the original implementation departs from it; a port should follow the specification and not reproduce these.

1. **Frame-rate dependence.** The reference integrates per rendered frame with no delta-time term, so it runs proportionally faster on high-refresh displays. The specification requires frame-rate independence.
2. **Minimap heading arrow offset.** The reference places the heading arrow 90° away from the kart's actual direction of travel, an artifact of the kart's yaw correction being applied to the marker's parent. The specification requires the arrow to indicate true heading.
3. **Layout round-trip scale compounding.** The reference re-normalises each asset on import and then applies the saved scale on top, so an export/import cycle does not reproduce the original sizes. The specification requires the saved scale to be treated as absolute.
4. **Speedometer never reaches full scale.** Because friction is applied after the speed clamp, the achievable speed is 96% of the clamp and the dial tops out at 115 rather than 120. This is accepted behaviour and matches the tuning; do not "fix" it by moving the clamp.
5. **A one-second dead spell after GO!.** The reference displays `GO!` and then withholds control for a further second, for a 5.0 s total pre-race delay. The specification releases control **on** the GO! frame, at 4.0 s, and lets the overlay linger instead.
6. **Lap direction is not actually tested.** The reference gates on the scalar velocity being positive, so a kart driving forward *southbound* through the band banks a lap. The source's own comment — "crossing Z = 5 line, moving in positive Z direction" — shows the directional test was the intent; the specification requires it.
7. **Developer instrumentation is visible in normal play.** The reference ships a tuning panel, a key/velocity/collision readout, and an origin axes gizmo on screen by default. The specification does not define them at all — a port may build whatever instrumentation it likes, but none of it is part of the player-facing HUD. The reference grid is *not* instrumentation: it is part of the intended look and stays.
8. **A dead free-look affordance.** The reference constructs an orbit camera and advertises "Mouse — Look (when stopped)" in the on-screen hints, but never enables the control and never re-enters a non-racing state. The specification has no free-look and no such hint; the fixed pre-race camera is the whole of it.
9. **An unreachable FINISHED state.** The reference declares a fourth game state that is never entered, because the session has no end condition. The specification defines three states. An end-of-session flow is listed under Optional Features.
10. **`minPropSeparation` ignores footprints.** The reference tests centre-to-centre distance only, so two large props can be placed almost touching (0.09 wu apart for a cottage pair) — a gap no kart can drive through, and one that can pin it. The specification keeps the rule as-is for world density and names Reset Kart as the escape; see the Collision feature.
11. **Regeneration can spawn a prop on the kart.** Clearance is measured from the world origin, not from the kart's current position, so regenerating while parked away from the start can drop a prop onto the kart. The specification accepts this: the collision response pushes the kart clear on the following tick, and adding a second clearance test is not required.

---

# Optional Features

These are additional, optional features to consider for specification and implementation. They **should not be implemented** until if and when they are specifically requested.

### 1. Engine and impact audio

* **Requirement:** Position an engine sound source on the kart and modulate its playback rate continuously with the speed ratio, so acceleration audibly rises in pitch and coasting falls away.
* **Requirement:** Trigger a one-shot impact sound at the point of contact on every registered collision, with its volume scaled by the velocity destroyed by the impact.
* **Requirement:** Use spatialised audio so props and impacts are heard from their world positions, with distance attenuation tuned to the 100 wu playfield.

### 2. Particle effects

* **Requirement:** Emit a tyre-dust particle burst from the rear of the kart when acceleration is applied from below the steering threshold.
* **Requirement:** Emit a continuous, speed-proportional exhaust wisp from the kart while under power.
* **Requirement:** Emit a short debris burst at the contact point on collision.

### 3. Boost mechanic

* **Requirement:** Add a boost input that temporarily raises the speed clamp and acceleration for a fixed duration, on a cooldown.
* **Requirement:** Push the field of view beyond its normal ceiling during boost, and return it smoothly afterward, so the effect is felt as well as measured.
* **Requirement:** Show boost availability and cooldown on the HUD.

### 4. Drifting and dynamic handling

* **Requirement:** Introduce a lateral velocity component with its own grip coefficient, so hard cornering at speed produces a controllable slide.
* **Requirement:** Scale the turn rate with speed rather than holding it constant, so low-speed manoeuvring is tight and high-speed cornering is wide.
* **Requirement:** Tie tyre-mark decals and dust emission to the magnitude of lateral slip.

### 5. Checkpoints and a real circuit *(promoted to the specification by `amend-gdd-for-checkpoint-circuit`; see Feature: Checkpoint Circuit)*

* **Requirement:** Define an ordered sequence of checkpoint gates that must each be passed, in order, before a finish-band crossing counts as a lap — replacing the current 5-second minimum with genuine lap validation.
* **Requirement:** Show the next checkpoint's direction on the HUD and highlight it on the minimap.
* **Requirement:** Author the circuit as a layout file so it ships alongside the procedural mode rather than replacing it.

### 6. Ghost replay

* **Requirement:** Record the kart's position and heading throughout the best lap.
* **Requirement:** Replay that recording as a translucent ghost kart during subsequent attempts, synchronised to the current clock.

### 7. Persistent best times

* **Requirement:** Write the best time to durable local storage so it survives a restart.
* **Requirement:** Show a short table of the session's most recent lap times alongside the best.

### 8. Environment progression

* **Requirement:** Add a time-of-day cycle that rotates the sun, shifts its colour and intensity, and re-tints the sky and fog to match.
* **Requirement:** Add a weather variant that alters fog density and ground grip.

### 9. End-of-session flow

* **Requirement:** Add a fourth game state entered on some end condition — a lap target, a time limit, or a quit action — in which the simulation is suspended and a summary is shown.
* **Requirement:** Offer a return path from that state to a fresh countdown without reloading, resetting the clock and the world but preserving the session best.

### 10. Kart customisation

* **Requirement:** Support alternate base-colour maps on the kart material so the vehicle can be recoloured without new geometry.
* **Requirement:** Expose the choice on a pre-race screen, entering the countdown from that screen rather than automatically.
