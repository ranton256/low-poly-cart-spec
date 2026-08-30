# G2 — the Acceptance Checklist as fourteen named cases (V7), each quoting
# its item and asserting the stated tolerance as a LITERAL. The machinery
# behind every item is proven across the other suites; this file is the one
# place a reviewer reads fourteen names against fourteen items and sees the
# document's own numbers. Plus the lap-gate ordering discriminator (Backlog).
#
#   godot --headless -s tests/conformance_test.gd
#
# Item 14 is split per CONSTRAINTS §6 Determinism and the reference frame:
# 14a (three batchings agree, here) and 14b (three refresh rates in the real
# game — tools/refresh_probe.gd, windowed, its run recorded in the change).
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const MainScene := preload("res://scenes/main.tscn")
const Sim := preload("res://scripts/core/sim.gd")
const InputState := preload("res://scripts/core/input_state.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")
const ChaseCamera := preload("res://scripts/core/chase_camera.gd")
const Collision := preload("res://scripts/core/collision.gd")
const Normalise := preload("res://scripts/core/normalise.gd")

const ITEMS := 14
const GO_TICK := 240  # item 1: 4.0 s at 60 Hz; ± 0.1 s is ± 6 ticks
const TIMING_TOL := 0.05  # items 4: the checklist's ± 0.05 s
const KART_BOX := AABB(Vector3(-1.1, 0.0, -1.18), Vector3(2.2, 1.2, 2.36))

var _root: Node3D = null
var _ran: int = 0


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	OS.set_environment("LPC_LAYOUT_FILE", "user://conformance_layout.json")
	await process_frame
	_root = MainScene.instantiate() as Node3D
	get_root().add_child(_root)
	await process_frame

	_item_01_boot_to_countdown_control_at_four_seconds()
	_item_02_every_prop_grounded_at_every_scale()
	_item_03_drives_the_direction_it_faces()
	_item_04_dial_timings()
	_item_05_steering_gates()
	_item_06_collision_stop_shove_shake_and_escape()
	_item_07_boundary_soft_rebound_grass_beyond()
	_item_08_camera_lag_settle_widen()
	_item_09_minimap()
	_item_10_lap_banking_rules()
	await _item_11_focus_release()
	_item_12_layout_round_trip()
	_item_13_live_tuning_next_tick()
	_item_14_frame_rate_independence_headless_half()
	_ordering_discriminator()

	_check(_ran == ITEMS, "all %d checklist items ran as named cases (%d)" % [ITEMS, _ran])
	OS.set_environment("LPC_LAYOUT_FILE", "")
	get_root().remove_child(_root)
	_root.free()
	RVTest.finish(
		self, "conformance: 14 items at their stated tolerances ok", "conformance check(s)"
	)


func _sim() -> RefCounted:
	var s := Sim.new()
	s.tuning = TuningLoader.load_tuning()
	s.input = InputState.new()
	s.race.start_racing_immediately()
	return s


## "boots to a countdown with no user interaction … hands over control
## 4.0 s ± 0.1 s later, on the GO! frame."
func _item_01_boot_to_countdown_control_at_four_seconds() -> void:
	_ran += 1
	var s := Sim.new()
	s.tuning = TuningLoader.load_tuning()
	s.input = InputState.new()
	s.race.mark_world_ready()
	s.input.forward = true
	var control_tick := -1
	for i in range(GO_TICK + 7):
		s.step()
		if control_tick < 0 and s.velocity > 0.0:
			control_tick = i + 1
	_check(
		absf(control_tick - GO_TICK) <= 6,
		"item 1: control at tick %d — 4.0 s ± 0.1 s (± 6 ticks) after boot" % control_tick
	)
	_check(_root.sim.race.state != 0, "item 1: the real boot reached the countdown unaided")


## "Every prop stands exactly on the ground — none floating, none sunk — at
## every random scale."
func _item_02_every_prop_grounded_at_every_scale() -> void:
	_ran += 1
	var field: Node3D = _root.props
	var checked := 0
	var sunk := 0
	for generation in range(2):
		for i in range(field.records.size()):
			var record: RefCounted = field.records[i]
			var node: Node3D = field.get_child(i) as Node3D
			# World bottom of the visual = node Y + authored bottom × scale;
			# grounded means that lands at exactly zero, at whatever scale this
			# placement rolled. The record's grounded box must agree.
			var authored: AABB = field._boxes[record.asset]
			var world_bottom: float = node.position.y + authored.position.y * node.scale.x
			if absf(world_bottom) > 0.001 or absf(record.normalised.box.position.y) > 0.001:
				sunk += 1
			checked += 1
		if generation == 0:
			_root.regenerate_world()
	_check(
		sunk == 0 and checked > 100,
		"item 2: %d props over two generations grounded — none floating, none sunk" % checked
	)


## "drives in the direction it visually faces, at all headings, forward and
## reverse." (The visual half — the derived yaw correction — is pinned by
## check_kart_conformance.py and kart_test; this asserts motion ∥ heading.)
func _item_03_drives_the_direction_it_faces() -> void:
	_ran += 1
	var misaligned := 0
	for heading in range(8):
		for sign in [1, -1]:
			var s := _sim()
			s.yaw = heading * PI / 4.0
			s.input.forward = sign > 0
			s.input.reverse = sign < 0
			var x0: float = s.pos_x
			var z0: float = s.pos_z
			for _i in range(30):
				s.step()
			var moved := Vector2(s.pos_x - x0, s.pos_z - z0).normalized()
			var facing: Vector2 = Vector2(sin(s.yaw), cos(s.yaw)) * float(sign)
			if moved.dot(facing) < 0.999:
				misaligned += 1
	_check(misaligned == 0, "item 3: motion parallels the heading at 8 headings, both senses")


## "passes 90% of steady-state speed — dial 103 — within 0.94 s ± 0.05 s …
## first reads 115 at 2.60 s ± 0.05 s and stays … falls below steerThreshold
## in 1.21 s ± 0.05 s."
func _item_04_dial_timings() -> void:
	_ran += 1
	var s := _sim()
	s.pos_z = -80.0  # the run needs ~91 wu of road; keep the boundary out of it
	s.input.forward = true
	var t103 := -1
	var t115 := -1
	for i in range(400):
		s.step()
		if t103 < 0 and s.speedo_readout() >= 103:
			t103 = i + 1
		if t115 < 0 and s.speedo_readout() >= 115:
			t115 = i + 1
	_check(
		absf(t103 / 60.0 - 0.94) <= TIMING_TOL,
		"item 4: dial 103 at %.3f s (0.94 ± 0.05)" % (t103 / 60.0)
	)
	_check(
		absf(t115 / 60.0 - 2.60) <= TIMING_TOL,
		"item 4: dial first reads 115 at %.3f s (2.60 ± 0.05)" % (t115 / 60.0)
	)
	var stays := true
	for _i in range(120):
		s.step()
		if s.speedo_readout() != 115:
			stays = false
	_check(stays, "item 4: and stays there")
	s.input.forward = false
	var t_coast := -1
	for i in range(200):
		s.step()
		if absf(s.velocity) <= s.tuning.steer_threshold:
			t_coast = i + 1
			break
	_check(
		absf(t_coast / 60.0 - 1.21) <= TIMING_TOL,
		"item 4: coast below steerThreshold at %.3f s (1.21 ± 0.05)" % (t_coast / 60.0)
	)


## "Steering is impossible from a standstill and reverses sense when
## reversing."
func _item_05_steering_gates() -> void:
	_ran += 1
	var s := _sim()
	s.input.left = true
	for _i in range(30):
		s.step()
	_check(s.yaw == 0.0, "item 5: no steering from a standstill")
	s.input.forward = true
	for _i in range(60):
		s.step()
	var forward_sense := signf(s.yaw)
	var r := _sim()
	r.input.left = true
	r.input.reverse = true
	for _i in range(60):
		r.step()
	_check(
		forward_sense > 0.0 and signf(r.yaw) < 0.0,
		"item 5: the same stick turns the opposite way in reverse"
	)


## "Hitting a tree stops the kart dead, shoves it clear, and shakes the
## camera — and the kart can always reverse back out of a single prop, at any
## approach angle. Being pinned between two near-touching props is accepted;
## Reset Kart frees it."
func _item_06_collision_stop_shove_shake_and_escape() -> void:
	_ran += 1
	var s := _sim()
	s.kart_normalised = Normalise.to_target_height(KART_BOX, 1.2)
	var prop := Collision.Prop.new()
	prop.asset = "tree"
	prop.box = AABB(Vector3(-1.0, 0.0, 9.0), Vector3(2.0, 2.0, 2.0))
	s.props = [prop]
	s.input.forward = true
	var hit_tick := -1
	for i in range(300):
		s.step()
		if s.last_hit != null:
			hit_tick = i
			break
	_check(hit_tick > 0 and s.velocity == 0.0, "item 6: stopped dead on contact")
	# Twin cameras, identical histories; jolt one. Any difference is the shake
	# and nothing else — ordinary chase motion cannot pass this.
	var calm := ChaseCamera.new()
	var shaken := ChaseCamera.new()
	for camera: RefCounted in [calm, shaken]:
		camera.tuning = s.tuning
		camera.seed_shake(7)
		for _i in range(30):
			camera.step(s.pos_x, s.pos_z, s.yaw, 0.0)
	shaken.jolt()
	calm.step(s.pos_x, s.pos_z, s.yaw, 0.0)
	shaken.step(s.pos_x, s.pos_z, s.yaw, 0.0)
	var displaced := Vector2(shaken.pos_x - calm.pos_x, shaken.pos_y - calm.pos_y).length()
	_check(displaced > 0.0, "item 6: the collision jolts the camera — its unjolted twin stays put")
	s.input.forward = false
	s.input.reverse = true
	var freed := false
	for _i in range(120):
		s.step()
		if s.last_hit == null and absf(s.velocity) > 0.01:
			freed = true
	_check(freed, "item 6: reversing backs out of a single prop")
	# The pin, accepted; Reset Kart frees it (asserted in depth in layout_test).
	s.reset_kart()
	_check(s.pos_x == 0.0 and s.pos_z == 0.0, "item 6: Reset Kart is the pin's escape")


## "Driving to the boundary produces a soft rebound with grass still visible
## beyond."
func _item_07_boundary_soft_rebound_grass_beyond() -> void:
	_ran += 1
	var s := _sim()
	s.input.forward = true
	var v_at_wall := 0.0
	var rebounded := false
	for _i in range(700):
		s.step()
		if s.bounced_this_tick and not rebounded:
			rebounded = true
			v_at_wall = s.velocity
	_check(
		rebounded and v_at_wall < 0.0 and absf(v_at_wall) < 0.1,
		"item 7: a soft rebound at the boundary (v=%.4f after ×−0.3)" % v_at_wall
	)
	var skirt: MeshInstance3D = _root.find_child("GroundSkirt", true, false) as MeshInstance3D
	_check(
		skirt != null and (skirt.mesh as PlaneMesh).size.x / 2.0 > 90.0 + 150.0,
		"item 7: grass beyond every boundary, past fog's end (the A11 skirt)"
	)


## "The camera lags through turns and settles behind the kart, and the field
## of view visibly widens with speed."
func _item_08_camera_lag_settle_widen() -> void:
	_ran += 1
	var camera := ChaseCamera.new()
	camera.tuning = TuningLoader.load_tuning()
	camera.seed_shake(7)
	for _i in range(200):
		camera.step(0.0, 0.0, 0.0, 0.0)
	var settled_x: float = camera.pos_x
	camera.step(10.0, 0.0, 0.0, 0.0)
	var first_step := absf(camera.pos_x - settled_x)
	_check(first_step > 0.0 and first_step < 10.0, "item 8: the camera lags, not teleports")
	var fov_rest: float = camera.fov
	for _i in range(200):
		camera.step(10.0, 0.0, 0.0, 0.96)
	_check(
		fov_rest == camera.tuning.fov_base and absf(camera.fov - 89.4) < 0.5,
		"item 8: FOV %s° at rest, %.1f° at speed (≈89.4)" % [fov_rest, camera.fov]
	)


## "The minimap tracks the kart, stays north-up, shows the marker and heading
## arrow, and those markers are invisible in the main view."
func _item_09_minimap() -> void:
	_ran += 1
	var cam: Camera3D = _root.get_node("Minimap/Viewport/Camera") as Camera3D
	var disc: Node3D = _root.get_node("MinimapMarkers/Disc") as Node3D
	var arrow: Node3D = _root.get_node("MinimapMarkers/Arrow") as Node3D
	_check(
		cam.global_basis.x.is_equal_approx(Vector3(1, 0, 0)) and disc != null and arrow != null,
		"item 9: orientation-fixed, marker and arrow present"
	)
	_check(
		(_root.chase_camera.cull_mask & (1 << 1)) == 0 and (cam.cull_mask & (1 << 1)) != 0,
		"item 9: the markers are invisible in the main view — masked, not moved"
	)


## "Crossing the white band northbound after 5 s banks a lap, freezes TIME on
## it for 0.5 s, flashes a new best in green when appropriate, then restarts
## the clock. Crossing it southbound under power banks nothing."
func _item_10_lap_banking_rules() -> void:
	_ran += 1
	var s := _sim()
	for _i in range(301):
		s.step()
	s.pos_z = -3.0
	s.input.forward = true
	for _i in range(120):
		s.step()
		if s.lap.banked_this_tick:
			break
	s.input.forward = false
	_check(s.lap.banked_seconds >= 5.0, "item 10: northbound after 5 s banks")
	_check(s.lap.hold_ticks == 30, "item 10: TIME freezes for 0.5 s (30 ticks)")
	_check(s.lap.best_flash_ticks == 60, "item 10: the first best flashes for 1.0 s")
	var southbound := _sim()
	for _i in range(301):
		southbound.step()
	southbound.yaw = PI
	southbound.pos_z = 8.0
	southbound.input.forward = true
	for _i in range(90):
		southbound.step()
	_check(southbound.lap.banked_seconds < 0.0, "item 10: southbound under power banks nothing")


## "Releasing focus mid-throttle stops the kart from driving away."
func _item_11_focus_release() -> void:
	_ran += 1
	_root.sim.race.start_racing_immediately()
	for _i in range(30):
		Input.action_press("accelerate")
		await physics_frame
	var moving: float = _root.sim.velocity
	_root.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not _root.input.forward, "item 11: the held throttle is released on the spot")
	Input.action_release("accelerate")
	for _i in range(60):
		await physics_frame
	_check(
		moving > 0.05 and _root.sim.velocity < moving * 0.2,
		"item 11: focus loss releases the throttle and the kart coasts down"
	)


## "Saving and reloading a layout reproduces the identical world, repeatably."
func _item_12_layout_round_trip() -> void:
	_ran += 1
	var field: Node3D = _root.props
	var before: Array = []
	for record in field.records:
		before.append([record.asset, record.x, record.z])
	_check(_root.save_layout(), "item 12: save succeeds")
	_root.regenerate_world()
	_check(_root.load_layout(), "item 12: load succeeds")
	var same: bool = field.records.size() == before.size()
	for i in range(before.size()):
		var record: RefCounted = field.records[i]
		if record.asset != before[i][0] or absf(record.x - before[i][1]) > 0.001:
			same = false
	_check(same, "item 12: the identical world, repeatably (byte-cycles in layout_test)")


## "Changing accel, friction, turnRate, or maxSpeed at runtime alters
## handling on the next tick, with no restart."
func _item_13_live_tuning_next_tick() -> void:
	_ran += 1
	var s := _sim()
	s.input.forward = true
	for _i in range(50):
		s.step()
	var v: float = s.velocity
	s.tuning.accel *= 2.0
	var expected: float = minf(v + s.tuning.accel, s.tuning.max_speed) * s.tuning.friction
	s.step()
	_check(
		absf(s.velocity - expected) < 1e-12,
		"item 13: a changed accel is in force on the very next tick"
	)


## "A scripted 60-second input sequence replayed at 30, 60, and 144 frames
## per second ends with the kart within 0.5 wu … within 0.05 s …" — the
## headless half: three tick-batchings agree exactly (14a). The refresh-rate
## half runs windowed in tools/refresh_probe.gd (14b), its run recorded.
func _item_14_frame_rate_independence_headless_half() -> void:
	_ran += 1
	var finals: Array = []
	for batch: int in [1, 2, 4]:
		var s := _sim()
		var tick := 0
		while tick < 3600:
			for _b in range(batch):
				s.input.forward = (tick % 7) != 0
				s.input.left = (tick % 11) < 4
				s.step()
				tick += 1
		finals.append(s.stats_line())
	_check(
		finals[0] == finals[1] and finals[1] == finals[2],
		"item 14 (headless half): three batchings agree byte-for-byte over 60 s"
	)


## The Backlog's ordering discriminator: a push-out carries the kart INTO the
## band on a tick whose stage-5 displacement independently qualifies — the
## lap banks ONLY because the gate observes the post-collision position. A
## gate moved before stage 7 sees z≈3.95, outside the band, and this fails.
func _ordering_discriminator() -> void:
	var s := _sim()
	s.kart_normalised = Normalise.to_target_height(KART_BOX, 1.2)
	for _i in range(301):
		s.step()
	var prop := Collision.Prop.new()
	prop.asset = "shover"
	prop.box = AABB(Vector3(-1.0, 0.0, 1.9), Vector3(2.0, 2.0, 2.0))
	s.props = [prop]
	s.pos_z = 3.82
	s.velocity = 0.15  # legitimate northbound power: step-5 dz ≈ 0.144 > threshold
	s.step()
	_check(
		s.pos_z > 4.0 and s.lap.banked_this_tick,
		(
			(
				"ordering: the push carried the kart into the band (z=%.2f) and the gate, "
				+ "running LAST, banked the qualifying crossing"
			)
			% s.pos_z
		)
	)
