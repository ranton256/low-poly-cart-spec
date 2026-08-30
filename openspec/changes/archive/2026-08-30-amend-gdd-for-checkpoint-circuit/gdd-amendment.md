# GDD amendment: Checkpoint Circuit (circuit-only)

The exact edits to `low-poly-cart-game-design-document.md`, in order of
appearance. Applied verbatim by the implementation's first task; until then
this file IS the draft under review.

---

## Edit 1 — *Session Bootstrap and Asset Normalisation*, boot source amended

The world built at boot is no longer a seeded scatter: the game loads the
**shipped circuit layout** (see Track Layout Persistence, version 2). The
existing bootstrap verdict is unchanged in shape — a circuit that fails to
load or validate is the same terminal LOADING state with a visible message,
never a countdown into a broken world.

## Edit 2 — *Procedural World Generation*: scatter becomes authoring machinery; G is re-bound

The feature's scatter rules (counts, separation, scale variation, seeding)
remain **normative for authoring**: they produced the shipped circuit's
field, layout authoring starts from them, and the port's tools and tests
continue to pin them. What changes is the player-facing action. The
*Regenerating the world on demand* scenario is replaced by:

```markdown
### Scenario: Restarting the circuit

* **Given** the player invokes the **Restart Circuit** action (the binding
  formerly known as Regenerate World)
* **When** the restart runs
* **Then** every prop is removed and its resources released, and the world
  is rebuilt from the loaded circuit layout — the same authored arrangement,
  not a fresh scatter
* **And** the kart returns to the start pose, the gate cursor returns to
  gate 1, and the lap clock restarts from **0.00**
* **And** the session's per-circuit best time is kept
* **And** the race state does not leave **RACING** — no fresh countdown; the
  restart is instant
```

## Edit 3 — new feature section, inserted after *Lap Detection and Best-Time Tracking*

```markdown
## Feature: Checkpoint Circuit

As a player,
I want an ordered course of visible gates that my lap must thread,
So that a lap time measures driving, not proximity to the finish line.

The game always plays a circuit. The shipped circuit is the default world,
other circuits load through Track Layout Persistence, and there is no
gateless mode: a layout the game will play always carries gates.

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

* **When** the kart crosses the start/finish band satisfying every other
  condition of *Completing a valid lap*
* **Then** the lap banks **only if the cursor has passed the final gate**;
  otherwise the crossing changes nothing and the clock keeps running
* **And** there is no minimum lap time: the ordered gates are the farming
  defence, and `minLapTime` is retired

### Scenario: Reset Kart and circuit progress

* **Given** a lap in progress with some gates passed
* **When** the player uses Reset Kart
* **Then** the cursor is untouched — Reset Kart restores the start pose and
  **nothing else**, exactly as Runtime Tuning and Player Actions states; a
  full fresh attempt is Restart Circuit's job
* **And** no shortcut results: the band still refuses to bank until the
  remaining gates are passed

### Scenario: Best times belong to their circuit

* **Given** laps banked on more than one circuit during a session
* **Then** each session best is kept per circuit `name`, and the `BEST`
  readout always shows the best of the circuit being played
* **And** medal targets are compared only against laps of their own circuit

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

* **Then** the HUD timer block gains a `GATE n/N` line
* **And** when the next gate is off-screen, a chevron at the screen edge
  points along the shortest turn toward it — fog ends at `fogEnd` and the
  playfield is wider than that; the player must never need to memorise the
  course to find it
* **And** the minimap shows every gate as a marker on the marker layer, the
  next gate emphasised (larger and in `gateNextColour`), with the same
  invisibility-in-the-main-view guarantee the kart markers carry
```

## Edit 4 — *Completing a valid lap* (Lap feature), amended conditions

Replace:

> * **And** at least `minLapTime` has elapsed on the current clock

with:

> * **And** every gate has been passed in order — the progress cursor is
>   past the final gate (see *Checkpoint Circuit*)

and in the *Rejecting a crossing* outline, replace the **Too soon** row:

> | Course not threaded | the progress cursor has not passed the final gate —
>   the player cannot farm times by shuttling across the line, because the
>   line alone is never enough |

The *Persisting the best time for the session* scenario's trigger list is
reworded for the renamed action ("when the circuit is restarted or the kart
is reset, the best is retained").

## Edit 5 — *Runtime Tuning and Player Actions* / *Input Handling*

The **Regenerate World** action is renamed **Restart Circuit** wherever it
appears (its binding stays unspecified, as before). Hint text (HUD feature,
*Title & controls* row) becomes:

> `W/S drive · A/D steer · G restart · follow the gates`

## Edit 6 — *Track Layout Persistence*, layout version 2

Append to the feature:

```markdown
### Scenario: A layout is a circuit

* **Given** a layout file with `"version": 2`
* **Then** it carries, beside `props`, a `circuit` object: a `name`, an
  ordered `gates` list — each `{ "position": [X, Z], "yaw": r,
  "width": w }` — and an optional `targets` object with `bronze`, `silver`,
  and `gold` times in seconds
* **And** the file is the guarantee that no prop blocks a gate mouth, which
  is why gates and props travel together
* **And** a file without a `circuit` object — version 1 included — is
  **refused on load with a named error**: such files remain valid authoring
  artifacts for building circuits from, but the game does not play them
* **And** saving writes the loaded circuit object back out unchanged, so
  the round-trip guarantees extend to it
```

## Edit 7 — *Heads-Up Display* feature table

A new row **Gate counter**: within the timer block, `GATE n/N` in the timer
label style; plus the screen-edge chevron for an off-screen next gate. The
*Title & controls* row's hint text as in Edit 5.

## Edit 8 — Tuning Constants

`minLapTime` is **retired**: its row is removed from the timing table and a
one-line note under the table records that the checkpoint circuit replaced
it at this amendment. A new **Circuit** table:

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

## Edit 9 — Acceptance Checklist

Item 1 gains the new boot source in passing ("boots **into the shipped
circuit** to a countdown with no user interaction…"). Item 10 is amended to:

> 10. Crossing the white band northbound banks a lap **only when every gate
>     has been passed in order** — with no minimum lap time — freezes
>     `TIME` on it for 0.5 s, flashes a new best in green when appropriate,
>     then restarts the clock. Crossing it southbound under power, or
>     without the course threaded, banks nothing.

New item 15:

> 15. The shipped circuit loads at boot with numbered gates; the next gate
>     is indicated on the gate itself, the HUD counter, and the minimap; a
>     lap that skips any gate refuses to bank; Restart Circuit rebuilds the
>     authored world, returns the kart to the start, and keeps the session
>     best.

## Edit 10 — Optional Features

Item 5's heading gains: *(promoted to the specification by
amend-gdd-for-checkpoint-circuit; see Feature: Checkpoint Circuit)* — the
body text is retained for the historical record.

---

## Edits 11–12 — consequential sites found at application, recorded per the drift rule

**Edit 11** — *Collision Detection and Response*, the prop-on-kart scenario:
its Given/When referenced regeneration; reworded to the load-a-circuit case
(title kept as a stable identifier). The acceptance — the response frees the
kart, no second clearance test required — is unchanged.

**Edit 12** — *Game Overview*: "no lap track" and "at least five seconds
after the clock started" contradicted the amendment; the overview now names
the gate course and the threaded-lap rule, and describes worlds as authored
layout files. "Drive forever" and the session shape are untouched.
