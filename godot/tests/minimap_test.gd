# The minimap — the design document's Minimap feature (all five scenarios)
# and godot/minimap's port decisions: a world-sharing SubViewport, a fixed
# camera basis, layer-mask marker isolation.
#
#   godot --headless -s tests/minimap_test.gd
#
# EXPECTED VALUES COME FROM THE TUNING TABLES: 200×200 inset 10 px from the
# bottom-left, altitude 100, half-extent 50, near 1 / far 1000, a ~2.4 wu red
# disc and a yellow true-heading arrow on render layer 2.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const ArtTuning := preload("res://scripts/art_tuning.gd")
const MainScene := preload("res://scenes/main.tscn")

## Render layer 2 as a cull-mask bit.
const LAYER_TWO_BIT := 1 << 1

var _root: Node3D = null
var _art: RefCounted = null
var _minimap: SubViewportContainer = null


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_art = ArtTuning.load_art()
	await process_frame
	_root = MainScene.instantiate() as Node3D
	get_root().add_child(_root)
	await process_frame
	_root.sim.race.start_racing_immediately()
	await process_frame
	_minimap = _root.get_node("Minimap") as SubViewportContainer
	_test_the_inset_is_the_specified_region()
	_test_the_framing_is_parallel_from_altitude()
	await _test_the_map_never_rotates()
	await _test_markers_track_the_kart_at_true_heading()
	_test_markers_are_masked_not_moved()
	get_root().remove_child(_root)
	_root.free()
	RVTest.finish(
		self, "minimap: inset, framing, fixed north, markers, masking ok", "minimap check(s)"
	)


# @covers Minimap / Rendering the minimap inset
func _test_the_inset_is_the_specified_region() -> void:
	_check(_minimap != null, "the running scene has the minimap")
	var inset: float = _art.num("minimapInset")
	var side: float = _art.num("minimapSize")
	_check(_minimap.size == Vector2(side, side), "the container is 200×200 (%s)" % _minimap.size)
	_check(
		_minimap.anchor_top == 1.0 and _minimap.anchor_left == 0.0,
		"anchored to the bottom-left corner"
	)
	_check(
		_minimap.offset_left == inset and _minimap.offset_bottom == -inset,
		"inset 10 px from the bottom-left corner"
	)
	var parent_size: Vector2 = _minimap.get_parent_area_size()
	_check(
		_minimap.position == Vector2(inset, parent_size.y - side - inset),
		"and actually ON screen at that inset (%s in %s)" % [_minimap.position, parent_size]
	)
	var viewport: SubViewport = _minimap.get_node("Viewport") as SubViewport
	_check(viewport != null and not viewport.own_world_3d, "a SubViewport sharing the main world")
	# The main view is untouched: the inset draws into its OWN render target
	# at its own size, and the main camera still renders through the ROOT
	# viewport. (The first draft of this assertion was a tautology — M5
	# Critic finding 3; the second read the root window size, which headless
	# runs do not honour.)
	_check(
		viewport.size == Vector2i(int(side), int(side)),
		(
			"the inset renders to its own %s target (%s)"
			% [Vector2i(int(side), int(side)), viewport.size]
		)
	)
	_check(
		(
			_root.chase_camera.get_viewport() == _root.get_viewport()
			and _root.chase_camera.get_viewport() != viewport
		),
		"while the main camera renders through the root viewport, untouched"
	)

	_check(_minimap.stretch, "the viewport fills the container without distorting the main view")


# @covers Minimap / Framing the minimap view
func _test_the_framing_is_parallel_from_altitude() -> void:
	var cam: Camera3D = _minimap.get_node("Viewport/Camera") as Camera3D
	_check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "the projection is parallel")
	RVTest.close(
		cam.size, _art.num("minimapHalfExtent") * 2.0, 0.001, "framing minimapHalfExtent each way"
	)
	RVTest.close(cam.global_position.y, _art.num("minimapAltitude"), 0.001, "from 100 wu up")
	RVTest.close(cam.near, _art.num("minimapNear"), 0.001, "near plane from data")
	RVTest.close(cam.far, _art.num("minimapFar"), 0.001, "far plane from data")
	RVTest.close(cam.global_position.x, _root.sim.pos_x, 0.5, "centred on the kart's X")
	RVTest.close(cam.global_position.z, _root.sim.pos_z, 0.5, "and Z")


# @covers Minimap / Keeping the minimap orientation fixed
func _test_the_map_never_rotates() -> void:
	var cam: Camera3D = _minimap.get_node("Viewport/Camera") as Camera3D
	var basis_before: Basis = cam.global_basis
	# +X right on the map means the camera's own X axis is world +X; +Z toward
	# the bottom edge means the camera's screen-down (−Y basis) is world +Z.
	_check(basis_before.x.is_equal_approx(Vector3(1, 0, 0)), "world +X toward the right edge")
	_check(basis_before.y.is_equal_approx(Vector3(0, 0, -1)), "world +Z toward the bottom edge")
	_root.sim.yaw = 2.3
	for _i in range(10):
		Input.action_press("steer_left")
		Input.action_press("accelerate")
		await physics_frame
	Input.action_release("steer_left")
	Input.action_release("accelerate")
	await process_frame
	_check(cam.global_basis == basis_before, "turning the kart does not turn the map")


# @covers Minimap / Marking the kart on the minimap
func _test_markers_track_the_kart_at_true_heading() -> void:
	var disc: MeshInstance3D = _root.get_node("MinimapMarkers/Disc") as MeshInstance3D
	var arrow: MeshInstance3D = _root.get_node("MinimapMarkers/Arrow") as MeshInstance3D
	_check(disc != null and arrow != null, "the disc and the arrow exist in the world")
	RVTest.close(
		(disc.mesh as CylinderMesh).top_radius,
		_art.num("minimapDiscRadiusWu"),
		0.001,
		"a flat disc of ~2.4 wu radius"
	)
	for mesh: MeshInstance3D in [disc, arrow]:
		var material: StandardMaterial3D = mesh.get_active_material(0) as StandardMaterial3D
		_check(
			material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
			"%s is unshaded — a flat symbol, not an object" % mesh.name
		)
	# Drive; the markers follow the post-physics position at the true heading.
	for _i in range(30):
		Input.action_press("accelerate")
		await physics_frame
	Input.action_release("accelerate")
	await process_frame
	RVTest.close(disc.global_position.x, _root.sim.pos_x, 0.5, "the disc tracks the kart's X")
	RVTest.close(disc.global_position.z, _root.sim.pos_z, 0.5, "and Z")
	RVTest.close(
		arrow.global_rotation.y,
		_root.sim.yaw,
		0.01,
		"the arrow points at the simulation's TRUE heading — no 90° offset"
	)


# @covers Minimap / Hiding minimap markers from the main view
func _test_markers_are_masked_not_moved() -> void:
	var disc: MeshInstance3D = _root.get_node("MinimapMarkers/Disc") as MeshInstance3D
	var arrow: MeshInstance3D = _root.get_node("MinimapMarkers/Arrow") as MeshInstance3D
	var minimap_cam: Camera3D = _minimap.get_node("Viewport/Camera") as Camera3D
	var chase: Camera3D = _root.chase_camera
	for mesh: MeshInstance3D in [disc, arrow]:
		_check(mesh.layers == LAYER_TWO_BIT, "%s lives on render layer 2 only" % mesh.name)
		_check(mesh.visible, "%s is never hidden or toggled — masking does the work" % mesh.name)
	_check(
		(chase.cull_mask & LAYER_TWO_BIT) == 0,
		"the chase camera's cull mask drops layer 2 — the main view never shows the markers"
	)
	_check((minimap_cam.cull_mask & LAYER_TWO_BIT) != 0, "the minimap camera's mask includes it")
