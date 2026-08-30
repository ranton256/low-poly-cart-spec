# Windowed performance probe (CONSTRAINTS §8 Performance and size budgets):
# boots the real game, reports cold-start-to-countdown and the average frame
# time over 240 racing frames against the 16.7 ms budget. Windowed — never in
# test.sh; run when a look change might have spent the frame budget.
#
#   godot -s tools/fps_probe.gd
extends SceneTree


func _init() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	await process_frame
	var root: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	get_root().add_child(root)
	await process_frame
	while root.sim.race.state == 0:
		await physics_frame
	print("fps probe: boot to countdown in %d ms from engine start" % Time.get_ticks_msec())
	root.sim.race.start_racing_immediately()
	for _i in range(90):
		Input.action_press("accelerate")
		await physics_frame
	var frames := 0
	var t0 := Time.get_ticks_usec()
	for _i in range(240):
		Input.action_press("accelerate")
		await process_frame
		frames += 1
	var us := Time.get_ticks_usec() - t0
	print(
		(
			"fps probe: %d racing frames, avg %.2f ms/frame (%.0f fps), budget 16.7 ms"
			% [frames, us / 1000.0 / frames, 1000000.0 * frames / us]
		)
	)
	quit(0)
