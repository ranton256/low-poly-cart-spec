# godot/collision-response Specification

## Purpose
Defines what counts as hitting a prop, which prop is resolved when the kart
overlaps several, how it is pushed clear, what happens to its speed — and the
guarantee about not becoming trapped, together with the case the design document
says that guarantee does not cover and must not be extended to.

The last of those is where this port's implementation and the design document
part company on a matter of fact rather than of interpretation. The document says
a kart pinned between two minimally separated props "cannot drive out"; the
response it specifies makes that state unstable, so the kart is ejected sideways
after between a quarter of a second and two seconds depending on its heading. The
requirements below state what the specified response actually guarantees. They do
not relax the rule the document is emphatic about — no more than one collision is
resolved per tick — and the discrepancy is raised against the document as ambiguity
A12 rather than being absorbed here.

## Requirements

### Requirement: The hit volume is recomputed every tick and forgiving

The kart's collision volume SHALL be recomputed from its current heading on every
tick, and SHALL be contracted on every side before testing, so that near misses do
not register.

#### Scenario: The volume follows the heading

- **WHEN** the kart's heading changes
- **THEN** its collision volume is recomputed from the new heading
- **AND** the volume is world-axis-aligned, so it is larger when the kart is
  oriented diagonally than when it is aligned with the axes
- **AND** that growth is accepted, not corrected: the design document chooses the
  cheap predictable test over an oriented-volume one

#### Scenario: The volume is contracted before testing

- **WHEN** the volume is tested against a prop
- **THEN** it has been contracted by the specified amount on every side
- **AND** a kart passing a prop with clearance greater than the contracted volume
  registers no collision, and its velocity, heading and position are entirely
  unaffected

### Requirement: At most one collision is resolved per tick

Props SHALL be tested in registration order and testing SHALL stop at the first
intersection, so that exactly one collision is resolved in a tick however many
props the kart overlaps.

#### Scenario: The first intersecting prop in registration order wins

- **WHEN** the kart's contracted volume overlaps more than one prop
- **THEN** the prop resolved is the first of them in registration order
- **AND** it is resolved whichever prop is nearest, or largest, or was contacted
  first in time — order is the rule, not proximity

#### Scenario: Testing stops at the first intersection

- **WHEN** a collision is found
- **THEN** no further prop is tested that tick
- **AND** exactly one response is applied

### Requirement: An impact stops the kart and pushes it clear

The response SHALL displace the kart away from the prop by the specified distance
and SHALL set its velocity to exactly zero.

#### Scenario: The push direction comes from the prop's centre

- **WHEN** a collision is resolved
- **THEN** the kart is displaced along the horizontal unit vector from the prop's
  volume centre to the kart's position
- **AND** the displacement is the specified distance, at every approach angle

#### Scenario: A degenerate direction ejects the kart backwards

- **WHEN** the kart's position and the prop's volume centre coincide within
  floating-point tolerance, so the direction between them is undefined
- **THEN** the kart is displaced along its own BACKWARD axis
- **AND** not along its forward axis, which would drive it further into the prop and
  walk it out the far side

#### Scenario: The velocity is zeroed, not reflected

- **WHEN** a collision is resolved
- **THEN** the kart's velocity becomes exactly zero
- **AND** it is neither reflected nor damped, so the kart stops dead rather than
  bouncing

#### Scenario: The camera is jolted

- **WHEN** a collision is resolved
- **THEN** the camera is displaced by a random offset within the specified
  horizontal and vertical limits
- **AND** the offset is drawn from the game's own seeded randomness, so the same
  run reproduces the same shudder

### Requirement: The kart is never trapped by a single prop

Repeated contact with one prop SHALL repeat the push and the velocity kill, and the
kart SHALL always be able to reverse away from it.

#### Scenario: Driving into one prop repeatedly

- **WHEN** the player holds forward into the same prop after being pushed clear
- **THEN** each contact repeats the push-out and the velocity kill
- **AND** the kart never wedges inside it, jitters through it, or tunnels past it

#### Scenario: Reversing out of one prop, from any approach

- **WHEN** the kart has been stopped against a prop and the player reverses
- **THEN** it moves away and is freed
- **AND** this holds whatever direction it approached from, because a response that
  works from one side and not another is a response that has been tested from one
  side

#### Scenario: A prop scattered onto the kart pushes it clear

- **WHEN** the world is regenerated while the kart sits away from the origin, and a
  prop is placed overlapping it
- **THEN** the collision response pushes the kart clear on the following tick
- **AND** it is not trapped, because the placement rule clears the ORIGIN and knows
  nothing about where the kart currently is

### Requirement: Being pinned between two props is specified behaviour, not a defect

The guarantee above covers ONE prop, which is what one resolution per tick can
deliver. A kart overlapping two props whose gap is smaller than its contracted
volume SHALL have its velocity set to zero on **every tick it is in contact**,
SHALL have exactly one of the overlaps resolved on each such tick, SHALL NOT be
carried past the pair by driving along the line joining them, and SHALL NOT be
freed by resolving more than one collision per tick.

#### Scenario: A kart between two minimally separated props is stopped on every tick

- **WHEN** the kart reaches two props placed at the minimum separation, whose gap is
  smaller than its contracted volume
- **THEN** it overlaps both, only the first in registration order is resolved, and
  the push-out drives it into the second
- **AND** its velocity is zero at the end of every tick it is in contact, and it is
  displaced a full push distance rather than a fraction of one, which is what
  distinguishes one resolution from two that cancel
- **AND** driving straight along the line joining the pair never carries it past
  them, however long the player holds forward

#### Scenario: The response is not extended to resolve the pin

- **WHEN** someone is tempted to fix the pin
- **THEN** the response still resolves exactly one collision per tick
- **AND** the design document's own remedy is the placement rule — a larger minimum
  separation — and not the collision response, because the separation is measured
  centre to centre and does not subtract footprints
- **AND** the reset action, not the response, is the specified escape

#### Scenario: The kart leaves the pair sideways, never forwards

- **WHEN** the kart has been held between two such props
- **THEN** it is eventually displaced clear of them transversely, because the push
  is radial from a prop's centre and the centred state is therefore an unstable
  equilibrium rather than a trap
- **AND** how long that takes depends strongly on the heading — about two seconds
  driving along the pair's axis and a quarter of a second across it
- **AND** the design document's statement that such a kart "cannot drive out" is
  therefore not producible by the response the same document specifies; ambiguity
  A12 records it and it is raised against the document rather than settled here
