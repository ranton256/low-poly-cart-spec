# TEMPLATE — the shape every headless suite takes.
#
#   godot --headless -s tests/<name>.gd
#
# Copy tests/harness.gd alongside this and fill in the assertions. The harness
# is the whole framework: no addon, no dependency, no runner.
extends SceneTree

# preload, NOT class_name: global class names come from a cache the editor
# writes, so a newly added class is invisible to `godot -s` on a fresh clone.
const RVTest := preload("res://tests/harness.gd")


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	# await process_frame FIRST if you need autoloads — they DO load under -s,
	# and an autoload that seeds RNG does it on a deferred first frame, so
	# seeding before that frame gets overwritten. See GOTCHAS.
	# await process_frame

	# TODO: assertions. Record every failure rather than aborting on the first —
	# a list is what a fix needs; the first failure alone is a guessing game.
	_check(true, "TODO: replace with real assertions")

	RVTest.finish(self, "<what passed, in one line>", "<thing>(s)")
