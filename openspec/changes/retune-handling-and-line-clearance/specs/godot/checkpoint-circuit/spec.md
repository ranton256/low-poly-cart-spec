# godot/checkpoint-circuit — delta for retune-handling-and-line-clearance

## MODIFIED Requirements

### Requirement: The shipped circuit is the boot world

Boot SHALL build the world by loading the committed shipped circuit file
through the layout path; failure is the existing terminal LOADING verdict.
A layout without a circuit SHALL be refused on load with a named error. The
shipped file SHALL be validated by a test: every gate inside the boundary,
no curated prop overlapping a gate mouth, targets ordered, **and no prop's
worst-case collision box — the world-axis expansion of its yawed box, the
volume that actually collides — within `lineClearanceWu` of the racing
line**. The racing line SHALL be the union of the baked drive's own path,
sampled per tick, and the straight line from the start pose through every
gate centre to the finish aim — the tighter line a gold time asks for and
the bang-bang pilot does not drive. The authoring tool SHALL enforce the
same rule when it curates, dropping or moving offenders and naming them.

#### Scenario: Boot is a circuit or a named failure

- **WHEN** the game boots with the shipped file present, and again with it
  broken
- **THEN** the first run reaches the countdown on the authored world and the
  second is a terminal LOADING state naming the failure

#### Scenario: A gateless file no longer loads

- **WHEN** a version-1 layout is loaded through the real binding
- **THEN** the world is unchanged and the named refusal is logged

#### Scenario: No invisible wall ambushes the racing line

- **WHEN** the shipped circuit is validated
- **THEN** every prop's worst-case collision box clears the racing line — the
  baked drive's own path and the tight line through the gate centres alike —
  by at least `lineClearanceWu`
- **AND** a prop that satisfied the eye but not the collision box — a
  broad-canopied tree at a diagonal yaw — is exactly what the rule refuses
