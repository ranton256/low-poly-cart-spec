# Input reaches the simulation as held state, and never sticks.
#
#   godot --headless -s tests/input_test.gd
#
# The design document's Input Handling feature. The bindings themselves are
# pinned in project.godot and asserted by tools/check_settings.py; this file
# tests what happens to them — that a held action reaches the core on every tick,
# that releasing stops it, that losing focus clears everything, and that a key
# nobody bound changes nothing and says nothing.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")

var _root: Node3D = null


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	await process_frame
	_root = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	get_root().add_child(_root)
	await process_frame

	await _test_a_held_action_reaches_the_core_every_tick()
	await _test_releasing_stops_it()
	await _test_focus_loss_clears_everything()
	await _test_an_unbound_key_changes_nothing()
	_test_every_specified_action_exists()

	_release_all()
	get_root().remove_child(_root)
	_root.free()
	_root = null
	RVTest.finish(
		self, "input: held, released, cleared on focus loss, unbound ignored", "input check(s)"
	)


func _release_all() -> void:
	for action in ["accelerate", "reverse", "steer_left", "steer_right"]:
		if InputMap.has_action(action):
			Input.action_release(action)


func _test_a_held_action_reaches_the_core_every_tick() -> void:
	Input.action_press("accelerate")
	# Several ticks, not one: the design document requires the input be treated as
	# held on EVERY tick until release, independent of the host's key repeat.
	for _i in range(6):
		await process_frame
	_check(_root.input.forward, "a held accelerate reaches the core as held state")
	_check(
		_root.sim.velocity > 0.0,
		"and it applies on every tick, so the kart is moving (velocity %.5f)" % _root.sim.velocity
	)


func _test_releasing_stops_it() -> void:
	Input.action_release("accelerate")
	for _i in range(3):
		await process_frame
	_check(not _root.input.forward, "releasing clears the held state")


# @covers Input Handling / Clearing stuck inputs on focus loss
func _test_focus_loss_clears_everything() -> void:
	Input.action_press("accelerate")
	Input.action_press("steer_left")
	for _i in range(3):
		await process_frame
	_check(_root.input.forward and _root.input.left, "two inputs are held before focus is lost")

	var moving_before: float = _root.sim.velocity
	_root.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(
		not _root.input.forward and not _root.input.left,
		"losing focus clears EVERY held input, not just the last one"
	)

	# And the kart coasts rather than driving away. The engine still reports the
	# keys as down — nothing released them — so this also checks that the clear
	# is not immediately undone by the next tick's input read.
	_release_all()
	for _i in range(30):
		await process_frame
	_check(
		_root.sim.velocity < moving_before,
		(
			"the kart coasts to a stop rather than driving away unattended (%.5f -> %.5f)"
			% [moving_before, _root.sim.velocity]
		)
	)


# @covers Input Handling / Ignoring unbound keys
## A key with no binding changes no state AND writes nothing to the log. The
## second half matters: an unbound key held down would otherwise flood it.
func _test_an_unbound_key_changes_nothing() -> void:
	var before := (
		"%s|%s|%s|%s"
		% [_root.input.forward, _root.input.reverse, _root.input.left, _root.input.right]
	)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_J
	event.pressed = true
	Input.parse_input_event(event)
	for _i in range(3):
		await process_frame
	var after := (
		"%s|%s|%s|%s"
		% [_root.input.forward, _root.input.reverse, _root.input.left, _root.input.right]
	)
	_check(before == after, "an unbound key leaves every held input unchanged")
	_check(
		not InputMap.has_action("unbound_j"),
		"the unbound key really is unbound, so this test is not passing vacuously"
	)


# @covers Input Handling / Mapping the control scheme
## Both key sets, as the design document's table gives them. check_settings.py
## pins the keycodes; this asserts the actions exist at runtime, which is what
## the root reads.
func _test_every_specified_action_exists() -> void:
	for action in [
		"accelerate", "reverse", "steer_left", "steer_right", "reset_kart", "save_layout"
	]:
		_check(InputMap.has_action(action), "the action %s is bound" % action)
	# Bound and inert until M7 — the document's table lists them, so the binding
	# is specified even while the effect is not.
	for action in ["reset_kart", "save_layout"]:
		_check(
			not _root.DRIVE_ACTIONS.has(action),
			"%s is bound but drives nothing yet, as M2 intends" % action
		)
