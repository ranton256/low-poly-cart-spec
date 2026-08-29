# Turns a seed into a field of obstacles.
#
# A seed in, an ORDERED array of placements out. A placement is data — an asset
# name, a position, a yaw, a scale, a ground offset — and a view instantiates
# meshes from it. Nothing here touches an engine type, so every rule the design
# document states is arithmetic a test can drive with no scene loaded.
#
# THE ORDER IS PART OF THE CONTRACT, not an accident of iteration.
# add-aabb-collision-response resolves "the first intersecting prop in
# registration order only", so a field that is right as a set and wrong as a
# sequence produces collisions that are wrong and reproducible. The rule is:
# asset by asset in the design document's own table order, and within an asset in
# the order candidates were accepted. See CONSTRAINTS §4 Architectural boundaries.
extends RefCounted

const Rng := preload("res://scripts/core/rng.gd")
const Normalise := preload("res://scripts/core/normalise.gd")

## The design document's table order, which is also the registration order. NOT
## the order of a Dictionary's keys: GDScript preserves insertion order today,
## and resting a collision contract on that is the kind of thing that breaks
## quietly in an engine upgrade.
const ASSET_ORDER: Array[String] = ["tree", "rock", "cone", "crate", "tires", "cottage"]


## One placed prop. A plain object rather than a Dictionary so a typo in a field
## name is a parse error rather than a null at run time.
class Placement:
	extends RefCounted
	var asset: String = ""
	var x: float = 0.0
	var z: float = 0.0
	var yaw: float = 0.0
	## The uniform scale actually applied: the asset's target-height normalisation
	## multiplied by this instance's variation factor.
	var scale: float = 1.0
	## Where to put the model's ORIGIN, relative to the placement position, so that
	## the scaled instance is centred on X and Z and rests at ground level on Y.
	##
	## In AUTHORED space scaled by `scale` — which is what a view applies to an
	## imported model, and which is NOT what Normalise.with_variation() returns.
	## That function operates on an already-grounded box, so its own offset.y is
	## always zero; using it directly leaves every prop sunk by half its authored
	## height. Derived below instead, from the box the specified path produces.
	var offset_x: float = 0.0
	var offset_y: float = 0.0
	var offset_z: float = 0.0

	## Where this placement sat when it was ACCEPTED, counting from zero across the
	## whole generation. The array index and this must agree: that is what "emitted
	## in acceptance order" means, and it is the half of the registration-order
	## rule that asset order does not cover.
	##
	## Review reordered placements WITHIN an asset — assets still contiguous, still
	## in the document's table order — and every check in the project passed. This
	## is what closes that.
	var sequence: int = -1

	func serialise() -> String:
		return (
			"%s|%.9f|%.9f|%.9f|%.9f|%.9f|%.9f|%.9f"
			% [asset, x, z, yaw, scale, offset_x, offset_y, offset_z]
		)


var tuning: RefCounted = null

## Reported per generation: what was asked for against what was placed. The
## design document requires the shortfall be visible rather than mistaken for a
## sparse seed.
var requested: Dictionary = {}
var achieved: Dictionary = {}
var attempts: Dictionary = {}


## Generate a field.
##
## `authored_boxes` maps an asset name to its authored bounding box, so the
## grounding offset can be computed through the same §3 contract the kart uses.
## Passing them in rather than loading models keeps this module free of the
## engine — the caller has already imported what it has.
func generate(seed_value: int, authored_boxes: Dictionary) -> Array:
	# SEED AT THE START OF EVERY GENERATION (design D2). rng.gd is a static,
	# process-global stream; without this a field would depend on how much
	# unrelated code had drawn from it first, and the spec requires that
	# scattering twice from one seed agree even if something ran in between.
	Rng.seed_rng(seed_value)

	requested = {}
	achieved = {}
	attempts = {}
	var placements: Array = []

	for asset in ASSET_ORDER:
		var count: int = int(tuning.prop_count(asset))
		requested[asset] = count
		achieved[asset] = 0
		attempts[asset] = 0
		if count <= 0 or not authored_boxes.has(asset):
			continue
		_place_asset(asset, count, authored_boxes[asset] as AABB, placements)

	return placements


## Everything the design document's "Giving up gracefully" scenario asks for: try
## until the budget runs out, then stop and let the caller see the shortfall.
func _place_asset(asset: String, count: int, authored: AABB, placements: Array) -> void:
	var clearance: float = clearance_for(asset)
	var extent: float = tuning.scatter_extent
	var separation: float = tuning.min_prop_separation
	var budget: int = int(tuning.attempt_budget) * count
	var normalised: RefCounted = Normalise.to_target_height(authored, tuning.target_height(asset))

	var placed: int = 0
	var tried: int = 0
	while placed < count and tried < budget:
		tried += 1
		var x: float = Rng.float_between(-extent, extent)
		var z: float = Rng.float_between(-extent, extent)
		if not _accepts(x, z, clearance, separation, placements):
			continue

		# Variation, then RE-GROUND. The order matters and normalise.gd owns it:
		# the offset is recomputed from the scaled box, not carried over.
		var factor: float = Rng.float_between(
			tuning.scale_variation_min, tuning.scale_variation_max
		)
		var varied: RefCounted = Normalise.with_variation(normalised, factor)

		var placement := Placement.new()
		placement.asset = asset
		placement.x = x
		placement.z = z
		placement.yaw = Rng.float_between(0.0, TAU)
		placement.scale = varied.scale
		# The offset that takes the AUTHORED box to the grounded, centred one the
		# specified path produced: box_final = authored * scale + offset, so
		# offset = box_final.position - authored.position * scale. Exact, and it
		# reuses with_variation's result rather than restating its arithmetic.
		placement.offset_x = varied.box.position.x - authored.position.x * varied.scale
		placement.offset_y = varied.box.position.y - authored.position.y * varied.scale
		placement.offset_z = varied.box.position.z - authored.position.z * varied.scale
		placement.sequence = placements.size()
		placements.append(placement)
		placed += 1

	achieved[asset] = placed
	attempts[asset] = tried


## The two rejection rules, from the design document's Scenario Outline.
##
## Separation is measured against EVERY previously placed prop, not only against
## others of the same asset: a generator that checks within one asset satisfies a
## naive test and produces a cone standing inside a crate.
func _accepts(x: float, z: float, clearance: float, separation: float, placements: Array) -> bool:
	if sqrt(x * x + z * z) < clearance:
		return false
	for existing in placements:
		var placement := existing as Placement
		var dx: float = x - placement.x
		var dz: float = z - placement.z
		if sqrt(dx * dx + dz * dz) < separation:
			return false
	return true


## The clearance radius for an asset. The design document's table gives 8 for
## every asset but the cottage, which gets 20 — "because cottageClearance is more
## than twice startClearance, cottages only ever appear as distant landmarks near
## the edges of the scattered field".
func clearance_for(asset: String) -> float:
	return tuning.cottage_clearance if asset == "cottage" else tuning.start_clearance


## The whole field as one string, for comparing two generations AS A SEQUENCE.
## Comparing sets would pass on a field with the same props in a different order,
## and the order is what collision resolves by.
static func serialise(placements: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for placement in placements:
		parts.append((placement as Placement).serialise())
	return "\n".join(parts)


## What was asked for against what was placed, for the developer log the design
## document requires.
func shortfall_report() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for asset in ASSET_ORDER:
		parts.append(
			"%s %d/%d in %d attempts" % [asset, achieved[asset], requested[asset], attempts[asset]]
		)
	return ", ".join(parts)
