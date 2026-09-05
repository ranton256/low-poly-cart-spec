# GDD amendment: Audio Feedback

The exact edits to `low-poly-cart-game-design-document.md`, in order of
appearance. Applied by the implementation's first task after owner approval;
until then this file IS the draft under review.

---

## Edit 1 — new feature section, inserted after *Feature: Checkpoint Circuit*

```markdown
## Feature: Audio Feedback

As a player,
I want the game to tell me with sound what just happened and how fast I am,
So that consequential events register without my eyes leaving the road.

*(Added by `amend-gdd-for-audio-cues`; this feature has no reference build —
the JS reference is silent — and is specified fresh. Known Deviations does
not apply to it.)*

### Scenario: The simulation publishes cues as data

* **Given** any tick in which a sounding event occurs
* **Then** the simulation appends to an ordered per-tick cue list a record of
  the cue's **id**, its **volume** (0–1), and — for spatial cues — its world
  position; the list is part of simulation state and appears in the
  determinism summary
* **And** the simulation itself never touches an audio API: views drain the
  list each frame and play it, exactly as every other view reads state
* **And** a headless run therefore produces the complete cue stream with no
  sound hardware at all

### Scenario: The engine note follows the speed ratio

* **Given** the state is RACING and audio is not muted
* **Then** a looping engine source plays on the kart with pitch
  `enginePitchBase + enginePitchSpan × ratio` and volume
  `engineVolumeBase + engineVolumeSpan × ratio`, where `ratio` is the same
  post-friction speed ratio the speedometer and camera read
* **And** both track the ratio continuously on the simulation clock, so
  acceleration audibly rises and coasting falls away
* **And** the engine source is silent while LOADING and through the
  countdown, and fades with the ratio rather than cutting

### Scenario: An impact is heard once, as hard as it hit

* **Given** a collision resolves at stage 7, destroying velocity `v`
* **Then** exactly one `impact` cue is emitted that tick, at volume
  `min(1, |v| / impactFullScale)` — a top-speed hit is full scale, a nudge
  is a tap — positioned at the struck prop
* **And** the pinned-between-props oscillation emits at most one impact cue
  per `impactRateLimit` — a pin is one event, not a drum roll

### Scenario: The race speaks at its moments

* **Then** each countdown step 3, 2, 1 emits `countdown_tick` and GO! emits
  the distinct `countdown_go`, on their exact ticks
* **And** banking a lap emits `lap_banked`; a new session best emits
  `new_best` as well; a medal lap emits its `medal` cue with the readout
* **And** passing the gate the cursor names emits `gate_passed`; the
  boundary rebound emits `rebound`
* **And** every volume above is a named constant in the Audio table

### Scenario: What must NOT sound

* **Then** a boundary rebound never plays the `impact` cue — the two are
  different physics and must be told apart by ear
* **And** an out-of-order, repeated, or backwards gate pass — which changes
  nothing — sounds like nothing
* **And** no cue of any kind is emitted in LOADING, and a terminal LOADING
  failure is silent
* **And** losing window focus mid-throttle emits nothing: the kart coasting
  down is the engine note falling, not an event
* **And** Reset Kart is silent — it is specified as the start pose and
  NOTHING else, and a sound is not nothing

### Scenario: Space is audible

* **Given** a spatial cue (`impact`, `gate_passed`, `rebound`)
* **Then** it is heard from its world position with distance attenuation
  reaching silence by `audioMaxDistance`, tuned to the 100 wu playfield
* **And** the engine note and the race-moment cues (`countdown_*`,
  `lap_banked`, `new_best`, `medal`) are non-spatial

### Scenario: Mute

* **Given** the player presses the **Mute** action (bound to `M`)
* **Then** all audio output toggles off or on; the cue stream itself is
  unaffected — the simulation keeps publishing, the view keeps score
* **And** the state is session-only: a fresh boot is always unmuted, and no
  settings surface exists or is implied

### Scenario: The cue stream is deterministic

* **Given** the same tick-timed input sequence (ambiguity A14's sense of
  "replayed")
* **Then** the cue stream — ids, order, tick timestamps, and volumes — is
  byte-identical across runs and across render rates
```

## Edit 2 — *Input Handling*: the Mute action

Add to the bound-actions list:

> * **And** a **Mute** action exists, bound to `M`, toggling all audio
>   output *(added by `amend-gdd-for-audio-cues`)*

## Edit 3 — HUD *Title & controls* hint text

The hint line becomes:

> `W/S drive · A/D steer · G restart · M mute · follow the gates`

## Edit 4 — Tuning Constants, new **Audio** table

| `name` | Value | Notes |
|---|---|---|
| `enginePitchBase` | 0.8 | Pitch scale at rest |
| `enginePitchSpan` | 0.7 | Pitch reaches 1.5 at full ratio |
| `engineVolumeBase` | 0.25 | |
| `engineVolumeSpan` | 0.35 | Volume reaches 0.6 at full ratio |
| `impactFullScale` | 0.24 wu/tick | The steady top speed; a full-speed hit is volume 1 |
| `impactRateLimit` | 0.25 s | At most one impact cue per this window while pinned |
| `reboundVolume` | 0.4 | |
| `countdownTickVolume` | 0.8 | |
| `countdownGoVolume` | 1.0 | |
| `lapBankedVolume` | 0.9 | |
| `newBestVolume` | 1.0 | |
| `gatePassedVolume` | 0.7 | |
| `medalVolume` | 1.0 | |
| `audioMaxDistance` | 120 wu | Spatial cues silent beyond this |
| `masterVolume` | 1.0 | The mute toggle multiplies output by 0 or this |

## Edit 5 — Acceptance Checklist, new item 16

> 16. A scripted run's cue stream — ids, order, tick timestamps, and
>     volumes — is identical at 30, 60, and 144 frames per second; the
>     engine note's pitch tracks the speed ratio between its named
>     endpoints; a full-speed collision sounds at full scale and a boundary
>     rebound never plays the impact cue.

## Edit 6 — Optional Features

Item 1's heading gains: *(promoted to the specification by
`amend-gdd-for-audio-cues`; see Feature: Audio Feedback)* — body retained
for the historical record.
