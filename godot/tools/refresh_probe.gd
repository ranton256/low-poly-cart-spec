# Acceptance 14b — the refresh-rate half of checklist item 14, in the REAL
# game: "A scripted 60-second input sequence replayed at 30, 60, and 144
# frames per second ends with the kart within 0.5 wu of the same position and
# within 0.05 s of the same lap time."
#
#   godot -s tools/refresh_probe.gd
#
# WINDOWED — the point is real rendering at real frame caps (vsync disabled,
# Engine.max_fps per pass) while physics holds its fixed 60 Hz. The input
# script is the lap suite's own phase table, replayed cyclically to the
# 3600th racing tick; presses land on frame boundaries, so a 30 fps pass
# batches two ticks behind each press and a 144 fps pass none — exactly the
# jitter the tolerance exists to bound. The headless half (three batchings,
# byte-agreement) is conformance_test item 14.
extends SceneTree

const LapSuite := preload("res://tests/lap_gate_test.gd")
const Common := preload("res://tools/capture_common.gd")

const RATES: Array[int] = [60, 30, 144]
const RACE_TICKS := 3600  # the checklist's 60 seconds
const POSITION_TOLERANCE_WU := 0.5
const LAP_TIME_TOLERANCE_S := 0.05
const PHASE_ACTIONS := ["accelerate", "steer_left", "steer_right"]


func _init() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame

	var results: Array = []
	for rate in RATES:
		results.append(await _run_at(rate))

	var failures := 0
	for i in range(RATES.size()):
		for j in range(i + 1, RATES.size()):
			var a: Dictionary = results[i]
			var b: Dictionary = results[j]
			var dist: float = Vector2(a.x - b.x, a.z - b.z).length()
			var lap_gap: float = absf(a.lap - b.lap)
			var ok := dist <= POSITION_TOLERANCE_WU and lap_gap <= LAP_TIME_TOLERANCE_S
			print(
				(
					(
						"refresh_probe: %d vs %d fps — position gap %.4f wu (≤ %.1f), "
						+ "lap gap %.4f s (≤ %.2f) %s"
					)
					% [
						RATES[i],
						RATES[j],
						dist,
						POSITION_TOLERANCE_WU,
						lap_gap,
						LAP_TIME_TOLERANCE_S,
						"ok" if ok else "FAIL"
					]
				)
			)
			if not ok:
				failures += 1

	for i in range(RATES.size()):
		var r: Dictionary = results[i]
		print(
			(
				(
					"refresh_probe: %3d fps — end (%.4f, %.4f), best lap %.4f s, "
					+ "%d frames drawn in %.1f s"
				)
				% [RATES[i], r.x, r.z, r.lap, r.frames, r.wall_s]
			)
		)
	if failures == 0:
		print("refresh_probe: acceptance 14b holds at 30/60/144 fps")
	quit(failures)


func _run_at(rate: int) -> Dictionary:
	Engine.max_fps = rate
	var root: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	get_root().add_child(root)
	await process_frame
	while not root.sim.race.is_racing():
		await physics_frame

	var drawn_at_start: int = Engine.get_frames_drawn()
	var wall_start: int = Time.get_ticks_msec()
	var race_start: int = root.sim.ticks
	var phase_index := 0
	var phase_start: int = race_start
	while root.sim.ticks - race_start < RACE_TICKS:
		var phase: Array = LapSuite.LAP_PHASES[phase_index % LapSuite.LAP_PHASES.size()]
		if root.sim.ticks >= phase_start + int(phase[3]):
			phase_start += int(phase[3])
			phase_index += 1
			phase = LapSuite.LAP_PHASES[phase_index % LapSuite.LAP_PHASES.size()]
		var held := PackedStringArray()
		var idle := PackedStringArray()
		for action_index in range(PHASE_ACTIONS.size()):
			if phase[action_index]:
				held.append(PHASE_ACTIONS[action_index])
			else:
				idle.append(PHASE_ACTIONS[action_index])
		# Release what the phase does NOT hold — a steer left over from the
		# previous phase would otherwise stay down for the rest of the run.
		Common.release(idle)
		Common.press(held)
		await physics_frame
	Common.release(PackedStringArray(PHASE_ACTIONS))

	# The drawn-frame count is the proof the pass really rendered at its cap:
	# ~1800 at 30 fps, ~3600 at 60, ~8600 at 144, over the same 60 s of race.
	var result := {
		"x": root.sim.pos_x,
		"z": root.sim.pos_z,
		"lap": root.sim.lap.best_seconds,
		"frames": Engine.get_frames_drawn() - drawn_at_start,
		"wall_s": (Time.get_ticks_msec() - wall_start) / 1000.0,
	}
	get_root().remove_child(root)
	root.free()
	await process_frame
	return result
