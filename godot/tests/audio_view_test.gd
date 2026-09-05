# The audio view — every parameter it sets, asserted with no sound card.
#
#   godot --headless -s tests/audio_view_test.gd
#
# THE SPEEDO-NEEDLE DISCIPLINE, applied to sound. tests/hud_test.gd does not
# photograph the dial; it asserts that the needle's angle is the function of the
# core's ratio that §7 states. The same is possible here and for the same reason:
# scripts/view/audio_view.gd decides nothing. Its pitch is a stated curve on the
# speed ratio, its volumes are the Audio table's own values carried by the cue
# records, its spatial split is the record's `spatial` flag, and its mute is a
# multiplier with two values. All of that is arithmetic and node properties.
#
# WHAT THIS SUITE CANNOT DO, said plainly rather than left to be discovered: it
# cannot hear. Godot's audio server exists under --headless but the driver is a
# dummy that mixes nothing, so no assertion below proves a speaker moved, that
# the impact sounds like an impact, or that the rebound is distinguishable from
# it by ear. That is the owner's listen test and it closes M10. What is proven
# here is that every value handed to the mixer is the one the design document
# names — which is the half a listener cannot check.
#
# THE GENERATOR IS CHECKED HERE TOO. tools/synth_cues.py renders the committed
# WAVs; this suite runs it twice into scratch directories and byte-compares, then
# asserts the committed set is that same output. Same shape as
# tests/circuit_content_test.gd's fixed-point check on the shipped circuit: an
# asset nobody can regenerate is a blob with a story attached.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const MainScene := preload("res://scenes/main.tscn")
const AudioView := preload("res://scripts/view/audio_view.gd")
const AudioCues := preload("res://scripts/core/audio_cues.gd")
const ArtTuning := preload("res://scripts/art_tuning.gd")
const Sim := preload("res://scripts/core/sim.gd")
const InputState := preload("res://scripts/core/input_state.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")
const Collision := preload("res://scripts/core/collision.gd")
const Normalise := preload("res://scripts/core/normalise.gd")
const Circuit := preload("res://scripts/core/circuit.gd")

## The Audio table's own numbers, restated as LITERALS on purpose: this file is
## the place a reviewer reads the document's curve endpoints against what the
## view produces, and a test that recomputed them from tuning.json would pass
## against any table at all. (tests/ is outside check_tuning_literals' scope for
## exactly this reason.)
const PITCH_AT_REST := 0.8
const PITCH_AT_FULL := 1.5
const VOLUME_AT_REST := 0.25
const VOLUME_AT_FULL := 0.6
const MAX_DISTANCE_WU := 120.0
const REBOUND_VOLUME := 0.4
const COUNTDOWN_TICK_VOLUME := 0.8
const COUNTDOWN_GO_VOLUME := 1.0

## The nine files tools/synth_cues.py renders — the eight cue ids plus the loop.
const CUE_FILES: Array[String] = [
	"countdown_go",
	"countdown_tick",
	"engine_loop",
	"gate_passed",
	"impact",
	"lap_banked",
	"medal",
	"new_best",
	"rebound",
]

## The recorded sample rate and format the generator writes.
const MIX_RATE := 22050

## The kart's authored box and target height, as conformance_test states them —
## what stage 7 recomputes the hit volume from.
const KART_BOX := AABB(Vector3(-1.1, 0.0, -1.18), Vector3(2.2, 1.2, 2.36))
const KART_HEIGHT := 1.2

const EPSILON := 1e-6

var _art: RefCounted = null
var _view: Node3D = null
var _root: Node3D = null


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_art = ArtTuning.load_art()
	await process_frame
	_view = AudioView.new()
	_view.name = "AudioUnderTest"
	get_root().add_child(_view)
	_view.configure(_art)
	await process_frame

	_test_the_committed_cue_set_is_the_generator_s_output()
	_test_every_cue_id_resolves_to_a_stream()
	_test_the_engine_curves_are_the_audio_table_s()
	_test_the_spatial_contract_is_configured()
	_test_the_engine_note_is_silent_until_racing()
	_test_the_engine_note_tracks_the_ratio_every_tick()
	_test_spatial_cues_play_from_their_world_position()
	_test_race_moments_are_not_spatial()
	_test_a_full_speed_impact_sounds_at_full_scale()
	_test_a_tick_is_drained_once()
	_test_mute_gates_output_and_nothing_else()
	await _test_the_running_game_is_wired_to_the_view()

	get_root().remove_child(_view)
	_view.free()
	RVTest.finish(
		self,
		"audio view: curves, routing, attenuation, mute — all from state",
		"audio view check(s)"
	)


# --- helpers ------------------------------------------------------------------


## A simulation already racing, with the shipped tuning table.
func _racing() -> RefCounted:
	var s := Sim.new()
	s.tuning = TuningLoader.load_tuning()
	s.input = InputState.new()
	s.race.start_racing_immediately()
	return s


## A simulation at the start of the real countdown, LOADING behind it.
func _booting() -> RefCounted:
	var s := Sim.new()
	s.tuning = TuningLoader.load_tuning()
	s.input = InputState.new()
	s.race.mark_world_ready()
	return s


## A cube prop, through the same normalisation the running game uses.
func _cube_prop(x: float, z: float, size: float) -> RefCounted:
	var authored := AABB(Vector3(-size / 2.0, 0.0, -size / 2.0), Vector3(size, size, size))
	var normalised: RefCounted = Normalise.to_target_height(authored, size)
	return Collision.make_prop("crate", normalised, 0.0, x, z)


## A fresh view bound to nothing, so a test can assert its untouched state.
func _fresh_view() -> Node3D:
	var view: Node3D = AudioView.new()
	get_root().add_child(view)
	view.configure(_art)
	return view


## The spatial voice that played most recently, or null.
func _last_spatial_played() -> AudioStreamPlayer3D:
	var newest: AudioStreamPlayer3D = null
	for player: AudioStreamPlayer3D in _view.spatial_voices():
		if player.stream != null:
			newest = player
	return newest


func _globalize(path: String) -> String:
	return ProjectSettings.globalize_path(path)


# --- the generator ------------------------------------------------------------


## Two renders into two scratch directories are byte-identical, and the committed
## set is that same output. The FIRST half is the determinism claim the delta
## spec makes; the second is what makes the committed WAVs regenerable rather
## than merely present.
func _test_the_committed_cue_set_is_the_generator_s_output() -> void:
	var python: String = _globalize("res://../godot/.venv/bin/python")
	var tool_path: String = _globalize("res://tools/synth_cues.py")
	var first: String = _globalize("user://synth_cues_a")
	var second: String = _globalize("user://synth_cues_b")
	var output: Array = []
	var ran_a: int = OS.execute(python, ["-B", tool_path, "--out", first], output, true)
	var ran_b: int = OS.execute(python, ["-B", tool_path, "--out", second], output, true)
	_check(
		ran_a == 0 and ran_b == 0,
		"tools/synth_cues.py runs twice (exit %d, %d): %s" % [ran_a, ran_b, "\n".join(output)]
	)
	var drifted := PackedStringArray()
	for name: String in CUE_FILES:
		var a := FileAccess.get_file_as_bytes("%s/%s.wav" % [first, name])
		var b := FileAccess.get_file_as_bytes("%s/%s.wav" % [second, name])
		if a.size() == 0 or a != b:
			drifted.append(name)
	_check(
		drifted.is_empty(),
		"and two runs are byte-identical across all 9 cues (drifted: %s)" % str(drifted)
	)

	var checked: Array = []
	var verdict: int = OS.execute(python, ["-B", tool_path, "--check"], checked, true)
	_check(
		verdict == 0,
		"and the COMMITTED set is that tool's output, byte for byte: %s" % "\n".join(checked)
	)


## Every id the core can emit resolves to a committed stream, and the engine loop
## is imported as a forward loop over its whole length. The loop half is an
## IMPORT setting, so it can be silently lost by a re-import — which is exactly
## why it is asserted here rather than trusted.
func _test_every_cue_id_resolves_to_a_stream() -> void:
	var ids: Array[String] = [
		AudioCues.COUNTDOWN_TICK,
		AudioCues.COUNTDOWN_GO,
		AudioCues.REBOUND,
		AudioCues.IMPACT,
		AudioCues.GATE_PASSED,
		AudioCues.LAP_BANKED,
		AudioCues.NEW_BEST,
		AudioCues.MEDAL,
	]
	var missing := PackedStringArray()
	for id: String in ids:
		var stream: AudioStreamWAV = load("res://assets/audio/%s.wav" % id)
		if stream == null or stream.mix_rate != MIX_RATE or stream.stereo:
			missing.append(id)
	_check(
		missing.is_empty(),
		"all 8 cue ids resolve to a committed %d Hz mono stream (missing: %s)" % [MIX_RATE, missing]
	)
	var loop: AudioStreamWAV = load("res://assets/audio/engine_loop.wav")
	_check(
		(
			loop != null
			and loop.loop_mode == AudioStreamWAV.LOOP_FORWARD
			and loop.loop_begin == 0
			and loop.loop_end == int(loop.get_length() * MIX_RATE) - 1
		),
		(
			(
				"the engine loop is imported as a forward loop over its whole length "
				+ "(mode %d, %d..%d) — if this fails, delete .godot/imported/engine_loop.wav-* "
				+ "and re-import"
			)
			% [loop.loop_mode, loop.loop_begin, loop.loop_end]
		)
	)


# --- the curves ---------------------------------------------------------------


## `enginePitchBase + enginePitchSpan x ratio` and `engineVolumeBase +
## engineVolumeSpan x ratio`, at both endpoints and in between. The CURVE, not
## one sampled property: a view that set the right pitch once and never again
## would pass a single-point assertion.
func _test_the_engine_curves_are_the_audio_table_s() -> void:
	RVTest.close(AudioView.engine_pitch(_art, 0.0), PITCH_AT_REST, EPSILON, "pitch at rest")
	RVTest.close(AudioView.engine_pitch(_art, 1.0), PITCH_AT_FULL, EPSILON, "pitch at full ratio")
	RVTest.close(AudioView.engine_volume(_art, 0.0), VOLUME_AT_REST, EPSILON, "volume at rest")
	RVTest.close(
		AudioView.engine_volume(_art, 1.0), VOLUME_AT_FULL, EPSILON, "volume at full ratio"
	)
	# Linear between the endpoints, sampled at five ratios. The document states
	# the curve as an affine function of the ratio and this is that claim.
	var bent := PackedStringArray()
	for step in range(5):
		var ratio: float = float(step) / 4.0
		var pitch: float = AudioView.engine_pitch(_art, ratio)
		var volume: float = AudioView.engine_volume(_art, ratio)
		if (
			absf(pitch - (PITCH_AT_REST + (PITCH_AT_FULL - PITCH_AT_REST) * ratio)) > EPSILON
			or absf(volume - (VOLUME_AT_REST + (VOLUME_AT_FULL - VOLUME_AT_REST) * ratio)) > EPSILON
		):
			bent.append("%.2f" % ratio)
	_check(bent.is_empty(), "both curves are affine in the ratio (bent at: %s)" % str(bent))
	# The decibel conversion, asserted separately so a mistake in it cannot hide
	# inside a linear volume that is right.
	RVTest.close(AudioView.gain_db(1.0), 0.0, EPSILON, "a linear gain of 1 is 0 dB")
	RVTest.close(AudioView.gain_db(0.5), -6.0206, 0.001, "a linear gain of 0.5 is -6.02 dB")
	_check(
		AudioView.gain_db(0.0) == AudioView.SILENCE_DB,
		"and zero gain is the named silence floor, never -inf (%f)" % AudioView.gain_db(0.0)
	)


# @covers Audio Feedback / Space is audible
## Attenuation reaching silence by `audioMaxDistance`, on the engine note and on
## every spatial voice. The CONFIGURATION is what is asserted: the interior curve
## belongs to Godot's mixer, but the bound the document makes normative is
## `max_distance`, which is Godot's own name for "no longer audible".
func _test_the_spatial_contract_is_configured() -> void:
	var wrong := PackedStringArray()
	var players: Array = [_view.engine_player()]
	players.append_array(_view.spatial_voices())
	for player: AudioStreamPlayer3D in players:
		if (
			absf(player.max_distance - MAX_DISTANCE_WU) > EPSILON
			or player.attenuation_model != AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		):
			wrong.append(player.name)
	_check(
		wrong.is_empty(),
		(
			"the engine note and all %d spatial voices attenuate to silence by %.0f wu (wrong: %s)"
			% [_view.spatial_voices().size(), MAX_DISTANCE_WU, str(wrong)]
		)
	)
	# And the race moments are NOT spatial — a different node type, not a 3D
	# player parked at the origin.
	var flat_ok := true
	for player: AudioStreamPlayer in _view.flat_voices():
		if player.get_class() != "AudioStreamPlayer":
			flat_ok = false
	_check(
		flat_ok and _view.flat_voices().size() == AudioView.VOICES,
		"and the race-moment voices are non-spatial players"
	)


# --- the engine note ----------------------------------------------------------


## Silent while LOADING and through the countdown — the note does not start
## before the handover. SILENCE IS "STOPPED", chosen over "attenuated to zero"
## because a stopped source cannot be heard through a mixer bug either.
func _test_the_engine_note_is_silent_until_racing() -> void:
	var view: Node3D = _fresh_view()
	var s := _booting()
	_check(
		not view.engine_player().playing and view.engine_player().volume_db == AudioView.SILENCE_DB,
		"the engine note is stopped and silent at boot"
	)
	var started_early := false
	for _i in range(239):  # every tick of LOADING and the countdown, short of GO
		s.step()
		view.draw_from(s)
		if view.engine_player().playing:
			started_early = true
	_check(
		not started_early and not s.race.is_racing(),
		"and stays stopped through all of LOADING and the countdown"
	)
	s.step()  # the GO tick — the handover
	view.draw_from(s)
	_check(
		s.race.is_racing() and view.engine_player().playing, "and starts on the GO tick, not before"
	)
	RVTest.close(
		view.engine_player().pitch_scale,
		PITCH_AT_REST,
		EPSILON,
		"and starts at the resting pitch (ratio 0)"
	)
	get_root().remove_child(view)
	view.free()


# @covers Audio Feedback / The engine note follows the speed ratio
## Pitch and volume follow the ratio on the SIMULATION clock, tick after tick,
## through acceleration and back down through the coast. "Fades with the ratio
## rather than cutting" is the coast half: the note is never stopped again once
## it starts, and the volume falls because the curve falls.
func _test_the_engine_note_tracks_the_ratio_every_tick() -> void:
	var view: Node3D = _fresh_view()
	var s := _racing()
	var drifted := 0
	var stopped := 0
	var peak_ratio := 0.0
	for tick in range(1200):
		s.input.forward = tick < 600  # accelerate, then coast
		s.step()
		view.draw_from(s)
		peak_ratio = maxf(peak_ratio, s.speed_ratio())
		if (
			absf(view.engine_player().pitch_scale - AudioView.engine_pitch(_art, s.speed_ratio()))
			> EPSILON
		):
			drifted += 1
		var want_db: float = AudioView.gain_db(AudioView.engine_volume(_art, s.speed_ratio()))
		if absf(view.engine_player().volume_db - want_db) > EPSILON:
			drifted += 1
		if not view.engine_player().playing:
			stopped += 1
	_check(
		drifted == 0 and peak_ratio > 0.9,
		(
			"the note's pitch and volume equal the curves at every one of 1200 ticks "
			+ "(%d divergences, peak ratio %.3f)" % [drifted, peak_ratio]
		)
	)
	_check(stopped == 0, "and it fades with the ratio rather than cutting (%d stops)" % stopped)
	# The kart is where the note comes from.
	_check(
		view.engine_player().position.is_equal_approx(Vector3(s.pos_x, 0.0, s.pos_z)),
		(
			"and it is positioned on the kart (%s vs %.3f, %.3f)"
			% [view.engine_player().position, s.pos_x, s.pos_z]
		)
	)
	get_root().remove_child(view)
	view.free()


# --- routing ------------------------------------------------------------------


## A boundary rebound is heard from where the kart met the fence, at the Audio
## table's `reboundVolume`, on a 3D player.
func _test_spatial_cues_play_from_their_world_position() -> void:
	var s := _racing()
	s.pos_z = s.tuning.drivable_extent - 0.01
	s.input.forward = true
	var bounced := false
	for _i in range(200):
		s.step()
		if s.bounced_this_tick:
			bounced = true
			break
	_check(bounced, "the kart reaches the fence and rebounds")
	_view.draw_from(s)
	var player: AudioStreamPlayer3D = _last_spatial_played()
	_check(
		player != null and player.stream == load("res://assets/audio/rebound.wav"),
		"the rebound plays the rebound stream on a 3D voice"
	)
	_check(
		player.position.is_equal_approx(Vector3(s.pos_x, 0.0, s.pos_z)),
		"from the kart's own position at the fence (%s)" % player.position
	)
	RVTest.close(
		player.volume_db,
		AudioView.gain_db(REBOUND_VOLUME),
		EPSILON,
		"at reboundVolume, converted once"
	)


## The countdown's three steps and GO! are heard from nowhere — a non-spatial
## player, at the table's own volumes.
func _test_race_moments_are_not_spatial() -> void:
	var view: Node3D = _fresh_view()
	var s := _booting()
	var tick_db: Array[float] = []
	var go_db: float = 0.0
	for _i in range(241):
		s.step()
		var before: int = view.cues_played()
		view.draw_from(s)
		if view.cues_played() == before:
			continue
		var played: AudioStreamPlayer = null
		for candidate: AudioStreamPlayer in view.flat_voices():
			if candidate.stream != null:
				played = candidate
		if played == null:
			continue
		if played.stream == load("res://assets/audio/countdown_tick.wav"):
			tick_db.append(played.volume_db)
		elif played.stream == load("res://assets/audio/countdown_go.wav"):
			go_db = played.volume_db
	_check(tick_db.size() == 3, "three countdown ticks sound, one per step (%d)" % tick_db.size())
	var wrong := 0
	for db: float in tick_db:
		if absf(db - AudioView.gain_db(COUNTDOWN_TICK_VOLUME)) > EPSILON:
			wrong += 1
	_check(wrong == 0, "each at countdownTickVolume (%d wrong)" % wrong)
	RVTest.close(
		go_db, AudioView.gain_db(COUNTDOWN_GO_VOLUME), EPSILON, "and GO! at its own volume"
	)
	# Nothing spatial sounded: the race's moments are heard from nowhere.
	var spatial_used := false
	for candidate: AudioStreamPlayer3D in view.spatial_voices():
		if candidate.stream != null:
			spatial_used = true
	_check(not spatial_used, "and no 3D voice was used for any of them")
	get_root().remove_child(view)
	view.free()


## "A top-speed hit is full scale." The core emits volume 1.0; the view must hand
## the mixer 0 dB — full scale, unattenuated by anything of its own.
func _test_a_full_speed_impact_sounds_at_full_scale() -> void:
	var view: Node3D = _fresh_view()
	var s := _racing()
	s.kart_normalised = Normalise.to_target_height(KART_BOX, KART_HEIGHT)
	s.props = [_cube_prop(0.0, 1.5, 2.0)]
	# Coasting at the clamp: friction brings stage 7 exactly the steady top
	# speed, which the Audio table names as `impactFullScale`. Same construction
	# tests/audio_cue_test.gd's `_hit_at` uses, for the same reason.
	s.velocity = s.tuning.max_speed
	s.step()
	view.draw_from(s)
	_check(s.last_hit != null, "a kart at the steady top speed reaches the prop")
	var player: AudioStreamPlayer3D = null
	for candidate: AudioStreamPlayer3D in view.spatial_voices():
		if candidate.stream == load("res://assets/audio/impact.wav"):
			player = candidate
	_check(player != null, "and the impact plays the impact stream, spatially")
	if player != null:
		RVTest.close(
			player.volume_db, 0.0, EPSILON, "at FULL SCALE — 0 dB, the literal item 16 asks for"
		)
	get_root().remove_child(view)
	view.free()


## A second call inside one tick is a no-op. Without the guard a 144 fps frame
## would play the tick's cues twice, which is the reason this view is driven from
## the physics callback at all.
##
## STOPPED ON A TICK THAT HAS CUES, deliberately: a first draft ran the whole
## countdown and then re-drained the LAST tick, which is silent — so removing the
## guard changed nothing and the case passed while proving nothing. Found by
## mutation, which is the only thing that would have found it.
func _test_a_tick_is_drained_once() -> void:
	var view: Node3D = _fresh_view()
	var s := _booting()
	var loud_tick := false
	for _i in range(241):
		s.step()
		if not s.cues.cues.is_empty():
			loud_tick = true
			break
	_check(loud_tick, "a countdown tick emits a cue")
	view.draw_from(s)
	var after_one_pass: int = view.cues_played()
	for _i in range(5):
		view.draw_from(s)
	_check(
		after_one_pass == s.cues.cues.size() and view.cues_played() == after_one_pass,
		(
			"the tick's %d cue(s) played once, and five more drains of the same tick play nothing (%d)"
			% [s.cues.cues.size(), view.cues_played()]
		)
	)
	get_root().remove_child(view)
	view.free()


# --- mute ---------------------------------------------------------------------


# @covers Audio Feedback / Mute
## The document's own division: output toggles, the simulation does not notice.
##
## THE PROOF THAT NOTHING LEAKS is a byte-comparison of the whole determinism
## summary across a muted and an unmuted replay of the same drive, plus the
## view's own count of records drained. If mute reached the simulation — or even
## made the view skip a record — one of those two moves.
func _test_mute_gates_output_and_nothing_else() -> void:
	var loud: Node3D = _fresh_view()
	var quiet: Node3D = _fresh_view()
	_check(not loud.is_muted(), "a fresh boot is unmuted — the document says always")
	_check(quiet.toggle_mute(), "and M mutes")

	var loud_sim := _racing()
	var quiet_sim := _racing()
	var summaries_agree := true
	for tick in range(600):
		for pair: Array in [[loud_sim, loud], [quiet_sim, quiet]]:
			var s: RefCounted = pair[0]
			s.input.forward = true
			s.input.left = tick > 200
			s.step()
			(pair[1] as Node3D).draw_from(s)
		if loud_sim.stats_line() != quiet_sim.stats_line():
			summaries_agree = false
	_check(
		summaries_agree, "the determinism summary is byte-identical muted and unmuted, every tick"
	)
	_check(
		loud.cues_played() == quiet.cues_played() and loud.cues_played() > 0,
		"and the view keeps score either way (%d vs %d)" % [loud.cues_played(), quiet.cues_played()]
	)
	_check(
		quiet.output_gain() == 0.0 and loud.output_gain() == 1.0,
		"muted output gain is zero and unmuted is masterVolume"
	)
	_check(
		(
			quiet.engine_player().volume_db == AudioView.SILENCE_DB
			and loud.engine_player().volume_db > AudioView.SILENCE_DB
		),
		"the engine note is silenced, not stopped"
	)
	# A cue already in flight is re-levelled by the toggle, rather than being
	# allowed to finish at its old volume — "all audio output toggles off". Driven
	# into the fence first, because the circling drive above never reaches one and
	# a spatial voice that never sounded would make this case pass vacuously.
	loud_sim.pos_z = loud_sim.tuning.drivable_extent - 0.01
	for _i in range(200):
		loud_sim.step()
		loud.draw_from(loud_sim)
		if loud_sim.bounced_this_tick:
			break
	var ringing := false
	for player: AudioStreamPlayer3D in loud.spatial_voices():
		if player.stream != null and player.volume_db > AudioView.SILENCE_DB:
			ringing = true
	loud.toggle_mute()
	var still_loud := false
	for player: AudioStreamPlayer3D in loud.spatial_voices():
		if player.stream != null and player.volume_db > AudioView.SILENCE_DB:
			still_loud = true
	_check(ringing and not still_loud, "muting silences the voices already in flight")
	_check(not loud.toggle_mute() and loud.output_gain() == 1.0, "and a second M restores output")
	for view: Node3D in [loud, quiet]:
		get_root().remove_child(view)
		view.free()


# --- the running game ---------------------------------------------------------


## The wiring, against the real scene: the node exists, it is configured, the
## root drains it on the SIMULATION clock, and the hint line advertises the key.
func _test_the_running_game_is_wired_to_the_view() -> void:
	_root = MainScene.instantiate() as Node3D
	get_root().add_child(_root)
	for _i in range(3):
		await process_frame
	_check(_root.audio != null, "main.tscn carries the audio view")
	_check(
		(
			_root.audio.engine_player() != null
			and _root.audio.spatial_voices().size() == AudioView.VOICES
		),
		"and the composition root configured it"
	)
	_check(not _root.audio.is_muted(), "the running game boots unmuted")
	var played_before: int = _root.audio.cues_played()
	var ticks_before: int = _root.sim.ticks
	for _i in range(120):
		await physics_frame
	_check(
		_root.sim.ticks > ticks_before and _root.audio.cues_played() >= played_before,
		"and the root drains it as the simulation advances"
	)
	var hints: Label = _root.overlay.get_node("Hints") as Label
	_check(
		hints.text == "W/S drive · A/D steer · G restart · M mute · follow the gates",
		"the hint line advertises M mute, at the document's own wording (%s)" % hints.text
	)
	get_root().remove_child(_root)
	_root.free()
