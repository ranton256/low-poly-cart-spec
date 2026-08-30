# Capture the grazing-angle state (M6 Critic finding 1's dedicated proof):
# the ground texture and a receding row of cones under a near-horizontal
# camera — the pose where anisotropic filtering visibly matters and where a
# silently-lost import flag would smear every distant texel.
#
#   godot -s tools/graze_capture.gd -- --out gallery/graze_cones.png
#
# WINDOWED, like every capture. Fully staged rather than driven: the cones
# sit at fixed positions and the camera is placed, not chased, so the state
# has no drive noise at all. The world is paused at a fixed post-GO tick,
# after the countdown overlay has cleared the centre of the frame.
extends SceneTree

const Common := preload("res://tools/capture_common.gd")
const Anisotropy := preload("res://scripts/view/anisotropy.gd")

const STAGE_TICK := 350
const SETTLE_FRAMES := 12
const MAX_BLACK_FRACTION := 0.20

## The row recedes north along the boundary of the camera's view; the spacing
## doubles so the far cones probe the mip chain, not just the near texels.
const CONE_ROWS: Array = [
	[21.6, 2.0, 1.0],
	[22.2, 6.0, 1.2],
	[22.8, 14.0, 1.4],
	[23.4, 30.0, 1.6],
]


func _init() -> void:
	var options := _parse()
	var out_path: String = options.get("out", "gallery/graze_cones.png")

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	await process_frame

	var root: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	get_root().add_child(root)
	await process_frame
	while root.sim.ticks < STAGE_TICK:
		await physics_frame
	paused = true

	# The staged row, from the field's own loaded cone scene — the same
	# import pipeline, materials, and anisotropy pass as every played cone.
	var field: Node3D = root.props
	var cone_scene: PackedScene = field._scenes["cone"] as PackedScene
	var authored: AABB = field._boxes["cone"]
	for row: Array in CONE_ROWS:
		var cone: Node3D = cone_scene.instantiate() as Node3D
		field.get_parent().add_child(cone)
		# The field's own normalisation arithmetic: row[2] is the target
		# height in world units; the authored model is whatever size it is.
		var scale: float = float(row[2]) / authored.size.y
		cone.scale = Vector3.ONE * scale
		cone.position = Vector3(
			float(row[0]) - authored.get_center().x * scale,
			-authored.position.y * scale,
			float(row[1]) - authored.get_center().z * scale
		)
		Anisotropy.apply(cone)

	# A grazing pose: half a world unit off the ground, looking flat north
	# along the row. The chase camera is repositioned in place so the real
	# viewport, FOV, and environment are what gets photographed.
	var camera: Camera3D = get_root().get_camera_3d()
	camera.global_transform = Transform3D.IDENTITY
	camera.global_position = Vector3(22.0, 0.5, -4.0)
	camera.look_at(Vector3(22.0, 0.3, 30.0), Vector3.UP)

	for _i in range(SETTLE_FRAMES):
		await process_frame

	var image: Image = await Common.fresh_frame(self, root, "graze_capture")
	if image == null:
		printerr("graze_capture: no image — this needs a WINDOWED run")
		quit(1)
		return
	if _black_fraction(image) > MAX_BLACK_FRACTION:
		printerr("graze_capture: the renderer had not caught up. Nothing written.")
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	if image.save_png(out_path) != OK:
		printerr("graze_capture: could not write %s" % out_path)
		quit(1)
		return
	print(
		(
			"graze_capture: wrote %s — %d staged cones at tick %d"
			% [out_path, CONE_ROWS.size(), STAGE_TICK]
		)
	)
	quit(0)


func _black_fraction(image: Image) -> float:
	var black := 0
	var step := 7
	var samples := 0
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			samples += 1
			if image.get_pixel(x, y).get_luminance() < 0.004:
				black += 1
	return float(black) / float(maxi(samples, 1))


func _parse() -> Dictionary:
	var options := {}
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size():
		var argument: String = arguments[index]
		if argument.begins_with("--") and index + 1 < arguments.size():
			options[argument.trim_prefix("--")] = arguments[index + 1]
			index += 2
		else:
			index += 1
	return options
