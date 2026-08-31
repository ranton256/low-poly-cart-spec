# The SHIPPED CIRCUIT as committed content — data/circuits/first-light.json.
#
#   godot --headless -s tests/circuit_content_test.gd
#
# Every other suite checks code. This one checks a FILE, because the file is
# where the game's course now lives: the design document makes a layout "the
# guarantee that no prop blocks a gate mouth", and a guarantee nobody re-checks
# after the next hand edit is a comment. The three properties the change's own
# spec names — every gate inside the boundary, no curated prop in a mouth,
# targets ordered — are asserted here against the bytes that ship.
#
# AND THE PROPERTY THAT KEEPS THE HARNESS ALIVE. Five standing proofs rest on
# one scripted drive banking a lap on this course and, with a circuit loaded,
# banking means threading. That drive is no longer something the gates were
# placed along: tools/author_first_light.gd BAKES it from the course, and
# tests/lap_gate_test.gd's LAP_PHASES is what the tool printed. The pass ticks
# and the bank TICK are pinned below, so a course edited without re-baking fails
# here by name, before lap_capture, refresh_probe and LPC_SMOKE fail one at a
# time and mysteriously.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const MainScene := preload("res://scenes/main.tscn")
const LayoutIO := preload("res://scripts/world/layout_io.gd")
const Circuit := preload("res://scripts/core/circuit.gd")
const Sim := preload("res://scripts/core/sim.gd")
const InputState := preload("res://scripts/core/input_state.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")
const LapSuite := preload("res://tests/lap_gate_test.gd")

## Where the baked drive banks, in racing ticks, and the gates it passes on the
## way. Regenerated with the course: tools/author_first_light.gd prints both.
const SCRIPTED_BANK_TICK := 1292
const SCRIPTED_BANK_SECONDS := 21.5333
const SCRIPTED_GATE_TICKS: Array = [139, 298, 544, 735, 931, 1090, 1248]

var _root: Node3D = null
var _tuning: RefCounted = null


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_tuning = TuningLoader.load_tuning()
	await process_frame
	_root = MainScene.instantiate() as Node3D
	get_root().add_child(_root)
	await process_frame

	_test_every_gate_is_inside_the_boundary()
	_test_no_curated_prop_blocks_a_gate_mouth()
	_test_the_targets_are_ordered()
	_test_the_boot_world_is_the_shipped_circuit()
	_test_the_shipped_file_is_a_fixed_point_of_the_round_trip()
	_test_the_scripted_drive_still_threads_and_banks()

	get_root().remove_child(_root)
	_root.free()
	RVTest.finish(
		self, "circuit content: bounds, clear mouths, targets, boot, harness ok", "content check(s)"
	)


## The committed circuit, read as a course with no world attached.
func _circuit() -> RefCounted:
	return LayoutIO.read_circuit(LayoutIO.SHIPPED_CIRCUIT_PATH)


func _test_every_gate_is_inside_the_boundary() -> void:
	var circuit: RefCounted = _circuit()
	_check(circuit != null, "the shipped circuit parses")
	if circuit == null:
		return
	_check(circuit.gate_count() >= 6, "with %d gates" % circuit.gate_count())
	var limit: float = _tuning.drivable_extent
	var outside: Array = []
	for index in range(circuit.gate_count()):
		var gate: RefCounted = circuit.gates[index]
		# The MOUTH's corners, not just the centre: a gate centred inside the
		# boundary can still have a pylon standing outside the drivable world.
		for corner: Vector2 in gate.mouth_corners(_tuning.gate_depth):
			if absf(corner.x) > limit or absf(corner.y) > limit:
				outside.append("gate %d at %v" % [index + 1, corner])
		if gate.width <= 0.0:
			outside.append("gate %d has width %f" % [index + 1, gate.width])
	_check(
		outside.is_empty(),
		"every gate lies inside the ±%.0f wu boundary, mouth and all: %s" % [limit, str(outside)]
	)


func _test_no_curated_prop_blocks_a_gate_mouth() -> void:
	var circuit: RefCounted = _circuit()
	var loaded: RefCounted = LayoutIO.import_layout(
		LayoutIO.SHIPPED_CIRCUIT_PATH, _root.props.authored_boxes()
	)
	_check(loaded.ok and not loaded.placements.is_empty(), "the shipped file's props load")
	# Through the field the game actually builds, so the boxes tested are the
	# boxes the kart would collide with — not a second derivation of them.
	var blocked: Array = []
	for prop: RefCounted in _root.props.collision_props():
		for index in range(circuit.gate_count()):
			var mouth: PackedVector2Array = (circuit.gates[index] as RefCounted).mouth_corners(
				_tuning.gate_depth
			)
			if Circuit.mouth_blocked(mouth, prop.box):
				blocked.append(
					(
						"%s at (%.1f, %.1f) in gate %d"
						% [prop.asset, prop.centre_x(), prop.centre_z(), index + 1]
					)
				)
	_check(
		blocked.is_empty(),
		(
			"no curated prop stands in a gate mouth (%d props checked): %s"
			% [_root.props.prop_count(), str(blocked)]
		)
	)


func _test_the_targets_are_ordered() -> void:
	var circuit: RefCounted = _circuit()
	for medal: String in Circuit.MEDAL_ORDER:
		_check(circuit.targets.has(medal), "the shipped circuit declares a %s target" % medal)
	var gold: float = float(circuit.targets.get("gold", 0.0))
	var silver: float = float(circuit.targets.get("silver", 0.0))
	var bronze: float = float(circuit.targets.get("bronze", 0.0))
	_check(
		bronze > silver and silver > gold and gold > 0.0,
		"ordered bronze > silver > gold, all positive (%.2f > %.2f > %.2f)" % [bronze, silver, gold]
	)
	# Provisional, and honest about it: gold is under the baked drive's own lap,
	# so the medal is a driving result rather than a participation prize.
	_check(
		gold < SCRIPTED_BANK_SECONDS,
		(
			"and gold (%.2f s) asks for a better lap than the scripted drive's %.2f s"
			% [gold, SCRIPTED_BANK_SECONDS]
		)
	)


## The boot world IS the shipped file — not a scatter that happens to look like
## one. Asserted prop for prop against the file's own records.
func _test_the_boot_world_is_the_shipped_circuit() -> void:
	var document: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(LayoutIO.SHIPPED_CIRCUIT_PATH)
	)
	var records: Array = document["props"]
	var field: Node3D = _root.props
	_check(
		field.prop_count() == records.size(),
		"the boot field holds the file's %d props (%d)" % [records.size(), field.prop_count()]
	)
	var drifted: Array = []
	for i in range(mini(field.prop_count(), records.size())):
		var record: RefCounted = field.records[i]
		var wanted: Dictionary = records[i]
		var position: Array = wanted["position"]
		if (
			record.asset != wanted["asset"]
			or absf(record.x - float(position[0])) > 0.001
			or absf(record.z - float(position[2])) > 0.001
		):
			drifted.append(str(i))
	_check(drifted.is_empty(), "each at the file's own asset and place: %s" % str(drifted))
	var circuit: RefCounted = _root.sim.circuit
	_check(
		circuit.circuit_name == "first-light",
		"the armed circuit is the file's (%s)" % circuit.circuit_name
	)
	_check(circuit.gate_count() == 7, "with its seven gates")
	_check(circuit.cursor == 1, "the cursor starting at gate 1")
	_check(_root.sim.lap.best_key == "first-light", "and the BEST readout keyed to it")


## A fixed point: Save Layout on the boot world writes the shipped file back,
## byte for byte. That is what makes the committed file editable by hand — an
## edit is the only thing that can change it.
func _test_the_shipped_file_is_a_fixed_point_of_the_round_trip() -> void:
	var scratch := "user://circuit_content_resave.json"
	OS.set_environment("LPC_LAYOUT_FILE", scratch)
	_check(_root.save_layout(), "the boot world saves")
	OS.set_environment("LPC_LAYOUT_FILE", "")
	_check(
		(
			FileAccess.get_file_as_string(scratch)
			== FileAccess.get_file_as_string(LayoutIO.SHIPPED_CIRCUIT_PATH)
		),
		"and the bytes are the shipped file's own — the circuit round-trips unchanged"
	)


## THE HARNESS PROPERTY. The baked drive threads every gate in order, on the
## ticks it was baked at, and banks on the tick it was baked at.
func _test_the_scripted_drive_still_threads_and_banks() -> void:
	var circuit: RefCounted = _circuit()
	var s := Sim.new()
	s.tuning = TuningLoader.load_tuning()
	s.input = InputState.new()
	s.race.start_racing_immediately()
	s.arm_circuit(circuit)
	var passes: Array = []
	var bank_tick := -1
	for phase: Array in LapSuite.LAP_PHASES:
		s.input.forward = phase[0]
		s.input.left = phase[1]
		s.input.right = phase[2]
		for _i in range(int(phase[3])):
			s.step()
			if passes.size() < s.circuit.cursor - 1:
				passes.append(s.ticks)
			if s.lap.banked_this_tick and bank_tick < 0:
				bank_tick = s.ticks
	_check(
		passes == SCRIPTED_GATE_TICKS,
		(
			"the baked drive passes all %d gates, in order, on the ticks it was baked at: %s"
			% [circuit.gate_count(), str(passes)]
		)
	)
	_check(
		bank_tick == SCRIPTED_BANK_TICK,
		(
			"and banks on tick %d, exactly where the tool baked it (got %d)"
			% [SCRIPTED_BANK_TICK, bank_tick]
		)
	)
	_check(
		absf(s.lap.best_seconds - SCRIPTED_BANK_SECONDS) < 0.01,
		"a %.2f s lap — the number the provisional targets were set from" % s.lap.best_seconds
	)
