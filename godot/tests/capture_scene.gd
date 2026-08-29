# Capture a scene to a PNG. The Godot half of tools/capture.sh.
#
# WINDOWED ONLY. Godot's headless mode has no renderer, so
# get_texture().get_image() returns null there — verified, not assumed. This is
# why the visual gate is separate from tools/test.sh and must stay that way:
# the moment a capture lands in the standing suite, it stops running over SSH
# and needs a virtual framebuffer. See GOTCHAS.md.
#
# Determinism matters as much here as in any other suite. The capture waits a
# FIXED number of frames rather than a duration, so the same scene produces the
# same pixels on a fast machine and a slow one. Anything animated must be a
# function of the simulation clock, or settled before the capture — a
# non-deterministic call count cannot be fixed by a seed.
#
#   godot -s tests/capture_scene.gd -- --scene res://scenes/main.tscn \
#       --out docs/progress/main.png --frames 30
extends SceneTree

const DEFAULT_SCENE := "res://scenes/main.tscn"
const DEFAULT_OUT := "gallery/capture.png"
const DEFAULT_FRAMES := 30


## Keep the capture window from stealing focus.
##
## A capture is a build step, not an app launch: it should not interrupt whatever
## the person running it is doing. Godot has no --no-focus command-line flag, so
## the window flag is set as early as the script runs, before the first frame is
## drawn. NO_FOCUS also keeps the window out of the way on later frames, which
## matters because a capture run may take dozens of windows in a row — the
## exposure search opens one per candidate scale.
##
## Best-effort by design: it is a request to the windowing system, and a platform
## may decline it. It must never fail the capture, so nothing here is asserted.
func _quieten_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	# Mouse passthrough as well: a window that cannot take focus can still
	# swallow a click if it happens to be under the pointer.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, true)


func _init() -> void:
	_quieten_window()
	var options := _parse_arguments()
	var scene_path: String = options.get("scene", DEFAULT_SCENE)
	var out_path: String = options.get("out", DEFAULT_OUT)
	var frames: int = int(options.get("frames", DEFAULT_FRAMES))

	# Autoloads finish _ready on a deferred first frame. Let them settle before
	# anything is seeded or instantiated. See GOTCHAS.md.
	await process_frame

	var instance := _instantiate(scene_path)
	if instance == null:
		quit(1)
		return
	get_root().add_child(instance)

	# A fixed frame count, never a timer.
	for _index in range(frames):
		await process_frame

	var image := get_root().get_texture().get_image()
	if image == null:
		printerr("capture: no image — this needs a WINDOWED run; headless has no renderer")
		quit(1)
		return

	var error := _write(image, out_path)
	if error != OK:
		printerr("capture: could not write %s (error %d)" % [out_path, error])
		quit(1)
		return

	print(
		(
			"capture: %s — %dx%d, %d frames of %s"
			% [out_path, image.get_width(), image.get_height(), frames, scene_path]
		)
	)
	quit(0)


func _instantiate(scene_path: String) -> Node:
	if not ResourceLoader.exists(scene_path):
		printerr("capture: no such scene: %s" % scene_path)
		return null
	var packed := load(scene_path) as PackedScene
	if packed == null:
		printerr("capture: %s is not a PackedScene" % scene_path)
		return null
	return packed.instantiate()


func _write(image: Image, out_path: String) -> int:
	var directory := out_path.get_base_dir()
	if directory != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	return image.save_png(out_path)


## Godot hands user arguments after `--` to OS.get_cmdline_user_args().
func _parse_arguments() -> Dictionary:
	var options := {}
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size():
		var key: String = arguments[index]
		if key.begins_with("--") and index + 1 < arguments.size():
			options[key.substr(2)] = arguments[index + 1]
			index += 2
		else:
			index += 1
	return options
