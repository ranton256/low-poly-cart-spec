# M7's visual proof: the same seeded field BEFORE saving and AFTER a
# save → regenerate → restore cycle — three frames, sim frozen throughout,
# so the ONLY thing that can differ between first and last is the world the
# layout machinery rebuilt.
#
#   godot -s tools/layout_capture.gd -- --out docs/progress
extends SceneTree

const Common := preload("res://tools/capture_common.gd")

const SETTLE := 12


func _init() -> void:
	var out_dir: String = _parse().get("out", "gallery")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	await process_frame
	var root: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	get_root().add_child(root)
	await process_frame
	while not root.sim.race.is_racing():
		await physics_frame
	while root.sim.race.ticks_in_state < 40:  # past the GO! linger
		await physics_frame
	paused = true  # the sim is frozen for all three frames

	if not await _shot(root, "%s/m7-layout-before.png" % out_dir):
		return
	if not root.save_layout():
		printerr("layout_capture: save failed")
		quit(1)
		return
	root.regenerate_world()
	if not await _shot(root, "%s/m7-layout-regenerated.png" % out_dir):
		return
	if not root.load_layout():
		printerr("layout_capture: load failed")
		quit(1)
		return
	if not await _shot(root, "%s/m7-layout-restored.png" % out_dir):
		return
	print("layout_capture: before / regenerated / restored written to %s" % out_dir)
	quit(0)


func _shot(root: Node3D, path: String) -> bool:
	for _i in range(SETTLE):
		await process_frame
	var image: Image = await Common.fresh_frame(self, root, "layout_capture")
	if image == null:
		quit(1)
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if image.save_png(path) != OK:
		printerr("layout_capture: could not write %s" % path)
		quit(1)
		return false
	return true


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
