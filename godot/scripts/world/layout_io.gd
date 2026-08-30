# Track layout export and import — the design document's Track Layout
# Persistence feature, in the VIEW layer (the core reads no files).
#
# The port decisions (godot/layout-persistence):
#
#   A2 — delivery: desktop writes to the user data directory and prints the
#   absolute path; the web hands the same bytes to the browser as a download.
#   `LPC_LAYOUT_FILE` overrides the path so suites never touch a real file
#   (the LPC_SAVE_FILE tradition). Loading reads the same location.
#
#   A3 — order: export walks the field's records IN REGISTRATION ORDER, and
#   import reconstructs placements IN FILE ORDER through the existing
#   `build()` path — which already releases every prop first and registers in
#   sequence. A restored track collides identically to the one saved.
#
#   Absolute scale, applied once: the file's scale is the node's final world
#   scale; import derives the collision box from the authored geometry AT
#   that scale (the same §3 arithmetic scatter used), never by re-normalising
#   — the round-trip suite proves cycles are byte-identical.
#
# VERSION 2 carries a `circuit` object beside `props` — a name, ordered gates
# (each a `position` [X, Z], a `yaw`, and a `width`), and optional `targets`.
# It is validated COMPLETELY before anything is released, exactly as the prop
# records are: a malformed circuit refuses the whole file, so no prop lands, no
# gate is armed, and the current world and clock are untouched. Saving writes
# the loaded circuit back through the same five-decimal quantization the props
# use, so the byte-identity guarantee extends to it.
#
# DELIBERATE INTERIM. The design document says a file WITHOUT a circuit —
# version 1 included — is refused on load with a named error. This change does
# NOT implement that refusal: the game must stay playable until the boot ships
# a circuit, so gateless files still load. The refusal lands with
# add-circuit-world-and-presentation, and the register's deferral for
# "A layout is a circuit" stays open until it does.
extends RefCounted

const Scatter := preload("res://scripts/core/scatter.gd")
const Normalise := preload("res://scripts/core/normalise.gd")
const Circuit := preload("res://scripts/core/circuit.gd")

const DEFAULT_PATH := "user://track_layout.json"

## The file version a layout carrying a circuit is written as.
const CIRCUIT_VERSION := 2

## The version a gateless layout is written as, unchanged since M7.
const PROP_ONLY_VERSION := 1


## What a load produced. A refusal is `ok == false` and NOTHING else is
## meaningful — an empty placements array used to carry that signal, which
## cannot distinguish "refused" from "a valid file of no props" and left no
## room for the circuit to travel back beside it.
class Loaded:
	extends RefCounted
	var ok: bool = false
	var placements: Array = []
	## The file's circuit, or null when it carried none (the v1 interim).
	var circuit: RefCounted = null


static func layout_path() -> String:
	var override := OS.get_environment("LPC_LAYOUT_FILE")
	return override if override != "" else DEFAULT_PATH


## One record per prop, the GDD's exact fields, in registration order. When a
## circuit is loaded it is written back beside them and the file is version 2.
static func export_layout(
	field: Node3D, boxes: Dictionary, path: String, circuit: RefCounted = null
) -> bool:
	var records: Array = []
	for i in range(field.records.size()):
		var record: RefCounted = field.records[i]
		var node: Node3D = field.get_child(i) as Node3D
		var authored: AABB = boxes[record.asset]
		# Quantize the scale FIRST and derive the height from the quantized
		# value: deriving both from the raw scale lets the scale's own
		# quantization error leak into the height's ninth digit on the next
		# cycle, and the byte-identity promise dies there.
		var scale: float = _q(record.normalised.scale)
		(
			records
			. append(
				{
					"asset": record.asset,
					"targetHeight": _q(authored.size.y * scale),  # from the quantized scale
					"position": [_q(node.position.x), _q(node.position.y), _q(node.position.z)],
					"yaw": _q(record.yaw),
					"scale": [scale, scale, scale],
				}
			)
		)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("layout: cannot write %s" % path)
		return false
	var document: Dictionary = {"version": PROP_ONLY_VERSION, "props": records}
	if circuit != null and circuit.has_gates():
		document["version"] = CIRCUIT_VERSION
		document["circuit"] = _circuit_record(circuit)
	file.store_string(JSON.stringify(document, "  ") + "\n")
	file.close()
	print("layout: saved %d props to %s" % [records.size(), ProjectSettings.globalize_path(path)])
	if OS.has_feature("web"):
		_offer_browser_download(path)
	return true


## Placements in FILE ORDER plus the file's circuit, or a refusal with the
## reason logged. Validation is complete BEFORE anything is instantiated or
## released — a malformed file must leave the current world untouched, and that
## rule now covers the circuit object whole.
static func import_layout(path: String, boxes: Dictionary) -> Loaded:
	var loaded := Loaded.new()
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("layout: %s is missing or empty" % path)
		return loaded
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("props"):
		push_error("layout: %s is not a layout file" % path)
		return loaded

	# The circuit FIRST, so a malformed one costs nothing to refuse. A file
	# carrying no circuit is not an error here — see the header's interim.
	var document: Dictionary = parsed
	if document.has("circuit"):
		var circuit: RefCounted = _read_circuit(document["circuit"])
		if circuit == null:
			return loaded  # the reason is already logged; nothing is released
		loaded.circuit = circuit

	var placements: Array = []
	var raw: Array = document["props"]
	for i in range(raw.size()):
		var record: Variant = raw[i]
		if not (record is Dictionary):
			push_error("layout: record %d is not an object" % i)
			return Loaded.new()
		var fields: Dictionary = record
		for key in ["asset", "targetHeight", "position", "yaw", "scale"]:
			if not fields.has(key):
				push_error("layout: record %d is missing %s" % [i, key])
				return Loaded.new()
		var asset: String = fields["asset"]
		if not boxes.has(asset):
			push_error("layout: record %d names unknown asset %s" % [i, asset])
			return Loaded.new()
		var position: Array = fields["position"]
		var scale: float = float((fields["scale"] as Array)[0])
		if position.size() != 3 or scale <= 0.0:
			push_error("layout: record %d has an invalid transform" % i)
			return Loaded.new()
		placements.append(_placement(asset, boxes[asset], position, float(fields["yaw"]), scale, i))
	loaded.placements = placements
	loaded.ok = true
	return loaded


## The circuit object, or null with the reason logged. WHOLE OR NOT AT ALL: one
## bad gate or one non-numeric target refuses the file, exactly as one bad prop
## record does.
static func _read_circuit(raw: Variant) -> RefCounted:
	if not (raw is Dictionary):
		push_error("layout: circuit is not an object")
		return null
	var fields: Dictionary = raw
	if not fields.has("name") or not (fields["name"] is String):
		push_error("layout: circuit is missing a name")
		return null
	if not fields.has("gates") or not (fields["gates"] is Array):
		push_error("layout: circuit is missing its gates")
		return null
	var gates: Array = fields["gates"]
	if gates.is_empty():
		# NOT the document's gateless-FILE refusal, which this change defers: a
		# circuit object that declares no gates is a malformed circuit, the way
		# a prop record with no asset is a malformed record.
		push_error("layout: circuit %s declares no gates" % fields["name"])
		return null

	var circuit := Circuit.new()
	circuit.circuit_name = fields["name"]
	for i in range(gates.size()):
		var entry: Variant = gates[i]
		if not (entry is Dictionary):
			push_error("layout: gate %d is not an object" % i)
			return null
		var gate: Dictionary = entry
		for key in ["position", "yaw", "width"]:
			if not gate.has(key):
				push_error("layout: gate %d is missing %s" % [i, key])
				return null
		if not (gate["position"] is Array) or (gate["position"] as Array).size() != 2:
			push_error("layout: gate %d has no [X, Z] position" % i)
			return null
		var position: Array = gate["position"]
		if not (_is_number(position[0]) and _is_number(position[1])):
			push_error("layout: gate %d has a non-numeric position" % i)
			return null
		if not (_is_number(gate["yaw"]) and _is_number(gate["width"])):
			push_error("layout: gate %d has a non-numeric yaw or width" % i)
			return null
		if float(gate["width"]) <= 0.0:
			push_error("layout: gate %d has a width of %s" % [i, gate["width"]])
			return null
		circuit.add_gate(
			float(position[0]), float(position[1]), float(gate["yaw"]), float(gate["width"])
		)

	# Targets are optional; a declared one must be a number, and must name a
	# medal the document knows.
	if fields.has("targets"):
		if not (fields["targets"] is Dictionary):
			push_error("layout: circuit targets are not an object")
			return null
		var targets: Dictionary = fields["targets"]
		for key: Variant in targets:
			if not (key is String) or not Circuit.MEDAL_ORDER.has(key):
				push_error("layout: circuit target %s is not a medal" % key)
				return null
			if not _is_number(targets[key]):
				push_error("layout: circuit target %s is not a number" % key)
				return null
			circuit.targets[key] = float(targets[key])
	return circuit


## JSON numbers arrive as either int or float depending on how they were
## written, and both are valid here — a string or a null is not.
static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


## The circuit as it goes back out, quantized like every other value the file
## carries so a load/save cycle is byte-identical from cycle zero.
static func _circuit_record(circuit: RefCounted) -> Dictionary:
	var gates: Array = []
	for gate: RefCounted in circuit.gates:
		(
			gates
			. append(
				{
					"position": [_q(gate.x), _q(gate.z)],
					"yaw": _q(gate.yaw),
					"width": _q(gate.width),
				}
			)
		)
	var record: Dictionary = {"name": circuit.circuit_name, "gates": gates}
	# Written in the document's own order, not the dictionary's iteration order,
	# so the bytes do not depend on how the file that was loaded was written.
	var targets: Dictionary = {}
	for medal: String in Circuit.MEDAL_ORDER:
		if circuit.targets.has(medal):
			targets[medal] = _q(float(circuit.targets[medal]))
	if not targets.is_empty():
		record["targets"] = targets
	return record


## Rebuild a placement from the file's absolute transform: the offsets are the
## same §3 arithmetic scatter computed, derived from the authored box at the
## recorded ABSOLUTE scale — which is what makes re-export byte-identical.
static func _placement(
	asset: String, authored: AABB, position: Array, yaw: float, scale: float, sequence: int
) -> RefCounted:
	var normalised: RefCounted = Normalise.to_target_height(authored, authored.size.y * scale)
	var placement := Scatter.Placement.new()
	placement.asset = asset
	placement.yaw = yaw
	placement.scale = scale
	placement.sequence = sequence
	placement.offset_x = normalised.box.position.x - authored.position.x * scale
	# The Y offset IS the node's world Y (build applies it directly), so it
	# comes from the file VERBATIM — "at exactly the recorded position". The
	# first draft re-derived it through the grounding arithmetic, whose ~1e-5
	# dust against scatter's own path broke cycle-zero byte-identity.
	placement.offset_y = float(position[1])
	placement.offset_z = normalised.box.position.z - authored.position.z * scale
	placement.x = float(position[0]) - placement.offset_x
	placement.z = float(position[2]) - placement.offset_z
	return placement


## Quantize to five decimal places on export — 10 µwu precision, far inside
## the document's "floating-point tolerance" and far outside anything
## physical. The width matters: reconstructing a placement re-derives the
## grounding through §3 arithmetic that can differ from scatter's own by
## ~1e-7, and JSON prints every digit. At 1e-5 the dust collapses, so the
## FIRST export and every later one are byte-identical — the delta spec's
## "two cycles, one layout" holds from cycle zero (M7 Critic finding 1;
## the first draft quantized at 1e-9 and only converged from cycle one).
static func _q(value: float) -> float:
	return float(String.num(value, 5))


## The web half of A2: hand the saved bytes to the browser as a download.
## Exercised at M8's web smoke — desktop and headless never reach this.
static func _offer_browser_download(path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	JavaScriptBridge.download_buffer(bytes, "track_layout.json", "application/json")
