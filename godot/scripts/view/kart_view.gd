# The kart as the player sees it: normalised, oriented, and positioned from
# simulation state.
#
# A READER. It never writes to the simulation — see CONSTRAINTS §4 Architectural
# boundaries. Everything it draws is a function of (pos_x, pos_z, yaw) plus the
# interpolation fraction.
extends Node3D

const Normalise := preload("res://scripts/core/normalise.gd")
const Anisotropy := preload("res://scripts/view/anisotropy.gd")
const ArtTuning := preload("res://scripts/art_tuning.gd")

const KART_MODEL := "res://assets/kart.glb"

## WHICH END OF THE AUTHORED LONG AXIS IS THE NOSE, as +1 for local +X or -1 for
## local -X. This is the one number the imported bounds CANNOT give: an
## axis-aligned box is symmetric, so it identifies the axis and says nothing
## about the direction along it.
##
## Fixed by committed visual proof — docs/progress/ shows the driver and steering
## wheel facing world forward — and corroborated by the mesh's vertex centroid,
## which sits off the box centre along this axis. Ambiguity A6 records both.
##
## The design document's "+90° yaw correction" is NOT transcribed: it is stated
## in the reference build's frame, and this engine's differs. What is derived
## below is the rotation that puts the nose on world forward in THIS frame.
const NOSE_SIGN := -1.0

## How far the mesh's vertex centroid must sit from the box centre, along the
## long axis, for the corroboration to mean anything. Measured at 0.0764 on the
## supplied model; a mesh whose centroid sits nearer the centre than this is
## too symmetric for the heuristic to speak, and the check says so rather than
## reporting a coin flip as evidence.
const CENTROID_MIN_OFFSET := 0.02

var _model: Node3D = null
var _normalised: RefCounted = null
var _yaw_correction: float = 0.0

var _previous_x: float = 0.0
var _previous_z: float = 0.0
var _previous_yaw: float = 0.0
var _has_previous: bool = false


func _ready() -> void:
	var art: RefCounted = ArtTuning.load_art()
	if art == null:
		push_error("kart view: no art tuning")
		return
	_model = (load(KART_MODEL) as PackedScene).instantiate() as Node3D
	Anisotropy.apply(_model)
	add_child(_model)

	var authored: AABB = _authored_box(_model)
	_yaw_correction = yaw_correction_for(authored)
	_normalised = Normalise.to_target_height(authored, art.num("kart"))

	# §3's contract, applied to the model itself: scale uniformly, then offset so
	# the lowest point rests at Y = 0 and the box is centred on X and Z. The
	# offset is in SCALED space, which is why it is applied after the scale
	# rather than folded into the same transform by hand.
	_model.scale = Vector3.ONE * _normalised.scale
	_model.position = _normalised.offset
	_model.rotation.y = _yaw_correction


## The rotation that puts the model's nose on world forward.
##
## Static and taking a box, so a conformance check can ask the same question of
## the same asset without instantiating a view.
static func yaw_correction_for(authored: AABB) -> float:
	# The axis is the longer HORIZONTAL extent — derived, not assumed, so a
	# re-exported model authored down a different axis fails loudly instead of
	# driving sideways.
	if absf(authored.size.x - authored.size.z) < 1e-6:
		push_error(
			(
				(
					"kart view: the authored box is square in plan (%.4f x %.4f), so it "
					% [authored.size.x, authored.size.z]
				)
				+ "identifies no long axis and the yaw correction cannot be derived"
			)
		)
		return 0.0
	if authored.size.x > authored.size.z:
		# Nose along local X. Rotating +X about Y by -90 degrees puts it on world
		# +Z, which is the design document's forward.
		return -NOSE_SIGN * PI / 2.0
	# Nose already along local Z: no correction beyond the sign.
	return 0.0 if NOSE_SIGN > 0.0 else PI


static func _authored_box(model: Node3D) -> AABB:
	for child in model.get_children():
		if child is MeshInstance3D:
			return (child as MeshInstance3D).get_aabb()
	return AABB()


## Where the kart's nose points in world space, for a given simulation yaw.
##
## The simulation's forward is (sin yaw, cos yaw) — the design document's +Z at
## yaw zero. This returns the VISIBLE nose direction, which is what a conformance
## check must compare travel against; comparing travel to the simulation's own
## forward would compare the simulation to itself.
func nose_direction() -> Vector3:
	var basis_forward: Vector3 = _model.global_transform.basis * Vector3(NOSE_SIGN, 0.0, 0.0)
	return Vector3(basis_forward.x, 0.0, basis_forward.z).normalized()


func yaw_correction() -> float:
	return _yaw_correction


func normalised() -> RefCounted:
	return _normalised


## Draw the kart between the previous and current simulation states.
##
## Position only. Yaw is taken from the current state rather than interpolated:
## at 60 Hz the largest per-tick turn is turnRate, and the visible difference is
## below a pixel at any speed the kart reaches — while interpolating an angle
## correctly means handling the wrap at pi, which is a bug waiting for the first
## kart that spins.
func draw_from(sim: RefCounted, fraction: float) -> void:
	if _model == null:
		return
	var x: float = sim.pos_x
	var z: float = sim.pos_z
	if _has_previous:
		x = lerpf(_previous_x, sim.pos_x, fraction)
		z = lerpf(_previous_z, sim.pos_z, fraction)
	position = Vector3(x, 0.0, z)
	rotation.y = sim.yaw + 0.0
	_model.rotation.y = _yaw_correction


## Called once per simulation step by the composition root, so the view knows
## where the kart WAS. Separate from draw_from() because a frame may contain no
## step, one, or several.
func remember(sim: RefCounted) -> void:
	_previous_x = sim.pos_x
	_previous_z = sim.pos_z
	_previous_yaw = sim.yaw
	_has_previous = true
