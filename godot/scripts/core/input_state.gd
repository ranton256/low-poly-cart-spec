# What the player is holding down, as plain flags.
#
# The simulation never reads an input device: the caller sets these before a
# tick and the tick observes them. That is what keeps scripts/core/ free of
# engine types (CONSTRAINTS §4 Architectural boundaries) and lets a test drive
# a scripted input sequence with no window.
#
# "Held", not "pressed": the design document specifies input as continuous
# state that persists across ticks until released, independent of any key-repeat
# behaviour of the host.
extends RefCounted

var forward: bool = false
var reverse: bool = false
var left: bool = false
var right: bool = false


## Release everything. The design document requires this on focus loss, so the
## kart coasts to a stop under friction rather than driving away unattended.
func clear() -> void:
	forward = false
	reverse = false
	left = false
	right = false


## The net drive direction for a tick: +1 forward, -1 reverse, 0 when neither or
## both are held. Both held is specified to cancel, leaving only friction.
func drive_sign() -> float:
	var f := 1.0 if forward else 0.0
	var r := 1.0 if reverse else 0.0
	return f - r


## The net steering direction, before the sign-of-travel correction the tick
## applies. Both held cancels.
func steer_sign() -> float:
	var l := 1.0 if left else 0.0
	var r := 1.0 if right else 0.0
	return l - r
