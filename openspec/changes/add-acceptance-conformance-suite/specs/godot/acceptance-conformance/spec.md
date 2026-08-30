# godot/acceptance-conformance — delta for add-acceptance-conformance-suite

## ADDED Requirements

### Requirement: Every checklist item has a named case at its literal tolerance

`tests/conformance_test.gd` SHALL hold one named case per Acceptance
Checklist item, asserting the item's stated tolerance as a literal, and SHALL
fail if any of the fourteen is absent. Item 14's headless half runs the
three-batching agreement; its refresh-rate half lives in the windowed
`tools/refresh_probe.gd`, whose recorded run asserts the 0.5 wu / 0.05 s
bounds at 30, 60, and 144 fps.

#### Scenario: Fourteen names, fourteen items

- **WHEN** the conformance suite runs
- **THEN** cases `_item_01` … `_item_14` each execute and report against
  their item's own numbers

### Requirement: The lap gate's place in the tick order is discriminated

The suite SHALL hold a case that passes only when the lap gate observes the
post-collision position: a push-out carrying the kart into the band on a tick
whose stage-5 displacement independently qualifies banks a lap; a gate
running before collision resolution sees the kart outside the band and fails
the case.

#### Scenario: Moving the gate breaks a test

- **WHEN** the gate's stage is moved before collision resolution
- **THEN** the discriminating case fails
