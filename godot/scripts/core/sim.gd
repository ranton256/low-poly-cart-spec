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

const TICKS_PER_SECOND := 60

# --- injected ---
var tuning: RefCounted = null
var input: RefCounted = null

# --- state ---
var velocity: float = 0.0
var yaw: float = 0.0
var pos_x: float = 0.0
var pos_z: float = 0.0
var ticks: int = 0

# --- observable outcomes of the last tick, for the view and for tests ---
var bounced_this_tick: bool = false


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


## Called once per rendered frame, before that frame's ticks.
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
	pos_x += forward_x() * velocity
	pos_z += forward_z() * velocity


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


## Stage 7 — collision detection and response. Empty until M3
## (add-aabb-collision-response). Its place in the order is part of the
## contract: a collision here discards the entire tick's acceleration, and the
## push-out must happen before the lap gate observes the position.
func _stage_7_collision() -> void:
	pass


## Stage 8 — the lap gate. Empty until M4 (add-lap-gate-and-timing). It runs
## last and observes only: a kart that clipped a prop inside the band has
## already been stopped and displaced before the gate is tested.
func _stage_8_lap_gate() -> void:
	pass


## A one-line state summary. Cheap, and far easier to diff between two runs than
## comparing object graphs — the determinism tests compare these strings.
func stats_line() -> String:
	return "t=%d v=%.9f yaw=%.9f x=%.9f z=%.9f" % [ticks, velocity, yaw, pos_x, pos_z]
