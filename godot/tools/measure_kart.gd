# Measure the imported kart, for tools/check_kart_conformance.py.
#
#   godot --headless -s tools/measure_kart.gd
#
# Prints one JSON object and nothing else. It reports MEASUREMENTS ONLY and makes
# no judgements: the expected values live in the design document, and the Python
# side reads them from there rather than from anything this project transcribed.
# That split is the point — see design D4 of add-kart-view-orientation-and-input.
extends SceneTree

const KartView := preload("res://scripts/view/kart_view.gd")
const Normalise := preload("res://scripts/core/normalise.gd")
const ArtTuning := preload("res://scripts/art_tuning.gd")


func _init() -> void:
	await process_frame
	var model: Node3D = (load("res://assets/kart.glb") as PackedScene).instantiate() as Node3D
	get_root().add_child(model)
	await process_frame

	var mesh_instance: MeshInstance3D = null
	for child in model.get_children():
		if child is MeshInstance3D:
			mesh_instance = child as MeshInstance3D
	if mesh_instance == null:
		printerr("measure_kart: no MeshInstance3D in the imported model")
		quit(1)
		return

	var authored: AABB = mesh_instance.get_aabb()
	var art: RefCounted = ArtTuning.load_art()
	var normalised: RefCounted = Normalise.to_target_height(authored, art.num("kart"))
	var correction: float = KartView.yaw_correction_for(authored)

	# The world-axis-aligned box at yaw 0, which is what the kart occupies while
	# it stands at the start line. The correction is folded in, so a kart turned
	# a quarter turn reports a transposed footprint rather than the same numbers.
	var world: AABB = Normalise.world_box(normalised, correction)

	var vertices: PackedVector3Array = (mesh_instance.mesh as Mesh).surface_get_arrays(0)[
		Mesh.ARRAY_VERTEX
	]
	var sum := Vector3.ZERO
	for v in vertices:
		sum += v
	var centroid: Vector3 = sum / float(vertices.size())
	var centre: Vector3 = authored.position + authored.size / 2.0

	print(
		(
			JSON
			. stringify(
				{
					"authored": [authored.size.x, authored.size.y, authored.size.z],
					"scale": normalised.scale,
					"normalised":
					[normalised.box.size.x, normalised.box.size.y, normalised.box.size.z],
					"lowest_y": normalised.box.position.y,
					"world_extent": [world.size.x, world.size.z],
					"yaw_correction_degrees": rad_to_deg(correction),
					"nose_sign": KartView.NOSE_SIGN,
					"centroid_offset":
					[centroid.x - centre.x, centroid.y - centre.y, centroid.z - centre.z],
					"vertex_count": vertices.size(),
				}
			)
		)
	)
	quit()
