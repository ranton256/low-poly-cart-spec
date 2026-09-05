# G2 — the Acceptance Checklist as sixteen named cases (V7), each quoting
# its item and asserting the stated tolerance as a LITERAL. The machinery
# behind every item is proven across the other suites; this file is the one
# place a reviewer reads sixteen names against sixteen items and sees the
# document's own numbers. Plus the lap-gate ordering discriminator (Backlog).
#
# THREE CASES MOVED WITH THE CHECKLIST when amend-gdd-for-checkpoint-circuit
# amended it: item 1 now boots into the SHIPPED CIRCUIT, item 2 reaches the
# random scales through the AUTHORING scatter (the boot world is authored
# content and no longer random at all), item 10 banks on a threaded course with
# no minimum lap time, and item 15 is new.
#
#   godot --headless -s tests/conformance_test.gd
#
# Item 14 is split per CONSTRAINTS §6 Determinism and the reference frame:
# 14a (three batchings agree, here) and 14b (three refresh rates in the real
# game — tools/refresh_probe.gd, windowed, its run recorded in the change).
#
# ITEM 16 IS SPLIT THE SAME WAY and for the same reason: its cross-rate clause
# needs the real game at three real refresh rates, so it rides the SAME probe
# record 14b does — the probe grew a per-pass cue-stream hash in
# add-audio-playback, and _item_16 parses that record for three agreeing
# hashes. Its other three clauses are headless and are asserted here.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const MainScene := preload("res://scenes/main.tscn")
const Sim := preload("res://scripts/core/sim.gd")
const InputState := preload("res://scripts/core/input_state.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")
const ChaseCamera := preload("res://scripts/core/chase_camera.gd")
const Collision := preload("res://scripts/core/collision.gd")
const Normalise := preload("res://scripts/core/normalise.gd")
const ArtTuning := preload("res://scripts/art_tuning.gd")
const AudioView := preload("res://scripts/view/audio_view.gd")
const AudioCues := preload("res://scripts/core/audio_cues.gd")
const Circuit := preload("res://scripts/core/circuit.gd")
const LayoutIO := preload("res://scripts/world/layout_io.gd")

const ITEMS := 16
const GO_TICK := 240  # item 1: 4.0 s at 60 Hz; ± 0.1 s is ± 6 ticks
const TIMING_TOL := 0.05  # items 4: the checklist's ± 0.05 s
const KART_BOX := AABB(Vector3(-1.1, 0.0, -1.18), Vector3(2.2, 1.2, 2.36))
const RECORDED_14B := "res://docs/progress/2026-09-04-refresh-probe.txt"
## tests/lap_gate_test.gd's LAP_PHASES, cycled — the drive item 14 replays.
## Baked from the shipped circuit by tools/author_first_light.gd, restated here
## rather than imported for the same reason main.gd restates it: this file is
## read as the checklist, and the drive it replays must be legible in it.
const LAP_SCRIPT: Array = [
	[true, false, false, 116],
	[true, true, false, 28],
	[true, false, true, 3],
	[true, false, false, 89],
	[true, true, false, 1],
	[true, false, false, 8],
	[true, true, false, 31],
	[true, false, true, 2],
	[true, false, false, 34],
	[true, false, true, 1],
	[true, false, false, 131],
	[true, true, false, 28],
	[true, false, false, 11],
	[true, false, true, 1],
	[true, false, false, 114],
	[true, false, true, 1],
	[true, true, false, 12],
	[true, false, true, 2],
	[true, false, false, 123],
	[true, true, false, 1],
	[true, false, false, 19],
	[true, true, false, 31],
	[true, false, false, 56],
	[true, true, false, 1],
	[true, false, false, 42],
	[true, true, false, 42],
	[true, false, true, 2],
	[true, false, false, 38],
	[true, false, true, 1],
	[true, false, false, 14],
	[true, false, true, 29],
	[true, true, false, 3],
	[true, false, true, 1],
	[true, false, false, 9],
	[true, false, true, 1],
	[true, false, false, 49],
]

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
	_item_14_frame_rate_independence()
	await _item_15_the_shipped_circuit_is_the_game()
	_item_16_the_game_speaks_the_same_way_every_time()
	_ordering_discriminator()

	_check(_ran == ITEMS, "all %d checklist items ran as named cases (%d)" % [ITEMS, _ran])
	OS.set_environment("LPC_LAYOUT_FILE", "")
	get_root().remove_child(_root)
	_root.free()
	RVTest.finish(
		self, "conformance: 16 items at their stated tolerances ok", "conformance check(s)"
	)


func _sim() -> RefCounted:
	var s := Sim.new()
	s.tuning = TuningLoader.load_tuning()
	s.input = InputState.new()
	s.race.start_racing_immediately()
	return s


## "The game boots into the shipped circuit, to a countdown with no user
## interaction and no configuration, and hands over control 4.0 s ± 0.1 s
## later, on the GO! frame." (Amended: the world is the shipped circuit.)
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
	# INTO THE SHIPPED CIRCUIT, not a scatter that resembles one: the armed
	# circuit is the committed file's, and the field is the file's own props.
	var document: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(LayoutIO.SHIPPED_CIRCUIT_PATH)
	)
	var shipped: Array = document["props"]
	var circuit: RefCounted = _root.sim.circuit
	var placed := true
	for i in range(mini(_root.props.records.size(), shipped.size())):
		var record: RefCounted = _root.props.records[i]
		var position: Array = (shipped[i] as Dictionary)["position"]
		if (
			record.asset != (shipped[i] as Dictionary)["asset"]
			or absf(record.x - float(position[0])) > 0.001
			or absf(record.z - float(position[2])) > 0.001
		):
			placed = false
	_check(
		(
			circuit.has_gates()
			and circuit.circuit_name == "first-light"
			and _root.props.records.size() == shipped.size()
			and placed
		),
		(
			"item 1: and it booted into the SHIPPED CIRCUIT — %s, %d gates, the file's own %d props"
			% [circuit.circuit_name, circuit.gate_count(), shipped.size()]
		)
	)


## "Every prop stands exactly on the ground — none floating, none sunk — at
## every random scale."
##
## THROUGH THE AUTHORING SCATTER, twice. The boot world is authored content
## now, so "every random scale" is no longer a property of it — the random
## scales live in the scatter this checks directly, which is also the machinery
## every circuit's props are authored from.
func _item_02_every_prop_grounded_at_every_scale() -> void:
	_ran += 1
	var field: Node3D = _root.props
	var checked := 0
	var sunk := 0
	for generation in range(2):
		_root.regenerate_world()
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
	_check(
		sunk == 0 and checked > 100,
		"item 2: %d props over two fresh scatters grounded — none floating, none sunk" % checked
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
	# The mask is a setting; the behaviour is which camera RENDERS. The world
	# scene's placeholder ships current=true and unmasked, and it held the
	# viewport through the whole pre-race phase until M8's grazing capture
	# caught the disc on screen — so assert the ACTIVE camera, in this
	# pre-race state, is the masked one.
	var active: Camera3D = get_root().get_camera_3d()
	_check(
		active != null and (active.cull_mask & (1 << 1)) == 0,
		"item 9: and the camera actually rendering — pre-race included — carries the mask"
	)


## "Crossing the white band northbound banks a lap ONLY when every gate has
## been passed in order — with no minimum lap time — freezes TIME on it for
## 0.5 s, flashes a new best in green when appropriate, then restarts the
## clock. Crossing it southbound under power, or without the course threaded,
## banks nothing." (Item 10 as amended.)
func _item_10_lap_banking_rules() -> void:
	_ran += 1
	# UNTHREADED, and given every chance: the shipped circuit armed, a long
	# clock behind it, and a clean northbound crossing of the REAL band.
	var unthreaded := _sim()
	unthreaded.arm_circuit(LayoutIO.read_circuit(LayoutIO.SHIPPED_CIRCUIT_PATH))
	for _i in range(401):
		unthreaded.step()
	unthreaded.pos_z = -3.0
	unthreaded.input.forward = true
	for _i in range(120):
		unthreaded.step()
	unthreaded.input.forward = false
	_check(unthreaded.pos_z > 6.0, "item 10: the unthreaded kart crossed the band")
	_check(
		unthreaded.lap.banked_seconds < 0.0 and unthreaded.lap.clock_seconds() > 5.0,
		(
			"item 10: %.2f s of clock and a clean crossing bank NOTHING unthreaded"
			% unthreaded.lap.clock_seconds()
		)
	)

	# THREADED, and fast: one gate on the way to the line, the whole lap inside
	# the retired 5 s minimum — which is the point, there is no minimum.
	var s := _sim()
	var course := Circuit.new()
	course.circuit_name = "item10"
	course.add_gate(0.0, -2.0, 0.0, 10.0)
	s.arm_circuit(course)
	s.pos_z = -4.0
	s.input.forward = true
	for _i in range(200):
		s.step()
		if s.lap.banked_this_tick:
			break
	s.input.forward = false
	_check(
		s.lap.banked_seconds > 0.0 and s.lap.banked_seconds < 5.0,
		"item 10: a threaded lap banks in %.2f s — no minimum applies" % s.lap.banked_seconds
	)
	_check(s.lap.hold_ticks == 30, "item 10: TIME freezes for 0.5 s (30 ticks)")
	_check(s.lap.best_flash_ticks == 60, "item 10: the first best flashes for 1.0 s")
	_check(s.circuit.cursor == 1, "item 10: and banking returns the cursor to gate 1")

	var southbound := _sim()
	southbound.arm_circuit(course)
	southbound.circuit.cursor = 2  # threaded: the only thing left to refuse is the direction
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
## The FULL recorded transform per prop — asset, x, z, yaw, and the
## normalised box — because "identical" quantified over half the fields is
## the weaker-property trap (the M8 Critic proved a z-mirrored world passed
## the first draft of this case). Byte-level cycles stay in layout_test.
func _item_12_layout_round_trip() -> void:
	_ran += 1
	var field: Node3D = _root.props
	var before: Array = []
	for record in field.records:
		before.append([record.asset, record.x, record.z, record.yaw, record.normalised.box])
	_check(_root.save_layout(), "item 12: save succeeds")
	_root.regenerate_world()
	_check(_root.load_layout(), "item 12: load succeeds")
	var same: bool = field.records.size() == before.size()
	for i in range(before.size()):
		var record: RefCounted = field.records[i]
		var box: AABB = before[i][4]
		if (
			record.asset != before[i][0]
			or absf(record.x - before[i][1]) > 0.001
			or absf(record.z - before[i][2]) > 0.001
			or absf(record.yaw - before[i][3]) > 0.001
			or not record.normalised.box.is_equal_approx(box)
		):
			same = false
	_check(
		same, "item 12: the identical world — every field of every record (bytes in layout_test)"
	)


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
## per second ends with the kart within 0.5 wu … within 0.05 s …"
##
## The item's carrier is tools/refresh_probe.gd — the real game, really
## rendering at three verified frame caps, replaying the same tick-timed
## sequence. "Replayed" MUST mean the same tick-timed inputs (ambiguity
## A14): quantising the input EDGES to frame boundaries instead diverges a
## measured 8.83 wu across 1/2/4-tick batchings — steering edges shifted one
## tick compound through a minute — so no port could hold 0.5 wu under that
## reading. This case holds the item's literals against the probe's RECORDED
## run, and re-proves headlessly that the sequence itself banks and replays
## byte-stably — a sim regression fails here before anyone reruns the probe.
func _item_14_frame_rate_independence() -> void:
	_ran += 1
	var finals: Array = []
	for _run in range(2):
		var s := _sim()
		# ON THE SHIPPED CIRCUIT, like the probe: the recorded run below is the
		# real game, which threads seven gates before it can bank, and the two
		# halves of this item must describe the same drive.
		s.arm_circuit(LayoutIO.read_circuit(LayoutIO.SHIPPED_CIRCUIT_PATH))
		var phase_index := 0
		var phase_start := 0
		for tick in range(3600):
			var phase: Array = LAP_SCRIPT[phase_index % LAP_SCRIPT.size()]
			if tick >= phase_start + int(phase[3]):
				phase_start += int(phase[3])
				phase_index += 1
				phase = LAP_SCRIPT[phase_index % LAP_SCRIPT.size()]
			s.input.forward = phase[0]
			s.input.left = phase[1]
			s.input.right = phase[2]
			s.step()
		finals.append([s.stats_line(), s.lap.best_seconds])
	_check(
		float(finals[0][1]) > 0.0 and finals[0][0] == finals[1][0],
		"item 14: the 60 s script banks a lap and replays byte-stably headless"
	)

	var record := FileAccess.get_file_as_string(RECORDED_14B)
	var pairs := 0
	var within := true
	for line in record.split("\n"):
		if " vs " not in line or "position gap" not in line:
			continue
		pairs += 1
		var gap_wu := float(line.get_slice("position gap ", 1).get_slice(" wu", 0))
		var gap_s := float(line.get_slice("lap gap ", 1).get_slice(" s", 0))
		if gap_wu > 0.5 or gap_s > 0.05 or not line.ends_with("ok"):
			within = false
	_check(
		pairs == 3 and within,
		(
			(
				"item 14: the recorded 30/60/144 fps run holds 0.5 wu and 0.05 s "
				+ "across all %d rate pairs (rerun: godot -s tools/refresh_probe.gd)"
			)
			% pairs
		)
	)
	# RE-PINNED by retune-handling-and-line-clearance, and this one SHOULD move:
	# it pins regenerated content, not a checklist figure. The ×1.25 retune
	# re-baked the drive and the same seven gates are threaded four seconds
	# quicker, so 22.00 became 17.93. The three literals above — 0.5 wu, 0.05 s,
	# three rate pairs — are the checklist's own and did not move.
	_check(
		record.count("best lap 17.93") == 3,
		"item 14: and the recorded run really banked its lap at all three rates"
	)


## "The shipped circuit loads at boot with numbered gates; the next gate is
## indicated on the gate itself, the HUD counter, and the minimap; a lap that
## skips any gate refuses to bank; Restart Circuit rebuilds the authored world,
## returns the kart to the start, and keeps the session best."
##
## Item 15, and the one item that spans the whole change: the file, the
## furniture, the HUD, the minimap, the core's refusal, and the binding. Each
## half is proven in depth elsewhere (circuit_content_test, gate_view_test,
## circuit_test, driver_test); this reads the checklist item against the
## running game, in one place, the way the other fourteen do.
func _item_15_the_shipped_circuit_is_the_game() -> void:
	_ran += 1
	var sim: RefCounted = _root.sim
	var circuit: RefCounted = sim.circuit
	_check(
		circuit.circuit_name == "first-light" and circuit.gate_count() == 7,
		(
			"item 15: the shipped circuit is loaded — %s, %d gates"
			% [circuit.circuit_name, circuit.gate_count()]
		)
	)
	# NUMBERED, each gate carrying its own place in the order.
	var numbered := true
	for number in range(1, circuit.gate_count() + 1):
		var numeral: Label3D = (
			_root.get_node_or_null("Gates/GateFurniture/Gate%d/Numeral" % number) as Label3D
		)
		if numeral == null or numeral.text != str(number):
			numbered = false
	_check(numbered, "item 15: with numbered gates standing in the world")

	# THE NEXT GATE, indicated in all three places the item names.
	circuit.cursor = 2
	# Three frames, not one: process_frame fires around the tree's own _process,
	# and the views are drawn from it — reading a label on the first frame after
	# a state change reads the frame BEFORE the change.
	for _i in range(3):
		await process_frame
	var art: RefCounted = ArtTuning.load_art()
	var next_colour: Color = art.colour("gateNextColour")
	var pylon: MeshInstance3D = (
		_root.get_node("Gates/GateFurniture/Gate2/PylonWest") as MeshInstance3D
	)
	var painted: Color = (pylon.material_override as StandardMaterial3D).albedo_color
	var on_the_gate: bool = Vector3(painted.r, painted.g, painted.b).normalized().is_equal_approx(
		Vector3(next_colour.r, next_colour.g, next_colour.b).normalized()
	)
	var counter: Label = _root.overlay.get_node("GateCounter") as Label
	var markers: Node3D = _root.get_node("GateMarkers") as Node3D
	var next_radius: float = (
		((markers.get_child(1) as MeshInstance3D).mesh as CylinderMesh).top_radius
	)
	var idle_radius: float = (
		((markers.get_child(2) as MeshInstance3D).mesh as CylinderMesh).top_radius
	)
	_check(
		on_the_gate and counter.text == "GATE 2/7" and next_radius > idle_radius,
		(
			"item 15: the next gate is indicated on the gate, the HUD (%s) and the minimap (%.1f vs %.1f wu)"
			% [counter.text, next_radius, idle_radius]
		)
	)
	circuit.cursor = 1

	# A LAP THAT SKIPS A GATE REFUSES TO BANK — under the real band, on the
	# shipped course, with a long clock behind it.
	var skipper := _sim()
	skipper.arm_circuit(LayoutIO.read_circuit(LayoutIO.SHIPPED_CIRCUIT_PATH))
	skipper.circuit.cursor = skipper.circuit.gate_count() - 1  # five of seven passed
	for _i in range(401):
		skipper.step()
	skipper.pos_z = -3.0
	skipper.input.forward = true
	for _i in range(120):
		skipper.step()
	_check(
		skipper.lap.banked_seconds < 0.0,
		(
			"item 15: a lap that skips unpassed gates refuses to bank, %.2f s in"
			% skipper.lap.clock_seconds()
		)
	)

	# RESTART CIRCUIT, through the real binding.
	sim.lap.best_seconds = 11.5
	sim.lap.bests[sim.lap.best_key] = 11.5
	sim.circuit.cursor = 3
	for _i in range(30):
		Input.action_press("accelerate")
		await physics_frame
	Input.action_release("accelerate")
	Input.action_press("regenerate_world")
	await physics_frame
	await physics_frame
	Input.action_release("regenerate_world")
	# "THE SAME AUTHORED ARRANGEMENT, NOT A FRESH SCATTER" — so the world is
	# compared against the arrangement this session is playing, prop for prop and
	# place for place. A count alone cannot tell the two apart: a regenerated
	# field has the same population as the one it replaced, which is precisely
	# what Restart Circuit must not do.
	var authored: Array = _root.loaded_circuit.placements
	var rebuilt: bool = _root.props.prop_count() == authored.size()
	for i in range(mini(_root.props.records.size(), authored.size())):
		var record: RefCounted = _root.props.records[i]
		var placement: RefCounted = authored[i]
		if (
			record.asset != placement.asset
			or absf(record.x - placement.x) > 0.001
			or absf(record.z - placement.z) > 0.001
		):
			rebuilt = false
	_check(
		(
			sim.pos_x == 0.0
			and sim.pos_z == 0.0
			and sim.velocity == 0.0
			and sim.circuit.cursor == 1
			and sim.lap.clock_seconds() < 0.05
			and sim.lap.best_seconds == 11.5
			and rebuilt
		),
		(
			(
				"item 15: Restart Circuit rebuilt the authored world (%d props, each at its own "
				+ "authored place), returned the kart, and kept the session best"
			)
			% _root.props.prop_count()
		)
	)
	sim.lap.best_seconds = -1.0
	sim.lap.bests.clear()


# @covers Audio Feedback / The cue stream is deterministic
## "A scripted run's cue stream — ids, order, tick timestamps, and volumes — is
## identical at 30, 60, and 144 frames per second; the engine note's pitch tracks
## the speed ratio between its named endpoints; a full-speed collision sounds at
## full scale and a boundary rebound never plays the impact cue."
##
## Four clauses, and the first one cannot be run headlessly: three REAL refresh
## rates need a real window, exactly as item 14b does, so it rides the same
## recorded probe run. The other three are arithmetic and are asserted here. The
## deep versions live elsewhere — tests/audio_cue_test.gd owns the emission rules
## and all five negative promises, tests/audio_view_test.gd owns the view's
## parameters — and this case restates the checklist's own literals, which is
## what every other item in this file does.
func _item_16_the_game_speaks_the_same_way_every_time() -> void:
	_ran += 1

	# Clause 1: the cue stream is identical at 30, 60 and 144 fps. Parsed from
	# the recorded windowed run, whose passes must agree on both hashes and on
	# the record count.
	var record := FileAccess.get_file_as_string(RECORDED_14B)
	var stamps := PackedStringArray()
	for line in record.split("\n"):
		# The tool's own lines only. The record carries prose above them, and a
		# looser match read the explanation as a fourth pass — caught by the case
		# failing on its own record, which is the shape item 14's parse uses too.
		if not line.begins_with("refresh_probe:") or "tick hash" not in line:
			continue
		stamps.append(line.get_slice("cue stream ", 1).strip_edges())
	var agree: bool = stamps.size() == 3
	for stamp in stamps:
		if stamp != stamps[0]:
			agree = false
	_check(
		agree and record.count("the cue stream is identical across 30/60/144 fps ok") == 1,
		(
			(
				"item 16: the recorded 30/60/144 fps run produced ONE cue stream — %d passes, %s "
				+ "(rerun: godot -s tools/refresh_probe.gd, windowed)"
			)
			% [stamps.size(), stamps[0] if stamps.size() > 0 else "nothing recorded"]
		)
	)

	# Clause 2: the engine note's pitch tracks the ratio BETWEEN ITS NAMED
	# ENDPOINTS — 0.8 at rest and 1.5 at full ratio, the Audio table's own
	# figures, and monotonically rising in between.
	var art: RefCounted = ArtTuning.load_art()
	_check(
		(
			absf(AudioView.engine_pitch(art, 0.0) - 0.8) < 1e-9
			and absf(AudioView.engine_pitch(art, 1.0) - 1.5) < 1e-9
		),
		(
			"item 16: the engine note runs 0.8 to 1.5 across the ratio (%.4f, %.4f)"
			% [AudioView.engine_pitch(art, 0.0), AudioView.engine_pitch(art, 1.0)]
		)
	)
	var rising := true
	var previous: float = AudioView.engine_pitch(art, 0.0)
	for step in range(1, 11):
		var pitch: float = AudioView.engine_pitch(art, float(step) / 10.0)
		if pitch <= previous:
			rising = false
		previous = pitch
	_check(rising, "item 16: and it TRACKS the ratio — strictly rising at every tenth of it")

	# Clause 3: a full-speed collision sounds at full scale. Coasting at the
	# clamp, friction hands stage 7 the steady top speed, which the Audio table
	# names as impactFullScale — so the volume is exactly 1.
	var s := _sim()
	s.kart_normalised = Normalise.to_target_height(KART_BOX, 1.2)
	var authored := AABB(Vector3(-1.0, 0.0, -1.0), Vector3(2.0, 2.0, 2.0))
	s.props = [
		Collision.make_prop("tree", Normalise.to_target_height(authored, 2.0), 0.0, 0.0, 1.5)
	]
	s.velocity = s.tuning.max_speed
	s.step()
	var impact: RefCounted = _cue_of(s, AudioCues.IMPACT)
	_check(
		s.last_hit != null and impact != null and absf(impact.volume - 1.0) < 1e-9,
		(
			"item 16: a full-speed collision sounds at FULL SCALE — volume %.9f"
			% (impact.volume if impact != null else -1.0)
		)
	)

	# Clause 4: a boundary rebound never plays the impact cue. Driven into the
	# fence with no prop within reach, so the only thing that can sound is the
	# rebound.
	var fence := _sim()
	fence.pos_z = fence.tuning.drivable_extent - 0.01
	fence.input.forward = true
	var rebounds := 0
	var impacts := 0
	for _i in range(240):
		fence.step()
		if _cue_of(fence, AudioCues.REBOUND) != null:
			rebounds += 1
		if _cue_of(fence, AudioCues.IMPACT) != null:
			impacts += 1
	_check(
		rebounds > 0 and impacts == 0,
		(
			"item 16: and a boundary rebound NEVER plays the impact cue (%d rebounds, %d impacts)"
			% [rebounds, impacts]
		)
	)


## This tick's first cue with this id, or null.
func _cue_of(s: RefCounted, id: String) -> RefCounted:
	for cue: AudioCues.Cue in s.cues.cues:
		if cue.id == id:
			return cue
	return null


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
