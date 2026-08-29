# Collision detection and response: the design document's own axis-aligned test.
#
# NO PHYSICS ENGINE, ever. Props are meshes plus an AABB record and the kart is a
# scalar recurrence — CONSTRAINTS §4 Architectural boundaries. What follows is the
# document's Collision Detection and Response feature, clause for clause.
#
# ONE COLLISION PER TICK, resolved against the FIRST intersecting prop in
# registration order. That is not an optimisation: the document states it, and it
# is why add-seeded-world-scatter spent most of its review effort making the
# emission order a contract rather than an accident.
#
# It also means the kart can be pinned between two props whose gap is smaller than
# its hitbox — it overlaps both, one is resolved, the push drives it into the
# other, and it oscillates with its velocity zeroed. THAT IS SPECIFIED BEHAVIOUR,
# not a defect. The document names Reset Kart as the escape and says the remedy is
# the placement rule, not this file: "a port that wants the stronger guarantee
# should raise minPropSeparation to clear the largest pair of footprints rather
# than resolve multiple collisions per tick".
#
# What tests/collision_test.gd asserts is NOT that the kart cannot escape — an
# earlier version of this comment said so and was wrong. The push below is radial
# from the prop's centre, which makes the centred state an unstable equilibrium:
# the kart is held for about 125 ticks driving along the pair's axis and 15-20
# across it, then squeezed out sideways. The suite asserts what the response really
# guarantees — the velocity is zeroed on every tick of contact, exactly one of the
# two overlaps is resolved, and driving at the pair never carries the kart past it
# — AND that the pin ends. So a fix that resolves both overlaps fails, and so does
# one that damps the transverse push to make the pin permanent. See ambiguity A12,
# which raises the document's own sentence against the document.
extends RefCounted

const Normalise := preload("res://scripts/core/normalise.gd")

## Below this, the horizontal vector from a prop's centre to the kart's position
## is treated as having no direction.
##
## The kart moves at most maxSpeed (0.2) wu per tick and pushDistance is 0.3, so
## a separation this small cannot arise from ordinary motion — it takes a prop
## scattered exactly onto the kart, which the document's own regeneration scenario
## describes. Stated here rather than tuned to a measurement: it is the scale at
## which a normalised direction stops being meaningful in 32-bit floats, not a
## number chosen because it made a test pass.
const DEGENERATE_DISTANCE := 1e-6


## One prop, as collision sees it: a world-axis-aligned volume and nothing else.
## Props do not rotate after placement, so this is computed once when the field is
## built rather than per tick.
class Prop:
	extends RefCounted
	var asset: String = ""
	var box: AABB = AABB()

	func centre_x() -> float:
		return box.position.x + box.size.x / 2.0

	func centre_z() -> float:
		return box.position.z + box.size.z / 2.0


## What a resolved collision did, for the caller to apply and for a test to read.
class Hit:
	extends RefCounted
	## Index into the prop array — the registration index, which is what makes
	## "the first intersecting prop in registration order" checkable.
	var index: int = -1
	var push_x: float = 0.0
	var push_z: float = 0.0
	## True when the push direction came from the kart's backward axis because the
	## kart and the prop centre coincided.
	var degenerate: bool = false


## The kart's hit volume for this tick: recomputed from its CURRENT heading, then
## contracted on every side.
##
## Recomputed rather than cached because the document requires it — the volume is
## world-axis-aligned, so it grows when the kart is diagonal, and that growth is
## accepted behaviour rather than something to correct.
static func kart_volume(
	normalised: RefCounted, yaw: float, x: float, z: float, contraction: float
) -> AABB:
	var box: AABB = Normalise.world_box(normalised, yaw)
	var moved := AABB(box.position + Vector3(x, 0.0, z), box.size)
	return Normalise.contracted(moved, contraction)


## A prop's collision volume, placed in the world.
##
## Computed once when the field is built, not per tick: props do not rotate after
## placement. (Whether a prop's volume should be its own box at its placed yaw or
## the axis-aligned box of the rotated instance has one answer while that holds,
## and this is it. A moving prop would make the two differ, which is why
## add-aabb-collision-response's design.md records the question rather than
## dropping it — it is that change's open question, not the design document's,
## which says only "the world-axis-aligned bounding volume of every registered
## prop".)
static func make_prop(
	asset: String, normalised: RefCounted, yaw: float, x: float, z: float
) -> Prop:
	var prop := Prop.new()
	prop.asset = asset
	var box: AABB = Normalise.world_box(normalised, yaw)
	prop.box = AABB(box.position + Vector3(x, 0.0, z), box.size)
	return prop


## The first intersecting prop in registration order, or -1.
##
## Stops at the first. However many props the kart overlaps, exactly one is the
## collision for this tick.
static func first_overlap(volume: AABB, props: Array) -> int:
	for i in range(props.size()):
		var prop: Prop = props[i] as Prop
		if volume.intersects(prop.box):
			return i
	return -1


## The push for a resolved collision.
##
## Direction is the horizontal unit vector FROM THE PROP'S VOLUME CENTRE TO THE
## KART'S POSITION — away from what it hit. When that is degenerate the kart's
## BACKWARD axis is used, ejecting it the way it came in.
##
## The backward axis is not interchangeable with the forward one. The document
## explains why: forward "would drive it further into the prop and walk it out the
## far side", which is the tunnelling another scenario forbids. A test asserting
## only that the kart moved passes on forward.
static func resolve(
	prop: Prop, kart_x: float, kart_z: float, kart_yaw: float, push_distance: float
) -> Hit:
	var hit := Hit.new()
	var away_x: float = kart_x - prop.centre_x()
	var away_z: float = kart_z - prop.centre_z()
	var length: float = sqrt(away_x * away_x + away_z * away_z)

	if length < DEGENERATE_DISTANCE:
		# Backward is the negation of the simulation's forward, (sin yaw, cos yaw).
		hit.degenerate = true
		away_x = -sin(kart_yaw)
		away_z = -cos(kart_yaw)
		length = 1.0

	hit.push_x = away_x / length * push_distance
	hit.push_z = away_z / length * push_distance
	return hit
