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
var velocity: float = 0.0
var yaw: float = 0.0
var pos_x: float = 0.0
var pos_z: float = 0.0
var ticks: int = 0

# --- observable outcomes of the last tick, for the view and for tests ---
var bounced_this_tick: bool = false

## The +Z displacement stage 5 actually applied this tick — THE crossing
## observable (godot/lap-timing D1). Captured where it happens: by stage 8 a
## collision may have zeroed the velocity, and net position change is moved
## by the clamp and the push-out too.
var last_step5_dz: float = 0.0

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

	# Stage 0 — the race state, every tick in every state (godot/race-state).
	# Its countdown length comes from the tuning like every other constant.
	if race.countdown_step_ticks == 0 and tuning != null:
		race.countdown_step_ticks = int(roundf(tuning.countdown_step * TICKS_PER_SECOND))
	race.advance()

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
func _stage_3_steer() -> void:
	if absf(velocity) <= tuning.steer_threshold:
		return
	yaw += tuning.turn_rate * input.steer_sign() * signf(velocity)


func _stage_4_friction() -> void:
	velocity *= tuning.friction


## Displaced along the kart's own heading. No lateral component: this game has
## no drift and no sideways velocity.
func _stage_5_integrate() -> void:
	last_step5_dz = forward_z() * velocity
	pos_x += forward_x() * velocity
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
	var hit: RefCounted = Collision.resolve(
		props[index] as Collision.Prop, pos_x, pos_z, yaw, tuning.push_distance
	)
	hit.index = index
	pos_x += hit.push_x
	pos_z += hit.push_z
	# EXACTLY zero. Not reflected, not damped — the kart stops dead.
	velocity = 0.0
	last_hit = hit


## Stage 8 — the lap gate. Runs last and observes only: a kart that clipped a
## prop inside the band has already been stopped and displaced before the gate
## is tested, and the gate reads stage 5's own displacement, which none of the
## later stages can have influenced.
func _stage_8_lap_gate() -> void:
	if lap.tuning == null:
		lap.tuning = tuning
	lap.advance(pos_x, pos_z, last_step5_dz)


## A one-line state summary. Cheap, and far easier to diff between two runs than
## comparing object graphs — the determinism tests compare these strings.
func stats_line() -> String:
	return (
		"t=%d state=%d ts=%d lc=%d hold=%d bank=%.2f best=%.2f v=%.9f yaw=%.9f x=%.9f z=%.9f"
		% [
			ticks,
			race.state,
			race.ticks_in_state,
			lap.clock_ticks,
			lap.hold_ticks,
			lap.banked_seconds,
			lap.best_seconds,
			velocity,
			yaw,
			pos_x,
			pos_z,
		]
	)
