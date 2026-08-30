# Anisotropic sampling on the base-colour maps — the GDD's §2 requirement,
# made real rather than pinned-but-inert.
#
# The M6 Critic's finding 1: the project pins the anisotropic LEVEL, but
# Godot only applies that level to samplers whose material requests
# anisotropy, and every imported material arrives at LINEAR_WITH_MIPMAPS.
# This one static pass flips the imported materials to the anisotropic
# sampler mode; the pinned level (16×) then governs. Shared by the kart view
# and the prop field, so a new consumer of imported models cannot forget it.
extends RefCounted


static func apply(root: Node3D) -> void:
	for child in root.get_children():
		if child is Node3D:
			apply(child as Node3D)
	if root is MeshInstance3D:
		var mesh_node := root as MeshInstance3D
		for surface in range(mesh_node.get_surface_override_material_count()):
			_flip(mesh_node.get_active_material(surface))


static func _flip(material: Material) -> void:
	var standard := material as BaseMaterial3D
	if standard == null:
		return
	standard.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
