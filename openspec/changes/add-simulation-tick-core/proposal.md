## Why

M0 built the apparatus that verifies the project. Nothing yet plays the game.

This is the first change that implements the design document's own behaviour: the
normative tick order from **Feature: Kart Driving Physics**, plus the boundary
containment feature. It is the milestone the roadmap calls "the rules of the game
are right, proven, and reproducible — with nothing on screen at all", and it is
deliberately headless. A tick that is wrong here is wrong in every milestone after
it, and far cheaper to find now than behind a camera.

**Design document sections implemented:** *Kart Driving Physics* (the tick order
and its 8 scenarios), *World Boundary Containment* (its first scenario only —
the second, *Keeping the boundary invisible*, is acceptance item 7 and needs
something rendered, so the roadmap assigns it to M2), *Input Handling*
(the state model — 3 of its 5 scenarios; the two that depend on a window belong to
M2), and *Runtime Tuning and Player Actions* (the adjust-without-restart scenario).

**Acceptance checklist items advanced:** **4** (the spin-up and coast curve, three
timings at ±0.05 s) and **5** (steering impossible at rest, sense reverses in
reverse). Item **14a** — the headless determinism half — is prepared for but owned
by `add-determinism-and-coverage-harness`.

## What Changes

- Implement `Sim.step()` as the design document's **eight ordered steps**, with the
  clamp before friction and the steering threshold tested on the post-clamp,
  pre-friction velocity. Steps 7 (collision) and 8 (lap gate) exist as ordered
  slots that do nothing yet — M3 and M4 fill them. The ordering is the contract,
  so the slots are present from the first commit rather than inserted later.
- Implement the input model as held state, set by a caller, cleared on demand —
  no engine input types in the core.
- Implement boundary containment: clamp to `±drivableExtent`, and apply
  `bounceFactor` **exactly once per tick** however many axes clamped.
- Replace the inherited placeholder `scripts/core/sim.gd` wholesale.
- Feed the tick from `godot/data/tuning.json` by **injection** — the core receives
  values, it does not read files. Retuning takes effect on the next tick with no
  restart.
- Expose the speedometer *ratio and readout arithmetic* from the core, because
  acceptance item 4 is stated in dial numbers (103, 115). Drawing the dial is M5.

Not in this change: the asset normalisation contract
(`add-asset-normalisation-contract`), the determinism harness and G1
(`add-determinism-and-coverage-harness`), collision, the lap gate, and anything
that renders.

## Capabilities

### New Capabilities

- `godot/simulation-core`: the kart's motion — how a tick advances velocity,
  heading and position, in what order, under what inputs, and how the world
  boundary contains it.

### Modified Capabilities

None. `openspec/specs/` does not exist yet: no change has been archived, so there
is no main spec to delta against. Two changes now carry unarchived deltas
(`add-godot-project-foundations`, `add-architecture-and-tuning-gates`), both
complete and committed — archiving them would let later changes modify their
capabilities properly.

## Impact

- **New**: `godot/scripts/core/tuning.gd` (a plain value object),
  `godot/scripts/core/input_state.gd`, `godot/scripts/tuning_loader.gd` (outside
  the core, so the core opens no file), and the suites `godot/tests/tick_test.gd`,
  `boundary_test.gd`, `determinism_test.gd`, `tuning_loader_test.gd`.
- **Rewritten**: `godot/scripts/core/sim.gd` — currently the skeleton's 2D
  placeholder, whose `SPEED`/`WIDTH`/`HEIGHT` constants and `emit_sfx` channel are
  not this game.
- **Modified**: `godot/tools/test.sh` gains the new suites;
  `godot/data/tuning_literal_allowlist.json` loses both entries, which are
  `sim.gd` coincidences that go stale when that file is replaced — the staleness
  rule will catch them.
- **Unmodified**: the design document. This change implements it, it does not
  change it.
- **Risk**: the tolerances are ±0.05 s on three timings and are met or the change
  is not done. `CONSTRAINTS §5 Conformance to the specification` forbids widening
  them.
- **Verification criteria touched**: V2 (determinism at a fixed seed) begins to
  mean something once a real simulation exists; V19's static-typing gate now
  covers real game code.
