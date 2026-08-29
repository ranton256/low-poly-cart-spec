# Seeded world scatter: the placement rules, the budget, the variation, the order.
#
#   godot --headless -s tests/scatter_test.gd
#
# TWO THINGS IN HERE ARE EASY TO GET WRONG IN A WAY THAT PASSES.
#
# The ORDER. add-aabb-collision-response resolves "the first intersecting prop in
# registration order only", so the sequence this generator emits is part of that
# contract. A test comparing two fields as SETS passes while the order varies, and
# the resulting collisions would be wrong and reproducible. Everything below
# compares serialised sequences.
#
# The RANGES. Acceptance item 2 is "every prop stands exactly on the ground at
# every random scale". A check at one scale passes on a generator that ignores
# scale; a check on one asset passes on one that mishandles the other six. This is
# the shape review caught in add-chase-camera, where the kart's aim was asserted at
# yaw 0 — the one heading where a world-frame bug is invisible.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const Scatter := preload("res://scripts/core/scatter.gd")
const Normalise := preload("res://scripts/core/normalise.gd")
const Rng := preload("res://scripts/core/rng.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")

const SEED_A := 20260829
const SEED_B := 987654321

## Synthetic authored boxes — deliberately NOT the real models. The placement
## rules are arithmetic and must hold for any input; using the supplied .glb
## bounds here would make this suite depend on an import and would test the
## assets rather than the generator. tools/check_scatter_conformance.py drives
## the real ones.
##
## Each is a different shape, including one whose origin is off-centre, so the
## grounding assertion cannot pass by every box happening to be symmetric.
## [size x, size y, size z, offset y, offset x, offset z]. The last three shift the
## box off its own origin.
##
## AT LEAST ONE IS OFF-CENTRE ON X AND Z, and that matters: review found that
## every synthetic box here AND all six supplied models are X/Z-symmetric about
## their origins, so offset_x and offset_z were identically zero on every input
## either the unit suite or the conformance gate ever saw — and setting
## `offset_x = 999.0` in the generator passed the entire project. `rock` below is
## the input that cannot happen on.
const AUTHORED := {
	"tree": [2.0, 6.0, 2.0, 0.0, 0.0, 0.0],
	"rock": [3.0, 1.2, 2.5, 0.0, 0.9, -0.7],
	"cone": [0.6, 1.0, 0.6, 0.0, 0.0, 0.0],
	"crate": [1.5, 1.5, 1.5, 0.0, 0.0, 0.0],
	"tires": [2.2, 0.9, 2.2, 0.0, 0.0, 0.0],
	"cottage": [7.0, 5.0, 6.0, 1.3, -1.1, 0.4],
}


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_test_a_seed_reproduces_the_field_as_a_sequence()
	_test_different_seeds_give_different_fields()
	_test_unrelated_draws_do_not_change_the_field()
	_test_the_start_area_stays_clear()
	_test_props_do_not_crowd_each_other_across_assets()
	_test_nothing_is_placed_outside_the_scatter_extent()
	_test_instances_are_centred_on_x_and_z()
	_test_the_budget_ends_an_impossible_request()
	_test_every_instance_rests_on_the_ground_at_every_scale()
	_test_variation_spans_its_range()
	_test_placements_are_in_acceptance_order()
	_test_the_registration_order_is_the_documents_table_order()
	RVTest.finish(self, "scatter: seeded, spaced, grounded, ordered", "scatter check(s)")


func _boxes() -> Dictionary:
	var out: Dictionary = {}
	for asset in AUTHORED:
		var d: Array = AUTHORED[asset]
		# position is the box's corner: an off-centre origin is expressed by
		# shifting it, which is what the fourth number does.
		out[asset] = AABB(
			Vector3(-d[0] / 2.0 + d[4], -d[1] / 2.0 + d[3], -d[2] / 2.0 + d[5]),
			Vector3(d[0], d[1], d[2])
		)
	return out


func _scatter() -> RefCounted:
	var s := Scatter.new()
	s.tuning = TuningLoader.load_tuning()
	return s


func _field(seed_value: int) -> Array:
	return _scatter().generate(seed_value, _boxes())


# @covers Procedural World Generation / Scattering the standard prop population
## AS A SEQUENCE. See the file header.
func _test_a_seed_reproduces_the_field_as_a_sequence() -> void:
	var first: String = Scatter.serialise(_field(SEED_A))
	var second: String = Scatter.serialise(_field(SEED_A))
	_check(first == second, "the same seed reproduces the field exactly, in order")
	_check(first.length() > 0, "and the field is not empty, so the comparison means something")


## A generator that ignored its seed would satisfy every other check in this file.
func _test_different_seeds_give_different_fields() -> void:
	_check(
		Scatter.serialise(_field(SEED_A)) != Scatter.serialise(_field(SEED_B)),
		"two different seeds produce different fields"
	)


## What seeding at the start of each generation buys (design D2): the field cannot
## depend on how much unrelated code drew from the shared stream first.
func _test_unrelated_draws_do_not_change_the_field() -> void:
	var clean: String = Scatter.serialise(_field(SEED_A))
	Rng.seed_rng(11111)
	for _i in range(37):
		Rng.randf01()
	var after: String = Scatter.serialise(_field(SEED_A))
	_check(clean == after, "unrelated draws from the shared stream do not change the field")


func _test_the_start_area_stays_clear() -> void:
	var s: RefCounted = _scatter()
	var placements: Array = s.generate(SEED_A, _boxes())
	var cottages_checked: int = 0
	for placement in placements:
		var p: Scatter.Placement = placement as Scatter.Placement
		var distance: float = sqrt(p.x * p.x + p.z * p.z)
		var clearance: float = s.clearance_for(p.asset)
		if p.asset == "cottage":
			cottages_checked += 1
		_check(
			distance >= clearance - 1e-9,
			"%s at %.2f from the origin clears its radius of %.1f" % [p.asset, distance, clearance]
		)
	# The larger radius is held to the LARGER value, which is what makes cottages
	# distant landmarks. Without this the check passes on a generator that used
	# startClearance for everything.
	_check(cottages_checked > 0, "cottages were placed, so their larger radius was exercised")


# @covers Procedural World Generation / Rejecting a candidate placement
## ACROSS ASSETS, not within one. A generator that checks separation only against
## others of the same asset satisfies a naive test and stands a cone inside a crate.
func _test_props_do_not_crowd_each_other_across_assets() -> void:
	var s: RefCounted = _scatter()
	var placements: Array = s.generate(SEED_A, _boxes())
	var separation: float = s.tuning.min_prop_separation
	var cross_asset_pairs: int = 0
	for i in range(placements.size()):
		for j in range(i + 1, placements.size()):
			var a: Scatter.Placement = placements[i] as Scatter.Placement
			var b: Scatter.Placement = placements[j] as Scatter.Placement
			var dx: float = a.x - b.x
			var dz: float = a.z - b.z
			var distance: float = sqrt(dx * dx + dz * dz)
			if a.asset != b.asset:
				cross_asset_pairs += 1
			if distance < separation - 1e-9:
				_check(
					false,
					(
						"%s and %s are %.4f apart, closer than %.1f"
						% [a.asset, b.asset, distance, separation]
					)
				)
				return
	_check(true, "no two props are closer than minPropSeparation")
	_check(
		cross_asset_pairs > 0,
		"and pairs of DIFFERENT assets were among those compared (%d)" % cross_asset_pairs
	)


# @covers Procedural World Generation / Leaving an empty outer ring
func _test_nothing_is_placed_outside_the_scatter_extent() -> void:
	var s: RefCounted = _scatter()
	var placements: Array = s.generate(SEED_A, _boxes())
	var extent: float = s.tuning.scatter_extent
	# PER AXIS. An earlier version reduced the field to max(|x|, |z|) and asserted
	# one number against the extent: a one-sided bound over both axes collapsed
	# into one. Review confined every candidate to a quarter of the Z range — a
	# 100 x 25 strip instead of 100 x 100 — and the whole suite stayed green.
	var worst_x: float = 0.0
	var worst_z: float = 0.0
	for placement in placements:
		var p: Scatter.Placement = placement as Scatter.Placement
		worst_x = maxf(worst_x, absf(p.x))
		worst_z = maxf(worst_z, absf(p.z))
	_check(
		worst_x <= extent + 1e-9 and worst_z <= extent + 1e-9,
		(
			"every prop is inside +/-%.0f wu on both axes (worst X %.3f, Z %.3f)"
			% [extent, worst_x, worst_z]
		)
	)
	# AND A FLOOR, which is what catches a squeezed axis. Candidates are uniform
	# over +/-extent, so with this many placements the furthest on each axis lands
	# close to the extent: the chance that 50-odd uniform draws all fall inside
	# 60% of the range is vanishing. Well below what uniformity produces, well
	# above what the quarter-range mutation gives (0.25).
	var floor_fraction: float = 0.6
	_check(
		placements.size() >= 40,
		"enough placements for the spread to mean something (%d)" % placements.size()
	)
	_check(
		worst_x >= extent * floor_fraction and worst_z >= extent * floor_fraction,
		(
			(
				"both axes span the extent (worst X %.1f, Z %.1f, floor %.1f) — a squeezed"
				+ " axis fails here rather than passing a one-sided bound"
			)
			% [worst_x, worst_z, extent * floor_fraction]
		)
	)


## The offsets that CENTRE an instance on its own origin, which nothing asserted
## until review set offset_x to 999 and watched the project stay green.
func _test_instances_are_centred_on_x_and_z() -> void:
	var s: RefCounted = _scatter()
	var boxes: Dictionary = _boxes()
	for placement in s.generate(SEED_A, boxes):
		var p: Scatter.Placement = placement as Scatter.Placement
		var authored: AABB = boxes[p.asset] as AABB
		# Where the scaled, offset box sits on each axis: its centre must land on
		# the placement position, not somewhere else.
		var centre_x: float = (authored.position.x + authored.size.x / 2.0) * p.scale + p.offset_x
		var centre_z: float = (authored.position.z + authored.size.z / 2.0) * p.scale + p.offset_z
		_check(
			absf(centre_x) < 1e-6 and absf(centre_z) < 1e-6,
			"%s is centred on its own origin (centre %.9f, %.9f)" % [p.asset, centre_x, centre_z]
		)


# @covers Procedural World Generation / Giving up gracefully when placements cannot be found
## Driven with a request the rules CANNOT satisfy, so the budget is what ends it.
## A budget check on a field that places easily never exercises the budget at all.
func _test_the_budget_ends_an_impossible_request() -> void:
	var s: RefCounted = _scatter()
	# A separation wider than the scatter area: after the first prop, nothing else
	# can ever be accepted.
	s.tuning.min_prop_separation = s.tuning.scatter_extent * 4.0
	var placements: Array = s.generate(SEED_A, _boxes())
	_check(placements.size() > 0, "the impossible request still placed something")
	var short: bool = false
	for asset in Scatter.ASSET_ORDER:
		if s.achieved[asset] < s.requested[asset]:
			short = true
			_check(
				s.attempts[asset] == int(s.tuning.attempt_budget) * s.requested[asset],
				(
					"%s stopped at exactly attemptBudget x N attempts (%d of %d)"
					% [asset, s.attempts[asset], int(s.tuning.attempt_budget) * s.requested[asset]]
				)
			)
	_check(short, "the impossible request fell short rather than looping forever")
	_check(s.shortfall_report().length() > 0, "and the shortfall is reported")


# @covers Procedural World Generation / Varying repeated instances so the field does not look tiled
## ACCEPTANCE ITEM 2, across the whole scale range and every asset.
##
## The generator's own scales are random, so this also drives the extremes
## directly: a check that only saw whatever the seed produced could miss the ends
## of the range, and the document says "at every random scale".
func _test_every_instance_rests_on_the_ground_at_every_scale() -> void:
	var s: RefCounted = _scatter()
	var boxes: Dictionary = _boxes()

	# What the generator actually produced.
	for placement in s.generate(SEED_A, boxes):
		var p: Scatter.Placement = placement as Scatter.Placement
		var lowest: float = _lowest_point(boxes[p.asset] as AABB, p.scale, p.offset_y)
		_check(
			absf(lowest) < 1e-6,
			"%s at scale %.4f rests at ground level (lowest %.9f)" % [p.asset, p.scale, lowest]
		)

	# And the extremes, for every asset, whether or not this seed reached them.
	var low: float = s.tuning.scale_variation_min
	var high: float = s.tuning.scale_variation_max
	for asset in Scatter.ASSET_ORDER:
		var normalised: RefCounted = Normalise.to_target_height(
			boxes[asset] as AABB, s.tuning.target_height(asset)
		)
		for factor in [low, (low + high) / 2.0, high]:
			var varied: RefCounted = Normalise.with_variation(normalised, factor)
			# The authored-space offset, derived the same way scatter.gd derives it.
			# with_variation's own offset.y is always zero — it operates on an
			# already-grounded box — so using it here would assert nothing.
			var authored: AABB = boxes[asset] as AABB
			var offset_y: float = varied.box.position.y - authored.position.y * varied.scale
			var lowest: float = _lowest_point(authored, varied.scale, offset_y)
			_check(
				absf(lowest) < 1e-6,
				"%s at variation %.2f rests at ground level (lowest %.9f)" % [asset, factor, lowest]
			)


## Where the model's lowest point ends up: the authored box scaled, then lifted.
func _lowest_point(authored: AABB, scale: float, offset_y: float) -> float:
	return authored.position.y * scale + offset_y


func _test_variation_spans_its_range() -> void:
	var s: RefCounted = _scatter()
	var placements: Array = s.generate(SEED_A, _boxes())
	var yaws: Array[float] = []
	var scales: Array[float] = []
	for placement in placements:
		var p: Scatter.Placement = placement as Scatter.Placement
		yaws.append(p.yaw)
		scales.append(p.scale)
	_check(yaws.size() > 10, "enough instances to judge spread (%d)" % yaws.size())
	_check(yaws.min() < PI / 2.0 and yaws.max() > 3.0 * PI / 2.0, "yaws span the full turn")
	_check(scales.min() < scales.max(), "instances differ in scale")
	# Every scale must lie inside the variation range, scaled by the asset's own
	# target-height factor — checked per asset, since the factors differ.
	for placement in placements:
		var p: Scatter.Placement = placement as Scatter.Placement
		var base: RefCounted = Normalise.to_target_height(
			(_boxes()[p.asset]) as AABB, s.tuning.target_height(p.asset)
		)
		var ratio: float = p.scale / base.scale
		_check(
			(
				ratio >= s.tuning.scale_variation_min - 1e-6
				and ratio <= s.tuning.scale_variation_max + 1e-6
			),
			(
				"%s's variation factor %.4f is inside [%.2f, %.2f]"
				% [p.asset, ratio, s.tuning.scale_variation_min, s.tuning.scale_variation_max]
			)
		)


## WITHIN an asset, not just between assets.
##
## Review reordered placements inside a single asset — leaving every asset
## contiguous and in the document's table order — and the whole project stayed
## green. That is the value add-aabb-collision-response resolves against, so it
## is the half worth guarding hardest.
func _test_placements_are_in_acceptance_order() -> void:
	var placements: Array = _field(SEED_A)
	var wrong: int = 0
	for i in range(placements.size()):
		var p: Scatter.Placement = placements[i] as Scatter.Placement
		if p.sequence != i:
			wrong += 1
			if wrong == 1:
				_check(
					false,
					(
						"placement %d was accepted %dth — the array is not in acceptance order"
						% [i, p.sequence]
					)
				)
	_check(wrong == 0, "every placement sits at the index it was accepted at")
	# And the sequence really was populated, so the check above is not comparing
	# two defaults.
	_check(
		placements.size() > 0 and (placements[0] as Scatter.Placement).sequence == 0,
		"the acceptance index is recorded, so this test is not vacuous"
	)


## The registration order the next change resolves collisions by.
func _test_the_registration_order_is_the_documents_table_order() -> void:
	var placements: Array = _field(SEED_A)
	var seen: Array[String] = []
	for placement in placements:
		var asset: String = (placement as Scatter.Placement).asset
		if seen.is_empty() or seen[-1] != asset:
			_check(not seen.has(asset), "%s's placements are contiguous, not interleaved" % asset)
			seen.append(asset)
	var expected: Array[String] = []
	for asset in Scatter.ASSET_ORDER:
		if seen.has(asset):
			expected.append(asset)
	_check(
		seen == expected,
		"assets are emitted in the document's table order (got %s, want %s)" % [seen, expected]
	)
