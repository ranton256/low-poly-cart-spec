# The design document's §3 asset normalisation contract.
#
#   godot --headless -s tests/normalise_test.gd
#
# THE CASE THAT MATTERS is _test_offset_comes_from_the_scaled_box. The design
# document names reusing pre-scale numbers as "the single most common porting
# error", and a suite built only on the supplied assets cannot catch it: those
# arrive centred on their own origin, which is exactly where offset-from-authored
# and offset-from-scaled coincide. The adversarial box is the point.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const Normalise := preload("res://scripts/core/normalise.gd")

# From the design document's §3 table. Duplicated here as the EXPECTED values a
# test asserts against, which is what a test is for; the shipped table lives in
# data/tuning.json and is gated separately.
const TARGET_HEIGHTS := {
	"kart": 1.2,
	"tree": 4.0,
	"rock": 1.5,
	"cone": 0.8,
	"crate": 1.0,
	"tires": 1.2,
	"cottage": 3.0,
}
const VARIATION_MIN := 0.8
const VARIATION_MAX := 1.2
# Grounding is exact: the offset is a subtraction that cancels, and this holds
# at 1e-9 across every target height.
const GROUND_TOLERANCE := 0.000000001

# SIZE comparisons cannot be that tight. AABB is real_t, which is 32-bit in a
# standard Godot build, so a height of 1.2 lands at 1.200000048 — a measured
# worst-case error of 4.77e-8 across the seven target heights, consistent with
# float32 epsilon. 1e-6 is ~20x that margin and still 1000x tighter than
# anything visible: at the design document's 1 wu ~ 0.75 m, 1e-6 wu is under a
# micrometre. Loosening beyond this would be hiding a real error, not absorbing
# a representational one.
const SIZE_TOLERANCE := 0.000001

# Horizontal centring is NOT a cancelling subtraction — it is
# position + size/2, which does not land on zero exactly for a box whose
# coordinates are not dyadic. Measured 8.94e-8 on a deliberately non-dyadic box,
# ~90x over the grounding bound. Reusing GROUND_TOLERANCE here passed only
# because every box in the suite used exactly-representable numbers, and the
# first real .glb AABB would have turned it red for a representational reason.
const CENTRE_TOLERANCE := 0.000001

# The design document's §1 authored kart box, and the exact world extents the
# §3 + §4 chain produces from it. The document prints 2.20 / 2.36 and
# 1.80 / 1.96, which are two-decimal roundings of these; DOCUMENT_ROUNDING
# admits that and nothing looser. M3's collision should use the exact figures.
const KART_AUTHORED := Vector3(2.000, 1.019, 1.868)
const KART_EXACT_WORLD_X := 2.199804
const KART_EXACT_WORLD_Z := 2.355250
const DOCUMENT_ROUNDING := 0.005


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_test_offset_comes_from_the_scaled_box()
	_test_scaling_is_uniform()
	_test_lowest_point_is_ground_at_every_target_height()
	_test_offcentre_authored_box_still_grounds()
	_test_non_dyadic_box_still_centres()
	_test_variation_regrounds_at_both_extremes()
	_test_variation_compounds_with_target_height()
	_test_variation_scales_the_footprint_too()
	_test_variation_compounds_the_scale()
	_test_degenerate_input_is_refused_not_guessed()
	_test_normalisation_is_idempotent()
	_test_world_box_grows_off_axis()
	_test_kart_world_box_matches_the_design_document()
	_test_height_unaffected_by_heading()
	_test_world_box_never_smaller_than_axis_aligned()
	RVTest.finish(
		self, "normalise: contract, grounding, variation, world box", "normalise check(s)"
	)


## An authored box that is BOTH mis-scaled and off-centre, so that computing the
## offset from the authored box and from the scaled box give measurably
## different answers. Authored height 2.0 against a target of 4.0 doubles it,
## and the box sits 3 wu above its own origin.
func _adversarial() -> AABB:
	return AABB(Vector3(-1.0, 3.0, -0.5), Vector3(2.0, 2.0, 1.0))


func _test_offset_comes_from_the_scaled_box() -> void:
	var authored := _adversarial()
	var n = Normalise.to_target_height(authored, 4.0)

	_check(absf(n.scale - 2.0) < 1e-12, "scale is target / authored height")

	# Correct: offset derived from the SCALED box, whose lowest point is 6.0.
	var offset_from_scaled: float = -authored.position.y * n.scale
	# Wrong: offset derived from the AUTHORED box, whose lowest point is 3.0.
	var offset_from_authored: float = -authored.position.y

	_check(
		absf(offset_from_scaled - offset_from_authored) > 1.0,
		(
			"the two orderings differ by %.2f wu on this box — the test can tell them apart"
			% absf(offset_from_scaled - offset_from_authored)
		)
	)
	_check(
		absf(n.offset.y - offset_from_scaled) < GROUND_TOLERANCE,
		"the offset is the one derived from the scaled box"
	)
	_check(
		absf(n.box.position.y) < GROUND_TOLERANCE,
		"and the result therefore rests on the ground (got y=%.12f)" % n.box.position.y
	)


func _test_scaling_is_uniform() -> void:
	var authored := AABB(Vector3(-1.0, 0.0, -0.5), Vector3(2.0, 2.0, 1.0))
	var n = Normalise.to_target_height(authored, 5.0)
	var ratio_x: float = n.box.size.x / authored.size.x
	var ratio_y: float = n.box.size.y / authored.size.y
	var ratio_z: float = n.box.size.z / authored.size.z
	_check(
		absf(ratio_x - ratio_y) < 1e-12 and absf(ratio_y - ratio_z) < 1e-12,
		"the same factor is applied to all three axes"
	)


func _test_lowest_point_is_ground_at_every_target_height() -> void:
	var authored := AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))
	for asset in TARGET_HEIGHTS:
		var target: float = TARGET_HEIGHTS[asset]
		var n = Normalise.to_target_height(authored, target)
		_check(
			absf(n.box.position.y) < GROUND_TOLERANCE,
			"%s rests exactly on the ground (y=%.12f)" % [asset, n.box.position.y]
		)
		_check(
			absf(n.box.size.y - target) < SIZE_TOLERANCE,
			"%s is exactly its target height (%.4f)" % [asset, n.box.size.y]
		)
		var centre_x: float = n.box.position.x + n.box.size.x / 2.0
		var centre_z: float = n.box.position.z + n.box.size.z / 2.0
		_check(
			absf(centre_x) < CENTRE_TOLERANCE and absf(centre_z) < CENTRE_TOLERANCE,
			"%s is centred horizontally on its transform position" % asset
		)


func _test_offcentre_authored_box_still_grounds() -> void:
	var authored := AABB(Vector3(7.0, -13.0, 2.5), Vector3(2.0, 2.0, 1.0))
	var n = Normalise.to_target_height(authored, 3.0)
	_check(absf(n.box.position.y) < GROUND_TOLERANCE, "an off-centre authored box still grounds")
	var centre_x: float = n.box.position.x + n.box.size.x / 2.0
	var centre_z: float = n.box.position.z + n.box.size.z / 2.0
	_check(
		absf(centre_x) < CENTRE_TOLERANCE and absf(centre_z) < CENTRE_TOLERANCE,
		"and the authored offset does not leak into the result"
	)


## Deliberately non-dyadic, so the horizontal centring bound is exercised by a
## box that cannot land on zero exactly — which is what a real .glb AABB is.
func _test_non_dyadic_box_still_centres() -> void:
	var authored := AABB(Vector3(0.333333, 0.1234567, -7.77), Vector3(1.019, 1.868, 0.333))
	var n = Normalise.to_target_height(authored, 4.0)
	var centre_x: float = n.box.position.x + n.box.size.x / 2.0
	var centre_z: float = n.box.position.z + n.box.size.z / 2.0
	_check(
		absf(centre_x) < CENTRE_TOLERANCE and absf(centre_z) < CENTRE_TOLERANCE,
		"a non-dyadic box centres within the stated bound (x=%.12f z=%.12f)" % [centre_x, centre_z]
	)
	_check(absf(n.box.position.y) < GROUND_TOLERANCE, "and still grounds exactly")


func _test_variation_regrounds_at_both_extremes() -> void:
	var authored := AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))
	for factor in [VARIATION_MIN, 1.0, VARIATION_MAX]:
		var n = Normalise.to_target_height(authored, 3.0)
		var v = Normalise.with_variation(n, factor)
		_check(
			absf(v.box.position.y) < GROUND_TOLERANCE,
			"a x%.1f instance still rests on the ground (y=%.12f)" % [factor, v.box.position.y]
		)


func _test_variation_compounds_with_target_height() -> void:
	var authored := AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))
	var n = Normalise.to_target_height(authored, 4.0)
	for factor in [VARIATION_MIN, VARIATION_MAX]:
		var v = Normalise.with_variation(n, factor)
		_check(
			absf(v.box.size.y - 4.0 * factor) < SIZE_TOLERANCE,
			"x%.1f of a 4.0 target is %.4f" % [factor, v.box.size.y]
		)
	# and the range matches what the design document states for a tree
	var low = Normalise.with_variation(n, VARIATION_MIN)
	var high = Normalise.with_variation(n, VARIATION_MAX)
	_check(
		(
			absf(low.box.size.y - 3.2) < SIZE_TOLERANCE
			and absf(high.box.size.y - 4.8) < SIZE_TOLERANCE
		),
		"a tree spans the document's stated 3.20 - 4.80 range"
	)


## §3's table gives a Final footprint range column for every asset, and nothing
## asserted it — variation applied to the vertical axis ONLY passed the entire
## suite. M3's collision tests against exactly these footprints, so a varied
## prop with a wrong hit box would have shipped green. Review caught it.
func _test_variation_scales_the_footprint_too() -> void:
	# A tree: §1 authored 0.786 x 2.000 x 0.794, §3 target 4.00, giving the
	# document's stated footprint range of 1.26-1.89 x 1.27-1.91.
	var authored := AABB(Vector3(-0.393, -1.0, -0.397), Vector3(0.786, 2.0, 0.794))
	var n = Normalise.to_target_height(authored, TARGET_HEIGHTS["tree"])
	for factor in [VARIATION_MIN, VARIATION_MAX]:
		var v = Normalise.with_variation(n, factor)
		_check(
			(
				absf(v.box.size.x - n.box.size.x * factor) < SIZE_TOLERANCE
				and absf(v.box.size.z - n.box.size.z * factor) < SIZE_TOLERANCE
			),
			(
				"x%.1f scales X and Z as well as Y (got %.4f x %.4f)"
				% [factor, v.box.size.x, v.box.size.z]
			)
		)
	# and the result lands inside the document's stated range
	var low = Normalise.with_variation(n, VARIATION_MIN)
	var high = Normalise.with_variation(n, VARIATION_MAX)
	_check(
		(
			absf(low.box.size.x - 1.2576) < DOCUMENT_ROUNDING
			and absf(high.box.size.x - 1.8864) < DOCUMENT_ROUNDING
		),
		(
			"a tree spans §3's stated 1.26-1.89 footprint on X (got %.4f - %.4f)"
			% [low.box.size.x, high.box.size.x]
		)
	)


## `scale` is the total authored-to-final factor, and nothing asserted it —
## dropping the multiplication entirely passed the suite.
func _test_variation_compounds_the_scale() -> void:
	var authored := AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))
	var n = Normalise.to_target_height(authored, 4.0)
	for factor in [VARIATION_MIN, VARIATION_MAX]:
		var v = Normalise.with_variation(n, factor)
		_check(
			absf(v.scale - n.scale * factor) < SIZE_TOLERANCE,
			"x%.1f multiplies the stored scale (%.4f vs %.4f)" % [factor, v.scale, n.scale * factor]
		)


## The degenerate path returns an unscaled, zero-size result rather than
## throwing. Asserted so the contract is stated rather than assumed — deleting
## the guard entirely used to pass.
func _test_degenerate_input_is_refused_not_guessed() -> void:
	var zero_height := AABB(Vector3(-1.0, 0.0, -1.0), Vector3(2.0, 0.0, 2.0))
	var n = Normalise.to_target_height(zero_height, 4.0)
	_check(n.box.size.y == 0.0, "a zero-height authored box yields a zero box, not a divide")
	var bad_target = Normalise.to_target_height(AABB(Vector3.ZERO, Vector3.ONE), 0.0)
	_check(bad_target.box.size.y == 0.0, "a zero target height yields a zero box")
	var bad_factor = Normalise.with_variation(n, 0.0)
	_check(bad_factor.box.size.y == 0.0, "a zero variation factor yields a zero box")


func _test_normalisation_is_idempotent() -> void:
	var authored := AABB(Vector3(-1.0, 5.0, -1.0), Vector3(2.0, 2.0, 2.0))
	var once = Normalise.to_target_height(authored, 3.0)
	var twice = Normalise.to_target_height(once.box, 3.0)
	_check(
		(
			absf(twice.box.size.y - once.box.size.y) < SIZE_TOLERANCE
			and absf(twice.box.position.y - once.box.position.y) < GROUND_TOLERANCE
		),
		"normalising an already-normalised instance changes nothing"
	)


func _test_world_box_grows_off_axis() -> void:
	var authored := AABB(Vector3(-1.0, -0.5, -0.6), Vector3(2.0, 1.0, 1.2))
	var n = Normalise.to_target_height(authored, 1.0)
	var aligned: AABB = Normalise.world_box(n, 0.0)
	var turned: AABB = Normalise.world_box(n, TAU / 8.0)
	_check(
		turned.size.x > aligned.size.x and turned.size.z > aligned.size.z,
		"a box turned 45 degrees is larger on both world axes"
	)


## The design document's §1 authored box, put through the whole chain.
##
## An earlier version of this test was TAUTOLOGICAL: it fed a box already 1.20
## tall at yaw 0, so to_target_height was the identity and world_box was the
## identity, and it asserted that 2.2 comes back as 2.2. It could not have
## failed. Review caught it.
##
## This starts from §1's authored inventory (2.000 x 1.019 x 1.868) and applies
## the real chain — §3's normalisation, then §4's +90 degree yaw correction —
## so the projection and the normalisation both have to be right.
##
## TOLERANCE. The document states 2.20 x 2.36 and 1.80 x 1.96, which are
## two-decimal roundings of the exact 2.19980 x 2.35525 and 1.79980 x 1.95525.
## The bound below admits that rounding and nothing looser. M3's collision will
## use the exact figures, not the printed ones.


func _test_kart_world_box_matches_the_design_document() -> void:
	# §1's authored box, centred on its own origin as the document states.
	var authored := AABB(-KART_AUTHORED / 2.0, KART_AUTHORED)
	var n = Normalise.to_target_height(authored, TARGET_HEIGHTS["kart"])

	# §3: scaling to the target height gives the document's local footprint row.
	_check(
		absf(n.box.size.y - 1.2) < SIZE_TOLERANCE,
		"the kart normalises to its 1.20 target height (got %.6f)" % n.box.size.y
	)
	_check(
		(
			absf(n.box.size.x - KART_EXACT_WORLD_Z) < SIZE_TOLERANCE
			and absf(n.box.size.z - KART_EXACT_WORLD_X) < SIZE_TOLERANCE
		),
		(
			"local footprint is 2.36 x 2.20 as §3 states (got %.5f x %.5f)"
			% [n.box.size.x, n.box.size.z]
		)
	)

	# §4: the +90 degree correction puts the long axis along world Z.
	var world: AABB = Normalise.world_box(n, TAU / 4.0)
	_check(
		(
			absf(world.size.x - KART_EXACT_WORLD_X) < DOCUMENT_ROUNDING
			and absf(world.size.z - KART_EXACT_WORLD_Z) < DOCUMENT_ROUNDING
		),
		(
			"kart measures 2.20 across world X and 2.36 along world Z (got %.5f x %.5f)"
			% [world.size.x, world.size.z]
		)
	)

	# and the collision feature's contracted hitbox follows from it.
	var contracted: AABB = Normalise.contracted(world, 0.2)
	_check(
		(
			absf(contracted.size.x - 1.799804) < DOCUMENT_ROUNDING
			and absf(contracted.size.z - 1.955250) < DOCUMENT_ROUNDING
		),
		(
			"contracted 0.2 per side gives the document's 1.80 x 1.96 (got %.5f x %.5f)"
			% [contracted.size.x, contracted.size.z]
		)
	)


func _test_height_unaffected_by_heading() -> void:
	var authored := AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))
	var n = Normalise.to_target_height(authored, 2.5)
	for i in range(16):
		var yaw := TAU * float(i) / 16.0
		var world: AABB = Normalise.world_box(n, yaw)
		_check(
			absf(world.size.y - 2.5) < SIZE_TOLERANCE and absf(world.position.y) < GROUND_TOLERANCE,
			"height and ground contact are unchanged at yaw %.3f" % yaw
		)


func _test_world_box_never_smaller_than_axis_aligned() -> void:
	var authored := AABB(Vector3(-1.0, 0.0, -0.4), Vector3(2.0, 1.0, 0.8))
	var n = Normalise.to_target_height(authored, 1.0)
	var aligned: AABB = Normalise.world_box(n, 0.0)
	var smaller := 0
	for i in range(32):
		var yaw := TAU * float(i) / 32.0
		var world: AABB = Normalise.world_box(n, yaw)
		var area: float = world.size.x * world.size.z
		if area < aligned.size.x * aligned.size.z - 1e-9:
			smaller += 1
	_check(
		smaller == 0, "no heading yields a smaller footprint than axis-aligned (%d did)" % smaller
	)
