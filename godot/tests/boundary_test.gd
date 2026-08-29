# World boundary containment — the design document's feature of that name.
#
#   godot --headless -s tests/boundary_test.gd
#
# The corner case is the point of this file. The design document calls it out
# specifically: applying the bounce factor once per axis squares it, and at a
# corner that leaves the kart accelerating INTO the corner instead of rebounding.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const Sim := preload("res://scripts/core/sim.gd")
const Tuning := preload("res://scripts/core/tuning.gd")
const InputState := preload("res://scripts/core/input_state.gd")


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_test_single_axis_clamps_and_rebounds()
	_test_corner_applies_the_factor_once()
	_test_no_bounce_when_inside()
	RVTest.finish(self, "boundary: clamp, rebound, corner applies once", "boundary check(s)")


func _sim() -> RefCounted:
	var t := Tuning.new()
	t.accel = 0.008
	t.max_speed = 0.2
	t.reverse_factor = 0.5
	t.friction = 0.96
	t.turn_rate = 0.04
	t.steer_threshold = 0.01
	t.bounce_factor = -0.3
	t.drivable_extent = 90.0
	t.speedo_max = 120.0
	var s := Sim.new()
	s.tuning = t
	s.input = InputState.new()
	return s


func _test_single_axis_clamps_and_rebounds() -> void:
	var s := _sim()
	var limit: float = s.tuning.drivable_extent
	# facing +Z, just short of the limit, moving fast enough to cross it
	s.yaw = 0.0
	s.pos_z = limit - 0.05
	s.velocity = 0.2
	s.step()
	_check(s.pos_z == limit, "the crossing axis is clamped exactly to the limit")
	_check(s.bounced_this_tick, "the tick reports that it bounced")
	_check(s.velocity < 0.0, "velocity is reversed by the bounce")
	_check(absf(s.velocity) < 0.2, "and reduced in magnitude, not increased")


## The one the design document warns about.
func _test_corner_applies_the_factor_once() -> void:
	var s := _sim()
	var limit: float = s.tuning.drivable_extent
	# heading into the +X/+Z corner, both axes crossing on the same tick
	s.yaw = TAU / 8.0
	s.pos_x = limit - 0.01
	s.pos_z = limit - 0.01
	s.velocity = 0.2
	var entry_speed: float = absf(s.velocity)
	s.step()

	_check(s.pos_x == limit and s.pos_z == limit, "both axes clamp to the limit")
	_check(s.bounced_this_tick, "the corner reports a bounce")

	# Applied once: |v| = 0.2 * 0.96 * 0.3. Applied per axis it would be
	# 0.2 * 0.96 * 0.09 — squaring the factor — which is SMALLER here, but the
	# sign is what matters: squaring a negative factor makes it positive, so the
	# kart would leave the corner still travelling into it.
	var once: float = 0.2 * s.tuning.friction * absf(s.tuning.bounce_factor)
	var squared: float = 0.2 * s.tuning.friction * s.tuning.bounce_factor * s.tuning.bounce_factor

	_check(
		absf(absf(s.velocity) - once) < 1e-12,
		"the factor is applied exactly once (|v|=%.9f, want %.9f)" % [absf(s.velocity), once]
	)
	_check(
		absf(s.velocity - squared) > 1e-12,
		"the result is not the per-axis squared value (%.9f)" % squared
	)
	_check(s.velocity < 0.0, "the kart rebounds rather than continuing into the corner")
	_check(absf(s.velocity) < entry_speed, "the corner impact costs speed, never adds it")


func _test_no_bounce_when_inside() -> void:
	var s := _sim()
	s.pos_z = 0.0
	s.velocity = 0.2
	s.step()
	_check(not s.bounced_this_tick, "no bounce well inside the field")
	_check(s.velocity > 0.0, "velocity keeps its sign")
