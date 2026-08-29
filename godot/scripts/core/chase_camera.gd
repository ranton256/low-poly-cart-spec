# The chase camera, as a fixed-step recurrence.
#
# IN scripts/core/ DELIBERATELY, AND IT IS NOT GAMEPLAY. This directory is
# otherwise the simulation, and putting cosmetic state here widens what it means
# — design D1 of add-chase-camera argues it rather than assuming it, and
# CONSTRAINTS §4 Architectural boundaries records the decision.
#
# The reason is that the design document states this camera's behaviour as
# NUMBERS: an easing factor per tick, a time constant of ~0.2 s, a settling time
# of ~0.5 s, and a field-of-view curve. Those are checkable — and this directory
# is the only one the boundary gate polices. A pure module is steppable headless
# wherever it sits; what core/ adds is that nothing here can quietly acquire a
# Node, read a file, or start easing per frame. Acceptance item 8 becomes a
# measurement instead of a judgement.
#
# The rule this directory really enforces is "fixed-step and engine-free", not
# "gameplay only". No engine types, no scene tree, constructible from a test.
# Scalars rather than Vector3 for the same reason the rest of the core uses them:
# Vector3 is 32-bit real_t, and this module shares the tick with values that are
# not.
#
# EASED PER TICK, NEVER PER FRAME — ambiguity A10. The design document states the
# easing per tick and the camera update once per frame; those are the same
# sentence at 60 fps and different behaviour everywhere else. Per frame, the time
# constant becomes 0.4 s at 30 fps and 0.083 s at 144 fps against a stated 0.2 s.
extends RefCounted

var tuning: RefCounted = null

# Where the camera is, and what it looks at. Both in world units; the position
# lags, the aim does not.
var pos_x: float = 0.0
var pos_y: float = 0.0
var pos_z: float = 0.0
var aim_x: float = 0.0
var aim_y: float = 0.0
var aim_z: float = 0.0
var fov: float = 0.0

var _placed: bool = false


## Advance one tick from the kart's post-step state.
##
## Called by the composition root immediately after Sim.step(). The kart's
## heading is the simulation's yaw, whose forward is (sin yaw, cos yaw) — the
## design document's +Z at yaw zero.
func step(kart_x: float, kart_z: float, kart_yaw: float, speed_ratio: float) -> void:
	var forward_x: float = sin(kart_yaw)
	var forward_z: float = cos(kart_yaw)

	# Behind and above, IN THE KART'S OWN FRAME. Behind means against the kart's
	# forward, not against a fixed world direction, which is what makes the
	# camera follow a turn rather than watch one.
	var target_x: float = kart_x - tuning.chase_back * forward_x
	var target_z: float = kart_z - tuning.chase_back * forward_z
	var target_y: float = tuning.chase_up

	if not _placed:
		# The first tick places the camera ON its target rather than easing from
		# the origin: a session must not open with the camera flying in from
		# wherever it happened to start.
		pos_x = target_x
		pos_y = target_y
		pos_z = target_z
		_placed = true
	else:
		pos_x += (target_x - pos_x) * tuning.chase_smoothing
		pos_y += (target_y - pos_y) * tuning.chase_smoothing
		pos_z += (target_z - pos_z) * tuning.chase_smoothing

	# THE AIM IS NOT SMOOTHED. The design document is explicit, and it is what
	# separates a trailing camera from a swaying one: the horizon stays level
	# while the position lags behind.
	aim_x = kart_x + tuning.aim_ahead * forward_x
	aim_z = kart_z + tuning.aim_ahead * forward_z
	aim_y = tuning.aim_up

	fov = field_of_view(speed_ratio)


## The field of view for a speed ratio, as a pure function.
##
## Static so a test can ask the curve directly without stepping anything, and so
## the view has no reason to compute it.
func field_of_view(speed_ratio: float) -> float:
	var ratio: float = clampf(speed_ratio, 0.0, 1.0)
	return tuning.fov_base + ratio * (tuning.fov_max - tuning.fov_base)


## Place the camera without easing — used when a session starts, and by anything
## that repositions the kart discontinuously. Without it the camera would treat a
## teleport as a very fast drive and swing across the field to catch up.
func reset() -> void:
	_placed = false


## The camera's horizontal offset from a point, as a direction. The settling
## measurement compares this against the kart's reversed heading; returning it
## here keeps that arithmetic in one place rather than in the test.
func offset_angle_from(kart_x: float, kart_z: float, kart_yaw: float) -> float:
	var to_camera_x: float = pos_x - kart_x
	var to_camera_z: float = pos_z - kart_z
	if absf(to_camera_x) < 1e-12 and absf(to_camera_z) < 1e-12:
		return 0.0
	# Where the camera SHOULD sit once settled: directly behind the kart.
	var behind_x: float = -sin(kart_yaw)
	var behind_z: float = -cos(kart_yaw)
	var length: float = sqrt(to_camera_x * to_camera_x + to_camera_z * to_camera_z)
	var dot: float = (to_camera_x * behind_x + to_camera_z * behind_z) / length
	return acos(clampf(dot, -1.0, 1.0))
