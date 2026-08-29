## MODIFIED Requirements

### Requirement: One renderer on every target

The project SHALL use a single renderer across every shipping target, so that one
specification produces one look and one set of visual baselines. The choice SHALL
rest on evidence that it can carry the design document's lighting, not on reasoning
about export support alone.

#### Scenario: Desktop and web render through the same path

- **WHEN** the project is exported to any supported target
- **THEN** the renderer is the same one used on every other target
- **AND** no second render path exists for any platform

#### Scenario: The choice is recorded as provisional

- **WHEN** a renderer is selected before there is evidence it can carry the design
  document's lighting
- **THEN** it is recorded as a decision with a named owner and the work that will
  settle it
- **AND** it is not left to an engine default
- **AND** it does not stay provisional once that work has run

#### Scenario: The choice is justified by a shadow comparison

- **WHEN** the renderer selection is inspected
- **THEN** it is supported by committed captures of the design document's specified
  sun, taken under the selected renderer and under the alternative
- **AND** the captures were judged against criteria written down before they were
  looked at
- **AND** the constraints document records the outcome as settled rather than as an
  open question

#### Scenario: An inadequate renderer is reported, not silently swapped

- **WHEN** the selected renderer cannot carry the specified lighting
- **THEN** the finding is recorded with its evidence
- **AND** the renderer is not changed as part of the same work, because the
  alternatives trade away a shipping target or a single look and that is a product
  decision

#### Scenario: The comparison can be re-run

- **WHEN** someone later doubts the decision
- **THEN** the captures can be regenerated from a committed scene and the committed
  capture tool
- **AND** regenerating them on an unchanged tree reproduces the same images
