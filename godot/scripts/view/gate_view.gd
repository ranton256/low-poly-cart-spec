# The gates, as world furniture — the design document's "What a gate looks
# like", and the minimap half of "Finding the next gate".
#
# A PURE CONSUMER, like every other view in this project: the cursor, the gate
# count and the geometry all come from the simulation's Circuit, and nothing
# here decides any of them. What this file owns is meshes and their colours.
#
# GENERATED GEOMETRY IN THE BAND'S FAMILY (scripts/world/world_builder.gd's
# _start_finish_band): unlit, translucent where it lies on the ground, cast
# shadow off, visible from both sides. NEVER a scatterable prop — the document
# is explicit that course furniture and obstacles must not be confusable — and
# never a collision obstacle: nothing here reaches sim.props, so the kart drives
# through a pylon exactly as it drives through the band.
#
# AND IT IS DIRECTIONAL. The mechanic is: a gate passed backwards counts for
# nothing. The furniture was symmetric anyway, so a player meeting a gate could
# not tell which way it faced — found by the owner's first playtest, and fixed in
# the specification itself (GDD "What a gate looks like", commit 869893e;
# ambiguity A15). Both marks now carry the pass direction: the ground stripe is
# an arrowhead along gate-forward and the overhead chevron leads along it, so a
# gate met from behind shows an arrow leaning away from the approach instead of
# the same shape from either side.
#
# TWO LAYERS, the standing mask rule (godot/minimap): the furniture is world
# geometry on layer 1, so the chase camera sees it; the minimap markers are on
# layer 2, which the chase camera's mask drops and the minimap camera's keeps.
# Masked, never moved or toggled.
#
# THE PULSE IS ON THE SIMULATION CLOCK. `sim.ticks` in, phase out — so the same
# tick renders the same frame, and a capture of tick N is reproducible. A wall
# clock here would put a non-deterministic value in every gallery baseline.
extends Node3D

const Sim := preload("res://scripts/core/sim.gd")

var _art: RefCounted = null
var _gates: Node3D = null
var _markers: Node3D = null
## The circuit the furniture was built for. Rebuilt when another one is armed —
## loading a layout swaps the course, and the gates must follow it.
var _built_for: RefCounted = null


## Build the containers. `world_parent` is the node the minimap markers join;
## they must live in the world the shared minimap viewport renders, exactly as
## the kart's markers do. Called once by the composition root.
func configure(art: RefCounted, world_parent: Node3D) -> void:
	_art = art
	_gates = Node3D.new()
	_gates.name = "GateFurniture"
	add_child(_gates)
	_markers = Node3D.new()
	_markers.name = "GateMarkers"
	world_parent.add_child(_markers)


## Once per rendered frame from the root. Builds on the first frame a circuit is
## armed, then colours every gate from the cursor.
func draw_from(sim: RefCounted) -> void:
	if _art == null or sim == null:
		return
	if sim.circuit != _built_for:
		_build(sim.circuit)
	if _built_for == null or not _built_for.has_gates():
		return
	for index in range(_built_for.gate_count()):
		_paint(index, _state_colour(index, sim.circuit.cursor), _pulse(sim, index))


## The colour a gate carries at this cursor: passed, next, or idle. Straight
## from the data layer — the view chooses no colour of its own.
func _state_colour(index: int, cursor: int) -> Color:
	var number: int = index + 1
	if number < cursor:
		return _art.colour("gatePassedColour")
	if number == cursor:
		return _art.colour("gateNextColour")
	return _art.colour("gateIdleColour")


## The next gate's brightness factor at this tick, 1.0 for every other gate.
## Public arithmetic in one place so the suite can assert the property the
## document asks for — the same tick, the same phase.
func _pulse(sim: RefCounted, index: int) -> float:
	if index + 1 != sim.circuit.cursor:
		return 1.0
	return pulse_factor(sim.ticks, _art.num("gatePulseSeconds"), _art.num("gatePulseDepth"))


## A cosine dip of `depth`, one cycle per `seconds` of SIMULATION time. Static
## and pure: given the tick, the phase is decided, which is the whole of the
## document's determinism requirement for it.
static func pulse_factor(ticks: int, seconds: float, depth: float) -> float:
	var period: float = maxf(seconds * float(Sim.TICKS_PER_SECOND), 1.0)
	var phase: float = TAU * float(ticks) / period
	return 1.0 - depth * (1.0 - cos(phase)) / 2.0


func _paint(index: int, colour: Color, pulse: float) -> void:
	var gate: Node3D = _gates.get_child(index) as Node3D
	var lit := Color(colour.r * pulse, colour.g * pulse, colour.b * pulse, colour.a)
	for part: Node3D in gate.get_children():
		if part is Label3D:
			(part as Label3D).modulate = lit
			continue
		var mesh := part as MeshInstance3D
		var material := mesh.material_override as StandardMaterial3D
		material.albedo_color = Color(lit.r, lit.g, lit.b, material.albedo_color.a)
	var marker: MeshInstance3D = _markers.get_child(index) as MeshInstance3D
	(marker.material_override as StandardMaterial3D).albedo_color = lit
	# The next gate is EMPHASISED — larger, as well as in its own colour.
	var next: bool = index + 1 == _built_for.cursor
	var radius: float = _art.num("gateMarkerNextRadiusWu" if next else "gateMarkerRadiusWu")
	var disc := marker.mesh as CylinderMesh
	if disc.top_radius != radius:
		disc.top_radius = radius
		disc.bottom_radius = radius


## Release the old furniture and build the new circuit's, gate for gate.
func _build(circuit: RefCounted) -> void:
	for holder: Node3D in [_gates, _markers]:
		for child in holder.get_children():
			holder.remove_child(child)
			child.free()
	_built_for = circuit
	if circuit == null or not circuit.has_gates():
		return
	for index in range(circuit.gate_count()):
		_gates.add_child(_furniture(circuit.gates[index], index + 1))
		_markers.add_child(_marker(circuit.gates[index], index + 1))


## One gate: two pylons, the ground arrow between them, the overhead chevron,
## and the billboard numeral above it.
##
## THE HOLDER CARRIES THE YAW and every piece is built in its frame, apex on
## local +Z. That is what makes the two arrows point along GATE-FORWARD at any
## yaw rather than along a world axis — tests/gate_view_test.gd derives each
## mesh's own forward from its vertices in world space and compares it to the
## gate's, at five yaws.
func _furniture(gate: RefCounted, number: int) -> Node3D:
	var height: float = _art.num("gatePylonHeight")
	var holder := Node3D.new()
	holder.name = "Gate%d" % number
	holder.position = Vector3(gate.x, 0.0, gate.z)
	holder.rotation.y = gate.yaw
	var half: float = gate.width / 2.0

	for side in [-1.0, 1.0]:
		var pylon := _pylon(height)
		pylon.name = "Pylon%s" % ("East" if side > 0.0 else "West")
		pylon.position = Vector3(side * half, height / 2.0, 0.0)
		holder.add_child(pylon)

	holder.add_child(_stripe(gate.width))
	holder.add_child(_chevron(height))
	holder.add_child(_numeral(height, number))
	return holder


func _pylon(height: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	var radius: float = _art.num("gatePylonRadiusWu")
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return _unlit(mesh, "Pylon", 1.0)


## The ground stripe: the band's own treatment — unlit, translucent, drawn from
## both sides, floating the band's height above the grass so it does not fight
## the ground plane for depth.
##
## AN ARROWHEAD, NOT A BAR (the amendment). Its base lies across the mouth on the
## near side of the segment and its apex reaches ahead of it along gate-forward:
## the same footprint the plane had — the gate's width by `gateDepth` — with a
## direction in it. A bar is symmetric, and a symmetric mark on a directional
## gate is exactly what the owner's first playtest could not read.
func _stripe(width: float) -> MeshInstance3D:
	var half: float = width / 2.0
	var reach: float = _art.num("gateDepth") / 2.0
	var corners: Array = [
		Vector3(-half, 0.0, -reach), Vector3(half, 0.0, -reach), Vector3(0.0, 0.0, reach)
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Both windings, so the arrow reads from above and from below — the same
	# reason the chevron and the minimap's arrow carry both.
	for triangle: Array in [[0, 1, 2], [0, 2, 1]]:
		for corner: int in triangle:
			surface.add_vertex(corners[corner])
	var node := _unlit(surface.commit(), "Stripe", _art.num("gateStripeOpacity"))
	node.position.y = _art.num("startFinishBandHeightY")
	return node


## The overhead chevron: a V of two quads spanning the gate at the pylons' top —
## upright in the gate's own plane, so it reads head-on from the approach the way
## the numeral does, rather than edge-on the way a chevron lying flat at 6 wu
## would.
##
## AND IT LEADS ALONG GATE-FORWARD (the amendment). The apex now sits `depth`
## AHEAD of the wings as well as `depth` below them — a 45° arrowhead whose
## horizontal axis is gate-forward, so from the approach it points away down the
## course and from the far side it leans back at the viewer: the back of a gate
## reading as a back. Laying it flat instead would say the same thing to nobody,
## because the chase camera sits below this height and would see it edge-on.
func _chevron(height: float) -> MeshInstance3D:
	var span: float = _art.num("gateChevronSpanWu")
	var depth: float = _art.num("gateChevronDepthWu")
	var thickness: float = _art.num("gateChevronThicknessWu")
	var outer: Array = [
		Vector3(-span, 0.0, 0.0), Vector3(0.0, -depth, depth), Vector3(span, 0.0, 0.0)
	]
	var inner: Array = [
		Vector3(-span, thickness, 0.0),
		Vector3(0.0, thickness - depth, depth),
		Vector3(span, thickness, 0.0),
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for arm in range(2):
		var quad: Array = [outer[arm], outer[arm + 1], inner[arm + 1], inner[arm]]
		for triangle: Array in [[0, 1, 2], [0, 2, 3], [0, 2, 1], [0, 3, 2]]:
			# Both windings, so the chevron reads from above and from below —
			# the same reason the minimap's arrow carries both.
			for corner: int in triangle:
				surface.add_vertex(quad[corner])
	var node := _unlit(surface.commit(), "Chevron", 1.0)
	node.position.y = height
	return node


## The gate's number, above the chevron and facing the camera.
func _numeral(height: float, number: int) -> Label3D:
	var label := Label3D.new()
	label.name = "Numeral"
	label.text = str(number)
	label.font = _system_font()
	label.font_size = int(_art.num("gateNumeralPx"))
	label.pixel_size = _art.num("gateNumeralPixelSize")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.shaded = false
	label.no_depth_test = false
	label.position = Vector3(0.0, height + _art.num("gateNumeralRiseWu"), 0.0)
	return label


## The minimap marker: a flat disc on layer 2, exactly the kart marker's
## treatment, at the gate's centre.
func _marker(gate: RefCounted, number: int) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	var radius: float = _art.num("gateMarkerRadiusWu")
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = _art.num("minimapDiscHeightWu")
	var node := _unlit(mesh, "GateMarker%d" % number, 1.0)
	node.layers = 1 << 1
	node.position = Vector3(gate.x, _art.num("minimapMarkerAltitudeWu"), gate.z)
	return node


## Every piece of gate furniture wears the same material family: unlit, no
## shadow, drawn from both sides, alpha only where a piece is translucent.
func _unlit(mesh: Mesh, node_name: String, opacity: float) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1.0, 1.0, 1.0, opacity)
	if opacity < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## The same system-font request the HUD makes — the repo ships no font asset.
func _system_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Helvetica Neue", "Arial", "sans-serif"])
	font.font_weight = 900
	return font
