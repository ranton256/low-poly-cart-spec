# Shared capture plumbing for the windowed tools (drive_capture, lap_capture):
# the held-input re-press, and the provably-fresh frame grab. One home, so a
# tool cannot carry half the hardening (the M6 Critic found lap_capture had
# the post-draw await but not the staleness tripwire).
extends RefCounted


## Re-press the held actions — the unfocused window clears held input every
## frame, correctly, so a synthetic hold must be re-established per frame.
static func press(actions: PackedStringArray) -> void:
	for action in actions:
		if InputMap.has_action(action):
			Input.action_press(action)


static func release(actions: PackedStringArray) -> void:
	for action in actions:
		if InputMap.has_action(action):
			Input.action_release(action)


## Grab a frame that is provably fresh: await the renderer's post-draw
## signal, then reject the staleness signature this project has actually
## produced — the countdown's huge white glyphs at screen centre while the
## sim reports the race well past the GO! linger. Retries re-await the
## renderer; persistent staleness returns null rather than a lie.
static func fresh_frame(tree: SceneTree, root: Node3D, tool_name: String) -> Image:
	for _attempt in range(5):
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var image := tree.get_root().get_texture().get_image()
		if image == null:
			return null
		if not _looks_like_stale_countdown(image, root):
			return image
		printerr("%s: stale countdown frame detected — re-awaiting the renderer" % tool_name)
	printerr("%s: the renderer kept presenting stale frames; nothing written" % tool_name)
	return null


static func _looks_like_stale_countdown(image: Image, root: Node3D) -> bool:
	var race: RefCounted = root.sim.race
	var linger_ticks: int = int(roundf(root.sim.tuning.go_linger * 60.0))
	if not (race.is_racing() and race.ticks_in_state > linger_ticks + 5):
		return false  # a countdown on screen would be legitimate
	var white: int = 0
	for y in range(image.get_height() / 4, image.get_height() / 2, 4):
		for x in range(image.get_width() / 2 - 100, image.get_width() / 2 + 100, 4):
			var pixel := image.get_pixel(x, y)
			if pixel.r > 0.98 and pixel.g > 0.98 and pixel.b > 0.98:
				white += 1
	return white > 40
