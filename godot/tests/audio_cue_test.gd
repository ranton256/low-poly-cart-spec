# The game's feedback vocabulary — the design document's Audio Feedback, checked
# without a sound card. Adapted from templates/av_cues.template.gd, which has
# waited for this suite since M0.
#
#   godot --headless -s tests/audio_cue_test.gd
#
# The template asks the simulation for exactly one thing: that it PUBLISH its
# one-shot effects as data rather than calling a player. scripts/core/audio_cues.gd
# is that list, so every assertion below is an ordinary state assertion.
#
# THE NEGATIVE ASSERTIONS ARE THE POINT, and the template says why: "a shielded
# hit must NOT play the hull-damage sound" is a design promise no gameplay test
# would notice breaking, because the game still works perfectly — it just stops
# telling the player the truth about what happened. The design document makes
# five such promises normative, and _test_what_must_not_sound() carries all five.
# Each was verified by adding the forbidden emission and watching the right case
# fail; the mutations and their failure lines are recorded in the change.
#
# WHAT THIS SUITE DOES NOT COVER, deliberately: nothing here makes a sound. The
# engine note, the spatial attenuation, mute, and the cross-render-rate half of
# the stream's determinism belong to add-audio-playback, and the scenario
# register still defers them.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const Sim := preload("res://scripts/core/sim.gd")
const InputState := preload("res://scripts/core/input_state.gd")
const AudioCues := preload("res://scripts/core/audio_cues.gd")
const Circuit := preload("res://scripts/core/circuit.gd")
const Collision := preload("res://scripts/core/collision.gd")
const Normalise := preload("res://scripts/core/normalise.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")
const LayoutIO := preload("res://scripts/world/layout_io.gd")
## The baked lap script acceptance item 14 replays, read from the file that IS
## the checklist rather than restated — the determinism case below must replay
## the same drive item 14 does or it is proving something else.
const Conformance := preload("res://tests/conformance_test.gd")

## The kart's authored box and target height, as conformance_test states them.
const KART_BOX := AABB(Vector3(-1.1, 0.0, -1.18), Vector3(2.2, 1.2, 2.36))
const KART_HEIGHT := 1.2

## A tenth of a full-scale hit — the document's "a nudge is a tap".
const NUDGE_FRACTION := 0.1

## One second of held input, in ticks: what the pin is asked to survive.
const HELD_SECOND := 60

## Long enough to reach the steady top speed to the last bit: 0.96^900 is 1e-16.
const SPIN_UP_TICKS := 900

## The pinned pair's footprints, `minPropSeparation` apart with a 0.09 wu gap —
## collision_test.gd's own arrangement, which is smaller than the contracted
## hitbox and therefore pins.
const PIN_GAP := 0.09

const REPLAY_TICKS := 3600


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_test_the_simulation_publishes_cues_as_data()
	_test_the_race_speaks_at_its_moments()
	_test_an_impact_is_heard_once_as_hard_as_it_hit()
	_test_what_must_not_sound()
	_test_the_cue_stream_replays_byte_identically()
	RVTest.finish(
		self, "audio cues: emissions, silences, and a byte-stable stream", "audio cue check(s)"
	)


# --- construction helpers -----------------------------------------------------


## The SHIPPED tuning table, not inline literals: the volumes under test are the
## Audio table's own, referred to by name, and a retune must reach this suite.
func _tuning() -> RefCounted:
	return TuningLoader.load_tuning()


## A simulation already racing — the kart-pipeline seam every stage suite uses.
func _racing() -> RefCounted:
	var s := Sim.new()
	s.tuning = _tuning()
	s.input = InputState.new()
	s.race.start_racing_immediately()
	return s


## A simulation at the start of the real countdown, LOADING behind it.
func _booting() -> RefCounted:
	var s := Sim.new()
	s.tuning = _tuning()
	s.input = InputState.new()
	s.race.mark_world_ready()
	return s


## A cube prop of plan size `size` centred on (x, z), through the same
## normalisation and the same Collision.make_prop() the running game uses.
func _cube_prop(asset: String, x: float, z: float, size: float) -> RefCounted:
	var authored := AABB(Vector3(-size / 2.0, 0.0, -size / 2.0), Vector3(size, size, size))
	var normalised: RefCounted = Normalise.to_target_height(authored, size)
	return Collision.make_prop(asset, normalised, 0.0, x, z)


## A one-gate circuit on the way to the band, with whatever medal targets are
## asked for.
func _course(targets: Dictionary) -> RefCounted:
	var course := Circuit.new()
	course.circuit_name = "audio"
	course.add_gate(0.0, -2.0, 0.0, 10.0)
	course.targets = targets
	return course


# --- reading the list ---------------------------------------------------------


func _ids(s: RefCounted) -> PackedStringArray:
	var out := PackedStringArray()
	for cue: AudioCues.Cue in s.cues.cues:
		out.append(cue.id)
	return out


func _has(s: RefCounted, id: String) -> bool:
	return id in _ids(s)


## The first cue with this id on this tick, or null.
func _cue(s: RefCounted, id: String) -> RefCounted:
	for cue: AudioCues.Cue in s.cues.cues:
		if cue.id == id:
			return cue
	return null


## Step once and return the tick's cues, copied out before the next tick clears
## them — the template's `_drain`, against a list the simulation owns.
func _drain(s: RefCounted) -> Array:
	s.step()
	return s.cues.cues.duplicate()


# --- the scenarios ------------------------------------------------------------


# @covers Audio Feedback / The simulation publishes cues as data
## The shape of the thing: a record per event, an ordered list cleared every
## tick, and membership of the determinism summary. No audio API is reachable
## from here — check_boundaries.py bans AudioStreamPlayer under scripts/core/ and
## is the enforcement; this asserts what the ban buys, which is that a headless
## run with no sound hardware produces the complete stream.
func _test_the_simulation_publishes_cues_as_data() -> void:
	var s := _racing()
	s.arm_circuit(_course({}))
	s.pos_z = -4.0
	s.input.forward = true

	var gate_tick_cues: Array = []
	var tick_of_gate := -1
	for i in range(REPLAY_TICKS):
		var tick_cues: Array = _drain(s)
		if tick_of_gate < 0:
			for cue: AudioCues.Cue in tick_cues:
				if cue.id == AudioCues.GATE_PASSED:
					tick_of_gate = i
					gate_tick_cues = tick_cues
		if s.lap.banked_this_tick:
			break

	_check(tick_of_gate >= 0, "the drive emitted a cue at all")
	if tick_of_gate < 0:
		return

	var record: AudioCues.Cue = gate_tick_cues[0]
	_check(
		record.id == AudioCues.GATE_PASSED and record.tick == tick_of_gate,
		"a cue is a record: an id and the tick it happened on (%s at %d)" % [record.id, record.tick]
	)
	_check(
		record.volume >= 0.0 and record.volume <= 1.0 and record.spatial,
		"carrying a volume in 0..1 (%.3f) and, for a spatial cue, a world position" % record.volume
	)
	_check(
		not s.cues.cues.has(record),
		"and the list is CLEARED at tick start — last tick's events are not replayed"
	)

	# The stream joins the determinism summary, which is what makes the standing
	# replay and batching suites cover it for free.
	var before: String = s.stats_line()
	var digest_before: int = s.cues.digest
	var count_before: int = s.cues.emitted
	s.cues.begin_tick(s.ticks)
	s.cues.emit(AudioCues.LAP_BANKED, s.tuning.lap_banked_volume)
	_check(
		"cues=" in before and ("n=%d" % count_before) in before,
		"the cue stream is in the determinism summary — the tick's cues and the count"
	)
	_check(
		s.cues.digest != digest_before and s.cues.emitted == count_before + 1,
		"and the running digest moves with every record, so a divergence anywhere shows"
	)
	_check(
		s.cues.emitted > 1 and s.stats_line() != before,
		"a headless run produces the complete stream with no sound hardware at all"
	)


# @covers Audio Feedback / The race speaks at its moments
## The countdown on its exact ticks, and the four moments stage 8 owns. Volumes
## are asserted against the Audio table BY NAME, never against a number written
## here: a retune must reach the game, not this file.
func _test_the_race_speaks_at_its_moments() -> void:
	_the_countdown_speaks_on_its_exact_ticks()
	_the_gate_the_cursor_names_speaks()
	_the_bank_speaks_of_the_lap_the_best_and_the_medal()


func _the_countdown_speaks_on_its_exact_ticks() -> void:
	var s := _booting()
	var ticks: Array = []
	var goes: Array = []
	var tick_volume := -1.0
	var go_volume := -1.0
	for _i in range(REPLAY_TICKS / 6):
		s.step()
		for cue: AudioCues.Cue in s.cues.cues:
			if cue.id == AudioCues.COUNTDOWN_TICK:
				ticks.append(cue.tick)
				tick_volume = cue.volume
			elif cue.id == AudioCues.COUNTDOWN_GO:
				goes.append(cue.tick)
				go_volume = cue.volume

	# The step boundaries, derived from the countdown's own machinery rather than
	# written down: countdown_index() turns over on the tick whose ticks_in_state
	# reaches a multiple of countdown_step_ticks, and the tick COUNT at that
	# moment is one less because sim.ticks is advanced at the end of the step.
	var step: int = s.race.countdown_step_ticks
	_check(step > 0, "the countdown length reached the machine from the tuning (%d ticks)" % step)
	_check(
		ticks == [step - 1, 2 * step - 1, 3 * step - 1],
		"countdown_tick on each of the 3/2/1 boundaries, exactly: %s" % str(ticks)
	)
	_check(
		goes == [4 * step - 1],
		"and the distinct countdown_go on the GO! tick, exactly: %s" % str(goes)
	)
	_check(
		tick_volume == s.tuning.countdown_tick_volume and go_volume == s.tuning.countdown_go_volume,
		"at countdownTickVolume and countdownGoVolume, by name"
	)


func _the_gate_the_cursor_names_speaks() -> void:
	var s := _racing()
	s.arm_circuit(_course({}))
	s.pos_z = -4.0
	s.input.forward = true
	var passes: Array = []
	for _i in range(REPLAY_TICKS):
		s.step()
		var cue: RefCounted = _cue(s, AudioCues.GATE_PASSED)
		if cue != null:
			passes.append(cue)
		if s.lap.banked_this_tick:
			break
	_check(passes.size() == 1, "one gate, one gate_passed cue (%d)" % passes.size())
	if passes.is_empty():
		return
	var gate: RefCounted = s.circuit.gates[0]
	var cue: AudioCues.Cue = passes[0]
	_check(
		cue.volume == s.tuning.gate_passed_volume,
		"at gatePassedVolume, by name (%.3f)" % cue.volume
	)
	_check(
		cue.spatial and cue.x == gate.x and cue.z == gate.z,
		"positioned at the gate it named (%.2f, %.2f)" % [cue.x, cue.z]
	)


func _the_bank_speaks_of_the_lap_the_best_and_the_medal() -> void:
	# A gold target no lap can miss, so the medal cue's presence is about the
	# emission and not about the driving.
	var s := _racing()
	s.arm_circuit(_course({"gold": 999.0}))
	s.pos_z = -4.0
	s.input.forward = true
	var banked: Array = []
	for _i in range(REPLAY_TICKS):
		s.step()
		if s.lap.banked_this_tick:
			banked = s.cues.cues.duplicate()
			break
	var ids := PackedStringArray()
	for cue: AudioCues.Cue in banked:
		ids.append(cue.id)
	_check(
		AudioCues.LAP_BANKED in ids and AudioCues.NEW_BEST in ids and AudioCues.MEDAL in ids,
		"the first banked lap speaks of the lap, the new best, and the medal: %s" % str(ids)
	)
	_check(
		s.lap.banked_medal == "gold",
		"and the medal cue is the one the lap gate already decided (%s)" % s.lap.banked_medal
	)
	for cue: AudioCues.Cue in banked:
		if cue.id == AudioCues.LAP_BANKED:
			_check(cue.volume == s.tuning.lap_banked_volume, "lapBankedVolume, by name")
		elif cue.id == AudioCues.NEW_BEST:
			_check(cue.volume == s.tuning.new_best_volume, "newBestVolume, by name")
		elif cue.id == AudioCues.MEDAL:
			_check(cue.volume == s.tuning.medal_volume, "medalVolume, by name")

	# A SECOND lap that is not a best. new_best is ADDITIONAL to lap_banked, so a
	# lap that does not beat the record must bank in silence about it.
	s.lap.best_seconds = 0.01
	s.lap.bests[s.lap.best_key] = 0.01
	s.circuit.rewind()
	s.pos_z = -4.0
	s.pos_x = 0.0
	s.yaw = 0.0
	var second := PackedStringArray()
	for _i in range(REPLAY_TICKS):
		s.step()
		if s.lap.banked_this_tick:
			second = _ids(s)
			break
	_check(
		AudioCues.LAP_BANKED in second and not (AudioCues.NEW_BEST in second),
		"a lap that beats nothing banks without new_best: %s" % str(second)
	)

	# And a circuit with no targets earns no medal cue.
	var plain := _racing()
	plain.arm_circuit(_course({}))
	plain.pos_z = -4.0
	plain.input.forward = true
	var plain_ids := PackedStringArray()
	for _i in range(REPLAY_TICKS):
		plain.step()
		if plain.lap.banked_this_tick:
			plain_ids = _ids(plain)
			break
	_check(
		AudioCues.LAP_BANKED in plain_ids and not (AudioCues.MEDAL in plain_ids),
		"a circuit with no targets banks without a medal cue: %s" % str(plain_ids)
	)


# @covers Audio Feedback / An impact is heard once, as hard as it hit
## Volume scaled by the velocity destroyed, positioned at the struck prop, and
## rate-limited so the specified two-prop pin is one event rather than a drum
## roll. Both ends of the scale are asserted, because a formula that only ever
## returns 1.0 would pass a test of the loud end alone.
func _test_an_impact_is_heard_once_as_hard_as_it_hit() -> void:
	var reference := _racing()

	# The Audio table calls impactFullScale "the steady top speed". Assert that
	# against the shipped physics rather than assuming it, so a retune that broke
	# the relationship would be caught here rather than silently rescale audio.
	var steady := 0.0
	for _i in range(SPIN_UP_TICKS):
		steady = minf(steady + reference.tuning.accel, reference.tuning.max_speed)
		steady *= reference.tuning.friction
	_check(
		absf(steady - reference.tuning.impact_full_scale) < 1e-9,
		"the shipped table's steady top speed IS impactFullScale (%.9f)" % steady
	)

	# A FULL-SPEED HIT. Coasting at the clamp, friction brings stage 7 the steady
	# top speed exactly, so the destroyed velocity is full scale.
	var full := _hit_at(reference.tuning.max_speed)
	_check(full != null, "the full-speed approach actually struck the prop")
	if full == null:
		return
	_check(
		absf(full.volume - 1.0) < 1e-9,
		"a hit at the steady top speed is full scale: volume %.9f" % full.volume
	)

	# A NUDGE. A tenth of the velocity destroyed is a tenth of the volume.
	var nudge_speed: float = (
		reference.tuning.impact_full_scale * NUDGE_FRACTION / reference.tuning.friction
	)
	var nudge := _hit_at(nudge_speed)
	_check(nudge != null, "the nudge actually struck the prop")
	if nudge == null:
		return
	_check(
		absf(nudge.volume - NUDGE_FRACTION) < 1e-9,
		"and a tenth of that is a tap: volume %.9f" % nudge.volume
	)

	_a_pin_is_one_event()


## Coast into a prop already overlapping the start pose at `speed` and return the
## impact cue. Coasting rather than driving so that stage 4 alone decides the
## velocity stage 7 destroys, which is the quantity under test.
func _hit_at(speed: float) -> RefCounted:
	var s := _racing()
	s.kart_normalised = Normalise.to_target_height(KART_BOX, KART_HEIGHT)
	var prop: RefCounted = _cube_prop("tree", 0.0, 1.5, 2.0)
	s.props = [prop]
	s.velocity = speed
	s.step()
	var cue: RefCounted = _cue(s, AudioCues.IMPACT)
	if cue == null:
		return null
	_check(s.last_hit != null and s.velocity == 0.0, "the collision resolved and stopped the kart")
	_check(
		cue.spatial and cue.x == prop.centre_x() and cue.z == prop.centre_z(),
		"the impact is positioned at the struck prop (%.3f, %.3f)" % [cue.x, cue.z]
	)
	return cue


## THE PIN, collision_test.gd's own arrangement: two footprints a hair closer
## than the contracted hitbox, driven along the pair's axis, which is the heading
## that holds longest. The kart really does collide on every tick — asserted,
## because otherwise this case could pass by never being pinned at all — and the
## cue stream must still be a handful of events rather than sixty.
func _a_pin_is_one_event() -> void:
	var s := _racing()
	s.kart_normalised = Normalise.to_target_height(KART_BOX, KART_HEIGHT)
	var separation: float = s.tuning.min_prop_separation
	var size: float = separation - PIN_GAP
	s.props = [
		_cube_prop("left", -separation / 2.0, 0.0, size),
		_cube_prop("right", separation / 2.0, 0.0, size),
	]
	s.yaw = PI / 2.0
	s.input.forward = true

	var hit_ticks := 0
	var impact_ticks: Array = []
	for _i in range(HELD_SECOND):
		s.step()
		if s.last_hit != null:
			hit_ticks += 1
		if _has(s, AudioCues.IMPACT):
			impact_ticks.append(s.cues.cues[0].tick)

	var window: int = s.cues.impact_window_ticks
	_check(
		window > 0,
		"the rate-limit window reached the recorder from impactRateLimit (%d ticks)" % window
	)
	_check(
		hit_ticks == HELD_SECOND,
		(
			"PRECONDITION: the pin collides on every one of the %d ticks (%d)"
			% [HELD_SECOND, hit_ticks]
		)
	)
	_check(
		impact_ticks.size() > 0 and impact_ticks.size() <= HELD_SECOND / window,
		(
			(
				"a second of pinned oscillation is %d impact cue(s) over %d colliding ticks"
				+ " — at most one per impactRateLimit"
			)
			% [impact_ticks.size(), hit_ticks]
		)
	)
	var closest := HELD_SECOND
	for i in range(1, impact_ticks.size()):
		closest = mini(closest, int(impact_ticks[i]) - int(impact_ticks[i - 1]))
	_check(
		closest >= window,
		"and no two impacts are closer than the window (%d ticks apart)" % closest
	)


# @covers Audio Feedback / What must NOT sound
## The five negative promises the design document makes normative, each its own
## named case. Every one was RED-verified by adding the emission it forbids.
func _test_what_must_not_sound() -> void:
	_a_rebound_is_not_an_impact()
	_an_ignored_gate_pass_is_silent()
	_loading_is_silent_including_a_failed_boot()
	_focus_loss_emits_nothing()
	_reset_kart_is_silent()


## "A boundary rebound never plays the impact cue — the two are different physics
## and must be told apart by ear."
func _a_rebound_is_not_an_impact() -> void:
	var s := _racing()
	s.kart_normalised = Normalise.to_target_height(KART_BOX, KART_HEIGHT)
	s.input.forward = true
	var bounced: Array = []
	for _i in range(REPLAY_TICKS):
		s.step()
		if s.bounced_this_tick:
			bounced = s.cues.cues.duplicate()
			break
	var ids := PackedStringArray()
	for cue: AudioCues.Cue in bounced:
		ids.append(cue.id)
	_check(AudioCues.REBOUND in ids, "the boundary rebound has its own cue (%s)" % str(ids))
	_check(
		not (AudioCues.IMPACT in ids),
		"and the rebounding tick emits NO impact cue — different physics, different sound"
	)
	if bounced.is_empty():
		return
	var cue: AudioCues.Cue = bounced[0]
	_check(cue.volume == s.tuning.rebound_volume, "at reboundVolume, by name (%.3f)" % cue.volume)
	_check(cue.spatial, "and positioned, like the other cues heard from a place")


## "An out-of-order, repeated, or backwards gate pass — which changes nothing —
## sounds like nothing."
func _an_ignored_gate_pass_is_silent() -> void:
	# NOT YET DUE: the cursor names gate 2, so driving through gate 1 changes
	# nothing. Two gates, so the course is never threaded and the band is silent
	# too — the promise is "no cue at all", not "no gate cue".
	var ahead := _racing()
	var course := Circuit.new()
	course.circuit_name = "audio-ignored"
	course.add_gate(0.0, -2.0, 0.0, 10.0)
	# Gate 2 sits far off the kart's line and faces across it, so this drive can
	# only ever pass gate 1 — the one the cursor is NOT naming.
	course.add_gate(60.0, -2.0, PI / 2.0, 10.0)
	ahead.arm_circuit(course)
	ahead.circuit.cursor = 2
	ahead.pos_z = -4.0
	ahead.input.forward = true
	var emitted := 0
	for _i in range(REPLAY_TICKS / 12):
		ahead.step()
		emitted += ahead.cues.cues.size()
	_check(
		ahead.pos_z > 0.0 and emitted == 0,
		(
			"a pass of a gate the cursor does not name (z=%.1f) emits nothing at all (%d)"
			% [ahead.pos_z, emitted]
		)
	)

	# REPEATED: pass the named gate legitimately, then cross it again.
	var again := _racing()
	again.arm_circuit(_course({}))
	again.pos_z = -4.0
	again.input.forward = true
	var first_pass := -1
	for i in range(REPLAY_TICKS / 12):
		again.step()
		if _has(again, AudioCues.GATE_PASSED):
			first_pass = i
			break
	_check(first_pass >= 0, "PRECONDITION: the named gate really was passed once")
	again.input.forward = false
	for _i in range(REPLAY_TICKS / 12):
		again.step()
	again.pos_z = -4.0
	again.velocity = 0.0
	again.input.forward = true
	var repeats := 0
	for _i in range(REPLAY_TICKS / 12):
		again.step()
		if _has(again, AudioCues.GATE_PASSED):
			repeats += 1
	_check(repeats == 0, "crossing the same gate again says nothing (%d)" % repeats)

	# BACKWARDS: the named gate, driven through from the far side.
	var backwards := _racing()
	backwards.arm_circuit(_course({}))
	backwards.pos_z = 4.0
	backwards.yaw = PI
	backwards.input.forward = true
	var wrong_way := 0
	for _i in range(REPLAY_TICKS / 12):
		backwards.step()
		wrong_way += backwards.cues.cues.size()
	_check(
		backwards.pos_z < -2.0 and wrong_way == 0,
		(
			"and the named gate taken backwards (z=%.1f) says nothing either (%d)"
			% [backwards.pos_z, wrong_way]
		)
	)


## "No cue of any kind is emitted in LOADING, and a terminal LOADING failure is
## silent."
func _loading_is_silent_including_a_failed_boot() -> void:
	var s := _racing()
	s.race.state = 0
	s.race.ticks_in_state = 0
	s.cues.emitted = 0
	for _i in range(REPLAY_TICKS / 6):
		s.step()
	_check(
		s.race.state == 0 and s.cues.emitted == 0,
		"a full minute of LOADING emits nothing (%d)" % s.cues.emitted
	)

	var failed := Sim.new()
	failed.tuning = _tuning()
	failed.input = InputState.new()
	failed.race.fail_load("no world")
	failed.input.forward = true
	for _i in range(REPLAY_TICKS / 6):
		failed.step()
	_check(
		failed.race.error_message != "" and failed.cues.emitted == 0,
		"and a terminal boot failure is silent too (%d)" % failed.cues.emitted
	)


## "Losing window focus mid-throttle emits nothing: the kart coasting down is the
## engine note falling, not an event." Focus loss reaches the core as exactly one
## thing — the held input released — so that is what is staged here.
func _focus_loss_emits_nothing() -> void:
	var s := _racing()
	s.pos_z = -40.0
	s.input.forward = true
	for _i in range(HELD_SECOND):
		s.step()
	var moving: float = s.velocity
	var before: int = s.cues.emitted
	s.input.clear()
	s.step()
	_check(
		moving > 0.0 and s.cues.emitted == before,
		"the tick focus is lost emits nothing (%d cues)" % (s.cues.emitted - before)
	)
	for _i in range(HELD_SECOND * 2):
		s.step()
	_check(
		s.velocity < moving * 0.2 and s.cues.emitted == before,
		"and the whole coast down after it is silent (%d cues)" % (s.cues.emitted - before)
	)


## "Reset Kart is silent — it is specified as the start pose and NOTHING else,
## and a sound is not nothing."
func _reset_kart_is_silent() -> void:
	var s := _racing()
	s.arm_circuit(_course({}))
	s.pos_z = -4.0
	s.input.forward = true
	for _i in range(REPLAY_TICKS / 12):
		s.step()
		if s.cues.emitted > 0:
			break
	_check(s.cues.emitted > 0, "PRECONDITION: this run has a cue stream to stay quiet against")
	var before: int = s.cues.emitted
	var list_before: int = s.cues.cues.size()
	s.reset_kart()
	_check(
		s.cues.emitted == before and s.cues.cues.size() == list_before,
		"Reset Kart appends nothing (%d)" % (s.cues.emitted - before)
	)
	s.input.clear()
	s.step()
	_check(
		s.pos_x == 0.0 and s.pos_z == 0.0 and s.cues.emitted == before,
		"and the tick after it is silent too (%d)" % (s.cues.emitted - before)
	)


## Acceptance item 16's headless half — "a scripted run's cue stream is
## identical". The same baked drive item 14 replays, run twice, with the WHOLE
## stream compared byte for byte rather than only the summary. The cross-render-
## rate half belongs to tools/refresh_probe.gd and waits for add-audio-playback.
func _test_the_cue_stream_replays_byte_identically() -> void:
	var streams: Array = []
	for _run in range(2):
		streams.append(_replay_the_lap_script())
	_check(
		streams[0] == streams[1],
		"the baked lap script's cue stream is byte-identical across two replays"
	)
	var stream: String = streams[0]
	_check(
		(
			AudioCues.COUNTDOWN_GO not in stream
			and AudioCues.GATE_PASSED in stream
			and AudioCues.LAP_BANKED in stream
			and AudioCues.NEW_BEST in stream
		),
		"GUARD: and it is a real stream — gates, a bank and a best over 60 s"
	)
	_check(
		stream.length() > REPLAY_TICKS / 12,
		"GUARD: of substance, not two events (%d characters)" % stream.length()
	)


## One replay of conformance_test.gd's LAP_SCRIPT on the shipped circuit,
## returning every tick's cues as one string. Only sounding ticks contribute, so
## the string is the STREAM and not a transcript of silence.
func _replay_the_lap_script() -> String:
	var s := _racing()
	s.arm_circuit(LayoutIO.read_circuit(LayoutIO.SHIPPED_CIRCUIT_PATH))
	var script: Array = Conformance.LAP_SCRIPT
	var phase_index := 0
	var phase_start := 0
	var out := PackedStringArray()
	for tick in range(REPLAY_TICKS):
		var phase: Array = script[phase_index % script.size()]
		if tick >= phase_start + int(phase[3]):
			phase_start += int(phase[3])
			phase_index += 1
			phase = script[phase_index % script.size()]
		s.input.forward = phase[0]
		s.input.left = phase[1]
		s.input.right = phase[2]
		s.step()
		if not s.cues.cues.is_empty():
			out.append(s.cues.line())
	return "\n".join(out)
