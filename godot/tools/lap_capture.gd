# Capture M4's second mandated proof: TIME frozen on a banked lap, BEST
# flashing green — by replaying the lap suite's own scripted drive through the
# real input path.
#
#   godot -s tools/lap_capture.gd -- --out docs/progress/<name>.png
#
# WINDOWED, like every capture. The phase table is
# tests/lap_gate_test.gd's LAP_PHASES — one source of truth: the suite proves
# the drive banks, this tool photographs the same drive doing it. Phases are
# RACING-relative (the suite starts racing immediately), so the tool waits out
# the real countdown before phase one begins.
extends SceneTree

const LapSuite := preload("res://tests/lap_gate_test.gd")

## Physics frames into the hold window before grabbing: far enough in to be
## unambiguous, well inside lapRestartDelay's 30 ticks and the 60-tick flash.
const CAPTURE_HOLD_TICKS := 10
const SETTLE_FRAMES := 12
const MAX_BLACK_FRACTION := 0.20

const PHASE_ACTIONS := ["accelerate", "steer_left", "steer_right"]


func _init() -> void:
	var options := _parse()
	var out_path: String = options.get("out", "gallery/lap.png")

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	await process_frame

	var root: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	get_root().add_child(root)
	await process_frame

	# The real countdown runs first; the phases are racing-relative.
	while not root.sim.race.is_racing():
		await physics_frame

	# Re-pressed every tick, for the same reason drive_capture.gd does it: the
	# unfocused window clears held input each frame, correctly.
	var banked := false
	for phase: Array in LapSuite.LAP_PHASES:
		if banked:
			break
		for _i in range(int(phase[3])):
			for action_index in range(PHASE_ACTIONS.size()):
				if phase[action_index]:
					Input.action_press(PHASE_ACTIONS[action_index])
			await physics_frame
			if root.sim.lap.banked_this_tick:
				banked = true
				break
		for action in PHASE_ACTIONS:
			Input.action_release(action)

	if not banked:
		printerr("lap_capture: the scripted drive never banked — is lap_gate_test green?")
		quit(1)
		return

	# Into the hold window: TIME holds the banked time, BEST flashes green.
	for _i in range(CAPTURE_HOLD_TICKS):
		await physics_frame
	for _i in range(SETTLE_FRAMES):
		await process_frame

	var image := get_root().get_texture().get_image()
	if image == null:
		printerr("lap_capture: no image — this needs a WINDOWED run")
		quit(1)
		return
	if _black_fraction(image) > MAX_BLACK_FRACTION:
		printerr("lap_capture: the renderer had not caught up; nothing written")
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	if image.save_png(out_path) != OK:
		printerr("lap_capture: could not write %s" % out_path)
		quit(1)
		return
	print(
		(
			"lap_capture: %s — banked %.2f s, best %.2f s, hold %d ticks left, flash %d ticks left"
			% [
				out_path,
				root.sim.lap.banked_seconds,
				root.sim.lap.best_seconds,
				root.sim.lap.hold_ticks,
				root.sim.lap.best_flash_ticks,
			]
		)
	)
	quit()


func _black_fraction(image: Image) -> float:
	var black: int = 0
	var total: int = 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			total += 1
			var pixel := image.get_pixel(x, y)
			if pixel.r == 0.0 and pixel.g == 0.0 and pixel.b == 0.0:
				black += 1
	return float(black) / float(maxi(total, 1))


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
