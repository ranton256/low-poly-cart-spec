# The checkpoint circuit — the design document's Checkpoint Circuit feature, as
# pure core state advanced from the tick's stage 8 beside the lap gate.
#
# WHAT A GATE IS. A directed segment on the ground: a centre (X, Z), a yaw, and
# a width, in world units. A gate is PASSED on a tick when, in the gate's own
# frame, the kart lies within half the width of the centre laterally, inside a
# slab `gateDepth` deep AHEAD of the segment, while the component of the tick's
# STAGE-5 INTEGRATION along gate-forward exceeds `gateCrossingThreshold`.
#
# THAT LAST CLAUSE IS THE WHOLE DEFENCE, and it is the band's, rotated. The
# observable is stage 5's own displacement, handed in by the caller — never net
# position change, which stages 6 and 7 also move: a kart pinned against a prop
# is shoved `pushDistance` (0.3 wu, thirty times the threshold) every tick and
# would otherwise walk through a gate without the player driving anywhere. It is
# not the scalar velocity's sign either — a kart under power pointed the wrong
# way through a gate has a negative gate-forward component and passes nothing.
# tests/circuit_test.gd stages both, and the first is mutation-verified.
#
# THE CURSOR FORGIVES. Only the gate the cursor NAMES can advance it, which is
# why this file tests exactly one gate per tick: a pass of any other gate —
# already passed, not yet due, or the named gate backwards — is not a rejection
# with consequences, it is nothing at all. No reset, no voided lap, no message.
# The only cure for a missed gate is to go and pass it.
#
# PURE — CONSTRAINTS §4 Architectural boundaries. No engine types, no file
# access, no clock. It reads position and the stage-5 observable, and writes
# only its own cursor.
extends RefCounted

## The best-time key a session with no circuit loaded uses. The interim: the
## game boots procedural until add-circuit-world-and-presentation ships a boot
## circuit, and those laps still deserve a best.
const NO_CIRCUIT_KEY := "procedural"

## The medal targets a circuit may declare, BEST FIRST — medal_for() returns the
## first one met, which is what "the name of the best target met" requires.
const MEDAL_ORDER: Array = ["gold", "silver", "bronze"]


## One gate: a directed segment on the ground, exactly the file's three fields.
class Gate:
	extends RefCounted
	var x: float = 0.0
	var z: float = 0.0
	var yaw: float = 0.0
	var width: float = 0.0

	## Gate-forward. The same convention as the kart's — the document's world
	## forward is +Z, so a yaw of zero faces +Z.
	func forward_x() -> float:
		return sin(yaw)

	func forward_z() -> float:
		return cos(yaw)

	## The MOUTH: the opening a kart drives through, as four world XZ corners —
	## `width` wide laterally, and `depth` deep on EACH side of the segment, so
	## it covers the pass slab and the approach that reaches it.
	##
	## Nothing in the tick reads this. It exists because the design document
	## makes the layout file "the guarantee that no prop blocks a gate mouth"
	## (Track Layout Persistence / A layout is a circuit), and a guarantee with
	## no shape cannot be checked — tests/circuit_content_test.gd checks the
	## shipped file against it, and tools/author_first_light.gd curates by it.
	## Vector2 (32-bit) rather than the core's usual scalars: a shape for an
	## overlap test with metres of margin, never a value the tick accumulates.
	func mouth_corners(depth: float) -> PackedVector2Array:
		var forward := Vector2(forward_x(), forward_z())
		# The lateral axis: gate-forward turned a quarter turn, as in passes().
		var lateral := Vector2(forward.y, -forward.x)
		var centre := Vector2(x, z)
		var half: Vector2 = lateral * (width / 2.0)
		var reach: Vector2 = forward * depth
		return PackedVector2Array(
			[
				centre - half - reach,
				centre + half - reach,
				centre + half + reach,
				centre - half + reach
			]
		)


# --- injected ---
var tuning: RefCounted = null

# --- state, all of it in the determinism summary ---
var circuit_name: String = ""
var gates: Array = []
var targets: Dictionary = {}

## The gate the cursor NAMES, 1-based like the document's numbering. It reaches
## gate_count() + 1 when the course has been threaded, and rewinds to 1 on a
## bank. Reset Kart does NOT touch it — that is the document's own sentence.
var cursor: int = 1


## Append a gate in file order. The order IS the course.
func add_gate(gate_x: float, gate_z: float, gate_yaw: float, gate_width: float) -> void:
	var gate := Gate.new()
	gate.x = gate_x
	gate.z = gate_z
	gate.yaw = gate_yaw
	gate.width = gate_width
	gates.append(gate)


func gate_count() -> int:
	return gates.size()


func has_gates() -> bool:
	return not gates.is_empty()


## True when every gate has been passed in order — the band's extra condition.
func is_threaded() -> bool:
	return has_gates() and cursor > gates.size()


## The key this circuit's session best is filed under.
func key() -> String:
	return circuit_name if has_gates() else NO_CIRCUIT_KEY


## Banking a lap returns the cursor to gate 1.
func rewind() -> void:
	cursor = 1


## One advance, from the tick's stage 8. OBSERVES ONLY: the arguments are the
## post-tick position and stage 5's own displacement, and the single thing this
## can change is the cursor.
func advance(pos_x: float, pos_z: float, step5_dx: float, step5_dz: float) -> void:
	if tuning == null or gates.is_empty() or cursor > gates.size():
		return
	if passes(gates[cursor - 1] as Gate, pos_x, pos_z, step5_dx, step5_dz):
		cursor += 1


## The pass test, in the gate's own frame. Public because the suite stages
## geometry against it directly, at yaws the running game would take minutes to
## drive to.
func passes(gate: Gate, pos_x: float, pos_z: float, step5_dx: float, step5_dz: float) -> bool:
	var to_x: float = pos_x - gate.x
	var to_z: float = pos_z - gate.z
	var forward_x: float = gate.forward_x()
	var forward_z: float = gate.forward_z()

	# Ahead of the segment, inside the slab. Open at both faces, like the band's
	# own Z ∈ (4, 6): the kart travels at most maxSpeed per tick and the slab is
	# gateDepth deep, so it is observed inside for many ticks and cannot skip it.
	var ahead: float = to_x * forward_x + to_z * forward_z
	if ahead <= 0.0 or ahead >= tuning.gate_depth:
		return false

	# Within half the width of the centre. The lateral axis is gate-forward
	# turned a quarter turn, so at a yaw of zero it is +X.
	var lateral: float = to_x * forward_z - to_z * forward_x
	if absf(lateral) >= gate.width / 2.0:
		return false

	# And stage 5's displacement, projected on gate-forward. THE observable.
	var along: float = step5_dx * forward_x + step5_dz * forward_z
	return along > tuning.gate_crossing_threshold


## Whether a prop's world box blocks a gate's mouth, on the ground plane.
##
## The other half of the guarantee mouth_corners() gives a shape to, and it
## lives here so the tool that CURATES a circuit's props and the test that
## re-checks the committed file cannot disagree about what "blocked" means.
##
## Separating axes, four of them: the world axes the prop's box is aligned to,
## and the mouth's own two. That is exact for two rectangles — no sampling, so
## a prop cannot slip between probe points.
static func mouth_blocked(mouth: PackedVector2Array, box: AABB) -> bool:
	var corners := PackedVector2Array(
		[
			Vector2(box.position.x, box.position.z),
			Vector2(box.position.x + box.size.x, box.position.z),
			Vector2(box.position.x + box.size.x, box.position.z + box.size.z),
			Vector2(box.position.x, box.position.z + box.size.z),
		]
	)
	var axes := PackedVector2Array(
		[
			Vector2(1.0, 0.0),
			Vector2(0.0, 1.0),
			(mouth[1] - mouth[0]).normalized(),
			(mouth[3] - mouth[0]).normalized(),
		]
	)
	for axis: Vector2 in axes:
		var a: Vector2 = _extent_along(mouth, axis)
		var b: Vector2 = _extent_along(corners, axis)
		if a.y < b.x or b.y < a.x:
			return false
	return true


## A polygon's extent along an axis, as (min, max).
static func _extent_along(points: PackedVector2Array, axis: Vector2) -> Vector2:
	var low: float = INF
	var high: float = -INF
	for point: Vector2 in points:
		var value: float = point.dot(axis)
		low = minf(low, value)
		high = maxf(high, value)
	return Vector2(low, high)


## The best target met, or "" for none — "at or under", not "under". A circuit
## may omit targets, and then nothing is ever earned.
func medal_for(seconds: float) -> String:
	for medal: String in MEDAL_ORDER:
		if targets.has(medal) and seconds <= float(targets[medal]):
			return medal
	return ""
