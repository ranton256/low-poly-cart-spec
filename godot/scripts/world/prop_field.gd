# The scattered props, as things you can see and will later collide with.
#
# A READER of scatter.gd's placements. It instantiates meshes and holds the AABB
# records collision will resolve against; it decides nothing about WHERE anything
# goes. All of that is scripts/core/scatter.gd, where it can be tested with no
# scene loaded.
#
# PROPS ARE MESHES PLUS AN AABB RECORD, never physics bodies.
# See CONSTRAINTS §4 Architectural boundaries. The design document's collision is its own
# axis-aligned test, and a StaticBody3D here would make this a different game.
#
# REGISTRATION ORDER IS PRESERVED. `records` is in the order scatter emitted, and
# add-aabb-collision-response resolves the first intersecting prop in that order.
# Anything that reorders this list changes collision outcomes.
extends Node3D

const Scatter := preload("res://scripts/core/scatter.gd")
const Normalise := preload("res://scripts/core/normalise.gd")
const Collision := preload("res://scripts/core/collision.gd")


## One prop as collision will see it: which asset, where, how big, and the
## normalised box its world AABB is recomputed from each tick.
class Record:
	extends RefCounted
	var asset: String = ""
	var x: float = 0.0
	var z: float = 0.0
	var yaw: float = 0.0
	var normalised: RefCounted = null
	## The placement's acceptance index, carried through unchanged. Collision
	## resolves the first intersecting prop in registration order, so a view that
	## reorders records changes what the game collides with — and nothing noticed
	## until review reordered one.
	var sequence: int = -1


var records: Array[Record] = []

var _boxes: Dictionary = {}
var _scenes: Dictionary = {}


## Load each supplied model once and remember its authored box. Called before the
## first generation; the boxes are what scatter needs and the scenes are what
## this node instantiates from.
func load_assets() -> bool:
	# LPC_FAIL_LOADS: the test seam (LPC_SAVE_FILE tradition) — report failure
	# exactly as a missing model would, so a suite can boot the real scene into
	# the terminal LOADING error without touching any asset (godot/hud).
	if OS.get_environment("LPC_FAIL_LOADS") != "":
		push_error("prop field: LPC_FAIL_LOADS is set — simulating a failed model load")
		return false
	for asset in Scatter.ASSET_ORDER:
		var packed: PackedScene = load("res://assets/%s.glb" % asset)
		if packed == null:
			push_error("prop field: could not load %s.glb" % asset)
			return false
		_scenes[asset] = packed
		var probe: Node3D = packed.instantiate() as Node3D
		add_child(probe)
		for child in probe.get_children():
			if child is MeshInstance3D:
				_boxes[asset] = (child as MeshInstance3D).get_aabb()
		remove_child(probe)
		probe.free()
	return _boxes.size() == Scatter.ASSET_ORDER.size()


func authored_boxes() -> Dictionary:
	return _boxes


## Build the field from a list of placements, replacing whatever was there.
##
## Every existing prop is removed and freed first — the design document's
## regeneration scenario requires the resources be released, not merely hidden.
func build(placements: Array) -> void:
	clear()
	for placement in placements:
		var p: Scatter.Placement = placement as Scatter.Placement
		var instance: Node3D = (_scenes[p.asset] as PackedScene).instantiate() as Node3D
		instance.name = "%s_%d" % [p.asset, records.size()]
		instance.scale = Vector3.ONE * p.scale
		# The offset is in authored space scaled by `scale`, and it centres the
		# model on its own origin as well as grounding it — so it is applied to
		# the MODEL, and the placement position moves the whole thing.
		instance.position = Vector3(p.x + p.offset_x, p.offset_y, p.z + p.offset_z)
		instance.rotation.y = p.yaw
		add_child(instance)

		var record := Record.new()
		record.asset = p.asset
		record.x = p.x
		record.z = p.z
		record.yaw = p.yaw
		record.sequence = p.sequence
		record.normalised = Normalise.to_target_height(
			_boxes[p.asset] as AABB, (_boxes[p.asset] as AABB).size.y * p.scale
		)
		records.append(record)


## Remove every prop and release it. queue_free() is DEFERRED — a caller counting
## children immediately afterwards still sees them — so this frees immediately
## and the records go with them.
func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	records.clear()


## The field as collision sees it, IN REGISTRATION ORDER.
##
## Built here rather than in the core because the records are a view type; the
## geometry is still the core's, through Collision.make_prop(). The order is the
## one scatter emitted, and collision resolves the first intersecting prop in it —
## so this must never sort, filter, or cull.
func collision_props() -> Array:
	var props: Array = []
	for record in records:
		props.append(
			Collision.make_prop(record.asset, record.normalised, record.yaw, record.x, record.z)
		)
	return props


func prop_count() -> int:
	return records.size()
