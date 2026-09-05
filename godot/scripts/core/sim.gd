# The simulation — the design document's kart tick, and nothing else.
#
# RULES, and they are the whole point:
#
#   1. No engine node dependencies. This file never touches Node, the scene
#      tree, engine input, engine time, or the engine RNG. It is constructible
#      and steppable by a test with no scene loaded.
#   2. Fixed timestep. step() advances exactly one tick. It never reads a frame
#      delta, and elapsed time is derived from the tick count.
#   3. Tuning is INJECTED. This file holds no constant the design document
#      names — see tuning.gd.
#   4. The view reads this; it never writes back.
#
# PRECISION. Velocity, yaw and position are 64-bit floats, and position is two
# scalars rather than a Vector3, which is 32-bit real_t in a standard build.
# The acceptance timings are asserted to +/- 0.05 s — three ticks — over runs of
# up to ~2600 ticks, and 32-bit accumulation does not have that precision
# spare. Conversion to Vector3 happens at the view boundary.
extends RefCounted

const Collision := preload("res://scripts/core/collision.gd")
const RaceState := preload("res://scripts/core/race_state.gd")
const LapGate := preload("res://scripts/core/lap_gate.gd")
const Circuit := preload("res://scripts/core/circuit.gd")
const AudioCues := preload("res://scripts/core/audio_cues.gd")

const TICKS_PER_SECOND := 60

# --- injected ---
var tuning: RefCounted = null
var input: RefCounted = null

# --- state ---
## The race state machine, advanced first every tick in every state
## (ambiguity A4). The kart stages run only while it is RACING. Its countdown
## length is wired from the tuning on the first step, so the machine stays
## constructible bare.
var race: RefCounted = RaceState.new()

## The lap gate, clock, and session best — stage 8's owner (godot/lap-timing).
var lap: RefCounted = LapGate.new()

## The checkpoint circuit — gates and the progress cursor, advanced at stage 8
## beside the lap gate (godot/checkpoint-circuit). Empty until a v2 layout arms
## one: the game still boots procedural until the presentation change ships the
## boot circuit, and an empty circuit changes nothing about the tick.
var circuit: RefCounted = Circuit.new()

## This tick's audio cues, as DATA (godot/audio-feedback). Cleared at the top of
## every step() and appended by the stage that owns each event; the view drains
## it once per TICK (A16) and plays it; the simulation never touches an audio API.
## Its rate-limit window is wired from the tuning on the first step, so the
## recorder stays constructible bare exactly like the race state machine.
var cues: RefCounted = AudioCues.new()
var velocity: float = 0.0
var yaw: float = 0.0
var pos_x: float = 0.0
var pos_z: float = 0.0
var ticks: int = 0

# --- the steering ease-in's state (stage 3) ---
## How many consecutive ticks the current steering direction has been held, and
## which direction that is. Zero and zero when nothing (or both) is held.
## STATE, not a derived value: the ramp is a function of the input's history,
## which is exactly what a pure per-tick function of the kart cannot recover.
var steer_hold_ticks: int = 0
var steer_hold_sign: float = 0.0

## Steering effectiveness this tick, 0..1 — `min(1, held / steerEaseSeconds)`.
## Written by stage 3 every tick, including the ticks that do not steer, and
## carried in stats_line() so two runs differing only in steering history do
## differ in the string the determinism suites compare.
var steer_ease: float = 0.0

# --- observable outcomes of the last tick, for the view and for tests ---
var bounced_this_tick: bool = false

## The +Z displacement stage 5 actually applied this tick — THE crossing
## observable (godot/lap-timing D1). Captured where it happens: by stage 8 a
## collision may have zeroed the velocity, and net position change is moved
## by the clamp and the push-out too.
var last_step5_dz: float = 0.0

## The +X half of the same observable. The band only ever needed +Z; a gate at
## an arbitrary yaw needs the whole displacement to project onto gate-forward,
## and it must be THIS vector rather than the net position change for the same
## reason the band's is — the clamp and the push-out move the kart too.
var last_step5_dx: float = 0.0

## The props this tick collides with, in REGISTRATION ORDER. Supplied by the
## caller like the tuning is, so the simulation stays constructible with no scene
## loaded and a test can place two props exactly where it wants them.
var props: Array = []

## The kart's normalised box, for recomputing its world volume each tick.
var kart_normalised: RefCounted = null

## The angle between the kart model's authored long axis and the simulation's
## forward. The design document says the hit volume is recomputed from the kart's
## CURRENT TRANSFORM, and the model's transform carries this correction — so a
## volume computed from `yaw` alone would be the kart's footprint rotated a
## quarter turn, 2.20 wu deep where the kart is 2.36. Supplied by the caller,
## which is the only place that has seen the asset. Zero for a synthetic kart.
var kart_yaw_offset: float = 0.0

## The collision resolved this tick, or null. The view reads it to jolt the
## camera; a test reads it to see which prop won.
var last_hit: RefCounted = null


## Seconds elapsed, derived from the tick count. Never a host clock.
func elapsed_seconds() -> float:
	return float(ticks) / float(TICKS_PER_SECOND)


## The speedometer ratio, 0..1 against the forward clamp.
func speed_ratio() -> float:
	if tuning.max_speed == 0.0:
		return 0.0
	return absf(velocity) / tuning.max_speed


## The integer the dial displays. Acceptance item 4 is stated in these numbers
## (103, 115), not in wu/tick, so the arithmetic lives here rather than in the
## HUD — otherwise every test of that item re-derives the formula and there are
## two definitions of one number. Drawing the needle is M5's problem.
func speedo_readout() -> int:
	return int(floorf(speed_ratio() * tuning.speedo_max))


## The kart's forward direction. The design document's world forward is +Z, so
## a yaw of zero faces +Z. In Godot terms this is the node's +basis.z; the
## engine's own -Z convention is a view concern and lives there.
func forward_x() -> float:
	return sin(yaw)


func forward_z() -> float:
	return cos(yaw)


## Called once per rendered frame.
##
## NOT "before that frame's ticks", which is what this line used to say. That was
## written against the batch model replay_test.gd uses; the real composition root
## drives Godot's fixed-rate loop, which runs a frame's physics steps BEFORE its
## per-frame callback. What makes this a seam is being once per rendered frame —
## the position relative to the steps is not what matters, and claiming an
## ordering the caller does not honour is worse than claiming none.
##
## A NO-OP, AND THAT IS THE POINT. A real composition root has a per-frame entry
## point, and this is the only surface through which frame-dependence could
## reach the core.
##
## Be precise about what replay_test.gd proves today: with this method empty,
## batch-independence still holds by construction — the three drivers run the
## same sequence of step() calls and differ only in where no-op calls fall. The
## harness is therefore a REGRESSION GUARD for a property that cannot currently
## be violated, not a present-tense proof. That is worth having, and it is not
## the same claim.
##
## If this ever stops being empty, the replay harness is what will notice — and
## it is the only suite that will. determinism_test.gd is blind to per-frame
## effects by design.
func begin_frame() -> void:
	pass


## One tick: the design document's eight stages, in its order.
##
## THE ORDER IS THE CONTRACT. Several of the document's statements are true only
## because of it — the clamp precedes friction, so the achievable steady speed
## is below the clamp rather than equal to it; the steering test reads the
## post-clamp, pre-friction velocity, so it sees a value slightly larger than
## the one that moves the kart.
func step() -> void:
	bounced_this_tick = false
	last_hit = null

	# The cue list is emptied FIRST, before any stage can append: a cue belongs to
	# the tick that emitted it, and a list carried over would let a view play last
	# tick's events again. The rate-limit window is wired from the tuning here for
	# the same reason the countdown length is, one line below.
	if cues.impact_window_ticks == 0 and tuning != null:
		cues.impact_window_ticks = int(roundf(tuning.impact_rate_limit * TICKS_PER_SECOND))
	cues.begin_tick(ticks)

	# Stage 0 — the race state, every tick in every state (godot/race-state).
	# Its countdown length comes from the tuning like every other constant.
	if race.countdown_step_ticks == 0 and tuning != null:
		race.countdown_step_ticks = int(roundf(tuning.countdown_step * TICKS_PER_SECOND))
	var countdown_before: int = race.countdown_index()
	var was_starting: bool = race.state == RaceState.STARTING
	race.advance()
	# The countdown's voice, on its exact ticks. GO! is not a fourth index — it is
	# the RACING transition itself — so it is detected as that transition, while
	# the three steps are detected as the DERIVED INDEX turning over, which is the
	# same edge the countdown overlay redraws on. Nothing can fire in LOADING:
	# countdown_index() is -1 there and stays -1, a failed boot included, and no
	# transition is taken from inside advance().
	if was_starting and race.is_racing():
		cues.emit(AudioCues.COUNTDOWN_GO, tuning.countdown_go_volume)
	elif countdown_before >= 0 and race.countdown_index() > countdown_before:
		cues.emit(AudioCues.COUNTDOWN_TICK, tuning.countdown_tick_volume)

	# The kart pipeline is gated on RACING: held input stays tracked (the
	# caller writes it every tick) but nothing accelerates, steers, or moves.
	# The GO! tick transitions AND runs the pipeline, so a key held through
	# the countdown takes effect on this very tick.
	if race.is_racing():
		_stage_1_accelerate()
		_stage_2_clamp()
		_stage_3_steer()
		_stage_4_friction()
		_stage_5_integrate()
		_stage_6_boundary()
		_stage_7_collision()
		_stage_8_lap_gate()

	ticks += 1


func _stage_1_accelerate() -> void:
	velocity += tuning.accel * input.drive_sign()


## Clamped BEFORE friction. Reverse is limited more tightly than forward.
func _stage_2_clamp() -> void:
	var forward_limit: float = tuning.max_speed
	var reverse_limit: float = tuning.max_speed * tuning.reverse_factor
	velocity = clampf(velocity, -reverse_limit, forward_limit)


## Tested on the post-clamp, PRE-friction velocity. The sign of travel is what
## reverses the steering sense when reversing.
##
## THE EASE IS NOT A SMOOTHING FILTER on the yaw — it is a factor on the rate,
## `turnRate × ease × sign(v)`, and it is a pure function of how many
## consecutive ticks this direction has been held. Onset was the complaint the
## first playtest raised: `yaw += turnRate` arrives whole on the tick the key
## goes down, and a step function feels like a jerk because it is one.
##
## TWO ORDERING DECISIONS, both deliberate:
##
##   1. The hold counter is advanced BEFORE the threshold gate, so the ramp
##      counts HELD ticks rather than steering ticks. The design document says
##      the ease "never gates the threshold rule" but does not settle this
##      edge; this port rules that the ramp models the hand on the key, not the
##      kart's speed. The alternative reintroduces a jerk exactly where the
##      kart accelerates through `steerThreshold` — the moment the feature
##      exists to smooth. tests/steer_test.gd asserts the choice by name.
##   2. The threshold gate itself is UNCHANGED: same comparison, same operand,
##      same early return. Below the threshold there is no steering at any ease.
func _stage_3_steer() -> void:
	var direction: float = input.steer_sign()
	# Released OR reversed — and "both held", which is neither direction — all
	# reach zero here, which is the reset the document specifies for the first
	# two and the consistent reading of the third.
	if direction != steer_hold_sign:
		steer_hold_ticks = 0
	steer_hold_sign = direction
	if direction != 0.0:
		steer_hold_ticks += 1
	steer_ease = _ease_for(steer_hold_ticks)
	if absf(velocity) <= tuning.steer_threshold:
		return
	yaw += tuning.turn_rate * steer_ease * direction * signf(velocity)


## The ramp: linear from 0 to 1 over `steerEaseSeconds` of held ticks, flat at
## 1 after. A zero-length ramp is no ramp — the limit of the definition, so a
## held tick is immediately full rate — rather than a defaulted value; the
## loader refuses a tuning table missing `steerEaseSeconds` outright.
func _ease_for(held_ticks: int) -> float:
	var ramp_ticks: float = tuning.steer_ease_seconds * float(TICKS_PER_SECOND)
	if ramp_ticks <= 0.0:
		return 1.0 if held_ticks > 0 else 0.0
	return minf(1.0, float(held_ticks) / ramp_ticks)


func _stage_4_friction() -> void:
	velocity *= tuning.friction


## Displaced along the kart's own heading. No lateral component: this game has
## no drift and no sideways velocity.
func _stage_5_integrate() -> void:
	last_step5_dx = forward_x() * velocity
	last_step5_dz = forward_z() * velocity
	pos_x += last_step5_dx
	pos_z += last_step5_dz


## Clamp each axis, then apply the bounce ONCE if either or both clamped.
##
## The flag is not decoration. Applying the factor per axis squares it, and at a
## corner that leaves the kart moving INTO the corner at +9% speed instead of
## rebounding — which the design document calls out specifically.
func _stage_6_boundary() -> void:
	var limit: float = tuning.drivable_extent
	var clamped_x: float = clampf(pos_x, -limit, limit)
	var clamped_z: float = clampf(pos_z, -limit, limit)
	if clamped_x != pos_x or clamped_z != pos_z:
		bounced_this_tick = true
	pos_x = clamped_x
	pos_z = clamped_z
	if bounced_this_tick:
		velocity *= tuning.bounce_factor
		# ITS OWN ID, never impact's. The document makes that normative: the two
		# are different physics and the player must be able to tell them apart by
		# ear. Heard from where the kart met the fence.
		cues.emit_at(AudioCues.REBOUND, tuning.rebound_volume, pos_x, pos_z)


## Stage 7 — collision detection and response.
##
## Its place in the order is part of the contract: a collision here discards the
## entire tick's acceleration, and the push-out must happen before the lap gate
## observes the position.
##
## AFTER the boundary, so a kart shoved out of a prop near the fence is not
## clamped back this tick. The design document orders it this way and the
## ordering tests hold it there.
##
## At most ONE collision per tick, against the first intersecting prop in
## registration order — see collision.gd's header for why that is specified
## rather than merely convenient, and what it costs.
func _stage_7_collision() -> void:
	if props.is_empty() or kart_normalised == null:
		return
	var volume: AABB = Collision.kart_volume(
		kart_normalised, yaw + kart_yaw_offset, pos_x, pos_z, tuning.hitbox_contraction
	)
	var index: int = Collision.first_overlap(volume, props)
	if index < 0:
		return

	# The FIRST intersecting prop, and no further testing this tick.
	var struck: Collision.Prop = props[index] as Collision.Prop
	var hit: RefCounted = Collision.resolve(struck, pos_x, pos_z, yaw, tuning.push_distance)
	hit.index = index
	pos_x += hit.push_x
	pos_z += hit.push_z
	# The velocity this collision DESTROYS, read before it is destroyed: the
	# document scales the impact cue by it, and after the next line there is
	# nothing left to measure.
	var destroyed: float = absf(velocity)
	# EXACTLY zero. Not reflected, not damped — the kart stops dead.
	velocity = 0.0
	last_hit = hit
	# "A top-speed hit is full scale, a nudge is a tap", at the struck prop, and
	# under the rate limit so the specified two-prop pin is one event rather than
	# a drum roll. The limit is the recorder's, not this stage's: the pin really
	# does collide on every tick and stage 7 must go on saying so.
	if tuning.impact_full_scale > 0.0:
		var loudness: float = minf(1.0, destroyed / tuning.impact_full_scale)
		cues.emit_impact(loudness, struck.centre_x(), struck.centre_z())


## Stage 8 — the circuit, then the lap gate. Both run last and observe only: a
## kart that clipped a prop inside the band has already been stopped and
## displaced before either is tested, and both read stage 5's own displacement,
## which none of the later stages can have influenced.
##
## THE CIRCUIT GOES FIRST, so a final gate sited on the start/finish line itself
## threads the course on the tick it is passed rather than the tick after.
func _stage_8_lap_gate() -> void:
	if lap.tuning == null:
		lap.tuning = tuning
	if circuit.tuning == null:
		circuit.tuning = tuning
	if lap.circuit == null:
		lap.circuit = circuit
	# ONLY WHEN THE CURSOR ADVANCES. An out-of-order, repeated or backwards pass
	# changes nothing, and the document says it must therefore sound like nothing;
	# the cursor's own movement is the whole test, so there is no second rule here
	# to disagree with circuit.gd's.
	var cursor_before: int = circuit.cursor
	circuit.advance(pos_x, pos_z, last_step5_dx, last_step5_dz)
	if circuit.cursor != cursor_before:
		var gate := circuit.gates[cursor_before - 1] as Circuit.Gate
		cues.emit_at(AudioCues.GATE_PASSED, tuning.gate_passed_volume, gate.x, gate.z)

	# The bank's three voices, READ from what the lap gate has just decided rather
	# than recomputed: the medal is its verdict at bank time, and a second opinion
	# here could differ from the one the HUD shows.
	var best_before: float = lap.best_seconds
	lap.advance(pos_x, pos_z, last_step5_dz)
	if lap.banked_this_tick:
		cues.emit(AudioCues.LAP_BANKED, tuning.lap_banked_volume)
		if lap.best_seconds != best_before:
			cues.emit(AudioCues.NEW_BEST, tuning.new_best_volume)
		if lap.banked_medal != "":
			cues.emit(AudioCues.MEDAL, tuning.medal_volume)


## Arm a circuit — what loading a version-2 layout does. The lap gate is
## re-pointed at it in the same breath, so the threaded condition, the best key,
## and the medal targets can never belong to a circuit that is not being played.
func arm_circuit(loaded: RefCounted) -> void:
	circuit = loaded
	circuit.tuning = tuning
	lap.circuit = circuit
	lap.select_circuit(circuit.key())


## Restart Circuit (Procedural World Generation / Restarting the circuit): a
## fresh attempt on the same circuit — the start pose, the cursor back at gate
## 1, and the lap clock from 0.00. The circuit's identity, its session best, and
## the race state are untouched: the restart is instant and never re-enters the
## countdown. Rebuilding the props is the caller's half (scripts/main.gd).
func restart_circuit() -> void:
	reset_kart()
	circuit.rewind()
	lap.restart_attempt()


## Reset Kart (Runtime Tuning and Player Actions): the start pose and
## NOTHING else — the lap clock, banked time, session best, race state, the
## CIRCUIT PROGRESS CURSOR, and the world are untouched. Also the document's
## specified escape from the two-prop pin: the pose it restores is clear ground.
## A full fresh attempt is Restart Circuit's job, not this one.
func reset_kart() -> void:
	pos_x = 0.0
	pos_z = 0.0
	yaw = 0.0
	velocity = 0.0


## A one-line state summary. Cheap, and far easier to diff between two runs than
## comparing object graphs — the determinism tests compare these strings.
##
## THE CUE STREAM IS IN IT, which is what makes the standing replay and batching
## suites cover the audio feature for free. Not the whole stream: this tick's
## cues verbatim, plus the running count, digest and rate-limit window that stand
## for every cue emitted so far — see audio_cues.gd's header for why a cumulative
## list here would make determinism_test quadratic.
func stats_line() -> String:
	return (
		(
			"t=%d state=%d ts=%d lc=%d hold=%d bank=%.2f best=%.2f"
			+ " circuit=%s gate=%d/%d medal=%s v=%.9f yaw=%.9f ease=%.9f x=%.9f z=%.9f %s"
		)
		% [
			ticks,
			race.state,
			race.ticks_in_state,
			lap.clock_ticks,
			lap.hold_ticks,
			lap.banked_seconds,
			lap.best_seconds,
			circuit.key(),
			circuit.cursor,
			circuit.gate_count(),
			lap.banked_medal if lap.banked_medal != "" else "-",
			velocity,
			yaw,
			steer_ease,
			pos_x,
			pos_z,
			cues.summary(),
		]
	)
