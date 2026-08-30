# Capture the game after driving a scripted input sequence.
#
#   godot -s tools/drive_capture.gd -- --out <path> --ticks 200 --hold accelerate,steer_left
#
# WINDOWED, like every capture. The chase camera's behaviour is only visible once
# the kart has been driven, and tools/capture.sh renders a scene at rest — this
# drives it first. The sequence is a fixed number of TICKS, never a duration, so
# the same commands produce the same frame on a fast machine and a slow one.
extends SceneTree

const Common := preload("res://tools/capture_common.gd")

const DEFAULT_TICKS := 200
## Rendered frames to wait before grabbing the viewport — belt only; the
## post-draw await in _fresh_frame is what guarantees freshness. Measured
## settle floor with it in place: mean 0.0217 / changed 0.177% / strong
## 0.020% over a double-capture diff of an identical 330-tick drive.
const SETTLE_FRAMES := 12
## A rendered frame of this game is grass, sky and props. If most of it is pure
## black the renderer had not caught up, and the capture is not evidence — refuse
## to write it rather than let a half-drawn frame be committed as proof.
const MAX_BLACK_FRACTION := 0.20


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
	# Driven to an exact SIMULATION tick, not a count of loop iterations —
	# boot consumes a variable frame or two, and counting iterations landed
	# the capture at different sim ticks run to run (the gallery's noise
	# floor showed 2.0 mean on this state; sim-aligned it is ~0).
	while root.sim.ticks < ticks:
		Common.press(hold)
		await physics_frame
	Common.release(hold)
	# FREEZE the tree before settling: the settle frames otherwise let the
	# simulation coast a run-varying number of ticks after the target — the
	# gallery's noise floor caught the whole scene shifted between two runs
	# of an identical command. Paused, the renderer still presents frames.
	paused = true

	# Let the frame settle, then grab ONLY after the renderer has presented a
	# frame (frame_post_draw) — the render target otherwise lags the scene,
	# and this tool has returned frames hundreds of ticks stale (M5 Critic
	# finding 8; it then bit the M5 proof re-capture). The settle loop stays
	# as belt for effects; the post-draw await is the braces.
	for _i in range(SETTLE_FRAMES):
		await process_frame

	var image: Image = await Common.fresh_frame(self, root, "drive_capture")
	if image == null:
		printerr("drive_capture: no image — this needs a WINDOWED run")
		quit(1)
		return
	var black: float = _black_fraction(image)
	if black > MAX_BLACK_FRACTION:
		printerr(
			(
				(
					"drive_capture: %.1f%% of the frame is pure black — the renderer had "
					+ "not caught up and this is not a usable capture. Nothing written."
				)
				% (black * 100.0)
			)
		)
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
				root.sim.ticks,
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


## How much of the frame is pure black. Sampled on a grid rather than every
## pixel: this runs after every capture and the answer does not need 900,000
## samples to be right.
func _black_fraction(image: Image) -> float:
	var black: int = 0
	var total: int = 0
	var step: int = 8
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
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
