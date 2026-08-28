# TEMPLATE — drive the real UI headlessly with synthesized input.
#
# No UI test framework. Two helpers do the whole job: send a key, and wait for a
# scene to appear. With those you can assert every transition, purchase, save
# write, and menu state in the actual scenes the player uses.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


## Press and release. Send BOTH: a press with no release leaves the action
## latched, and the next scene reads it as input the player never gave.
func _key(keycode: Key, shift := false) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = keycode
	down.keycode = keycode
	down.shift_pressed = shift
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventKey.new()
	up.physical_keycode = keycode
	up.keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)


## Wait for a named scene, with a frame budget rather than a wall-clock timeout,
## so a slow machine cannot flake the test.
func _wait_scene(name: String, timeout_frames := 300) -> bool:
	for i in range(timeout_frames):
		await process_frame
		if current_scene and current_scene.name == name:
			return true
	return false


func _init() -> void:
	# Redirect saves BEFORE anything can load one. A suite that writes the real
	# save file will eventually destroy someone's progress — see GOTCHAS.
	OS.set_environment("LPC_SAVE_FILE", "user://save_test.cfg")
	_run()


func _run() -> void:
	await process_frame  # let autoloads finish _ready

	# Free any autoload whose animation runs on WALL-CLOCK time (scene wipes,
	# fades). Headless frames arrive faster than the tween expects and the
	# transition never completes, so scene changes appear to hang.
	# var wipe := root.get_node_or_null("/root/Transition")
	# if wipe: wipe.free()

	# Grab the REAL autoload. A manually added twin is renamed on collision, and
	# the scenes talk to the original — so you would be configuring a node
	# nothing reads.
	# var cfg: Node = root.get_node("/root/Config")

	change_scene_to_file("res://scenes/menu.tscn")
	_check(await _wait_scene("Menu"), "menu loads")

	# TODO: walk the flow. Assert state at each step, not just arrival:
	#   _key(KEY_ENTER)
	#   _check(await _wait_scene("Game"), "menu -> game")
	#   _check(current_scene.sim.level == 1, "starts at level 1")
	#
	# Send exactly ONE confirm per screen. An extra press re-enters the next
	# scene, which re-runs its setup and can silently consume RNG draws — a real
	# bug that cost a day: a stray Enter burned 300 draws and desynced the seed.

	RVTest.finish(self, "All flow checks passed.", "flow check(s)")
