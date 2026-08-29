## Context

See `proposal.md` — *Why*. What shapes the approach:

- **The core is done and must stay untouched.** `Sim.step()`, the boundary, the input model and
  the normalisation contract were built and proved in M1. This change drives them; it does not
  reopen them.
- **`begin_frame()` already exists and is empty.** `add-determinism-and-coverage-harness` added
  it as the composition root's seam, precisely so that the replay harness could fail if
  frame-dependence ever reached the core. This change is what gives it a caller.
- **§3 states the axis.** *"The kart's authored long axis is its local X."* The §1 inventory
  agrees: the authored box is 2.000 × 1.019 × 1.868, and X is the longest horizontal axis. So
  the axis is not in doubt. The **sign** is: an axis-aligned box is symmetric, and "+90°" is
  stated in a frame this engine does not share.
- **§3 also states the answer.** Final footprint 2.36 × 2.20, height 1.20. Those are the
  document's numbers, which makes them the independent oracle this project has otherwise
  lacked — every other check bottoms out in `tuning.json`, which is our transcription.
- **The world is static and must stay checkable that way.** `world-presentation` requires that
  `scenes/world.tscn` render with nothing stepping.

## Goals / Non-Goals

**Goals:**
- A drivable kart whose motion matches its facing, with the sign of that facing evidenced.
- Frame-rate independence demonstrated at the level of the running game, not just the core.
- Input that cannot stick.

**Non-Goals:**
- The chase camera, its easing and its FOV curve. The placeholder viewpoint stands.
- Collision, props, lap timing, the state machine, the HUD.
- The effects of `R` and `P`. Bound here, implemented in M7.
- Settling **A10**. The accumulator this change builds is what makes "per tick" meaningful for
  the camera, but the camera is where the question is answered.

## Decisions

### D1 — The composition root is a script on `main.tscn`, and `world.tscn` stays static

`main.tscn` instantiates `world.tscn` and adds the root plus the kart view. The world scene
keeps no script of its own beyond the builder and remains loadable and capturable on its own.

*Why it matters beyond tidiness:* `world-presentation`'s scenario "The scene renders with
nothing stepping" is a committed requirement. If the root lived in `world.tscn`, that
requirement would become false and would have to be modified — a spec change caused by a
filing decision rather than by a behaviour change.

*Alternatives considered.* **An autoload singleton** — the usual Godot idiom for a game root;
rejected because an autoload runs for every scene including the test scenes, so suites would
start acquiring a simulation they did not ask for. **The root inside `world.tscn`** — fewer
files; rejected for the reason above.

### D2 — Manual interpolation with `Engine.get_physics_interpolation_fraction()`, not Godot's built-in

The view reads the previous and current simulation states and lerps between them by the engine's
reported fraction.

*Why not the built-in.* Godot 4's physics interpolation works by capturing each node's transform
across physics frames and interpolating the node. It would work here — but it interpolates
*nodes*, and the thing being interpolated in this project is *simulation state*, which is not a
node and never will be. The kart view is a function of `(pos_x, pos_z, yaw)`; letting the engine
interpolate a transform we derived from those values puts a second, invisible source of truth
between the simulation and the screen. It also binds `add-chase-camera`: a camera eased per tick
in the core and then interpolated by the engine is smoothed twice, and the second smoothing is
one nobody specified.

*Alternatives considered.* **Built-in physics interpolation** — less code and handles
rotation via proper slerp; rejected above, and the roadmap already names the manual route.
**No interpolation** — the simulation runs at 60 Hz and most displays are 60 Hz; rejected
because it is only true on the machine you tested, and acceptance item 14 exists because this
project does not accept that argument anywhere else.

### D2a — AMENDED: the fixed step is GODOT'S loop, not one we build on top

D2 above named `Engine.get_physics_interpolation_fraction()` without saying which
loop it describes, and implementation made the gap obvious: that call reports the
fraction of *Godot's* physics tick. Running our own accumulator alongside it gives
two fixed-step loops, and the engine's fraction describes the wrong one.

**Adopted: `_physics_process` is the accumulator.** It steps the simulation exactly
once per call, at the rate `project.godot` pins. Godot's main loop already does what
the design document's *Reference Tick* section asks — accumulate real elapsed time,
run whole fixed steps, carry the remainder — and `physics_ticks_per_second = 60` and
`physics_jitter_fix = 0` are pinned precisely so that loop is authoritative. This is
also what `godot/CLAUDE.md` already states the project does: `_physics_process` is
used "only because it is the fixed-rate callback".

**What this costs, stated plainly.** The accumulator is no longer ours, so its
behaviour is not ours to test — a suite driving synthetic elapsed times would be
testing Godot. Frame-rate independence now rests on three things instead of one: the
pinned settings, the engine's documented fixed-step loop, and the replay harness,
which already proves at the core that state depends on the sequence of steps and not
on how they are grouped.

**What this buys, and it is not nothing.** A cross-check that does not exist today:
`project.godot`'s `physics_ticks_per_second` must equal the core's own
`TICKS_PER_SECOND`. Those are two independent declarations of the same rate, in two
files, and nothing currently notices if they diverge — at which point every timing
figure in the design document silently stops applying.

*Alternatives reconsidered.* **Our own accumulator in `_process`** — we would own and
test the carry logic directly, and the spec's "leftover time is carried" would be
verifiable by mutation; rejected because it makes the pinned physics settings
decorative and puts a second fixed-step loop in a project whose whole determinism
story rests on there being one.

**Consequence for `begin_frame()`.** Godot runs physics steps *before* `_process`
within a frame, so a per-frame entry point called from `_process` fires after that
frame's steps. `sim.gd` documents it as "before that frame's ticks", which was
written against the batch model `replay_test.gd` uses. The comment is corrected
rather than the code contorted: what the seam is for is being *once per rendered
frame*, which is where frame-dependence would enter; its position relative to the
steps is not what makes it a seam.

### D3 — Yaw: axis from the bounds, sign from a capture, corroborated by the mesh's own asymmetry

The correction is `KART_YAW_CORRECTION`, one constant, computed at import from the model's
bounds:

1. The **axis** is the longer horizontal extent of the authored bounding box — §3 says it is
   local X, and this derives rather than assumes it, so a re-exported model with a different
   authored orientation fails loudly instead of driving sideways.
2. The **sign** is fixed by a committed capture showing the driver and steering wheel facing
   world forward, which is the cue §4 itself names.
3. A **vertex-centroid offset** along that axis is measured and committed as a second witness:
   a kart's mass is not symmetric front-to-back, so the centroid sits off centre in a direction
   that identifies the nose without reference to the capture.

*Why all three.* The 16-heading test cannot do this job — it compares travel against a nose
direction derived from the same constant, so a sign error makes both sides wrong together and
the test agrees with itself. This is the tautology class this project has already been rejected
for twice (a kart known-answer test whose input was already the answer; a clamp test that held
whether or not the clamp existed). Writing it down here so the test can state its own limit
rather than implying a strength it lacks.

*Alternatives considered.* **Transcribe +90°** — simplest, and the document does say it;
rejected because it is stated in the reference build's frame, and A6 exists because that frame
differs. **Derive the sign from bounds alone** — impossible: an axis-aligned box is symmetric.
**Trust the centroid alone** — rejected as the sole authority: it is a heuristic about how this
model happens to be built, and if a future asset were symmetric it would silently give a
coin-flip. It is a second witness, not a first.

### D4 — Conformance is checked against the design document, not against `tuning.json`

A committed tool extracts the kart's authored bounding box from §1 and its final dimensions and
footprint from §3, and asserts the built kart against those.

*Why this and not another `world_test`-style check.* `tests/world_test.gd` verifies that the
scene agrees with `tuning.json` — it reads the same file the scene reads, so it catches a scene
that ignores its data and cannot catch data that misreads the document. That gap is fine for
values `check_tuning_transcription.py` already covers, and the kart's final footprint is not one
of them. §3 owns those numbers; the check should too.

*Alternatives considered.* **Add the footprint to `tuning.json` and check the scene against it**
— consistent with everything else here; rejected because it converts an independent oracle into
another transcription, and the transcription is the thing most likely to be wrong.

### D5 — Bindings live in `project.godot`'s InputMap, pinned by `check_settings.py`

Godot's InputMap is where an engine-native project states its bindings, and the editor writes it.
The settings gate is extended to assert every action and key the document's table names.

*Why pin them.* `project.godot` is rewritten by the editor, which has already cost this project
comment loss on pinned settings (recorded in `godot/CLAUDE.md`). A binding silently dropped by a
rewrite is exactly the kind of thing nobody notices until a key stops working.

*Alternatives considered.* **Define the InputMap at runtime from a data file** — keeps bindings
out of an editor-rewritten file and makes them re-bindable later; rejected for now because it
puts the game's controls somewhere Godot's own tooling cannot see, for a re-binding feature the
document does not ask for. Worth revisiting if M7's player actions grow.

### D6 — Focus loss clears input through the core's existing `clear()`

The root observes the engine's focus-out notification and calls the simulation's existing
`InputState.clear()`. No new clearing logic.

*Why it belongs to the root.* Focus is an engine concern and the core has no notion of it, which
is why `clear()` was built in M1 with nothing calling it (`att` 11). Keeping the observation in
the root and the effect in the core preserves the boundary.

### D7 — The kart view is a reader, and its own scene

`scenes/kart.tscn` holds the imported model with the normalisation and yaw correction applied;
a small script positions it from simulation state each frame. It writes nothing back.

## Risks / Trade-offs

- **A sign error passes the 16-heading test.** → Three independent lines of evidence (D3), and
  the test says in its own body what it does and does not establish. This is the one risk in the
  change that cannot be closed by a test.
- **The centroid heuristic may not generalise.** → It is a second witness, never the deciding
  one, and the check states which model and which measurement it rests on.
- **`project.godot` is editor-rewritten.** → The settings gate covers the bindings; a lost
  binding fails the suite rather than being discovered in play.
- **Interpolation can mask a stepping bug.** A view that lerps smoothly looks correct even if the
  accumulator is wrong. → The accumulator is tested headlessly against step counts, not judged by
  eye, and the existing replay harness already proves batching-independence at the core.
- **The kart is the first thing in this project to cast a shadow.** A7 and A8 were settled on the
  spike's scene, and their real subject — the kart's contact shadow, which the document calls the
  primary cue for where it is on the ground — becomes visible here for the first time. → Worth a
  capture and a look, and a finding if it does not hold up; not worth reopening the decisions
  pre-emptively.

## Open Questions

- Whether the interpolated view should also interpolate yaw, or take the stepped yaw and
  interpolate position only. Both are defensible at 60 Hz and the difference is invisible at the
  speeds involved; it does not change the specs, the approach, or the task breakdown.
