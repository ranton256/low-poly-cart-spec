# The kart travels in the direction it visually faces.
#
#   godot --headless -s tests/kart_test.gd
#
# READ THIS BEFORE TRUSTING IT.
#
# The 16-heading check below proves that travel and facing are CONSISTENT. It
# does NOT prove the facing is correct, and it cannot: it compares the
# simulation's displacement against a nose direction derived from
# KART_YAW_CORRECTION, so a correction wrong by half a turn makes both sides
# wrong together and every one of the 16 headings agrees. A kart driving
# tail-first passes this file completely.
#
# What settles the sign is elsewhere, and deliberately so — ambiguity A6:
#   * docs/progress/2026-08-29-m2-kart-front.png, a committed capture from the
#     +Z side showing the steering wheel in front of the seat, so the camera is
#     looking at the kart's front while the kart faces world forward;
#   * the mesh's vertex-centroid offset, checked below, which sits toward the
#     kart's REAR and therefore corroborates which end is which without
#     reference to the capture.
#
# This project has been rejected twice for tests that agreed with their own
# assumptions — a known-answer test whose input was already the answer, and a
# clamp test that held whether or not the clamp existed. This is the same shape,
# caught before it was written rather than after.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const KartView := preload("res://scripts/view/kart_view.gd")
const Sim := preload("res://scripts/core/sim.gd")
const Tuning := preload("res://scripts/core/tuning.gd")
const InputState := preload("res://scripts/core/input_state.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")

const HEADINGS := 16
## Enough ticks to move measurably; far short of the boundary at any heading.
const DRIVE_TICKS := 90
## Displacement direction against nose direction. Loose enough for 32-bit basis
## maths, tight enough that a heading wrong by one degree fails.
const DIRECTION_TOLERANCE := 0.002

var _view: Node3D = null


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	await process_frame
	_view = KartView.new()
	get_root().add_child(_view)
	await process_frame

	_test_travel_matches_facing_at_every_heading()
	_test_the_centroid_corroborates_which_end_is_the_nose()
	_test_the_correction_is_derived_from_the_asset()
	_test_a_square_plan_refuses_to_guess()

	get_root().remove_child(_view)
	_view.free()
	_view = null
	RVTest.finish(
		self, "kart: travel matches facing at 16 headings, nose corroborated", "kart check(s)"
	)


func _sim() -> RefCounted:
	var s := Sim.new()
	s.tuning = TuningLoader.load_tuning()
	s.input = InputState.new()
	# Pipeline suite: skip the countdown (race-state seam; race_state_test owns it).
	s.race.start_racing_immediately()
	return s


# @covers Session Bootstrap and Asset Normalisation / Placing the kart at the start line
## THE CONSISTENCY CHECK. See the file header for what it does not establish.
func _test_travel_matches_facing_at_every_heading() -> void:
	for i in range(HEADINGS):
		var yaw: float = TAU * float(i) / float(HEADINGS)
		for reversing in [false, true]:
			var s := _sim()
			s.yaw = yaw
			if reversing:
				s.input.reverse = true
			else:
				s.input.forward = true
			var from_x: float = s.pos_x
			var from_z: float = s.pos_z
			for _t in range(DRIVE_TICKS):
				s.step()
			var moved := Vector3(s.pos_x - from_x, 0.0, s.pos_z - from_z)
			if moved.length() < 1e-6:
				_check(
					false,
					"the kart moved at yaw %.3f (%s)" % [yaw, "reverse" if reversing else "forward"]
				)
				continue

			# The nose direction the VIEW would draw at this yaw — not the
			# simulation's own forward vector, which would compare the simulation
			# against itself and pass on any correction at all.
			_view.rotation.y = yaw
			var nose: Vector3 = _view.nose_direction()
			var want: Vector3 = nose if not reversing else -nose
			var offset: float = moved.normalized().distance_to(want)
			_check(
				offset < DIRECTION_TOLERANCE,
				(
					"at yaw %.3f the kart travels %s along its visible nose (off by %.5f)"
					% [yaw, "backwards" if reversing else "forwards", offset]
				)
			)


## The mesh's own asymmetry, as the second witness A6 requires.
##
## A go-kart's mass sits toward its rear — engine, seat, rear tyres — so the
## vertex centroid is offset from the bounding-box centre along the long axis,
## AWAY from the nose. That gives an answer about which end is which that owes
## nothing to the capture, which is the point of having two witnesses.
func _test_the_centroid_corroborates_which_end_is_the_nose() -> void:
	var model: Node3D = null
	for child in _view.get_children():
		if child is Node3D:
			model = child as Node3D
	_check(model != null, "the view instantiated the model")
	if model == null:
		return
	var mesh_instance: MeshInstance3D = null
	for child in model.get_children():
		if child is MeshInstance3D:
			mesh_instance = child as MeshInstance3D
	if mesh_instance == null:
		_check(false, "the model contains a mesh")
		return

	var box: AABB = mesh_instance.get_aabb()
	var vertices: PackedVector3Array = (mesh_instance.mesh as Mesh).surface_get_arrays(0)[
		Mesh.ARRAY_VERTEX
	]
	var sum := Vector3.ZERO
	for v in vertices:
		sum += v
	var centroid: Vector3 = sum / float(vertices.size())
	var offset: float = centroid.x - (box.position.x + box.size.x / 2.0)

	# Below this the mesh is too symmetric for the heuristic to speak, and saying
	# so is better than reporting a coin flip as corroboration.
	_check(
		absf(offset) >= KartView.CENTROID_MIN_OFFSET,
		(
			(
				"the mesh is asymmetric enough along its long axis for the centroid to "
				+ "indicate an end (offset %.4f, needs %.4f)"
			)
			% [offset, KartView.CENTROID_MIN_OFFSET]
		)
	)
	# The nose is the end the mass is NOT at.
	var indicated_nose_sign: float = -signf(offset)
	_check(
		is_equal_approx(indicated_nose_sign, KartView.NOSE_SIGN),
		(
			(
				"the centroid sits toward the kart's rear, so it indicates the nose at "
				+ "local %+.0fX — which is what NOSE_SIGN says (%+.0f)"
			)
			% [indicated_nose_sign, KartView.NOSE_SIGN]
		)
	)


## The correction is COMPUTED from the imported bounds, not transcribed. A model
## re-exported down a different axis must change the answer rather than keep it.
func _test_the_correction_is_derived_from_the_asset() -> void:
	var long_x := AABB(Vector3(-1.0, -0.5, -0.9), Vector3(2.0, 1.0, 1.8))
	var long_z := AABB(Vector3(-0.9, -0.5, -1.0), Vector3(1.8, 1.0, 2.0))
	_check(
		not is_equal_approx(
			KartView.yaw_correction_for(long_x), KartView.yaw_correction_for(long_z)
		),
		"a model authored along Z gets a different correction from one authored along X"
	)
	_check(
		absf(absf(KartView.yaw_correction_for(long_x)) - PI / 2.0) < 1e-9,
		"an X-authored model is corrected by a quarter turn"
	)


## A box with no long horizontal axis identifies nothing, and the derivation must
## say so rather than pick one.
func _test_a_square_plan_refuses_to_guess() -> void:
	var square := AABB(Vector3(-1.0, -0.5, -1.0), Vector3(2.0, 1.0, 2.0))
	_check(
		is_zero_approx(KartView.yaw_correction_for(square)),
		"a square-in-plan model yields no correction rather than an arbitrary one"
	)
