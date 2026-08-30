# Author the shipped circuit, `godot/data/circuits/first-light.json`.
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
#   2. GATES, placed along the trajectory of tests/lap_gate_test.gd's
#      LAP_PHASES. That is not decoration: lap_gate_test, tools/lap_capture.gd,
#      tools/refresh_probe.gd, main.gd's LPC_SMOKE and conformance item 10 all
#      rest on that one scripted drive banking a lap, and once the boot world is
#      a circuit, banking means THREADING. Gates on the drive's own path keep
#      every one of those proofs true, unmodified. Each entry below is the
#      kart's own position and yaw at the named tick of that drive.
#   3. TARGETS, provisional, from the same drive's measured lap time.
#
# Curation is deletions only: a prop whose collision box overlaps a gate mouth
# is dropped, because the file is the design document's own guarantee that no
# prop blocks a mouth. tests/circuit_content_test.gd re-checks that guarantee
# against the committed file, so this tool cannot quietly ship a blocked gate.
extends SceneTree

const Collision := preload("res://scripts/core/collision.gd")
const Circuit := preload("res://scripts/core/circuit.gd")
const LayoutIO := preload("res://scripts/world/layout_io.gd")
const PropField := preload("res://scripts/world/prop_field.gd")
const Scatter := preload("res://scripts/core/scatter.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")

const OUT_PATH := "res://data/circuits/first-light.json"
const SCRATCH_PATH := "user://first_light_scatter.json"

## main.gd's STARTING_SEED — the field every committed baseline was captured
## against, restated here because the tool must not boot the game to get it
## (the game now boots from the file this tool writes).
const FIELD_SEED := 20260829

const CIRCUIT_NAME := "first-light"

## [x, z, yaw, width]. Positions and yaws are the scripted drive's own state at
## racing ticks 120, 300, 460, 560, 660 and 870; widths are content, chosen
## generous enough that the drive threads with room either side.
##
## SPACING IS A LOOK AS WELL AS A COURSE. Gates 4 and 5 sit at ticks 560 and 660
## rather than further down the southbound leg because the loop closes at the
## origin, and a second gate in the start basin turned the pre-race view into a
## thicket of pylons (seen in the first gallery capture of this change). Gate 6
## stays — it is the last gate before the line and belongs there — and carries a
## wider mouth so its pylons frame the start rather than filling it.
const GATES: Array = [
	[0.0, 18.46636, 0.0, 12.0],
	[0.0, 52.99202, 0.0, 12.0],
	[9.45124, 52.52101, 3.16, 10.0],
	[9.09784, 33.32427, 3.16, 10.0],
	[8.74444, 14.12752, 3.16, 10.0],
	[-1.07465, -2.11889, 6.32, 14.0],
]

## PROVISIONAL, and the owner's playtest is what settles them. Method: the
## scripted drive above banks at 15.03 s headless (15.05 s in the running game,
## which starts its clock a tick or two later). Gold is that time less a little
## over half a second — a tighter line through the same gates; silver and bronze
## are looser rings around it.
const TARGETS: Dictionary = {"gold": 14.5, "silver": 16.5, "bronze": 19.0}


func _init() -> void:
	var tuning: RefCounted = TuningLoader.load_tuning()
	if tuning == null:
		printerr("author_first_light: no tuning")
		quit(1)
		return
	await process_frame

	var field: Node3D = Node3D.new()
	field.set_script(PropField)
	get_root().add_child(field)
	if not field.load_assets():
		printerr("author_first_light: could not load the prop models")
		quit(1)
		return
	var scatter: RefCounted = Scatter.new()
	scatter.tuning = tuning
	field.build(scatter.generate(FIELD_SEED, field.authored_boxes()))
	if not LayoutIO.export_layout(field, field.authored_boxes(), SCRATCH_PATH):
		printerr("author_first_light: could not export the scatter")
		quit(1)
		return

	var circuit: RefCounted = _circuit()
	var blocked: Array = _blocked_indices(field, circuit, tuning.gate_depth)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH_PATH))
	var kept: Array = []
	for i in range((document["props"] as Array).size()):
		if not blocked.has(i):
			kept.append((document["props"] as Array)[i])
	document["props"] = kept
	document["version"] = LayoutIO.CIRCUIT_VERSION
	document["circuit"] = LayoutIO.circuit_record(circuit)

	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("author_first_light: cannot write %s" % OUT_PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(document, "  ") + "\n")
	file.close()
	print(
		(
			"author_first_light: %s — seed %d, %d props (%d dropped from gate mouths), %d gates"
			% [OUT_PATH, FIELD_SEED, kept.size(), blocked.size(), circuit.gate_count()]
		)
	)
	quit(0)


func _circuit() -> RefCounted:
	var circuit: RefCounted = Circuit.new()
	circuit.circuit_name = CIRCUIT_NAME
	for gate: Array in GATES:
		circuit.add_gate(float(gate[0]), float(gate[1]), float(gate[2]), float(gate[3]))
	circuit.targets = TARGETS.duplicate()
	return circuit


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
