# The game's voice — the design document's Audio Feedback, made audible.
#
# A PURE CONSUMER, exactly like the speedometer needle and the gate furniture.
# scripts/core/audio_cues.gd publishes an ordered per-tick list of records; this
# node drains that list and plays it. It decides nothing: not when a cue happens,
# not how loud it is (the record carries the Audio table's own volume), not where
# it is (the record carries the position). What it owns is players, streams, and
# the curves the Audio table states for the engine note.
#
# EVERY PARAMETER IS A FUNCTION OF CORE STATE AND THE DATA LAYER, and that is
# what makes a silent machine able to check it. `engine_pitch()` and
# `engine_volume()` are static, take the ratio, and return a number; the mute
# gate is a multiplier with two values; the spatial split comes from the record's
# own `spatial` flag. tests/audio_view_test.gd asserts all of it with no sound
# card in the room — the speedo-needle discipline, applied to sound.
#
# THE HEADLESS CAVEAT, stated rather than implied: an audio server exists under
# `--headless`, but it is a dummy that mixes nothing. Nothing in the suite proves
# a speaker moved. What the suite proves is that the node properties and the
# mapping functions are right, which is the whole of what a test can own here.
# The remaining half — whether it SOUNDS like what the document describes — is
# the owner's listen test, and no gate in this repository replaces it.
#
# ON THE SIMULATION CLOCK, ONCE PER TICK. The composition root calls draw_from()
# from _physics_process, immediately after Sim.step(), and NOT from the per-frame
# callback every other view uses. That is deliberate and it is the only correct
# reading: `sim.cues` holds ONE tick's records and is cleared at the top of the
# next step, so a per-frame drain plays a tick's cues twice at 144 fps and drops
# every other tick's entirely at 30 fps — including a countdown beep. The
# document's own words for the engine curves are "on the simulation clock", and
# the cue list is the same clock. The tick guard below makes a second call in one
# tick a no-op rather than a double play.
#
# WHAT IS NOT HERE: any decision about which events sound. Adding one would put a
# game rule in the view, which CONSTRAINTS §4 Architectural boundaries forbids
# and which would give the cue stream a second, silent definition.
extends Node3D

const AudioCues := preload("res://scripts/core/audio_cues.gd")

## Where the generated cue set lives. Rendered by tools/synth_cues.py and
## committed; the id in the path is the cue id the core emits, so a stream is
## resolved by the record itself and there is no table here to drift.
const STREAM_PATH := "res://assets/audio/%s.wav"

## The looping engine note. NOT a cue id — the engine note is a continuous curve
## on the speed ratio, which is why audio_cues.gd deliberately does not publish
## it as a record.
const ENGINE_STREAM := "engine_loop"

## How many one-shots may overlap, per family. A lap bank can emit `lap_banked`,
## `new_best` and `medal` on ONE tick, and a rebound can land on the same tick as
## a gate pass, so a single player per family would cut the previous cue off
## mid-note. Eight is comfortably above the largest tick the document allows
## (three race moments; two spatial) and costs nine idle nodes.
const VOICES := 8

## What a gain of zero is written as. Godot's `linear_to_db(0.0)` is -inf, which
## is not a value a property should carry; -80 dB is one ten-thousandth of full
## scale and is the floor Godot's own volume controls use.
const SILENCE_DB := -80.0

var _art: RefCounted = null

## Session-only, and false at boot: the document is explicit that a fresh boot is
## always unmuted and that no settings surface exists or is implied.
var _muted: bool = false

var _engine: AudioStreamPlayer3D = null
var _spatial: Array[AudioStreamPlayer3D] = []
var _flat: Array[AudioStreamPlayer] = []
var _next_spatial: int = 0
var _next_flat: int = 0

## The linear gain each voice was last handed, BEFORE the mute multiplier. Kept
## so that pressing M silences a cue already in flight rather than letting it
## finish at its old volume — "all audio output toggles off" is the document's
## word, and a 0.6 s medal chord ringing through the toggle is not off.
var _spatial_gain: Array[float] = []
var _flat_gain: Array[float] = []
var _engine_gain: float = 0.0

## The tick this node last drained. -1 means "never", which is distinct from
## tick 0. The guard is what makes a second call inside one tick a no-op.
var _last_tick: int = -1

## How many records have been played since boot — the view's own score, which
## the document asks for by name: muting stops the speakers, and "the view keeps
## score" regardless. Read by the suite to prove the drain is unaffected.
var _played: int = 0


## The pitch the engine note carries at a speed ratio: `enginePitchBase +
## enginePitchSpan x ratio`, the Audio table verbatim. Static and pure so the
## suite can assert the CURVE rather than one sampled property.
static func engine_pitch(art: RefCounted, ratio: float) -> float:
	return art.num("enginePitchBase") + art.num("enginePitchSpan") * clampf(ratio, 0.0, 1.0)


## The engine note's linear volume at a speed ratio: `engineVolumeBase +
## engineVolumeSpan x ratio`. Linear, because that is the space the document
## states it in; the conversion to Godot's decibels is gain_db()'s job and is
## asserted separately, so a mistake in one cannot hide inside the other.
static func engine_volume(art: RefCounted, ratio: float) -> float:
	return art.num("engineVolumeBase") + art.num("engineVolumeSpan") * clampf(ratio, 0.0, 1.0)


## Linear gain to the decibels a player wants. The one place the conversion
## happens, and the reason SILENCE_DB exists.
static func gain_db(linear: float) -> float:
	return SILENCE_DB if linear <= 0.0 else linear_to_db(linear)


## Build the players and load the streams. Called once by the composition root,
## after the art table is available — the same seam gate_view and minimap use.
func configure(art: RefCounted) -> void:
	_art = art
	_engine = AudioStreamPlayer3D.new()
	_engine.name = "EngineNote"
	_engine.stream = _stream(ENGINE_STREAM)
	_configure_spatial(_engine)
	_engine.volume_db = SILENCE_DB
	add_child(_engine)
	for index in range(VOICES):
		var spatial := AudioStreamPlayer3D.new()
		spatial.name = "SpatialVoice%d" % index
		_configure_spatial(spatial)
		add_child(spatial)
		_spatial.append(spatial)
		_spatial_gain.append(0.0)
		var flat := AudioStreamPlayer.new()
		flat.name = "Voice%d" % index
		add_child(flat)
		_flat.append(flat)
		_flat_gain.append(0.0)


## Once per simulation tick, from the composition root, after Sim.step().
##
## Two jobs, in the document's own order: the engine note's curves, then this
## tick's cue list. The tick guard makes a repeat call inside one tick a no-op.
func draw_from(sim: RefCounted) -> void:
	if _art == null or sim == null or sim.ticks == _last_tick:
		return
	_last_tick = sim.ticks
	_drive_engine(sim)
	for cue: RefCounted in sim.cues.cues:
		_play(cue)


## Mute (M), edge-triggered by the composition root. Returns the new state.
##
## OUTPUT ONLY. Nothing here touches the simulation: the cue stream keeps
## flowing, `sim.stats_line()` is untouched, and this node keeps draining and
## counting. The already-playing voices are re-levelled so the toggle is
## immediate rather than "from the next cue onward".
func toggle_mute() -> bool:
	_muted = not _muted
	_apply_output_gain()
	return _muted


func is_muted() -> bool:
	return _muted


## The mute multiplier: `masterVolume` or zero, which is exactly how the Audio
## table describes it ("The mute toggle multiplies output by 0 or this").
func output_gain() -> float:
	return 0.0 if _muted else _art.num("masterVolume")


## Records played since boot. Counted whether or not anything was audible.
func cues_played() -> int:
	return _played


func engine_player() -> AudioStreamPlayer3D:
	return _engine


## The voices, for the suite. Spatial and non-spatial are separate pools because
## they are separate node types — a 3D player positioned at the origin is not the
## same thing as a non-spatial one, and the document splits the cues.
func spatial_voices() -> Array[AudioStreamPlayer3D]:
	return _spatial


func flat_voices() -> Array[AudioStreamPlayer]:
	return _flat


## The pitch and volume the engine note carries this tick, and whether it sounds
## at all. SILENT UNTIL RACING — the note does not start during LOADING or the
## countdown, which is the document's "silent while LOADING and through the
## countdown" — and from the handover onward it FADES WITH THE RATIO rather than
## being cut: it is never stopped again, and coasting takes it down to
## `engineVolumeBase` on the curve alone.
func _drive_engine(sim: RefCounted) -> void:
	if not sim.race.is_racing():
		return
	if not _engine.playing:
		_engine.play()
	_engine.position = Vector3(sim.pos_x, 0.0, sim.pos_z)
	_engine.pitch_scale = engine_pitch(_art, sim.speed_ratio())
	_engine_gain = engine_volume(_art, sim.speed_ratio())
	_engine.volume_db = gain_db(_engine_gain * output_gain())


## One record onto one player. The record decides everything: which pool by its
## `spatial` flag, where by its x/z, how loud by its volume. The view multiplies
## in the mute gate and nothing else.
func _play(cue: RefCounted) -> void:
	_played += 1
	var stream: AudioStream = _stream(cue.id)
	if stream == null:
		return
	if cue.spatial:
		var index: int = _next_spatial
		_next_spatial = (_next_spatial + 1) % VOICES
		var player: AudioStreamPlayer3D = _spatial[index]
		player.stream = stream
		player.position = Vector3(cue.x, 0.0, cue.z)
		_spatial_gain[index] = cue.volume
		player.volume_db = gain_db(cue.volume * output_gain())
		player.play()
		return
	var flat_index: int = _next_flat
	_next_flat = (_next_flat + 1) % VOICES
	var flat: AudioStreamPlayer = _flat[flat_index]
	flat.stream = stream
	_flat_gain[flat_index] = cue.volume
	flat.volume_db = gain_db(cue.volume * output_gain())
	flat.play()


## Re-level every voice from its stored gain. Called when the mute state moves.
func _apply_output_gain() -> void:
	var gate: float = output_gain()
	for index in range(VOICES):
		_spatial[index].volume_db = gain_db(_spatial_gain[index] * gate)
		_flat[index].volume_db = gain_db(_flat_gain[index] * gate)
	if _engine != null:
		_engine.volume_db = gain_db(_engine_gain * gate)


## The spatial contract, applied identically to the engine note and every spatial
## voice: heard from a world position, with distance attenuation reaching silence
## by `audioMaxDistance`.
##
## THE BOUND IS THE PART THE DOCUMENT MAKES NORMATIVE, and `max_distance` is
## Godot's own name for it — the distance past which the source is not heard at
## all. The interior curve is the engine's inverse-square rolloff at the default
## unit size, which over the 100 wu playfield puts a cue at the far fence some
## 40 dB down before the bound cuts it; that shape is the engine's, not this
## file's, and the suite asserts the CONFIGURATION rather than pretending to
## re-derive Godot's mixer.
func _configure_spatial(player: AudioStreamPlayer3D) -> void:
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	player.max_distance = _art.num("audioMaxDistance")


## A stream by cue id. Null — with a named error — rather than a crash, because a
## missing WAV must not take the game down; the suite asserts every id resolves.
func _stream(id: String) -> AudioStream:
	var path: String = STREAM_PATH % id
	if not ResourceLoader.exists(path):
		push_error("audio: no stream for cue %s at %s" % [id, path])
		return null
	return load(path) as AudioStream
