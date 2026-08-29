# Applies the chase camera to a Camera3D.
#
# A READER, and a thin one. Everything about where the camera goes, what it looks
# at and how wide its view is lives in scripts/core/chase_camera.gd; this file
# copies those numbers onto a node. If a calculation ever appears here, it is in
# the wrong place — the behaviour has one home so that it has one test.
#
# NOT INTERPOLATED, and that is deliberate (design D3). The kart is drawn between
# simulation states; the camera is not. The camera is already a smoothing filter
# over the kart's motion with a time constant of 0.2 s, and interpolating it would
# add a second, much shorter smoothing that nobody specified — while decoupling
# the settling time the suite measures from the one the player sees.
extends Camera3D


## Called by the composition root each frame, after the frame's ticks.
func apply(state: RefCounted, near_clip: float, far_clip: float) -> void:
	# Nothing to apply until the camera has been stepped at least once. Godot
	# rejects a field of view outside 1..179, and an unstepped camera reports
	# zero — the per-frame callback can run before the first fixed-rate one.
	if state == null or state.fov < 1.0:
		return
	near = near_clip
	far = far_clip
	fov = state.fov
	var eye := Vector3(state.pos_x, state.pos_y, state.pos_z)
	var target := Vector3(state.aim_x, state.aim_y, state.aim_z)
	# A camera sitting exactly on its aim point has no look direction, which Godot
	# reports as an error rather than a warning. It cannot happen with the
	# document's offsets, and costs nothing to exclude.
	if eye.distance_to(target) < 0.001:
		return
	look_at_from_position(eye, target, Vector3.UP)
	current = true
