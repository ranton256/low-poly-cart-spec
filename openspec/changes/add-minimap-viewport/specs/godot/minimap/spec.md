# godot/minimap — delta for add-minimap-viewport

The design document specifies the inset, the framing, and the markers. These
are the port's decisions: the viewport mechanism, the fixed camera basis, and
the layer-mask isolation.

## ADDED Requirements

### Requirement: The minimap is a world-sharing SubViewport

The minimap SHALL render through its own `SubViewport` sharing the main
world, with an orthographic camera at `minimapAltitude` framing
`minimapHalfExtent` each way — which is what makes it never occluded by the
main scene, its depth independent, and the main view undistorted.

#### Scenario: The inset is the specified region

- **WHEN** the HUD is built
- **THEN** the container is the data layer's 200×200, inset 10 px from the
  bottom-left, borderless, and the main viewport is untouched

### Requirement: The camera basis is fixed — the map never rotates

The minimap camera's orientation SHALL be a constant: looking straight down,
world +X toward the map's right edge and world +Z toward its bottom edge,
regardless of kart heading. Only its X/Z position follows the kart, from the
post-physics snapshot, while RACING.

#### Scenario: Turning the kart does not turn the map

- **WHEN** the kart's yaw changes by any amount
- **THEN** the minimap camera's basis is bit-identical to its constant

### Requirement: Markers live in the world and are masked, not moved

The kart disc and heading arrow SHALL be unshaded meshes in the main world on
render layer 2: the minimap camera's cull mask includes layer 2, the chase
camera's excludes it. Neither marker is hidden, moved off-screen, or toggled
per frame; the arrow's yaw is the simulation's own — the true heading, never
the reference build's offset.

#### Scenario: The markers exist exactly once and only the minimap sees them

- **WHEN** the main view and the minimap render the same frame
- **THEN** the markers are visible nodes on layer 2, the chase camera's mask
  drops that layer, and the minimap camera's includes it
