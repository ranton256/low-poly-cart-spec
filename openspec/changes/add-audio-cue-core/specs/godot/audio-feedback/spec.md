# godot/audio-feedback — delta for add-audio-cue-core

## ADDED Requirements

### Requirement: Cues are simulation records emitted at their exact stages

The core SHALL keep a per-tick ordered cue list (id, volume from the Audio
table by name, optional world position), cleared at tick start and appended
only by the stage that owns each event: countdown boundaries and GO by the
race state, rebound by stage 6, impact by stage 7 (volume scaled by the
velocity destroyed, positioned at the struck prop, at most one per
`impactRateLimit`), gate/lap/best/medal by stage 8. The stream — ids, tick
timestamps, volumes — SHALL join the determinism summary. No audio API
appears in the core (the standing banned-symbols gate is the enforcement).

#### Scenario: A full-speed hit is full scale, a nudge is a tap

- **WHEN** collisions destroy the steady top speed and a tenth of it
- **THEN** the impact cues carry volume 1.0 and ~0.1, at the struck prop

#### Scenario: A pin is one event

- **WHEN** the two-prop pin oscillates for a second
- **THEN** at most one impact cue is emitted per `impactRateLimit` window

### Requirement: Silence keeps its promises

The core SHALL emit nothing for: a boundary rebound's impact (rebound has
its own id), a gate pass the cursor ignores, any tick in LOADING (a failed
boot included), the tick focus is lost, and Reset Kart. Each promise SHALL
be covered by a test that fails if the forbidden emission is added.

#### Scenario: The rebound is not an impact

- **WHEN** the kart rebounds off the boundary at speed
- **THEN** the tick's cues contain `rebound` and do not contain `impact`

#### Scenario: The ignored pass is silent

- **WHEN** the kart passes a gate the cursor does not name
- **THEN** the tick emits no cue at all
