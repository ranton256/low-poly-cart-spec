# Capture the game after driving a scripted input sequence.
#
#   godot -s tools/drive_capture.gd -- --out <path> --ticks 200 --hold accelerate,steer_left
#
# WINDOWED, like every capture. The chase camera's behaviour is only visible once
# the kart has been driven, and tools/capture.sh renders a scene at rest — this
# drives it first. The sequence is a fixed number of TICKS, never a duration, so
# the same commands produce the same frame on a fast machine and a slow one.
extends SceneTree

const DEFAULT_TICKS := 200


func _init() -> void:
	var options := _parse()
	var out_path: String = options.get("out", "gallery/drive.png")
	var ticks: int = int(options.get("ticks", DEFAULT_TICKS))
	var hold: PackedStringArray = str(options.get("hold", "")).split(",", false)

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	await process_frame

	var root: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	get_root().add_child(root)
	await process_frame

	# RE-PRESSED EVERY TICK, and that is not belt-and-braces. This tool runs the
	# window unfocused so captures do not interrupt whoever is running them, and
	# the game's own focus-loss handler clears every held input the moment the
	# window is not focused — which is exactly what the design document asks for
	# and exactly what stops a synthetic hold from reaching the kart. A first run
	# of this tool drove 560 ticks and reported the kart stopped at z=56.064.
	# Re-pressing re-establishes the hold after each clear, so the capture drives
	# through the real input path rather than around it.
	for _i in range(ticks):
		for action in hold:
			if InputMap.has_action(action):
				Input.action_press(action)
		await physics_frame
	for action in hold:
		if InputMap.has_action(action):
			Input.action_release(action)
	# Let the frame settle so the capture is of a drawn frame, not a mid-step one.
	for _i in range(3):
		await process_frame

	var image := get_root().get_texture().get_image()
	if image == null:
		printerr("drive_capture: no image — this needs a WINDOWED run")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	if image.save_png(out_path) != OK:
		printerr("drive_capture: could not write %s" % out_path)
		quit(1)
		return
	# Report WHERE the kart ended up. A capture whose subject's position nobody
	# recorded cannot be checked against what it claims to show.
	print(
		(
			"drive_capture: %s — %d ticks holding [%s]; kart at x=%.3f z=%.3f yaw=%.3f v=%.5f, %d steps"
			% [
				out_path,
				ticks,
				", ".join(hold),
				root.sim.pos_x,
				root.sim.pos_z,
				root.sim.yaw,
				root.sim.velocity,
				root.steps(),
			]
		)
	)
	quit()


func _parse() -> Dictionary:
	var options := {}
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size():
		if arguments[index].begins_with("--") and index + 1 < arguments.size():
			options[arguments[index].substr(2)] = arguments[index + 1]
			index += 2
		else:
			index += 1
	return options
