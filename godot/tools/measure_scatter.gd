# Generate a field from the REAL imported models and report it, for
# tools/check_scatter_conformance.py.
#
#   godot --headless -s tools/measure_scatter.gd
#
# Prints one JSON object and nothing else. MEASUREMENTS ONLY, no judgements: the
# expected counts, clearances and separation live in the design document, and the
# Python side reads them from there rather than from anything this port
# transcribed. Same split as tools/measure_kart.gd.
#
# tests/scatter_test.gd drives SYNTHETIC boxes, deliberately — the placement
# rules are arithmetic and must hold for any input. This drives the six
# scattered models, so the two together cover the generator and the assets.
extends SceneTree

const Scatter := preload("res://scripts/core/scatter.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")

const SEED := 20260829


func _init() -> void:
	await process_frame
	var boxes: Dictionary = {}
	for asset in Scatter.ASSET_ORDER:
		var packed: PackedScene = load("res://assets/%s.glb" % asset)
		if packed == null:
			printerr("measure_scatter: could not load %s.glb" % asset)
			quit(1)
			return
		var model: Node3D = packed.instantiate() as Node3D
		get_root().add_child(model)
		await process_frame
		for child in model.get_children():
			if child is MeshInstance3D:
				boxes[asset] = (child as MeshInstance3D).get_aabb()
		get_root().remove_child(model)
		model.free()

	var scatter := Scatter.new()
	scatter.tuning = TuningLoader.load_tuning()
	var placements: Array = scatter.generate(SEED, boxes)

	var rows: Array = []
	for placement in placements:
		var p: Scatter.Placement = placement as Scatter.Placement
		(
			rows
			. append(
				{
					"asset": p.asset,
					"x": p.x,
					"z": p.z,
					"yaw": p.yaw,
					"scale": p.scale,
					"offset_y": p.offset_y,
					"lowest": (boxes[p.asset] as AABB).position.y * p.scale + p.offset_y,
				}
			)
		)

	var achieved: Dictionary = {}
	for asset in Scatter.ASSET_ORDER:
		achieved[asset] = scatter.achieved[asset]

	print(
		(
			JSON
			. stringify(
				{
					"seed": SEED,
					"emitted_order": Scatter.ASSET_ORDER,
					"achieved": achieved,
					"placements": rows,
					"report": scatter.shortfall_report(),
				}
			)
		)
	)
	quit()
