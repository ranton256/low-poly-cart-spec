# Author the shipped circuit, `godot/data/circuits/first-light.json`, AND bake
# the scripted drive every harness replays across it.
#
#   godot --headless -s tools/author_first_light.gd
#
# THE PROVENANCE OF A COMMITTED CONTENT FILE, executable. The file is content,
# not generated art — it is committed and hand-tunable — but the props in it
# came from somewhere, and "somewhere" has to be reproducible or the next person
# cannot tell an authored decision from a typo. Running this rewrites the file
# from three inputs:
#
#   1. The seed-20260829 scatter, through the AUTHORING path the design
#      document keeps normative (Procedural World Generation) — Scatter into a
#      PropField, exported by the real Save Layout writer, so the props half is
#      byte-for-byte what the game itself would save.
#   2. GATES, a touring course authored as centres, yaws and widths (below).
#   3. TARGETS, derived from the lap the baked drive actually turns.
#
# THE DEPENDENCY IS INVERTED, and that is this tool's reason to exist. Until the
# first playtest the gates were placed ON the trajectory of the historical
# LAP_PHASES table, because five standing proofs rest on that one scripted drive
# banking a lap and, with a circuit loaded, banking means THREADING. That kept
# the harness alive and made the course a hairpin: out, u-turn, back. So the
# drive is DERIVED FROM THE COURSE instead. A deterministic waypoint pilot
# (below) drives the real simulation gate to gate, its per-tick inputs are
# recorded, and runs of identical held input are baked into the phase table
# every consumer already eats:
#
#   tests/lap_gate_test.gd        LAP_PHASES   — the source the tools import
#   scripts/main.gd               SMOKE_PHASES — restated, because the shipped
#                                                binary must not import test code
#   tests/conformance_test.gd     LAP_SCRIPT   — item 14's cycled drive
#   tests/circuit_content_test.gd              — the pinned pass and bank ticks
#
# Re-authoring the course is now: move a gate, re-run this, paste the printed
# table into those four places, re-run the suite.
#
# Curation is deletions only: a prop whose collision box overlaps a gate mouth
# is dropped, because the file is the design document's own guarantee that no
# prop blocks a mouth. tests/circuit_content_test.gd re-checks that guarantee
# against the committed file, so this tool cannot quietly ship a blocked gate.
# The tool ALSO refuses to bake a drive that touches a prop at all: two of the
# consumers replay this table on a simulation with no props in it, so a table
# whose kart bounces off a crate would bank in the game and not in the suite.
extends SceneTree

const Circuit := preload("res://scripts/core/circuit.gd")
const InputState := preload("res://scripts/core/input_state.gd")
const KartView := preload("res://scripts/view/kart_view.gd")
const LayoutIO := preload("res://scripts/world/layout_io.gd")
const PropField := preload("res://scripts/world/prop_field.gd")
const Scatter := preload("res://scripts/core/scatter.gd")
const Sim := preload("res://scripts/core/sim.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")

const OUT_PATH := "res://data/circuits/first-light.json"
const SCRATCH_PATH := "user://first_light_scatter.json"

## main.gd's STARTING_SEED — the field every committed baseline was captured
## against, restated here because the tool must not boot the game to get it
## (the game now boots from the file this tool writes).
const FIELD_SEED := 20260829

const CIRCUIT_NAME := "first-light"

## [x, z, yaw, width]. A TOUR OF THE FIELD, not a corridor: north up the start
## straight, right through the north-east, down the east side, across the far
## south, back through the south-west, and north through the band. Six mouths
## are 12 wu; the last is 14, so its pylons frame the start line rather than
## filling it.
##
## The yaws are the BISECTOR of the bearing in and the bearing out at each
## centre — a gate squares up to the line a driver actually takes through it —
## except gate 1, which faces due north so it squares up to the start pose.
## Positions and widths are the authored decisions. Nothing here is measured off
## a drive, which is the whole point of this change.
const GATES: Array = [
	[0.0, 22.0, 0.0, 12.0],
	[26.0, 36.0, 1.7787, 12.0],
	[54.0, 0.0, 3.09336, 12.0],
	[35.0, -30.0, 3.9596, 12.0],
	[2.0, -48.0, 4.84322, 12.0],
	[-19.0, -28.0, 6.17229, 12.0],
	[-3.0, -4.0, 0.588, 14.0],
]

## Where the pilot steers once the course is threaded: the band's own centre
## line, past its far edge. Aiming AT the band would leave the kart circling a
## point it has already reached; aiming at the far boundary instead would let it
## cross tens of world units off the centre line, outside `lapGateAbsXLimit`.
const FINISH_AIM := Vector2(0.0, 12.0)

## The pilot gives up rather than loop forever. Three times the lap it bakes.
const PILOT_TICK_BUDGET := 4000

## PROVISIONAL, and the owner's playtest is what settles them. Method: gold is
## the baked lap less a second — a tighter line through the same gates, which
## the bang-bang pilot does not drive; silver and bronze are looser rings at
## +1.5 s and +4 s. Each is rounded DOWN to the nearest half second, so the
## numbers on screen are round and gold stays under the baked lap.
const GOLD_MARGIN_S := -1.0
const SILVER_MARGIN_S := 1.5
const BRONZE_MARGIN_S := 4.0
const TARGET_ROUNDING_S := 0.5


## The waypoint pilot: the held input for one tick, as a pure function of the
## simulation's state and the point being steered at.
##
## Bang-bang, and deliberately no cleverer than that. Accelerate always; steer
## toward the centre of the gate the cursor names, or toward FINISH_AIM once the
## course is threaded. The steering sign is the sign of the cross product of the
## kart's heading with the bearing to that point, which is exactly the sign of
## the wrapped angle between them; the deadband is one tick of `turnRate`,
## because an error smaller than a single tick's turn authority cannot be
## corrected without overshooting — a pilot that tries chatters left-right every
## tick and bakes a table of hundreds of one-tick phases.
##
## Static and taking plain values, so the bake is reproducible from simulation
## state alone with nothing remembered between ticks.
static func pilot_input(
	yaw: float, pos_x: float, pos_z: float, target: Vector2, deadband: float
) -> Array:
	var error: float = wrapf(atan2(target.x - pos_x, target.y - pos_z) - yaw, -PI, PI)
	return [true, error > deadband, error < -deadband]


## Runs of identical held input, as [accelerate, steer_left, steer_right, ticks]
## — exactly the shape LAP_PHASES has always had.
static func bake_phases(per_tick: Array) -> Array:
	var phases: Array = []
	for row: Array in per_tick:
		if not phases.is_empty() and _same_input(phases[-1] as Array, row):
			phases[-1][3] = int(phases[-1][3]) + 1
			continue
		phases.append([row[0], row[1], row[2], 1])
	return phases


## One phase as pastable GDScript.
static func phase_source(phase: Array) -> String:
	return (
		"\t[%s, %s, %s, %d],"
		% [
			"true" if phase[0] else "false",
			"true" if phase[1] else "false",
			"true" if phase[2] else "false",
			int(phase[3]),
		]
	)


static func _same_input(phase: Array, row: Array) -> bool:
	return phase[0] == row[0] and phase[1] == row[1] and phase[2] == row[2]


func _init() -> void:
	var tuning: RefCounted = TuningLoader.load_tuning()
	if tuning == null:
		printerr("author_first_light: no tuning")
		quit(1)
		return
	await process_frame

	var field: Node3D = _scatter_field(tuning)
	if field == null:
		quit(1)
		return
	var document: Dictionary = _curate_and_write(field, tuning)
	if document.is_empty():
		quit(1)
		return

	var kart: Node3D = Node3D.new()
	kart.set_script(KartView)
	get_root().add_child(kart)
	await process_frame
	var drive: Dictionary = _bake_and_verify(tuning, field, kart)
	if drive.is_empty():
		quit(1)
		return

	var seconds: float = float(drive["bank"]) / float(Sim.TICKS_PER_SECOND)
	document["circuit"] = LayoutIO.circuit_record(_circuit(_targets(seconds)))
	if not _write(document):
		quit(1)
		return
	_report(drive, seconds)
	quit(0)


## The seed-20260829 scatter in a real PropField, or null having said why.
func _scatter_field(tuning: RefCounted) -> Node3D:
	var field: Node3D = Node3D.new()
	field.set_script(PropField)
	get_root().add_child(field)
	if not field.load_assets():
		printerr("author_first_light: could not load the prop models")
		return null
	var scatter: RefCounted = Scatter.new()
	scatter.tuning = tuning
	field.build(scatter.generate(FIELD_SEED, field.authored_boxes()))
	if not LayoutIO.export_layout(field, field.authored_boxes(), SCRATCH_PATH):
		printerr("author_first_light: could not export the scatter")
		return null
	return field


## Drop the props standing in a gate mouth and write the file, targets not yet
## known. Returns the document it wrote, or {} having said why.
func _curate_and_write(field: Node3D, tuning: RefCounted) -> Dictionary:
	var circuit: RefCounted = _circuit({})
	var blocked: Array = _blocked_indices(field, circuit, tuning.gate_depth)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH_PATH))
	var kept: Array = []
	for i in range((document["props"] as Array).size()):
		if not blocked.has(i):
			kept.append((document["props"] as Array)[i])
	document["props"] = kept
	document["version"] = LayoutIO.CIRCUIT_VERSION
	document["circuit"] = LayoutIO.circuit_record(circuit)
	if not _write(document):
		return {}
	print(
		(
			"author_first_light: %s — seed %d, %d props (%d dropped from gate mouths), %d gates"
			% [OUT_PATH, FIELD_SEED, kept.size(), blocked.size(), circuit.gate_count()]
		)
	)
	return document


## Bake the drive twice and agree with itself, or {} having said why.
##
## THE BAKE RUNS AGAINST THE FILE, not against what is still in memory: the game
## reads five-decimal quantized props and gates, and a drive baked from
## unquantized ones is a drive nobody plays. The second bake has NO props, which
## is the simulation tests/lap_gate_test.gd and conformance item 14 replay the
## table on — identical, or the table is a drive only one of the two worlds can
## follow.
func _bake_and_verify(tuning: RefCounted, field: Node3D, kart: Node3D) -> Dictionary:
	var loaded: RefCounted = LayoutIO.import_layout(OUT_PATH, field.authored_boxes())
	if not loaded.ok:
		printerr("author_first_light: the file this tool just wrote does not load")
		return {}
	field.build(loaded.placements)
	var drive: Dictionary = _bake(tuning, loaded.circuit, field.collision_props(), kart)
	var bare: Dictionary = _bake(tuning, LayoutIO.read_circuit(OUT_PATH), [], kart)
	if drive.is_empty() or bare.is_empty():
		return {}
	if str(bare["phases"]) == str(drive["phases"]) and bare["bank"] == drive["bank"]:
		return drive
	printerr(
		(
			"author_first_light: the drive differs with props (tick %d) and without (%d)"
			% [drive["bank"], bare["bank"]]
		)
	)
	return {}


## The course, optionally carrying targets. Built twice: once bare, to curate
## and bake against, and once with the targets the bake derived.
func _circuit(targets: Dictionary) -> RefCounted:
	var circuit: RefCounted = Circuit.new()
	circuit.circuit_name = CIRCUIT_NAME
	for gate: Array in GATES:
		circuit.add_gate(float(gate[0]), float(gate[1]), float(gate[2]), float(gate[3]))
	circuit.targets = targets.duplicate()
	return circuit


func _write(document: Dictionary) -> bool:
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("author_first_light: cannot write %s" % OUT_PATH)
		return false
	file.store_string(JSON.stringify(document, "  ") + "\n")
	file.close()
	return true


## Drive the course with the pilot and record what it held, tick by tick.
##
## The simulation is the real one, armed with the real circuit and carrying the
## real kart hit volume, so a drive that would hit a prop in the game hits one
## here. Returns {} — having said why — rather than a table nobody should use.
func _bake(tuning: RefCounted, circuit: RefCounted, props: Array, kart: Node3D) -> Dictionary:
	var s := Sim.new()
	s.tuning = tuning
	s.input = InputState.new()
	s.race.start_racing_immediately()
	s.arm_circuit(circuit)
	s.props = props
	s.kart_normalised = kart.normalised()
	s.kart_yaw_offset = kart.yaw_correction()

	var per_tick: Array = []
	var passes: Array = []
	var collisions: int = 0
	while s.ticks < PILOT_TICK_BUDGET:
		var held: Array = pilot_input(s.yaw, s.pos_x, s.pos_z, _waypoint(s), tuning.turn_rate)
		s.input.forward = held[0]
		s.input.left = held[1]
		s.input.right = held[2]
		per_tick.append(held)
		s.step()
		if s.last_hit != null:
			collisions += 1
		if passes.size() < s.circuit.cursor - 1:
			passes.append(s.ticks)
		if s.lap.banked_this_tick:
			break
	if not s.lap.banked_this_tick:
		printerr(
			(
				"author_first_light: the pilot never banked — %d of %d gates in %d ticks"
				% [passes.size(), circuit.gate_count(), s.ticks]
			)
		)
		return {}
	if collisions > 0:
		printerr(
			"author_first_light: the pilot hit a prop on %d ticks; move a gate off it" % collisions
		)
		return {}
	return {"phases": bake_phases(per_tick), "passes": passes, "bank": s.ticks}


## Where the pilot is steering: the centre of the gate the cursor names, or the
## finish aim once the course is threaded.
func _waypoint(s: RefCounted) -> Vector2:
	if s.circuit.is_threaded():
		return FINISH_AIM
	var gate: RefCounted = s.circuit.gates[s.circuit.cursor - 1]
	return Vector2(gate.x, gate.z)


## The medal times, from the lap the pilot turned. See the margins above.
func _targets(seconds: float) -> Dictionary:
	return {
		"gold": _rounded(seconds + GOLD_MARGIN_S),
		"silver": _rounded(seconds + SILVER_MARGIN_S),
		"bronze": _rounded(seconds + BRONZE_MARGIN_S),
	}


func _rounded(seconds: float) -> float:
	return floorf(seconds / TARGET_ROUNDING_S) * TARGET_ROUNDING_S


## Which registration indices sit in a gate mouth. Reported by name as they are
## found, so the curation is readable in the tool's own output rather than only
## in the diff.
func _blocked_indices(field: Node3D, circuit: RefCounted, depth: float) -> Array:
	var blocked: Array = []
	var props: Array = field.collision_props()
	for i in range(props.size()):
		var prop: RefCounted = props[i]
		for gate_index in range(circuit.gates.size()):
			var gate: RefCounted = circuit.gates[gate_index]
			if not Circuit.mouth_blocked(gate.mouth_corners(depth), prop.box):
				continue
			blocked.append(i)
			print(
				(
					"author_first_light: dropping %s #%d at (%.2f, %.2f) — in gate %d's mouth"
					% [prop.asset, i, prop.centre_x(), prop.centre_z(), gate_index + 1]
				)
			)
			break
	return blocked


## The baked drive, as the four consumers want to read it: the table as pastable
## GDScript, the pass ticks and bank tick circuit_content_test.gd pins, and the
## lap the targets came from.
func _report(drive: Dictionary, seconds: float) -> void:
	var phases: Array = drive["phases"]
	print("author_first_light: baked %d phases — the table, ready to paste:" % phases.size())
	print("const LAP_PHASES: Array = [")
	for phase: Array in phases:
		print(phase_source(phase))
	print("]")
	print(
		(
			"author_first_light: gates passed at %s, banked on tick %d — a %.4f s lap"
			% [str(drive["passes"]), drive["bank"], seconds]
		)
	)
	print("author_first_light: targets %s" % str(_targets(seconds)))
