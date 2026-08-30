# Proposal: add-checkpoint-circuit-core

## Why

The GDD now specifies the Checkpoint Circuit (owner-approved amendment,
commit 656a4b5); the port owes the behaviour. This change builds everything
that can be true **without touching the boot or drawing a pixel**: the pure
circuit module, the amended lap condition, per-circuit bests, and layout
version 2. The game still boots procedural after this change — a circuit
exists only when a v2 layout is loaded through `L` — so the standing suites,
baselines, and captures stay untouched while the mechanics land under full
test. The boot swap, the shipped circuit, and everything visible are
`add-circuit-world-and-presentation`.

## What Changes

- **`scripts/core/circuit.gd`** (pure, banned-symbols clean): holds the
  ordered gates, the progress cursor, and the gate-pass test — kart position
  transformed into the gate frame, |lateral| < width/2, inside the
  `gateDepth` slab, stage-5 displacement's gate-forward component above
  `gateCrossingThreshold`. Advanced from stage 8 beside the lap gate,
  observe-only; the cursor ignores out-of-order, repeated, and backwards
  passes. Empty circuit = no gates loaded (the pre-M9 interim).
- **The threaded-lap condition** in `lap_gate.gd`: when a circuit is loaded,
  banking requires the cursor past the final gate; the `minLapTime` guard
  remains ONLY as the no-circuit interim and dies with the next change (the
  bridge and its deletion are already recorded in `port_decisions`).
- **Per-circuit bests**: the lap module's best keyed by circuit name (the
  no-circuit interim keys as "procedural"); medal determination (gold /
  silver / bronze / none) computed in the core at bank time from the loaded
  targets — display is the next change's job. Cursor, circuit name, and
  medal join `stats_line()` for the determinism summary.
- **Layout v2** in `layout_io.gd`: parse and validate the `circuit` object
  (name, gates each `[x,z]`/yaw/width, optional targets), refuse a file
  whose circuit is malformed as a whole (the existing
  refuse-before-releasing rule extends to it), round-trip the object
  byte-identically through save. **Interim deviation, recorded:** the GDD
  says gateless files are *refused*; until the boot ships a circuit, this
  change still ACCEPTS v1/gateless files (the game must remain playable) —
  the refusal lands with the boot swap, and the register's deferral for
  that scenario stays open until it does.
- **Suites**: `circuit_test.gd` (gate frames at several yaws, cursor rules,
  threaded banking, reset untouched, per-circuit bests, medal edges at
  exactly-target), layout_test grows the v2 round-trip and malformed-circuit
  refusals; the ordering discriminator gains a gate sibling (a push-out
  cannot pass a gate — mutation-verified like the band's).
- **Coverage**: claims 5 of M9's 10 deferrals (Defining a gate; Progress is
  a cursor; The band banks only a threaded lap; Reset Kart and circuit
  progress; Best times belong to their circuit) and the core half of A
  layout is a circuit — the file-refusal half stays deferred to the next
  change, honestly.

## What is deliberately excluded

- The boot swap, the shipped circuit file, `G` re-bind, gateless-file
  refusal, all visuals/HUD/minimap, medal display, gallery, G2 re-pointing
  — all `add-circuit-world-and-presentation`.
