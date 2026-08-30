# Proposal: add-layout-persistence

## Why

A lucky procedural arrangement dies with the session. The design document's
*Track Layout Persistence* feature — three of M7's four remaining scenarios —
turns it into a repeatable track, and it carries the two open ambiguities
whose settlement M7 owns: **A2** (how the file reaches the player, per
platform) and **A3** (whether registration order survives the round trip —
it must, because collision resolves the first intersecting prop in that
order).

**Design-document features implemented:** *Track Layout Persistence* entire
(Exporting, Restoring, Round-tripping). **Acceptance items advanced:** 12.

## What Changes

- **`scripts/world/layout_io.gd`** (view layer — the core reads no files):
  export walks the prop field's records **in registration order** and writes
  indented, human-readable `track_layout.json` — one record per prop with the
  GDD's exact fields: asset id, target height, full position, yaw, full
  scale. The scale written is the **absolute final world scale**.
- **Import** reconstructs placements from records **in file order** and hands
  them to the existing `build()` path — which already releases every prop
  first and registers in order — so restoration reuses the exact machinery
  regeneration trusts. Scale is applied as recorded, never re-derived through
  normalisation, so cycles cannot compound (acceptance 12's trap).
- **A2 settled:** on desktop the file is written to the user data directory
  and its absolute path printed (the lightest "delivered to the player" that
  is a real file in a real folder); on the web the same JSON is handed to the
  browser as a download via the JS bridge (exercised at M8's web smoke —
  disclosed). Loading is by keybind `L` (`load_layout`, pinned like the other
  bindings); `LPC_LAYOUT_FILE` overrides the path for suites, in the
  `LPC_SAVE_FILE` tradition.
- **A3 settled:** export order IS registration order; import registers in
  file order; the round-trip test asserts collision order element by element.
- Tests (`layout_test.gd`, RED first): export fields and formatting, restore
  at exact transforms with release-first, round-trip identity within
  floating-point tolerance, double-cycle byte-identity, order preservation,
  and a rejected malformed file leaving the world untouched.

## What is deliberately excluded

- Reset Kart and the live tuning path — `add-runtime-tuning-and-reset`.
- Durable best times or any save system: this is player-initiated file
  export, exactly as CONSTRAINTS §15 Not applicable records.
- The milestone's before/after visual proof — with the second change, so the
  capture shows the whole loop.
