# The scattered field in a running scene: props exist, regeneration replaces
# them, and the kart is left alone.
#
#   godot --headless -s tests/prop_field_test.gd
#
# tests/scatter_test.gd proves the placement rules with no scene loaded. This is
# the half that needs a tree: that the placements become props, that regenerating
# releases the old ones, and that the design document's requirement — the kart's
# position, heading, velocity and the running clock all untouched — actually
# holds in the game rather than only in the generator.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const Scatter := preload("res://scripts/core/scatter.gd")
const LayoutIO := preload("res://scripts/world/layout_io.gd")

var _root: Node3D = null


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	await process_frame
	_root = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	get_root().add_child(_root)
	await process_frame

	_test_the_field_is_populated()
	_test_records_keep_the_acceptance_order()
	_test_records_are_in_registration_order()
	await _test_regeneration_replaces_the_props()
	_test_regeneration_leaves_the_kart_alone()

	get_root().remove_child(_root)
	_root.free()
	_root = null
	RVTest.finish(self, "prop field: populated, regenerated, kart untouched", "prop field check(s)")


func _requested_total() -> int:
	var total: int = 0
	for asset in Scatter.ASSET_ORDER:
		total += int(_root.sim.tuning.prop_count(asset))
	return total


## THE BOOT FIELD IS THE SHIPPED CIRCUIT'S, not a scatter, so its population is
## the committed file's — the requested totals LESS whatever curation dropped
## from a gate mouth (tools/author_first_light.gd). Asserting the tuning's
## totals here passed only while the curation happened to drop nothing; the
## requested totals are a property of a REGENERATED field, checked below.
func _test_the_field_is_populated() -> void:
	_check(_root.props != null, "the scene has a prop field")
	if _root.props == null:
		return
	var count: int = _root.props.prop_count()
	var shipped: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(LayoutIO.SHIPPED_CIRCUIT_PATH)
	)
	var authored: int = (shipped["props"] as Array).size()
	_check(
		count == authored and count <= _requested_total(),
		(
			"the boot field is the shipped circuit's own %d props (%d requested by the tuning)"
			% [authored, _requested_total()]
		)
	)
	# One node per record, so nothing is registered that is not drawn and nothing
	# drawn that collision will not see.
	_check(
		_root.props.get_child_count() == count,
		(
			"one instantiated node per record (%d nodes, %d records)"
			% [_root.props.get_child_count(), count]
		)
	)


## The order the next change resolves collisions by, preserved through the view.
##
## Against the ACCEPTANCE INDEX, not against Scatter.ASSET_ORDER. Comparing the
## view's asset sequence to the port's own constant is what let review reorder
## records inside an asset with the whole suite green.
func _test_records_keep_the_acceptance_order() -> void:
	var records: Array = _root.props.records
	_check(records.size() > 0, "there are records to check")
	var wrong: int = 0
	for i in range(records.size()):
		if records[i].sequence != i:
			wrong += 1
			if wrong == 1:
				_check(
					false,
					(
						"record %d carries acceptance index %d — the view reordered them"
						% [i, records[i].sequence]
					)
				)
	_check(wrong == 0, "every record sits at the index its placement was accepted at")


## The order the next change resolves collisions by, preserved through the view.
func _test_records_are_in_registration_order() -> void:
	var seen: Array[String] = []
	for record in _root.props.records:
		var asset: String = record.asset
		if seen.is_empty() or seen[-1] != asset:
			_check(not seen.has(asset), "%s's records are contiguous" % asset)
			seen.append(asset)
	var expected: Array[String] = []
	for asset in Scatter.ASSET_ORDER:
		if seen.has(asset):
			expected.append(asset)
	_check(seen == expected, "records follow the document's table order (got %s)" % [seen])


func _test_regeneration_replaces_the_props() -> void:
	var before_seed: int = _root.field_seed
	var before: Array[String] = []
	for record in _root.props.records:
		before.append("%s|%.6f|%.6f" % [record.asset, record.x, record.z])

	_root.regenerate_world()
	# One frame, because queue_free() is DEFERRED and a count taken immediately
	# would still see the old nodes.
	#
	# Be precise about what this does NOT establish: prop_field.clear() frees
	# immediately rather than queueing, and swapping it back to queue_free() does
	# NOT fail this test — verified by trying it. After a frame both are correct,
	# and the difference is only visible to a caller counting children within the
	# same frame. The immediate free is the better choice for that reason, not
	# because anything here would catch the other.
	await process_frame

	_check(_root.field_seed != before_seed, "regenerating moved to a new seed")
	_check(
		_root.props.prop_count() == _requested_total(),
		"the fresh population is complete (%d)" % _root.props.prop_count()
	)
	_check(
		_root.props.get_child_count() == _root.props.prop_count(),
		(
			"and no nodes from the old field survive (%d nodes, %d records)"
			% [_root.props.get_child_count(), _root.props.prop_count()]
		)
	)
	var after: Array[String] = []
	for record in _root.props.records:
		after.append("%s|%.6f|%.6f" % [record.asset, record.x, record.z])
	_check(before != after, "and the arrangement actually changed")


## Regeneration is now the AUTHORING path (the GDD's scenario became
## "Restarting the circuit" at amend-gdd-for-checkpoint-circuit, deferred to
## the M9 implementation) — but the machinery's own guarantee below still
## holds and still matters: a world operation is not a kart reset.
func _test_regeneration_leaves_the_kart_alone() -> void:
	var sim: RefCounted = _root.sim

	# THE TICK IS PAUSED ACROSS THIS ASSERTION, and that is the test, not a
	# convenience. `regenerate_world()` is synchronous: it scatters, rebuilds the
	# view and re-wires the simulation without yielding, so nothing here needs a
	# frame. What a frame WOULD do is advance the kart — friction alone takes
	# 0.15 to 0.144 in one tick, integration moves it, and now that stage 7 has a
	# body a prop dropped on the kart zeroes its velocity outright, which is a
	# different scenario's specified behaviour.
	#
	# The first version of this test awaited a frame and asserted the kart was
	# unchanged. It passed while stage 7 was empty and the physics frame usually
	# missed the window; it flaked once in a full run of the gate after collision
	# was wired, with "its velocity is untouched". A test that depends on a
	# physics frame NOT landing is not a test of regeneration.
	_root.set_physics_process(false)

	sim.pos_x = 12.5
	sim.pos_z = -7.25
	sim.yaw = 1.25
	sim.velocity = 0.15
	var ticks_before: int = sim.ticks

	_root.regenerate_world()

	_check(
		sim.pos_x == 12.5 and sim.pos_z == -7.25,
		"the kart's position is untouched by regeneration (%.9f, %.9f)" % [sim.pos_x, sim.pos_z]
	)
	_check(sim.yaw == 1.25, "its heading is untouched (%.9f)" % sim.yaw)
	_check(sim.velocity == 0.15, "its velocity is untouched (%.9f)" % sim.velocity)
	# The clock is the tick count; regeneration must neither advance nor reset it.
	# Exact, now that nothing else can advance it.
	_check(
		sim.ticks == ticks_before,
		"the running clock is untouched (%d -> %d)" % [ticks_before, sim.ticks]
	)
	# And the field really was replaced, so none of the above is vacuous.
	_check(_root.props.prop_count() == _requested_total(), "and a fresh field was built")

	_root.set_physics_process(true)
