# The gates as the player meets them — the design document's "What a gate looks
# like", "Finding the next gate", and the display half of "Medal targets".
#
#   godot --headless -s tests/gate_view_test.gd
#
# EXPECTED VALUES COME FROM THE DESIGN DOCUMENT and the tuning tables: pylons of
# `gatePylonHeight`, a translucent ground stripe between them, an overhead
# chevron, a numeral facing the camera; `gateNextColour` for the gate the cursor
# names with a pulse on the SIMULATION clock, `gatePassedColour` behind it,
# `gateIdleColour` ahead; `GATE n/N` in the timer block; the minimap marking
# every gate with the next emphasised, invisible in the main view; the medal's
# name beside the held TIME in its own colour.
#
# THE ASSERTIONS ARE THE PROPERTIES THEMSELVES, not that some text contains
# something (the weaker-property lesson): colours are compared to the data
# layer's own values, the pulse is compared tick against tick, and the chevron's
# direction is compared to the arithmetic it is supposed to be doing.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const MainScene := preload("res://scenes/main.tscn")
const ArtTuning := preload("res://scripts/art_tuning.gd")
const GateView := preload("res://scripts/view/gate_view.gd")
const ChevronView := preload("res://scripts/view/gate_chevron_view.gd")
const OverlayView := preload("res://scripts/view/overlay_view.gd")

## Render layer 2 as a cull-mask bit, as in minimap_test.
const LAYER_TWO_BIT := 1 << 1

var _root: Node3D = null
var _art: RefCounted = null


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_art = ArtTuning.load_art()
	await _settle()
	_root = MainScene.instantiate() as Node3D
	get_root().add_child(_root)
	await _settle()
	_root.sim.race.start_racing_immediately()
	await _settle()

	_test_each_gate_is_drawn_as_the_document_describes()
	_test_gates_are_not_obstacles()
	await _test_the_colours_are_the_cursor_s_truth()
	await _test_the_pulse_is_on_the_simulation_clock()
	await _test_the_minimap_marks_every_gate_with_the_next_emphasised()
	await _test_the_hud_counts_the_gates()
	_test_the_hint_line_names_the_objective()
	await _test_the_edge_chevron_points_at_the_next_gate()
	await _test_the_medal_joins_the_held_readout()

	get_root().remove_child(_root)
	_root.free()
	RVTest.finish(
		self, "gate view: furniture, colours, pulse, wayfinding, medal ok", "gate view check(s)"
	)


## Three idle frames, so a state change set here has certainly been DRAWN
## before the next assertion reads a label or a material: process_frame fires
## around the tree's own _process, and one frame can read the frame before.
func _settle() -> void:
	for _i in range(3):
		await process_frame


func _gate_node(number: int) -> Node3D:
	return _root.get_node("Gates/GateFurniture/Gate%d" % number) as Node3D


# @covers Checkpoint Circuit / What a gate looks like
func _test_each_gate_is_drawn_as_the_document_describes() -> void:
	var circuit: RefCounted = _root.sim.circuit
	_check(circuit.gate_count() > 0, "the boot circuit has gates to draw")
	var height: float = _art.num("gatePylonHeight")
	for number in range(1, circuit.gate_count() + 1):
		var gate: Node3D = _gate_node(number)
		if gate == null:
			_check(false, "gate %d has furniture in the world" % number)
			return
		var source: RefCounted = circuit.gates[number - 1]
		_check(
			(
				absf(gate.position.x - source.x) < 0.001
				and absf(gate.position.z - source.z) < 0.001
				and absf(gate.rotation.y - source.yaw) < 0.001
			),
			"gate %d stands at the circuit's own centre and yaw" % number
		)
		# Two pylons, at the ends of the segment, of the specified height.
		var west: MeshInstance3D = gate.get_node("PylonWest") as MeshInstance3D
		var east: MeshInstance3D = gate.get_node("PylonEast") as MeshInstance3D
		_check(west != null and east != null, "gate %d has two pylons" % number)
		for pylon: MeshInstance3D in [west, east]:
			var mesh := pylon.mesh as CylinderMesh
			RVTest.close(mesh.height, height, 0.001, "gate %d pylon is gatePylonHeight" % number)
		RVTest.close(
			absf(east.position.x - west.position.x),
			source.width,
			0.001,
			"gate %d's pylons stand the gate's own width apart" % number
		)
		# The stripe between them, translucent and on the ground.
		var stripe: MeshInstance3D = gate.get_node("Stripe") as MeshInstance3D
		var plane := stripe.mesh as PlaneMesh
		RVTest.close(plane.size.x, source.width, 0.001, "gate %d's stripe spans the mouth" % number)
		var material := stripe.material_override as StandardMaterial3D
		_check(
			(
				material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
				and material.albedo_color.a < 1.0
			),
			"gate %d's stripe is translucent" % number
		)
		# The chevron overhead, and the numeral above it, facing the camera.
		var chevron: MeshInstance3D = gate.get_node("Chevron") as MeshInstance3D
		RVTest.close(chevron.position.y, height, 0.001, "gate %d's chevron is overhead" % number)
		var numeral: Label3D = gate.get_node("Numeral") as Label3D
		_check(
			numeral.text == str(number), "gate %d shows its number (%s)" % [number, numeral.text]
		)
		_check(
			numeral.billboard == BaseMaterial3D.BILLBOARD_ENABLED and numeral.position.y > height,
			"gate %d's numeral sits above the chevron and faces the camera" % number
		)
		# Unlit, and casting nothing — the band's own family.
		for part: Node3D in [west, east, stripe, chevron]:
			var part_material := (part as MeshInstance3D).material_override as StandardMaterial3D
			_check(
				(
					part_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
					and (
						(part as MeshInstance3D).cast_shadow
						== GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					)
				),
				"gate %d's %s is unlit and casts no shadow" % [number, part.name]
			)
	_check(true, "every gate is pylons, stripe, chevron and numeral, generated in code")


## "Gates are NOT collision obstacles: the kart drives through pylons
## unimpeded, as it does through the band." The proof that survives review
## deleting a line: nothing gate-shaped is in the array collision resolves
## against, and the gate furniture is not in the prop field at all.
func _test_gates_are_not_obstacles() -> void:
	var sim: RefCounted = _root.sim
	_check(
		sim.props.size() == _root.props.prop_count(),
		(
			"the collision array holds the props and only the props (%d vs %d)"
			% [sim.props.size(), _root.props.prop_count()]
		)
	)
	var gate_shaped: Array = []
	for prop: RefCounted in sim.props:
		if "gate" in String(prop.asset).to_lower() or "pylon" in String(prop.asset).to_lower():
			gate_shaped.append(prop.asset)
	_check(gate_shaped.is_empty(), "and nothing gate-shaped among them: %s" % str(gate_shaped))
	_check(
		_root.props.find_child("Gate*", true, false) == null,
		"no gate furniture hides inside the prop field"
	)
	# And end to end: the kart parked in a gate mouth collides with nothing.
	var gate: RefCounted = sim.circuit.gates[0]
	var saved := Vector2(sim.pos_x, sim.pos_z)
	sim.pos_x = gate.x
	sim.pos_z = gate.z
	sim.step()
	_check(sim.last_hit == null, "and a kart standing in a gate's mouth hits nothing")
	sim.pos_x = saved.x
	sim.pos_z = saved.y


func _test_the_colours_are_the_cursor_s_truth() -> void:
	var circuit: RefCounted = _root.sim.circuit
	circuit.cursor = 3
	# Drawn HERE rather than after an awaited frame, so the tick the pulse is
	# read from below is the tick that was painted: the simulation advances
	# between an await and the next line, and the pulse moves with it.
	_root.gates.draw_from(_root.sim)
	var drawn_tick: int = _root.sim.ticks
	var passed: Color = _art.colour("gatePassedColour")
	var idle: Color = _art.colour("gateIdleColour")
	var next: Color = _art.colour("gateNextColour")
	for number in range(1, circuit.gate_count() + 1):
		var painted: Color = _painted_colour(number)
		if number < 3:
			_check(painted.is_equal_approx(passed), "gate %d is passed — gatePassedColour" % number)
		elif number > 3:
			_check(
				painted.is_equal_approx(idle), "gate %d is not yet due — gateIdleColour" % number
			)
	var pulse: float = GateView.pulse_factor(
		drawn_tick, _art.num("gatePulseSeconds"), _art.num("gatePulseDepth")
	)
	var wanted := Color(next.r * pulse, next.g * pulse, next.b * pulse)
	_check(
		_painted_colour(3).is_equal_approx(wanted),
		(
			"gate 3 is the NEXT gate — gateNextColour under its pulse (%s vs %s)"
			% [_painted_colour(3), wanted]
		)
	)
	# The numeral carries the state too, so the gate reads at a distance.
	var numeral: Label3D = _gate_node(1).get_node("Numeral") as Label3D
	_check(numeral.modulate.is_equal_approx(passed), "and the numeral wears the same state colour")
	circuit.cursor = 1


## The pulse phase is a function of the TICK, so the same tick renders the same
## frame — which is what makes a gallery baseline of it possible at all. Part of
## "What a gate looks like" (claimed above): the document says the next gate's
## pulse is animated on the SIMULATION clock, and this is that clause.
func _test_the_pulse_is_on_the_simulation_clock() -> void:
	var seconds: float = _art.num("gatePulseSeconds")
	var depth: float = _art.num("gatePulseDepth")
	var period: int = int(seconds * 60.0)
	var at_37: float = GateView.pulse_factor(37, seconds, depth)
	var at_37_again: float = GateView.pulse_factor(37, seconds, depth)
	_check(at_37 == at_37_again, "the same tick gives the same phase")
	_check(
		(
			GateView.pulse_factor(0, seconds, depth)
			!= GateView.pulse_factor(period / 2, seconds, depth)
		),
		"a different tick gives a different one — it is a pulse, not a constant"
	)
	RVTest.close(
		GateView.pulse_factor(period, seconds, depth),
		GateView.pulse_factor(0, seconds, depth),
		0.0001,
		"and it closes its cycle in gatePulseSeconds of SIMULATION time"
	)
	_check(
		(
			GateView.pulse_factor(period / 2, seconds, depth) >= 1.0 - depth - 0.0001
			and GateView.pulse_factor(0, seconds, depth) <= 1.0
		),
		"dipping by gatePulseDepth at its darkest and never brightening past the colour itself"
	)
	# And through the running view: draw the same tick twice, get the same paint.
	var gates: Node3D = _root.gates
	gates.draw_from(_root.sim)
	var first: Color = _painted_colour(1)
	gates.draw_from(_root.sim)
	_check(_painted_colour(1) == first, "drawing the same tick twice paints identically")


# @covers Checkpoint Circuit / Finding the next gate
func _test_the_minimap_marks_every_gate_with_the_next_emphasised() -> void:
	var circuit: RefCounted = _root.sim.circuit
	circuit.cursor = 2
	await _settle()
	var markers: Node3D = _root.get_node("GateMarkers") as Node3D
	_check(
		markers != null and markers.get_child_count() == circuit.gate_count(),
		"every gate has a minimap marker (%d)" % markers.get_child_count()
	)
	var chase: Camera3D = _root.chase_camera
	var minimap_cam: Camera3D = _root.get_node("Minimap/Viewport/Camera") as Camera3D
	var next_radius := 0.0
	var idle_radius := 0.0
	for index in range(markers.get_child_count()):
		var marker: MeshInstance3D = markers.get_child(index) as MeshInstance3D
		var gate: RefCounted = circuit.gates[index]
		_check(
			absf(marker.position.x - gate.x) < 0.001 and absf(marker.position.z - gate.z) < 0.001,
			"marker %d sits on its gate" % (index + 1)
		)
		_check(marker.layers == LAYER_TWO_BIT, "marker %d is on render layer 2 only" % (index + 1))
		_check(marker.visible, "and is never hidden — masking does the work")
		var radius: float = (marker.mesh as CylinderMesh).top_radius
		if index == 1:
			next_radius = radius
		elif index == 0:
			idle_radius = radius
	_check(
		next_radius > idle_radius,
		"the next gate's marker is LARGER (%.1f vs %.1f wu)" % [next_radius, idle_radius]
	)
	var marker_colour: Color = (
		((markers.get_child(1) as MeshInstance3D).material_override as StandardMaterial3D)
		. albedo_color
	)
	var next_colour: Color = _art.colour("gateNextColour")
	_check(
		Vector3(marker_colour.r, marker_colour.g, marker_colour.b).normalized().is_equal_approx(
			Vector3(next_colour.r, next_colour.g, next_colour.b).normalized()
		),
		"and wears gateNextColour (under the pulse)"
	)
	_check(
		(chase.cull_mask & LAYER_TWO_BIT) == 0 and (minimap_cam.cull_mask & LAYER_TWO_BIT) != 0,
		"the standing mask guarantee holds for the gate markers too"
	)
	# The furniture, by contrast, IS main-view geometry.
	var pylon: MeshInstance3D = _gate_node(1).get_node("PylonWest") as MeshInstance3D
	_check(
		(pylon.layers & 1) != 0 and (chase.cull_mask & 1) != 0,
		"while the gate furniture is on layer 1, where the chase camera sees it"
	)
	circuit.cursor = 1


func _test_the_hud_counts_the_gates() -> void:
	var counter: Label = _root.overlay.get_node("GateCounter") as Label
	var circuit: RefCounted = _root.sim.circuit
	await _settle()
	_check(counter.visible, "the timer block carries a gate counter")
	_check(
		counter.text == "GATE 1/%d" % circuit.gate_count(),
		"reading the cursor against the gate count (%s)" % counter.text
	)
	circuit.cursor = 4
	await _settle()
	_check(
		counter.text == "GATE 4/%d" % circuit.gate_count(),
		"which follows the cursor (%s)" % counter.text
	)
	# A threaded course holds at N rather than reading one past the final gate.
	circuit.cursor = circuit.gate_count() + 1
	await _settle()
	_check(
		counter.text == "GATE %d/%d" % [circuit.gate_count(), circuit.gate_count()],
		"and holds at N once the course is threaded (%s)" % counter.text
	)
	circuit.cursor = 1
	# §7's timer label style, in the timer block: same font size as TIME's label,
	# same right edge, below BEST.
	var time_label: Label = _root.overlay.get_node("TimeLabel") as Label
	var best_value: Label = _root.overlay.get_node("BestValue") as Label
	_check(
		counter.label_settings.font_size == time_label.label_settings.font_size,
		"in the timer LABEL style (%d px)" % counter.label_settings.font_size
	)
	_check(
		(
			counter.offset_right == time_label.offset_right
			and counter.offset_top > best_value.offset_top
		),
		"inside the timer block, under BEST"
	)
	var area: Vector2 = counter.get_parent_area_size()
	var rect: Rect2 = counter.get_rect()
	_check(
		rect.position.x >= 0.0 and rect.end.x <= area.x and rect.end.y <= area.y,
		"and on screen (%s in %s)" % [rect, area]
	)


func _test_the_hint_line_names_the_objective() -> void:
	var hints: Label = _root.overlay.get_node("Hints") as Label
	_check(
		hints.text == "W/S drive · A/D steer · G restart · follow the gates",
		"the hint line is §7's own text, verbatim (%s)" % hints.text
	)


## The direction arithmetic first, because that is the part a screenshot cannot
## check and a "the chevron is visible" assertion would silently accept wrong.
func _test_the_edge_chevron_points_at_the_next_gate() -> void:
	var screen := Vector2(1280.0, 720.0)
	var centre: Vector2 = screen / 2.0
	_check(
		ChevronView.direction_to(centre + Vector2(400.0, 0.0), centre, false).is_equal_approx(
			Vector2.RIGHT
		),
		"a gate off the right of the screen points right"
	)
	_check(
		ChevronView.direction_to(centre + Vector2(0.0, -300.0), centre, false).is_equal_approx(
			Vector2.UP
		),
		"one off the top points up"
	)
	# BEHIND the camera: the projection is mirrored through the centre, so the
	# raw direction points exactly the wrong way and must be negated.
	_check(
		ChevronView.direction_to(centre + Vector2(400.0, 0.0), centre, true).is_equal_approx(
			Vector2.LEFT
		),
		"a gate BEHIND the camera and projecting right points LEFT — the mirror undone"
	)
	_check(
		ChevronView.is_off_screen(Vector2(640.0, 360.0), screen, true),
		"a gate behind the camera is off-screen however it projects"
	)
	_check(
		not ChevronView.is_off_screen(Vector2(640.0, 360.0), screen, false),
		"and one projecting into the viewport is not"
	)
	var edge: Vector2 = ChevronView.edge_position(Vector2.RIGHT, screen, 48.0)
	_check(
		absf(edge.x - (screen.x - 48.0)) < 0.001 and absf(edge.y - centre.y) < 0.001,
		"the chevron sits at the screen edge, inset (%s)" % edge
	)
	var corner: Vector2 = ChevronView.edge_position(Vector2.ONE.normalized(), screen, 48.0)
	_check(
		corner.x <= screen.x - 48.0 + 0.001 and corner.y <= screen.y - 48.0 + 0.001,
		"and never outside it, on either axis (%s)" % corner
	)

	# Then through the running game: a gate behind the kart is off-screen, and
	# the control the player sees is shown, pointing where the maths says.
	var chevron: Control = _root.overlay.get_node("GateChevron") as Control
	var circuit: RefCounted = _root.sim.circuit
	_root.sim.pos_x = 0.0
	_root.sim.pos_z = 60.0
	_root.sim.yaw = 0.0
	circuit.cursor = 1  # gate 1 is far to the SOUTH of that pose — behind the kart
	# Enough ticks for the chase camera to ease in behind the kart and look
	# north: the chevron is about where the CAMERA is pointed, not the kart.
	for _i in range(150):
		await physics_frame
	await _settle()
	_check(chevron.visible, "the running game shows the chevron when the next gate is behind")
	_check(
		absf(chevron.pointing.length() - 1.0) < 0.001, "as a unit direction (%s)" % chevron.pointing
	)
	var rect: Rect2 = chevron.get_rect()
	var area: Vector2 = chevron.get_parent_area_size()
	_check(
		(
			rect.position.x >= 0.0
			and rect.end.x <= area.x
			and rect.position.y >= 0.0
			and rect.end.y <= area.y
		),
		"drawn inside the viewport, at its edge (%s in %s)" % [rect, area]
	)
	# And hidden once the course is threaded — there is no next gate to find.
	circuit.cursor = circuit.gate_count() + 1
	await _settle()
	_check(not chevron.visible, "and hides once the course is threaded")
	circuit.cursor = 1
	_root.sim.pos_z = 0.0


## The display half of "Medal targets": the held TIME readout joined by the
## medal's name in its colour, for exactly the hold window. A pure consumer of
## the core's bank-time verdict — set the verdict, read the label.
# @covers Checkpoint Circuit / Medal targets
func _test_the_medal_joins_the_held_readout() -> void:
	var medal: Label = _root.overlay.get_node("Medal") as Label
	var time_value: Label = _root.overlay.get_node("TimeValue") as Label
	var lap: RefCounted = _root.sim.lap
	lap.banked_seconds = 14.25
	lap.hold_ticks = 30
	lap.banked_medal = "gold"
	await _settle()
	_check(medal.visible, "a medal lap shows its medal during the hold")
	_check(medal.text == "GOLD", "named (%s)" % medal.text)
	_check(
		medal.label_settings.font_color.is_equal_approx(_art.colour("medalGoldColour")),
		"in medalGoldColour"
	)
	_check(time_value.text == "14.25", "beside the held TIME (%s)" % time_value.text)
	_check(
		medal.label_settings.font_size == time_value.label_settings.font_size,
		"at the readout's own size — it JOINS the readout"
	)
	for name_and_key: Array in [["silver", "medalSilverColour"], ["bronze", "medalBronzeColour"]]:
		lap.banked_medal = name_and_key[0]
		await _settle()
		_check(
			(
				medal.text == String(name_and_key[0]).to_upper()
				and medal.label_settings.font_color.is_equal_approx(_art.colour(name_and_key[1]))
			),
			"and %s in %s" % [name_and_key[0], name_and_key[1]]
		)
	# A medal-less lap shows only the time.
	lap.banked_medal = ""
	await _settle()
	_check(not medal.visible, "a lap that met no target shows nothing extra")
	lap.banked_medal = "gold"
	lap.hold_ticks = 0
	await _settle()
	_check(not medal.visible, "and the medal leaves with the hold window")
	lap.banked_medal = ""
	lap.banked_seconds = -1.0


## What a gate's furniture is painted, read off the pylon's own material.
func _painted_colour(number: int) -> Color:
	var pylon: MeshInstance3D = _gate_node(number).get_node("PylonWest") as MeshInstance3D
	var colour: Color = (pylon.material_override as StandardMaterial3D).albedo_color
	return Color(colour.r, colour.g, colour.b)
