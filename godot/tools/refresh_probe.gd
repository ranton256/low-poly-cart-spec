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
# 3600th racing tick. The drive loop awaits physics_frame, which fires once
# per PHYSICS TICK at every render rate, so the input sequence is identical
# tick-for-tick across the three passes — deliberately (ambiguity A14):
# "replayed" must mean the same tick-timed sequence, because quantising the
# edges to frame boundaries instead diverges a measured 8.83 wu across
# 1/2/4-tick batchings, a bound no port could meet. What the three passes
# therefore prove is the item's substance — the fixed-tick loop is fully
# decoupled from the render rate the drawn-frame counts verify — and the
# tolerance absorbs whatever float or scheduling wiggle real rendering adds
# (measured: none). conformance_test item 14 pins this run's record.
#
# AND THE CUE STREAM, added by add-audio-playback for acceptance item 16: "a
# scripted run's cue stream — ids, order, tick timestamps, and volumes — is
# identical at 30, 60, and 144 frames per second". Two hashes per pass, and
# they answer different questions:
#
#   tick hash    this probe's own FNV-1a fold over sim.cues.line() sampled once
#                per physics tick of the scripted drive. line() renders each
#                record as id@tick:volume(x,z), so the fold covers exactly the
#                four things the checklist names, in emission order.
#   core digest  scripts/core/audio_cues.gd's own running digest over EVERY
#                record emitted since the pass began, countdown included. It
#                needs no sampling and so cannot be defeated by one.
#
# The sampling phase is the same in all three passes (the loop awaits
# physics_frame, which fires once per tick at every render rate), so the tick
# hash is comparable across them; it is not a figure with meaning on its own,
# and neither hash is pinned as a literal anywhere — what conformance item 16
# asserts is that the three passes AGREE.
extends SceneTree

const LapSuite := preload("res://tests/lap_gate_test.gd")
const Common := preload("res://tools/capture_common.gd")
const AudioCues := preload("res://scripts/core/audio_cues.gd")

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
		var result: Dictionary = await _run_at(rate)
		# A pass that drew (almost) no frames measured nothing: an occluded or
		# undrawn window renders the frame-cap meaningless, and one such run was
		# nearly recorded as evidence before the operator caught it. Refuse
		# rather than rely on the reader noticing a zero in the frame column.
		if int(result.frames) < rate * 10:
			printerr(
				(
					(
						"refresh_probe: the %d fps pass drew only %d frames — an occluded "
						+ "or undrawn window is not evidence of a rate. Nothing recorded."
					)
					% [rate, int(result.frames)]
				)
			)
			quit(1)
			return
		results.append(result)

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
	# THE CUE STREAM, item 16's own clause. Compared pass against pass rather than
	# against a pinned literal: the hashes are a function of the drive and the
	# tuning table, both of which move by proposal, and what the checklist asks is
	# that the three RATES agree.
	var cue_stable := true
	for i in range(1, RATES.size()):
		var a: Dictionary = results[0]
		var b: Dictionary = results[i]
		if a.cue_hash != b.cue_hash or a.cue_digest != b.cue_digest or a.cues != b.cues:
			cue_stable = false
	for i in range(RATES.size()):
		var r: Dictionary = results[i]
		print(
			(
				"refresh_probe: %3d fps — cue stream %d records, tick hash 0x%08x, core digest 0x%08x"
				% [RATES[i], int(r.cues), int(r.cue_hash), int(r.cue_digest)]
			)
		)
	print(
		(
			"refresh_probe: the cue stream is identical across 30/60/144 fps %s"
			% ("ok" if cue_stable else "FAIL")
		)
	)
	if not cue_stable:
		failures += 1

	if failures == 0:
		print("refresh_probe: acceptance 14b holds at 30/60/144 fps")
	quit(failures)


## FNV-1a over the text, folded into a running hash. The algorithm and its three
## numbers are scripts/core/audio_cues.gd's — imported rather than restated, so
## the probe and the core cannot disagree about what a digest is.
func _fold(hash_value: int, text: String) -> int:
	var folded: int = hash_value
	for i in range(text.length()):
		folded = (folded ^ text.unicode_at(i)) & AudioCues.DIGEST_MASK
		folded = (folded * AudioCues.DIGEST_PRIME) & AudioCues.DIGEST_MASK
	return folded


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
	var cue_hash: int = AudioCues.DIGEST_SEED
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
		# ONE SAMPLE PER PHYSICS TICK, at every render rate — physics_frame is the
		# tick, not the frame. line() is the tick's records as stable text.
		cue_hash = _fold(cue_hash, root.sim.cues.line())
	Common.release(PackedStringArray(PHASE_ACTIONS))

	# The drawn-frame count is the proof the pass really rendered at its cap:
	# ~1800 at 30 fps, ~3600 at 60, ~8600 at 144, over the same 60 s of race.
	var result := {
		"x": root.sim.pos_x,
		"z": root.sim.pos_z,
		"lap": root.sim.lap.best_seconds,
		"frames": Engine.get_frames_drawn() - drawn_at_start,
		"wall_s": (Time.get_ticks_msec() - wall_start) / 1000.0,
		"cue_hash": cue_hash,
		"cue_digest": root.sim.cues.digest,
		"cues": root.sim.cues.emitted,
	}
	get_root().remove_child(root)
	root.free()
	await process_frame
	return result
