# The minimap — §7's 200×200 inset, the design document's Minimap feature.
#
# The port decisions (godot/minimap):
#
#   1. A SubViewport SHARING the main world (`own_world_3d = false`), with its
#      own orthographic camera. That single choice is what the document's
#      "depth cleared first, never occluded, no distortion of the main view"
#      means in Godot terms — a second viewport has its own depth and its own
#      target, and touches the main image not at all.
#   2. The camera basis is a CONSTANT: looking straight down with world +X
#      toward the map's right edge and world +Z toward its bottom edge. Only
#      the X/Z position follows the kart — post-physics, while RACING (the
#      Suspending scenario pins that tracking stops outside it).
#   3. The markers are unshaded meshes in the MAIN world on render layer 2:
#      the minimap camera's mask includes the layer, the chase camera's drops
#      it. Masked, never moved or toggled. The arrow's yaw is the
#      simulation's own — the true heading; the reference build's 90° offset
#      is a listed deviation the port must not reproduce.
extends SubViewportContainer

## Looking down −Y with world +X right and +Z at the bottom edge:
## camera X = world X, camera up (+Y basis) = world −Z, camera −Z = world −Y.
const DOWN_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))

var _camera: Camera3D = null
var _markers: Node3D = null
var _disc: MeshInstance3D = null
var _arrow: MeshInstance3D = null


## Build the viewport, camera, and markers from the art table. `world_parent`
## is the 3D node the markers join — they must live in the world the shared
## viewport renders. Called once by the composition root.
func configure(art: RefCounted, world_parent: Node3D) -> void:
	var side: float = art.num("minimapSize")
	var inset: float = art.num("minimapInset")
	custom_minimum_size = Vector2(side, side)
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	# Offsets, not position — the same off-screen trap the timer block hit.
	offset_left = inset
	offset_right = inset + side
	offset_top = -side - inset
	offset_bottom = -inset
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport := SubViewport.new()
	viewport.name = "Viewport"
	viewport.own_world_3d = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = art.num("minimapHalfExtent") * 2.0
	_camera.near = art.num("minimapNear")
	_camera.far = art.num("minimapFar")
	_camera.cull_mask = (1 << 0) | (1 << 1)
	# The map is an instrument: its camera carries its own Environment with
	# fog disabled, so the field stays legible instead of washing out through
	# 50 wu of fog (M6 decision; the main view's fog is untouched).
	var map_env := Environment.new()
	map_env.background_mode = Environment.BG_CLEAR_COLOR
	map_env.fog_enabled = false
	_camera.environment = map_env
	viewport.add_child(_camera)
	_camera.global_transform = Transform3D(
		DOWN_BASIS, Vector3(0.0, art.num("minimapAltitude"), 0.0)
	)

	_markers = Node3D.new()
	_markers.name = "MinimapMarkers"
	world_parent.add_child(_markers)
	_disc = _make_disc(art)
	_arrow = _make_arrow(art)
	_markers.add_child(_disc)
	_markers.add_child(_arrow)


## Once per rendered frame from the root. Tracking runs only while RACING;
## the markers and camera read the post-physics snapshot.
func draw_from(sim: RefCounted) -> void:
	if _camera == null or sim == null:
		return
	if not sim.race.is_racing():
		return
	_camera.global_position.x = sim.pos_x
	_camera.global_position.z = sim.pos_z
	_disc.global_position = Vector3(sim.pos_x, _disc.global_position.y, sim.pos_z)
	_arrow.global_position = Vector3(sim.pos_x, _arrow.global_position.y, sim.pos_z)
	_arrow.global_rotation = Vector3(0.0, sim.yaw, 0.0)


func _make_disc(art: RefCounted) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = art.num("minimapDiscRadiusWu")
	mesh.bottom_radius = art.num("minimapDiscRadiusWu")
	mesh.height = art.num("minimapDiscHeightWu")
	var instance := MeshInstance3D.new()
	instance.name = "Disc"
	instance.mesh = mesh
	instance.material_override = _flat_material(art.colour("minimapDiscColour"))
	instance.layers = 1 << 1
	instance.position.y = art.num("minimapMarkerAltitudeWu")
	return instance


## A triangle in the XZ plane pointing along local +Z — the kart's own
## forward convention, so rotation.y = yaw is the true heading.
func _make_arrow(art: RefCounted) -> MeshInstance3D:
	var half_w: float = art.num("minimapArrowWidthWu") / 2.0
	var base_z: float = art.num("minimapDiscRadiusWu")
	var tip_z: float = base_z + art.num("minimapArrowLengthWu")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.add_vertex(Vector3(0.0, 0.0, tip_z))
	surface.add_vertex(Vector3(half_w, 0.0, base_z))
	surface.add_vertex(Vector3(-half_w, 0.0, base_z))
	# Both winding orders, so the flat symbol reads from straight above
	# regardless of culling.
	surface.add_vertex(Vector3(0.0, 0.0, tip_z))
	surface.add_vertex(Vector3(-half_w, 0.0, base_z))
	surface.add_vertex(Vector3(half_w, 0.0, base_z))
	var instance := MeshInstance3D.new()
	instance.name = "Arrow"
	instance.mesh = surface.commit()
	instance.material_override = _flat_material(art.colour("minimapArrowColour"))
	instance.layers = 1 << 1
	instance.position.y = art.num("minimapMarkerAltitudeWu")
	return instance


func _flat_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material
