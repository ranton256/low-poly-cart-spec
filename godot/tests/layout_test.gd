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
const Collision := preload("res://scripts/core/collision.gd")

const TEST_PATH := "user://layout_test.json"
const SECOND_PATH := "user://layout_test_2.json"
const BAD_PATH := "user://layout_test_bad.json"
const THIRD_PATH := "user://layout_test_3.json"
const V2_SEED_PATH := "user://layout_test_v2_seed.json"
const V2_A_PATH := "user://layout_test_v2_a.json"
const V2_B_PATH := "user://layout_test_v2_b.json"
const V2_C_PATH := "user://layout_test_v2_c.json"
const BAD_CIRCUIT_PATH := "user://layout_test_bad_circuit.json"
const GATELESS_PATH := "user://layout_test_gateless.json"

## The circuit the v2 cases carry. Deliberately not five-decimal values: the
## export's own quantization is what has to make the cycles agree.
const SEED_CIRCUIT: Dictionary = {
	"name": "round_trip",
	"gates":
	[
		{"position": [12.3456789, -4.2], "yaw": 0.7853981633974483, "width": 9.87654321},
		{"position": [-30.5, 41.25], "yaw": -1.5707963267948966, "width": 12.0},
		{"position": [0.0, 5.0], "yaw": 0.0, "width": 10.0},
	],
	"targets": {"bronze": 60.0, "silver": 45.5, "gold": 38.25},
}

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
	await _test_the_watch_detects_a_change_on_the_sim_clock()
	_test_a_malformed_circuit_refuses_the_whole_file()
	_test_a_circuit_round_trips_byte_identically()
	_test_a_gateless_file_is_refused()

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
	# The delta spec's property, held from CYCLE ZERO: five-decimal export
	# quantization collapses the reconstruction dust (~6e-8 between scatter's
	# grounding and the §3 re-derivation), so the first export, the re-export,
	# and every later cycle are the same bytes. The first draft only converged
	# from cycle one — the M7 Critic disproved the spec with a one-line probe.
	OS.set_environment("LPC_LAYOUT_FILE", SECOND_PATH)
	_check(_root.save_layout(), "second export succeeds")
	_check(_root.load_layout(), "second import succeeds")
	OS.set_environment("LPC_LAYOUT_FILE", THIRD_PATH)
	_check(_root.save_layout(), "third export succeeds")
	OS.set_environment("LPC_LAYOUT_FILE", TEST_PATH)
	var a := FileAccess.get_file_as_string(TEST_PATH)
	var b := FileAccess.get_file_as_string(SECOND_PATH)
	var c := FileAccess.get_file_as_string(THIRD_PATH)
	_check(
		a == b and a != "",
		"export → import → export is BYTE-identical from CYCLE ZERO — the delta spec's property"
	)
	_check(b == c, "and every later cycle agrees")
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

	# The pin's specified escape — against the REAL pin: two props at the
	# minimum 3 wu separation, the kart centred between them, held with its
	# velocity zeroed every tick (the M7 Critic's finding 2: the first draft
	# staged a single prop, a weaker arrangement than the spec's).
	var saved_props: Array = sim.props
	var pin_a := Collision.Prop.new()
	pin_a.asset = "pin_a"
	pin_a.box = AABB(Vector3(29.0, 0.0, 37.5), Vector3(2.0, 2.0, 2.0))
	var pin_b := Collision.Prop.new()
	pin_b.asset = "pin_b"
	pin_b.box = AABB(Vector3(29.0, 0.0, 40.5), Vector3(2.0, 2.0, 2.0))
	sim.props = [pin_a, pin_b]
	sim.pos_x = 30.0
	sim.pos_z = 40.0
	sim.velocity = 0.0
	var held := 0
	for _i in range(10):
		await physics_frame
		if sim.last_hit != null:
			held += 1
	_check(held >= 8, "setup: the kart is HELD between the pair, hit after hit (%d/10)" % held)
	_check(
		absf(sim.pos_z - 40.0) < 1.5 and sim.velocity == 0.0,
		"oscillating in place with velocity zeroed — the document's pin"
	)
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
	sim.props = saved_props


## The mtime watch itself — cadence, change detection, application (the M7
## Critic's finding 3: only the apply step had coverage). A stale baseline
## stands in for a real edit, so no repo file is written.
func _test_the_watch_detects_a_change_on_the_sim_clock() -> void:
	var sim: RefCounted = _root.sim
	var file_accel: float = sim.tuning.accel
	sim.tuning.accel = file_accel * 3.0
	_root._tuning_mtime = 1  # a baseline no real file reports: the next poll sees change
	_root._tuning_poll_tick = 0
	for _i in range(30):
		await physics_frame
	_check(
		sim.tuning.accel == file_accel * 3.0,
		"inside the one-second cadence the watch has not fired"
	)
	for _i in range(40):
		await physics_frame
	_check(
		sim.tuning.accel == file_accel,
		"at the cadence the change is detected and the table applied — in force next tick"
	)


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


## Write the current saved layout back out as version 2 carrying `circuit`,
## so the props half is known-good and only the circuit is under test.
func _write_v2(path: String, circuit: Variant) -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	var document: Dictionary = parsed.duplicate(true)
	document["version"] = 2
	document["circuit"] = circuit
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "  ") + "\n")
	file.close()


## Save the current field to `path` through the real Save Layout action.
func _save_to(path: String) -> bool:
	OS.set_environment("LPC_LAYOUT_FILE", path)
	return _root.save_layout()


## Load `path` through the real Load Layout action.
func _load_from(path: String) -> bool:
	OS.set_environment("LPC_LAYOUT_FILE", path)
	return _root.load_layout()


func _test_a_malformed_circuit_refuses_the_whole_file() -> void:
	var field: Node3D = _root.props
	var sim: RefCounted = _root.sim
	var count_before: int = field.records.size()
	var first_x: float = (field.records[0] as RefCounted).x
	var clock_before: int = sim.lap.clock_ticks

	# The delta spec's two named cases: a gate missing its width, and a
	# non-numeric target.
	var no_width: Dictionary = SEED_CIRCUIT.duplicate(true)
	(no_width["gates"] as Array)[1].erase("width")
	_write_v2(BAD_CIRCUIT_PATH, no_width)
	_check(not _load_from(BAD_CIRCUIT_PATH), "a gate missing its width refuses the whole file")

	var bad_target: Dictionary = SEED_CIRCUIT.duplicate(true)
	bad_target["targets"] = {"gold": "fast"}
	_write_v2(BAD_CIRCUIT_PATH, bad_target)
	_check(not _load_from(BAD_CIRCUIT_PATH), "a non-numeric target refuses it too")

	_write_v2(BAD_CIRCUIT_PATH, {"name": "empty", "gates": []})
	_check(not _load_from(BAD_CIRCUIT_PATH), "and so does a circuit that declares no gates")

	OS.set_environment("LPC_LAYOUT_FILE", TEST_PATH)
	_check(
		(
			field.records.size() == count_before
			and absf((field.records[0] as RefCounted).x - first_x) < 0.0001
		),
		"no prop was released — the current world is untouched"
	)
	_check(
		sim.circuit.circuit_name == "first-light",
		"and no gate was armed — the boot circuit is still the one being played"
	)
	_check(sim.lap.clock_ticks == clock_before, "and the clock did not move")


## The circuit half of "A layout is a circuit": the round trip. The refusal
## half is _test_a_gateless_file_is_refused below, and the two together are what
## claims the scenario.
# @covers Track Layout Persistence / A layout is a circuit
func _test_a_circuit_round_trips_byte_identically() -> void:
	var sim: RefCounted = _root.sim
	_write_v2(V2_SEED_PATH, SEED_CIRCUIT)
	_check(_load_from(V2_SEED_PATH), "a version-2 layout loads")
	_check(sim.circuit.gate_count() == 3, "and arms its three gates in file order")
	_check(sim.circuit.circuit_name == "round_trip", "under the file's own name")
	_check(float(sim.circuit.targets["silver"]) == 45.5, "carrying its medal targets")
	_check(sim.lap.best_key == "round_trip", "and the best readout is keyed to it")

	# Cycle zero onwards, exactly as the v1 case: save, load, save, load, save.
	_check(_save_to(V2_A_PATH), "the first re-export succeeds")
	_check(_load_from(V2_A_PATH), "re-importing it succeeds")
	_check(_save_to(V2_B_PATH), "the second re-export succeeds")
	_check(_load_from(V2_B_PATH), "and re-importing that one too")
	_check(_save_to(V2_C_PATH), "the third re-export succeeds")
	OS.set_environment("LPC_LAYOUT_FILE", TEST_PATH)

	var a := FileAccess.get_file_as_string(V2_A_PATH)
	var b := FileAccess.get_file_as_string(V2_B_PATH)
	var c := FileAccess.get_file_as_string(V2_C_PATH)
	_check(a != "" and a == b, "a v2 cycle is BYTE-identical from CYCLE ZERO, circuit included")
	_check(b == c, "and every later cycle agrees")
	var written: Dictionary = JSON.parse_string(a)
	_check(int(written["version"]) == 2, "the re-export is a version-2 file")
	_check(written.has("circuit"), "carrying the circuit object beside props")
	var gates: Array = (written["circuit"] as Dictionary)["gates"]
	_check(gates.size() == 3, "with every gate written back, in order")
	_check(
		(written["circuit"] as Dictionary)["name"] == "round_trip",
		"and the circuit's name unchanged"
	)

	# Leave the world as the suite found it: the shipped circuit armed, which is
	# what the boot loaded and what the refusal case below expects to survive.
	_check(_load_from(LayoutIO.SHIPPED_CIRCUIT_PATH), "and the shipped circuit re-loads")
	OS.set_environment("LPC_LAYOUT_FILE", TEST_PATH)


## The refusal half of "A layout is a circuit", through the REAL binding and on
## a file the game itself would write: exporting with no circuit armed is
## exactly how an authoring artifact is made, and the document says the game
## does not play one. The interim add-checkpoint-circuit-core recorded — that
## gateless files still loaded — ends here.
func _test_a_gateless_file_is_refused() -> void:
	var field: Node3D = _root.props
	var sim: RefCounted = _root.sim
	var count_before: int = field.records.size()
	var first_x: float = (field.records[0] as RefCounted).x
	var name_before: String = sim.circuit.circuit_name
	var gates_before: int = sim.circuit.gate_count()

	# A version-1 file: the shipped circuit's own props with the circuit removed,
	# so the props half is known-good and only its absence is under test.
	var document: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(LayoutIO.SHIPPED_CIRCUIT_PATH)
	)
	document.erase("circuit")
	document["version"] = LayoutIO.PROP_ONLY_VERSION
	var file := FileAccess.open(GATELESS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "  ") + "\n")
	file.close()

	_check(not _load_from(GATELESS_PATH), "a version-1 layout is refused on load, by name")
	OS.set_environment("LPC_LAYOUT_FILE", TEST_PATH)
	_check(
		(
			field.records.size() == count_before
			and absf((field.records[0] as RefCounted).x - first_x) < 0.0001
		),
		"and the world is unchanged — nothing was released"
	)
	_check(
		sim.circuit.circuit_name == name_before and sim.circuit.gate_count() == gates_before,
		"and the circuit being played is untouched (%s, %d gates)" % [name_before, gates_before]
	)
