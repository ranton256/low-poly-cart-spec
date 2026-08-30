# Track layout persistence — the design document's feature entire, plus the
# port decisions in godot/layout-persistence: A2's delivery, A3's order, the
# absolute-scale-applied-once rule, refuse-whole validation.
#
#   godot --headless -s tests/layout_test.gd
#
# EXPECTED VALUES COME FROM THE DESIGN DOCUMENT: one record per prop carrying
# asset id, target height, full position, yaw, full scale; indented
# human-readable JSON; release-first restore; round trips identical within
# floating-point tolerance and byte-identical across repeated cycles.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const MainScene := preload("res://scenes/main.tscn")
const LayoutIO := preload("res://scripts/world/layout_io.gd")

const TEST_PATH := "user://layout_test.json"
const SECOND_PATH := "user://layout_test_2.json"
const BAD_PATH := "user://layout_test_bad.json"
const THIRD_PATH := "user://layout_test_3.json"

var _root: Node3D = null


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	OS.set_environment("LPC_LAYOUT_FILE", TEST_PATH)
	await process_frame
	_root = MainScene.instantiate() as Node3D
	get_root().add_child(_root)
	await process_frame

	_test_export_writes_the_specified_records()
	_test_restore_rebuilds_exactly_in_file_order()
	_test_repeated_cycles_are_byte_identical()
	_test_malformed_file_is_refused_whole()
	await _test_reset_kart_is_surgical()
	_test_live_tuning_applies_next_tick()

	OS.set_environment("LPC_LAYOUT_FILE", "")
	get_root().remove_child(_root)
	_root.free()
	RVTest.finish(
		self, "layout: export, exact restore, order, no drift, refusal ok", "layout check(s)"
	)


# @covers Track Layout Persistence / Exporting the current layout
func _test_export_writes_the_specified_records() -> void:
	_check(_root.save_layout(), "Save Layout reports success")
	var text := FileAccess.get_file_as_string(TEST_PATH)
	_check(text != "", "track_layout.json exists at the layout path")
	_check(text.contains("\n  "), "and is indented, human-readable text")
	var parsed: Variant = JSON.parse_string(text)
	_check(parsed is Dictionary and (parsed as Dictionary).has("props"), "a JSON object with props")
	var props: Array = (parsed as Dictionary)["props"]
	var field: Node3D = _root.props
	_check(
		props.size() == field.records.size() and props.size() > 50,
		"one record per placed prop (%d)" % props.size()
	)
	for i in range(props.size()):
		var record: Dictionary = props[i]
		for key in ["asset", "targetHeight", "position", "yaw", "scale"]:
			if not record.has(key):
				_check(false, "record %d is missing %s" % [i, key])
				return
		if record["asset"] != (field.records[i] as RefCounted).asset:
			_check(false, "record %d is out of registration order" % i)
			return
	_check(true, "every record carries the specified fields, in registration order")
	# The scale is the ABSOLUTE final world scale: it matches the instantiated
	# node's world scale exactly.
	var first: Dictionary = props[0]
	var node: Node3D = field.get_child(0) as Node3D
	RVTest.close(
		(first["scale"] as Array)[0],
		node.scale.x,
		0.0001,
		"the recorded scale is the node's absolute world scale"
	)
	RVTest.close(
		(first["position"] as Array)[1],
		node.position.y,
		0.0001,
		"and the position is the node's full world position, Y included"
	)


# @covers Track Layout Persistence / Restoring a saved layout
func _test_restore_rebuilds_exactly_in_file_order() -> void:
	var field: Node3D = _root.props
	var before: Array = []
	for record in field.records:
		before.append([record.asset, record.x, record.z, record.yaw])
	var nodes_before: Array = []
	for child in field.get_children():
		nodes_before.append([child.name, (child as Node3D).position, (child as Node3D).scale.x])

	# Change the world completely, then restore.
	_root.regenerate_world()
	var changed := false
	for i in range(mini(before.size(), field.records.size())):
		if absf((field.records[i] as RefCounted).x - before[i][1]) > 0.001:
			changed = true
	_check(changed, "setup: regeneration produced a different field")

	_check(_root.load_layout(), "Load Layout reports success")
	_check(
		field.records.size() == before.size(), "every prop restored (release-first, then rebuild)"
	)
	var order_ok := true
	var transform_ok := true
	for i in range(before.size()):
		var record: RefCounted = field.records[i]
		if record.asset != before[i][0]:
			order_ok = false
		if (
			absf(record.x - before[i][1]) > 0.001
			or absf(record.z - before[i][2]) > 0.001
			or absf(record.yaw - before[i][3]) > 0.001
		):
			transform_ok = false
	_check(order_ok, "in the file's order — collision resolves identically (A3)")
	_check(transform_ok, "each at exactly the recorded transform")
	# The collision array agrees element by element.
	var sim_props: Array = _root.sim.props
	_check(sim_props.size() == before.size(), "the simulation was re-wired to the restored field")
	for i in range(before.size()):
		if (sim_props[i] as RefCounted).asset != before[i][0]:
			_check(false, "collision prop %d is out of order" % i)
			return
	_check(true, "and the collision order matches the saved field, prop for prop")
	# Node transforms match the pre-restore nodes exactly.
	for i in range(nodes_before.size()):
		var node: Node3D = field.get_child(i) as Node3D
		if (
			node.position.distance_to(nodes_before[i][1]) > 0.001
			or absf(node.scale.x - nodes_before[i][2]) > 0.0001
		):
			_check(false, "node %d transform drifted on restore" % i)
			return
	_check(true, "every restored node sits at the saved world transform and scale")


# @covers Track Layout Persistence / Round-tripping a layout without drift
func _test_repeated_cycles_are_byte_identical() -> void:
	# The scenario's property is CONVERGENCE: "repeated export/import cycles
	# produce identical layouts rather than progressively shrinking or growing
	# props". The first re-export may differ from scatter's own file by float
	# dust (the variation path grounds through different arithmetic — observed
	# at 6e-8 on one component, far inside the stated tolerance and asserted
	# so above); from then on, cycles must be BYTE-identical — any scale
	# compounding would grow without bound instead.
	OS.set_environment("LPC_LAYOUT_FILE", SECOND_PATH)
	_check(_root.save_layout(), "second export succeeds")
	_check(_root.load_layout(), "second import succeeds")
	OS.set_environment("LPC_LAYOUT_FILE", THIRD_PATH)
	_check(_root.save_layout(), "third export succeeds")
	OS.set_environment("LPC_LAYOUT_FILE", TEST_PATH)
	var b := FileAccess.get_file_as_string(SECOND_PATH)
	var c := FileAccess.get_file_as_string(THIRD_PATH)
	_check(b == c and b != "", "cycle N and cycle N+1 are BYTE-identical — no compounding")
	# And the headline number: scales across the two files are equal, so props
	# neither shrink nor grow.
	var pb: Dictionary = JSON.parse_string(b)
	var pc: Dictionary = JSON.parse_string(c)
	var first_b: Dictionary = (pb["props"] as Array)[0]
	var first_c: Dictionary = (pc["props"] as Array)[0]
	_check(
		(first_b["scale"] as Array)[0] == (first_c["scale"] as Array)[0],
		"prop scale is bit-stable across cycles"
	)


func _test_malformed_file_is_refused_whole() -> void:
	var field: Node3D = _root.props
	var count_before: int = field.records.size()
	var first_x: float = (field.records[0] as RefCounted).x
	var bad := FileAccess.open(BAD_PATH, FileAccess.WRITE)
	bad.store_string('{"props": [{"asset": "not_a_real_asset", "yaw": 0}]}')
	bad.close()
	OS.set_environment("LPC_LAYOUT_FILE", BAD_PATH)
	_check(not _root.load_layout(), "a malformed layout is refused")
	OS.set_environment("LPC_LAYOUT_FILE", TEST_PATH)
	_check(
		(
			field.records.size() == count_before
			and absf((field.records[0] as RefCounted).x - first_x) < 0.0001
		),
		"and the current world is untouched — nothing was released"
	)


# @covers Runtime Tuning and Player Actions / Resetting the kart
func _test_reset_kart_is_surgical() -> void:
	var sim: RefCounted = _root.sim
	sim.race.start_racing_immediately()
	for _i in range(40):
		Input.action_press("accelerate")
		await physics_frame
	Input.action_release("accelerate")
	_check(sim.pos_z > 1.0, "setup: the kart drove away (z=%.2f)" % sim.pos_z)
	# A best and a banked time on the board — the M4 review's standing note:
	# persistence THROUGH the reset, not only through regeneration.
	sim.lap.best_seconds = 42.5
	sim.lap.banked_seconds = 43.0
	var clock_before: float = sim.lap.clock_seconds()
	var ticks_before: int = sim.ticks

	sim.reset_kart()
	_check(
		sim.pos_x == 0.0 and sim.pos_z == 0.0 and sim.yaw == 0.0 and sim.velocity == 0.0,
		"the kart stands at the origin facing +Z at zero velocity"
	)
	_check(sim.lap.best_seconds == 42.5, "the session best is untouched")
	_check(sim.lap.banked_seconds == 43.0, "the banked time is untouched")
	_check(sim.lap.clock_seconds() == clock_before, "the clock did not move")
	_check(sim.ticks == ticks_before, "the reset consumed no tick of its own")
	_check(sim.race.is_racing(), "and the race state is untouched")
	sim.lap.best_seconds = -1.0
	sim.lap.banked_seconds = -1.0

	# The pin's specified escape: hold the kart against a prop, then reset.
	var target: RefCounted = sim.props[0]
	sim.pos_x = target.centre_x() + 0.2
	sim.pos_z = target.centre_z() + 0.2
	await physics_frame
	_check(sim.last_hit != null, "setup: the kart is held against a prop")
	# Through the REAL binding: R while racing.
	Input.action_press("reset_kart")
	await physics_frame
	await physics_frame
	Input.action_release("reset_kart")
	_check(
		sim.pos_x == 0.0 and sim.pos_z == 0.0,
		"R frees it to the origin — the document's escape from the pin is real"
	)
	await physics_frame
	_check(sim.last_hit == null, "standing on clear ground (startClearance keeps the origin open)")


## The live tuning surface: re-applying the file lands in the SHARED object
## and is in force on the next tick, disturbing nothing else. (The
## next-tick property itself is claimed by the determinism suite's
## tuning-change test since M4; this proves the running game's surface.)
func _test_live_tuning_applies_next_tick() -> void:
	var sim: RefCounted = _root.sim
	var file_accel: float = sim.tuning.accel
	sim.tuning.accel = file_accel * 3.0  # a drifted live value
	var x_before: float = sim.pos_x
	var ticks_before: int = sim.ticks
	_check(_root.apply_tuning_file(), "the tuning file re-applies while the game runs")
	_check(sim.tuning.accel == file_accel, "into the same shared object every consumer holds")
	_check(
		sim.pos_x == x_before and sim.ticks == ticks_before,
		"the application itself disturbs neither the kart nor the clock"
	)
