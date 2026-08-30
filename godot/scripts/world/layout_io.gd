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
extends RefCounted

const Scatter := preload("res://scripts/core/scatter.gd")
const Normalise := preload("res://scripts/core/normalise.gd")

const DEFAULT_PATH := "user://track_layout.json"


static func layout_path() -> String:
	var override := OS.get_environment("LPC_LAYOUT_FILE")
	return override if override != "" else DEFAULT_PATH


## One record per prop, the GDD's exact fields, in registration order.
static func export_layout(field: Node3D, boxes: Dictionary, path: String) -> bool:
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
	file.store_string(JSON.stringify({"version": 1, "props": records}, "  ") + "\n")
	file.close()
	print("layout: saved %d props to %s" % [records.size(), ProjectSettings.globalize_path(path)])
	if OS.has_feature("web"):
		_offer_browser_download(path)
	return true


## Placements in FILE ORDER, or an empty array with the reason logged.
## Validation is complete BEFORE anything is instantiated or released —
## a malformed file must leave the current world untouched.
static func import_layout(path: String, boxes: Dictionary) -> Array:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("layout: %s is missing or empty" % path)
		return []
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("props"):
		push_error("layout: %s is not a layout file" % path)
		return []
	var placements: Array = []
	var raw: Array = (parsed as Dictionary)["props"]
	for i in range(raw.size()):
		var record: Variant = raw[i]
		if not (record is Dictionary):
			push_error("layout: record %d is not an object" % i)
			return []
		var fields: Dictionary = record
		for key in ["asset", "position", "yaw", "scale"]:
			if not fields.has(key):
				push_error("layout: record %d is missing %s" % [i, key])
				return []
		var asset: String = fields["asset"]
		if not boxes.has(asset):
			push_error("layout: record %d names unknown asset %s" % [i, asset])
			return []
		var position: Array = fields["position"]
		var scale: float = float((fields["scale"] as Array)[0])
		if position.size() != 3 or scale <= 0.0:
			push_error("layout: record %d has an invalid transform" % i)
			return []
		placements.append(_placement(asset, boxes[asset], position, float(fields["yaw"]), scale, i))
	return placements


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
	placement.offset_y = normalised.box.position.y - authored.position.y * scale
	placement.offset_z = normalised.box.position.z - authored.position.z * scale
	placement.x = float(position[0]) - placement.offset_x
	placement.z = float(position[2]) - placement.offset_z
	return placement


## Quantize to nine decimal places on export. Re-deriving a value through the
## §3 arithmetic can move the last ulp (import composes one extra multiply),
## and JSON prints every digit — so the double-cycle byte-identity the round
## trip promises needs an idempotent representation. 1e-9 is far inside the
## document's "floating-point tolerance" and far outside anything physical.
static func _q(value: float) -> float:
	return float(String.num(value, 9))


## The web half of A2: hand the saved bytes to the browser as a download.
## Exercised at M8's web smoke — desktop and headless never reach this.
static func _offer_browser_download(path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	JavaScriptBridge.download_buffer(bytes, "track_layout.json", "application/json")
