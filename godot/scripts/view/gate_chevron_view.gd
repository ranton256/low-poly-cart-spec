# The screen-edge chevron — the half of the design document's "Finding the next
# gate" that the HUD carries: "when the next gate is off-screen, a chevron at
# the screen edge points along the shortest turn toward it".
#
# WHY IT EXISTS AT ALL, in the document's own words: fog ends at `fogEnd` and
# the playfield is wider than that, so a player who has not memorised the course
# would otherwise have nothing to steer by.
#
# A PURE CONSUMER, and deliberately a thin one: the only thing it computes is
# where a world point lands on screen and which way that is from the middle. The
# direction and placement are static functions taking plain vectors, so the
# suite can assert the arithmetic headlessly — a Control that only ever answers
# "is the triangle roughly over there" is the weaker-property trap.
extends Control

## The triangle's proportions, as fractions of its half-size: how far its base
## sits behind the middle, and how wide that base is. Shape, not tuning.
const BASE_SETBACK := 0.38
const BASE_HALF_WIDTH := 0.72

## The unit vector the triangle is drawn along. Held so a test can read what
## was drawn rather than infer it from pixels.
var pointing := Vector2.UP

## How far the chevron sits from the screen's edge, and how big it is: port
## decisions, from the data layer like every other px value.
var _size_px := 0.0
var _colour := Color.WHITE
var _inset_px := 0.0


func configure(art: RefCounted) -> void:
	_size_px = art.num("gateChevronHudPx")
	_inset_px = art.num("gateChevronHudInsetPx")
	_colour = art.colour("gateNextColour")
	custom_minimum_size = Vector2(_size_px * 2.0, _size_px * 2.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Where the chevron points: from the screen's centre toward the next gate's
## projection, NEGATED when the gate is behind the camera — an unprojected point
## behind the near plane lands mirrored through the centre, so using it raw
## points the player exactly the wrong way.
static func direction_to(projected: Vector2, centre: Vector2, behind: bool) -> Vector2:
	var offset: Vector2 = projected - centre
	if behind:
		offset = -offset
	if offset.is_zero_approx():
		# Degenerate only when the gate projects onto the centre pixel, which is
		# on-screen by definition and therefore never drawn.
		return Vector2.UP
	return offset.normalized()


## Where it sits: on the rectangle inset `inset` from every edge, along the
## direction from the centre. Clamped to the rectangle rather than placed on a
## circle, so the chevron is at the EDGE the gate lies past on both axes.
static func edge_position(direction: Vector2, screen: Vector2, inset: float) -> Vector2:
	var half: Vector2 = screen / 2.0 - Vector2(inset, inset)
	var scale_x: float = INF if is_zero_approx(direction.x) else half.x / absf(direction.x)
	var scale_y: float = INF if is_zero_approx(direction.y) else half.y / absf(direction.y)
	return screen / 2.0 + direction * minf(scale_x, scale_y)


## True when the gate's projection is outside the viewport — including behind
## the camera, which projects to a point that may well land inside it.
static func is_off_screen(projected: Vector2, screen: Vector2, behind: bool) -> bool:
	if behind:
		return true
	return (
		projected.x < 0.0 or projected.y < 0.0 or projected.x > screen.x or projected.y > screen.y
	)


## Once per rendered frame from the overlay. Hidden unless a circuit is loaded,
## the course is unthreaded, and the gate the cursor names is off-screen.
func draw_from(sim: RefCounted, camera: Camera3D) -> void:
	if camera == null or sim == null or _size_px == 0.0:
		return
	var circuit: RefCounted = sim.circuit
	if not circuit.has_gates() or circuit.is_threaded():
		visible = false
		return
	var gate: RefCounted = circuit.gates[circuit.cursor - 1]
	var target := Vector3(gate.x, 0.0, gate.z)
	var screen: Vector2 = get_parent_area_size()
	var behind: bool = camera.is_position_behind(target)
	var projected: Vector2 = camera.unproject_position(target)
	if not is_off_screen(projected, screen, behind):
		visible = false
		return
	visible = true
	var direction: Vector2 = direction_to(projected, screen / 2.0, behind)
	var centre: Vector2 = edge_position(direction, screen, _inset_px)
	# OFFSETS on an anchored Control, never `position` — the M5 trap. The rect
	# is anchored to the top-left, so the offsets ARE the screen position.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = centre.x - _size_px
	offset_top = centre.y - _size_px
	offset_right = centre.x + _size_px
	offset_bottom = centre.y + _size_px
	pointing = direction
	queue_redraw()


func _draw() -> void:
	var middle: Vector2 = size / 2.0
	var side := Vector2(-pointing.y, pointing.x)
	draw_polygon(
		[
			middle + pointing * _size_px,
			middle - pointing * _size_px * BASE_SETBACK + side * _size_px * BASE_HALF_WIDTH,
			middle - pointing * _size_px * BASE_SETBACK - side * _size_px * BASE_HALF_WIDTH,
		],
		[_colour, _colour, _colour]
	)
