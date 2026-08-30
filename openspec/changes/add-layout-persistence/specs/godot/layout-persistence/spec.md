# godot/layout-persistence — delta for add-layout-persistence

The design document specifies the record fields, the release-first restore,
and the no-drift round trip. These are the port's decisions: where the file
goes (A2), what preserves collision order (A3), and which layer touches disk.

## ADDED Requirements

### Requirement: The layout file is delivered per platform (A2)

Save Layout SHALL write indented `track_layout.json` to the user data
directory on desktop, printing the absolute path; on the web the same bytes
SHALL be offered as a browser download. Loading is by the pinned `load_layout`
binding reading the same location. `LPC_LAYOUT_FILE` overrides the path so no
suite touches a real user file. All file I/O lives in the view layer.

#### Scenario: Saving delivers a real file the player can find

- **WHEN** Save Layout is triggered on desktop
- **THEN** `track_layout.json` exists at the user data directory, indented and
  human-readable, and the path was printed

### Requirement: Registration order is the file's order (A3)

Export SHALL write records in the field's registration order, and import
SHALL register props in the file's record order — so a restored track
resolves collisions identically to the one that was saved, element for
element.

#### Scenario: The round trip preserves collision order

- **WHEN** a field is exported and re-imported
- **THEN** the collision array matches the original in length and per-index
  asset identity

### Requirement: Restored scale is absolute, applied once

Import SHALL apply each record's scale as the final world scale — never
through the normalisation path — and reconstruct the collision box from the
authored geometry at that scale, so repeated export/import cycles are
byte-identical rather than compounding.

#### Scenario: Two cycles, one layout

- **WHEN** a layout is exported, imported, and exported again
- **THEN** the two files are identical

### Requirement: A malformed layout changes nothing

Import SHALL validate the file — parseable JSON, known assets, complete
records — before releasing anything; a rejected file leaves the current
world, the simulation's props, and the clock untouched, with the reason
logged.

#### Scenario: A corrupt file is refused whole

- **WHEN** loading a file with an unknown asset or a missing field
- **THEN** no prop is released, the collision array is unchanged, and the
  error is logged
