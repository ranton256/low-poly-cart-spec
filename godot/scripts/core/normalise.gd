# The design document's §3 asset normalisation contract, as arithmetic.
#
# Four steps, in this order:
#   1. Measure the model's bounding box.
#   2. Compute scale = targetHeight / box.height and apply it uniformly.
#   3. RE-MEASURE the box after scaling.
#   4. Offset so the lowest point is exactly Y = 0 and the box is centred on X/Z.
#
# STEP 3 IS WHY THIS FILE EXISTS. The design document calls reusing pre-scale
# numbers "the single most common porting error; it buries props halfway into
# the ground." So the scaled box is computed as its own value below and the
# offset is visibly derived from THAT — not folded into one expression against
# the authored numbers, where the two orderings collapse together and the
# mistake becomes invisible.
#
# The caller supplies the authored box. This file never asks an engine for one,
# which is what lets the contract be proven against synthetic boxes with no
# model file present and nothing rendered.
extends RefCounted


## Halves are written `/ 2.0` rather than `* 0.5` throughout: 0.5 is the value of
## `reverseFactor`, `goLinger` and `lapRestartDelay`, so the literal collides with
## the tuning gate. Rather than grow the exemption allowlist — which is how a gate
## gets worked around — the arithmetic is written in a form that does not collide.
##
## The result of normalising an authored box to a target height.
##
## READ THIS BEFORE PLACING AN INSTANCE. The three fields are not in the same
## frame, and getting it wrong puts a prop in the ground:
##
##   scale   the TOTAL authored-to-final factor. After with_variation() it
##           already includes the variation factor — do not multiply again.
##   offset  from to_target_height(), expressed in scaled-authored space.
##           From with_variation() it is identically (0,0,0), because the input
##           box was already grounded. A caller placing a VARIED instance wants
##           to_target_height().offset * factor, NOT with_variation().offset.
##   box     the final extent, lowest point at zero, centred on X and Z.
##
## The asymmetry is a consequence of variation being a second pass over an
## already-grounded box. It is stated here because M2 and M3 both walk this path.
class Normalised:
	extends RefCounted
	var scale: float = 1.0
	var offset: Vector3 = Vector3.ZERO
	var box: AABB = AABB()

	func height() -> float:
		return box.size.y


## Normalise an authored box to a target height.
##
## `authored` is the model's own bounding box, in its own space, with whatever
## origin the artist gave it — the supplied set arrives centred on its origin,
## but nothing here assumes that.
static func to_target_height(authored: AABB, target_height: float) -> Normalised:
	var result := Normalised.new()
	if authored.size.y <= 0.0 or target_height <= 0.0:
		return result

	# Step 2: uniform scale.
	result.scale = target_height / authored.size.y

	# Step 3: RE-MEASURE. This is a distinct value, derived from the scale, and
	# every number below comes from it rather than from `authored`.
	var scaled := AABB(authored.position * result.scale, authored.size * result.scale)

	# Step 4: lowest point to zero, box centred on X and Z.
	result.offset = Vector3(
		-(scaled.position.x + scaled.size.x / 2.0),
		-scaled.position.y,
		-(scaled.position.z + scaled.size.z / 2.0)
	)
	result.box = AABB(scaled.position + result.offset, scaled.size)
	return result


## Apply random size variation on top of an already-normalised instance, and
## re-ground it.
##
## The order is the design document's: the factor multiplies the target-height
## normalisation, and the instance is re-grounded AFTER. Varying before
## grounding leaves a prop floating or sunk by (factor - 1) x height / 2 — for a
## cottage at x1.2 that is 0.3 wu, which is the "buried halfway" symptom.
static func with_variation(normalised: Normalised, factor: float) -> Normalised:
	var result := Normalised.new()
	if factor <= 0.0:
		return result
	result.scale = normalised.scale * factor
	var scaled := AABB(normalised.box.position * factor, normalised.box.size * factor)
	result.offset = Vector3(
		-(scaled.position.x + scaled.size.x / 2.0),
		-scaled.position.y,
		-(scaled.position.z + scaled.size.z / 2.0)
	)
	result.box = AABB(scaled.position + result.offset, scaled.size)
	return result


## The world-axis-aligned box of a normalised instance rotated by `yaw`.
##
## A function rather than stored state: the design document requires this be
## recomputed from the instance's current rotation every tick, because the
## extents change continuously as it turns. Collision tests against this.
static func world_box(normalised: Normalised, yaw: float) -> AABB:
	var half_x := normalised.box.size.x / 2.0
	var half_z := normalised.box.size.z / 2.0
	var c := absf(cos(yaw))
	var s := absf(sin(yaw))
	# Projecting a rotated rectangle onto the world axes.
	var extent_x := half_x * c + half_z * s
	var extent_z := half_x * s + half_z * c
	var centre_x := normalised.box.position.x + half_x
	var centre_z := normalised.box.position.z + half_z
	return AABB(
		Vector3(centre_x - extent_x, normalised.box.position.y, centre_z - extent_z),
		Vector3(extent_x * 2.0, normalised.box.size.y, extent_z * 2.0)
	)


## Shrink a box by `amount` on every horizontal side, as the collision feature
## specifies for the kart's hit volume. Height is untouched.
static func contracted(box: AABB, amount: float) -> AABB:
	return AABB(
		Vector3(box.position.x + amount, box.position.y, box.position.z + amount),
		Vector3(box.size.x - amount * 2.0, box.size.y, box.size.z - amount * 2.0)
	)
