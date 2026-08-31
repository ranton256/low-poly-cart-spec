# Photograph one gate from IN FRONT of it and from BEHIND it — the proof that a
# gate's pass direction is readable at a glance from either side.
#
#   godot -s tools/gate_side_capture.gd -- --out gallery/gate_front.png --side front
#   godot -s tools/gate_side_capture.gd -- --out gallery/gate_back.png  --side back
#
# WINDOWED, like every capture. This state exists because the requirement it
# serves is a COMPARISON: the design document (What a gate looks like, amended
# after the owner's first playtest) asks that a gate met from behind "visibly
# reads as the back of a gate rather than an oncoming one", and no single frame
# can show that. Two frames of the same gate from opposite sides can, and a
# reviewer settles the question by looking at them side by side rather than by
# believing a sentence in a commit message.
#
# FULLY STAGED, like graze_capture.gd: nothing is driven, the camera is placed
# rather than chased, and the world is paused at a fixed simulation tick. The
# subject is the SHIPPED CIRCUIT's first gate, so the pose follows the course if
# the course moves.
extends SceneTree

const Common := preload("res://tools/capture_common.gd")

## An exact multiple of the 48-tick gate pulse period, and past the GO! linger,
## so the overlay is clear and the next gate sits at full gateNextColour — the
## phase is chosen rather than caught, exactly as gallery.sh's gate_next is.
const STAGE_TICK := 288
const SETTLE_FRAMES := 12
const MAX_BLACK_FRACTION := 0.20

## Where the camera stands relative to the gate, in the GATE's own frame: back
## along its forward axis for the approach, ahead of it for the far side, at
## eye height and looking at the middle of the mouth.
const EYE_DISTANCE_WU := 12.0
const EYE_HEIGHT_WU := 4.0
const LOOK_HEIGHT_WU := 1.5


func _init() -> void:
	var options := _parse()
	var out_path: String = options.get("out", "gallery/gate_front.png")
	var side: String = options.get("side", "front")
	if side != "front" and side != "back":
		printerr("gate_side_capture: --side must be front or back, not %s" % side)
		quit(1)
		return

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	await process_frame
	var root: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	get_root().add_child(root)
	await process_frame
	while root.sim.ticks < STAGE_TICK:
		await physics_frame
	paused = true

	# The gate's own frame, so this reads the course rather than a hardcoded
	# pose: "front" is the side a lap approaches from, which is BEHIND the
	# segment in gate-forward terms.
	var gate: RefCounted = root.sim.circuit.gates[0]
	var forward := Vector3(gate.forward_x(), 0.0, gate.forward_z())
	var centre := Vector3(gate.x, 0.0, gate.z)
	var offset: float = -EYE_DISTANCE_WU if side == "front" else EYE_DISTANCE_WU
	var camera: Camera3D = get_root().get_camera_3d()
	camera.global_transform = Transform3D.IDENTITY
	camera.global_position = centre + forward * offset + Vector3.UP * EYE_HEIGHT_WU
	camera.look_at(centre + Vector3.UP * LOOK_HEIGHT_WU, Vector3.UP)

	for _i in range(SETTLE_FRAMES):
		await process_frame

	var image: Image = await Common.fresh_frame(self, root, "gate_side_capture")
	if image == null:
		printerr("gate_side_capture: no image — this needs a WINDOWED run")
		quit(1)
		return
	if _black_fraction(image) > MAX_BLACK_FRACTION:
		printerr("gate_side_capture: the renderer had not caught up. Nothing written.")
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	if image.save_png(out_path) != OK:
		printerr("gate_side_capture: could not write %s" % out_path)
		quit(1)
		return
	print(
		(
			"gate_side_capture: wrote %s — gate 1 from the %s, at tick %d"
			% [out_path, side, STAGE_TICK]
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
