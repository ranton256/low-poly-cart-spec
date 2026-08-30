# GDD amendment: Checkpoint Circuit

The exact edits to `low-poly-cart-game-design-document.md`, in order of
appearance. Applied verbatim by the implementation's first task; until then
this file IS the draft under review.

---

## Edit 1 — new feature section, inserted after *Lap Detection and Best-Time Tracking*

```markdown
## Feature: Checkpoint Circuit

As a player,
I want an ordered course of visible gates that my lap must thread,
So that a lap time measures driving, not proximity to the finish line.

The game has two modes and one rule for telling them apart: **circuit mode**
is active exactly when the loaded layout carries a `circuit` object (see
Track Layout Persistence); regenerating the world returns to **procedural
mode**. Everything in this feature applies to circuit mode; procedural mode
is unchanged by it.

### Scenario: Defining a gate

* **Given** a loaded circuit
* **Then** each gate is a directed segment on the ground: a centre **(X, Z)**,
  a yaw, and a width, in world units
* **And** a gate is **passed** on a tick when, in the gate's own frame, the
  kart's position lies within half the width of the centre laterally and
  inside a slab `gateDepth` deep ahead of the segment, while the component
  of the tick's **step-5 integration** along gate-forward exceeds
  `gateCrossingThreshold`
* **And** the test runs at the same stage as lap detection, observes only,
  and therefore shares the band's immunities: a push-out or boundary shove
  cannot pass a gate, and a kart heading backwards through one cannot either

### Scenario: Progress is a cursor, not a checklist

* **Given** gates numbered **1..N** in file order and a progress cursor
  starting at **1**
* **When** the kart passes the gate the cursor names
* **Then** the cursor advances by one
* **And** passing any *other* gate — already passed, not yet due, or the
  right gate backwards — changes **nothing**: no reset, no voided lap, no
  message; the only cure for a missed gate is to go and pass it
* **And** banking a lap returns the cursor to **1**

### Scenario: The band banks only a threaded lap

* **Given** circuit mode
* **When** the kart crosses the start/finish band satisfying every condition
  of *Completing a valid lap*
* **Then** the lap banks **only if the cursor has passed the final gate**;
  otherwise the crossing changes nothing and the clock keeps running
* **And** the `minLapTime` condition is **not applied in circuit mode** —
  ordered gates are the farming defence, and they are a better one

### Scenario: Reset Kart and circuit progress

* **Given** a lap in progress with some gates passed
* **When** the player uses Reset Kart
* **Then** the cursor is untouched — Reset Kart restores the start pose and
  **nothing else**, exactly as Runtime Tuning and Player Actions states
* **And** no shortcut results: the band still refuses to bank until the
  remaining gates are passed

### Scenario: Leaving circuit mode

* **Given** circuit mode
* **When** the player regenerates the world, or loads a layout without a
  `circuit` object
* **Then** the game returns to procedural mode: the gates and their HUD and
  minimap presence are removed, and lap detection reverts to the
  `minLapTime` rule
* **And** the clock restarts and the cursor state is discarded

### Scenario: Best times belong to their circuit

* **Given** laps banked in more than one context during a session
* **Then** each session best is kept **per context** — one per circuit
  `name`, one for procedural mode — and the `BEST` readout always shows the
  best of the *current* context
* **And** medal targets (below) are compared only against laps of their own
  circuit

### Scenario: Medal targets

* **Given** a circuit whose file declares `bronze`, `silver`, and `gold`
  target times
* **When** a lap banks at or under a target
* **Then** the held `TIME` readout is joined, for the hold window, by the
  name of the best target met, in that medal's colour (`medalGoldColour`,
  `medalSilverColour`, `medalBronzeColour`)
* **And** a circuit may omit targets, in which case nothing extra is shown

### Scenario: What a gate looks like

* **Given** a loaded circuit
* **Then** each gate is drawn as generated geometry in the band's visual
  family — two unlit pylons of height `gatePylonHeight` at the segment's
  ends, a translucent ground stripe between them, and an overhead chevron —
  never as a scatterable prop, so course furniture and obstacles cannot be
  confused
* **And** gates are **not** collision obstacles: the kart drives through
  pylons unimpeded, as it does through the band
* **And** the gate the cursor names is shown in `gateNextColour` with a
  pulse animated on the **simulation clock**; gates already passed this lap
  show `gatePassedColour`; gates not yet due show `gateIdleColour`
* **And** each gate shows its number above the chevron, facing the camera

### Scenario: Finding the next gate

* **Given** circuit mode
* **Then** the HUD timer block gains a `GATE n/N` line
* **And** when the next gate is off-screen, a chevron at the screen edge
  points along the shortest turn toward it — fog ends at `fogEnd` and the
  playfield is wider than that; the player must never need to memorise the
  course to find it
* **And** the minimap shows every gate as a marker on the marker layer, the
  next gate emphasised (larger and in `gateNextColour`), with the same
  invisibility-in-the-main-view guarantee the kart markers carry
```

---

## Edit 2 — *Completing a valid lap* (Lap feature), amended conditions

The scenario's `minLapTime` given becomes mode-dependent. Replace:

> * **And** at least `minLapTime` has elapsed on the current clock

with:

> * **And** — in procedural mode — at least `minLapTime` has elapsed on the
>   current clock, **or** — in circuit mode — every gate has been passed in
>   order (see *Checkpoint Circuit*)

and in the *Rejecting a crossing* outline, amend the **Too soon** row:

> | Too soon | in procedural mode, the clock has been running for less than
>   `minLapTime`; in circuit mode, the progress cursor has not passed the
>   final gate — the player cannot farm times by shuttling across the line
>   in either mode |

## Edit 3 — *Track Layout Persistence*, layout version 2

Append to the feature:

```markdown
### Scenario: A layout that carries a circuit

* **Given** a layout file with `"version": 2`
* **Then** it may carry, beside `props`, a `circuit` object: a `name`, an
  ordered `gates` list — each `{ "position": [X, Z], "yaw": r,
  "width": w }` — and an optional `targets` object with `bronze`, `silver`,
  and `gold` times in seconds
* **And** a version-1 file (or a version-2 file without `circuit`) is a
  procedural-mode layout, exactly as before
* **And** loading a circuit file arms circuit mode with its curated props —
  the file is the guarantee that no prop blocks a gate mouth, which is why
  gates and props travel together
* **And** saving while in circuit mode writes the circuit object back out
  unchanged, so the round-trip guarantees extend to it
```

## Edit 4 — HUD feature table, two rows amended/added

* The **Title & controls** row's hint text is amended to name the
  objective: the control hints read `W/S drive · A/D steer · G regenerate
  world · cross the line to lap` in procedural mode and `W/S drive ·
  A/D steer · follow the gates` in circuit mode.
* A new row **Gate counter**: within the timer block, `GATE n/N` in the
  timer label style, circuit mode only; plus the screen-edge chevron for an
  off-screen next gate.

## Edit 5 — Tuning Constants, new **Circuit** table

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

(Gate widths, positions, and targets are **content**, not tuning — they live
in each circuit's layout file.)

## Edit 6 — Acceptance Checklist

Item 10 is amended to:

> 10. In procedural mode, crossing the white band northbound after 5 s banks
>     a lap, freezes `TIME` on it for 0.5 s, flashes a new best in green
>     when appropriate, then restarts the clock; crossing it southbound
>     under power banks nothing. In circuit mode the same crossing banks
>     **only** when every gate has been passed in order — and then with no
>     minimum time.

New item 15:

> 15. Loading the shipped circuit shows numbered gates; the next gate is
>     indicated on the gate itself, the HUD counter, and the minimap; a
>     lap that skips any gate refuses to bank; a lap that threads all of
>     them banks without the 5-second minimum.

## Edit 7 — Optional Features

Item 5's heading gains: *(promoted to the specification by
amend-gdd-for-checkpoint-circuit; see Feature: Checkpoint Circuit)* — the
body text is retained for the historical record, matching how the section
already treats implemented requests.
