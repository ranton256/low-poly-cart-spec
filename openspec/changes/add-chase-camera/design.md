## Context

See `proposal.md` — *Why*. What shapes the approach:

- **A10 is open and this change owns it.** The document states the easing per tick
  and the camera update per frame; they are the same sentence at 60 fps and
  different behaviour everywhere else.
- **The composition root already has the shape this needs.** `add-kart-view-…`
  settled that Godot's `_physics_process` is the fixed-step accumulator (its design
  D2a) and that the root steps the simulation exactly once per call. "Per tick"
  therefore has an unambiguous home: immediately after `sim.step()`.
- **The kart view interpolates between simulation states.** Whatever the camera
  does about interpolation has to compose with that, not fight it.
- **The document gives numbers, not adjectives.** `chaseSmoothing` 0.08/tick with a
  stated time constant of ≈0.2 s; settling "within roughly half a second"; the
  field of view running 75° → 90° with ≈89.4° at the achievable top speed. All
  checkable.
- **`world-presentation` requires the placeholder be declared temporary.** This is
  the change that was named as replacing it, so that requirement gets its other
  half rather than being quietly outgrown.

## Goals / Non-Goals

**Goals:**
- A camera whose lag is the same on any display.
- Acceptance item 8 as a measurement.
- The placeholder retired from the running game without breaking the world scene's
  own captures.

**Non-Goals:**
- The collision shake. It belongs to M3, which introduces collisions.
- The minimap camera (M5) and the full frame-ordering scenario (M5).
- Re-opening A11. This change should *report* what the specified camera sees at the
  boundary, because M6 needs that, but deciding it is M6's.

## Decisions

### D1 — The camera is a pure module in `scripts/core/`, stepped after `sim.step()`

`scripts/core/chase_camera.gd` holds position, aim and field of view as plain
scalars and exposes a `step(kart_state)`. The composition root calls it once per
tick, immediately after advancing the simulation. A thin view node reads it and
applies it to a `Camera3D`.

*Why the core.* The easing is a fixed-step recurrence, exactly like the physics,
and the properties the document states about it are numbers — a time constant, a
settling time, a curve. What `scripts/core/` adds is **enforcement**: it is the
only directory the boundary gate polices, so nothing here can quietly acquire a
`Node`, read a file, or start easing per frame.

*Corrected.* This paragraph first said the core was "the only place in this project
where a per-tick recurrence can be driven and asserted with no scene loaded". That
is false — any `RefCounted` module is steppable headless wherever it sits — and the
alternatives below had already said so. Review found the false version repeated
into `CONSTRAINTS.md`, `proposal.md` and the module's own header, which is how a
rationalisation spreads: it reads well, so it gets copied.

*What this costs.* The camera is cosmetic, and `scripts/core/` is otherwise the
simulation. This is a real widening of what "core" means and it should be said out
loud rather than discovered later. The boundary that matters is unchanged: no
engine types, no `Node`, no file access, constructible and steppable from a test.
The rule is not "core is gameplay" but "core is the fixed-step, engine-free part",
and the camera qualifies on both.

*Alternatives considered.* **A `Node3D` easing in `_physics_process`** — the
obvious Godot idiom, and it keeps the core about the kart; rejected because the
settling-time assertion then needs a scene tree, and because a camera that eases
inside a node is one refactor away from easing in `_process`. **A view-layer module
outside `scripts/core/`** — pure and testable without widening the core; rejected
narrowly, because the boundary gate does not police that directory and the thing
most worth protecting here is that nothing ever eases per frame.

### D2 — A10 is settled: the easing is per tick, and "per frame" is the incidental half

The frame-ordering scenario's **sequence** is normative — physics, then camera,
then minimap, then HUD — and its **cardinality** is incidental. The camera is
updated after the frame's ticks, however many there were.

*Why this reading.* The *Reference Tick* section requires frame-rate independence
in general terms and calls a naive per-frame port non-conformant. A per-frame ease
gives a time constant of 0.4 s at 30 fps and 0.083 s at 144 fps against a stated
0.2 s, so reading the ordering scenario literally contradicts a stronger and more
general statement elsewhere in the same document.

*What is given up.* At a display rate slower than the tick rate the camera is
updated more than once per frame, which the ordering scenario, read literally, does
not describe. That is the cost, and it buys a camera that behaves identically
everywhere.

*Alternatives considered.* **Ease per frame with a delta-compensated factor** —
`1 - pow(1 - k, delta * 60)` reproduces the time constant at any rate and honours
the ordering scenario's cardinality; rejected because it makes the camera read
frame delta, which CONSTRAINTS §4 Architectural boundaries forbids anywhere the simulation can see, and
because it replaces an exact recurrence with a floating-point approximation of one
for no gain this project can measure.

### D3 — The camera is NOT interpolated between ticks

The view applies the camera's stepped position directly. The kart is interpolated;
the camera is not.

*Why.* The camera is already a smoothing filter over the kart's motion — that is
its entire job — with a time constant of 0.2 s, twelve ticks. Interpolating it adds
a second, much shorter smoothing of a quantity that is already smooth, and the
visible difference at 60 Hz is a fraction of a pixel. What it would cost is
clarity: two smoothings, only one specified, and a settling-time measurement that
no longer matches what is drawn.

*The consequence, stated:* at display rates well above 60 fps the camera position
updates in 60 Hz steps while the kart moves every frame, so the kart can shift
slightly within the frame relative to the camera. At the document's speeds this is
sub-pixel. If it ever shows, interpolating the camera is the fix, and it should be
a change with a capture behind it rather than a precaution taken now.

*Alternatives considered.* **Interpolate the camera as well** — symmetric with the
kart and arguably more correct at high refresh rates; rejected above, and revisited
if a capture ever shows it.

### D4 — The placeholder stays in `world.tscn`; the chase camera lives in `main.tscn`

`world.tscn` keeps its placeholder viewpoint so it remains loadable and capturable
on its own with nothing stepping — a committed requirement, and what
`kart_front_view.tscn` and `kart_overhead_view.tscn` depend on. `main.tscn` adds
the chase camera and makes it current, so the running game looks through the
specified one.

*Alternatives considered.* **Delete the placeholder** — tidier; rejected because it
would break the world scene's own captures and force `world-presentation`'s "renders
with nothing stepping" scenario to be modified for no behavioural reason.

### D5 — Settling is measured against a stated threshold, not eyeballed

"Settles behind the kart within roughly half a second" becomes: after the turn
ends, the angle between the camera's offset and the kart's reversed heading falls
below a stated threshold within the stated time. The threshold is written down with
its reasoning, and the test reports the measured time either way.

*Why say this at all.* "Roughly half a second" invites a test that passes because
its tolerance was chosen after seeing the answer. Fixing the threshold first, and
reporting the measurement, is the same discipline the exposure work used — and the
reason that work survived three reviews.

## Risks / Trade-offs

- **Widening `scripts/core/` to hold cosmetic state.** → Stated in D1 rather than
  slipped in. The test for whether this was right is whether anything else cosmetic
  follows it in; if the HUD starts asking, the answer is no.
- **A settling threshold chosen to pass.** → Fixed and committed before the
  measurement, with the measured value printed on every run.
- **The FOV curve is trivial and might be tested trivially.** A test asserting
  `fov == fovBase + ratio * (fovMax - fovBase)` re-implements the formula and
  proves nothing. → Assert the document's own anchors instead: the resting value,
  the ≈89.4° at achievable top speed, monotonicity, and the clamp.
- **The camera could mask a kart-orientation error.** A camera that always sits
  behind the kart makes a tail-first kart look almost normal. → A6 is already
  settled with three witnesses and a committed capture from a fixed viewpoint;
  worth knowing that this change removes the framing in which the error was visible.

## Open Questions

- What the specified camera sees at the drivable boundary, which A11 needs. This
  change should capture it and say, but deciding is M6's and nothing here depends
  on the answer.
