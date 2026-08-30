# The environment the design document's §5 and §6 specify, built from data.
#
#   godot --headless -s tests/world_test.gd
#
# HEADLESS, WITH A SCENE TREE. Godot's headless mode has no renderer but it does
# have a scene tree, so much about the world that has nothing to do with pixels
# can be checked here — sizes, positions, colours, energies, and the ratios
# between them. NOT "everything except the pixels" — which is what this header
# claimed until review mutated nine specified values and watched them all pass.
#
# The split is the point: what the captures in docs/progress/ prove is
# that the result looks right, and a picture cannot tell you whether the sun's
# energy is the document's number times one shared scale or a value someone
# typed. This file answers that half, on every run, for free.
#
# It reads the same tuning data the scene does, so it is NOT an independent
# oracle for the values themselves — see docs/GLOSSARY.md. What it verifies is
# that the scene USES them, and the relationships between them: the ratios, the
# derived grid geometry, and the decisions design D1 and D2a settled.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const ArtTuning := preload("res://scripts/art_tuning.gd")

const WORLD_SCENE := "res://scenes/world.tscn"
const EPSILON := 1e-6

var _art: RefCounted = null
var _world: Node3D = null


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	await process_frame
	_art = ArtTuning.load_art()
	var packed: PackedScene = load(WORLD_SCENE)
	_world = packed.instantiate() as Node3D
	get_root().add_child(_world)
	await process_frame

	_test_every_specified_element_exists()
	_test_ground_matches_the_document()
	_test_ground_skirt_settles_a11()
	_test_grid_geometry_is_derived_not_typed()
	_test_band_sits_where_the_document_puts_it()
	_test_fog_and_tonemapping()
	_test_the_lighting_ratios_survive_the_scale()
	_test_the_sun_is_configured_to_cast()
	_test_the_sky_is_not_drawn()
	_test_a_viewpoint_exists()
	_test_nothing_advances()
	# Free the instantiated scene before the tree exits, or Godot reports
	# allocator pages still in use — noise that would obscure a real error.
	get_root().remove_child(_world)
	_world.free()
	_world = null
	_art = null
	RVTest.finish(self, "world: elements, ground, grid, band, fog, light ratios", "world check(s)")


func _node(name: String) -> Node:
	return _world.get_node_or_null(name)


func _test_every_specified_element_exists() -> void:
	for name in ["WorldEnvironment", "Ground", "GridMinor", "GridAxes", "StartFinishBand", "Sun"]:
		_check(_node(name) != null, "the world contains %s" % name)


func _test_ground_matches_the_document() -> void:
	var ground := _node("Ground") as MeshInstance3D
	var size: float = _art.num("groundSize")
	var mesh := ground.mesh as PlaneMesh
	_check(
		absf(mesh.size.x - size) < EPSILON and absf(mesh.size.y - size) < EPSILON,
		"ground is %.1f x %.1f wu" % [size, size]
	)
	var material := ground.material_override as StandardMaterial3D
	_check(
		material.albedo_color == _art.colour("groundColour"), "ground carries the specified albedo"
	)
	_check(
		absf(material.roughness - _art.num("groundRoughness")) < EPSILON,
		"ground roughness is the specified value"
	)
	_check(
		absf(material.metallic - _art.num("groundMetalness")) < EPSILON,
		"ground metalness is the specified value"
	)
	# §5's ground is a FLOOR. PlaneMesh defaults to facing +Y, but the orientation
	# is settable, and a ground turned to FACE_Z is a 200 wu wall through the middle
	# of the field that passes every size, colour and position check.
	_check(mesh.orientation == PlaneMesh.FACE_Y, "ground lies flat, facing up")
	# "centred on the origin, at Y = 0" — §5. A ground lifted off zero breaks the
	# normalisation contract's whole premise, which is that every instance rests
	# with its lowest point at Y = 0.
	_check(
		ground.global_position.is_equal_approx(Vector3.ZERO),
		"ground is centred on the origin at Y = 0 (got %v)" % ground.global_position
	)
	# §5 is explicit that the ground RECEIVES shadows and CASTS none. This comment
	# used to sit above a check of the casting half alone — the exact overclaiming
	# this file's header was rewritten to stop.
	_check(
		ground.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"ground does not cast a shadow"
	)
	_check(
		not material.disable_receive_shadows,
		"ground receives shadows — the kart's contact shadow lands here"
	)


## The grid's line count is DERIVED from the specified extent and divisions, so
## this asserts the arithmetic rather than a number someone counted. 20 divisions
## over the central extent means 21 lines per axis; one of them passes through
## zero on each axis and is an axis line, leaving 20 minor lines per axis.
## A11's settlement: the skirt keeps every stated number intact while putting
## every ground edge past fog's end from anywhere drivable.
func _test_ground_skirt_settles_a11() -> void:
	var skirt: MeshInstance3D = _node("GroundSkirt") as MeshInstance3D
	var art: RefCounted = _world.art
	_check(skirt != null, "the skirt exists")
	var size: float = art.num("groundSkirtSize")
	_check((skirt.mesh as PlaneMesh).size == Vector2(size, size), "spanning groundSkirtSize")
	_check(
		size / 2.0 - art.num("drivableExtent") > art.num("fogEnd"),
		(
			"its nearest edge from the boundary (%d wu) lies past fogEnd (%d wu)"
			% [int(size / 2.0 - art.num("drivableExtent")), int(art.num("fogEnd"))]
		)
	)
	var material: StandardMaterial3D = skirt.material_override as StandardMaterial3D
	_check(
		material.albedo_color.is_equal_approx(art.colour("groundColour")),
		"in the Ground's own albedo"
	)
	_check(skirt.position.y < 0.0, "a hair below Y = 0 — §5's Ground stays exactly 200×200")
	_check(skirt.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "casting nothing")
	var ground: MeshInstance3D = _node("Ground") as MeshInstance3D
	_check(
		(ground.mesh as PlaneMesh).size == Vector2(art.num("groundSize"), art.num("groundSize")),
		"and the specified Ground is untouched"
	)


func _test_grid_geometry_is_derived_not_typed() -> void:
	var divisions: int = int(_art.num("gridDivisions"))
	var height: float = _art.num("gridHeight")
	var lines_per_axis: int = divisions + 1
	var axis_lines_per_axis: int = 1 if divisions % 2 == 0 else 0
	var minor_per_axis: int = lines_per_axis - axis_lines_per_axis

	# PRIMITIVE_LINES: two vertices per line, two axes.
	var want_minor: int = minor_per_axis * 2 * 2
	var want_axes: int = axis_lines_per_axis * 2 * 2

	var minor := (_node("GridMinor") as MeshInstance3D).mesh as ArrayMesh
	var axes := (_node("GridAxes") as MeshInstance3D).mesh as ArrayMesh
	var minor_verts: int = (
		(minor.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	)
	var axis_verts: int = (
		(axes.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	)

	_check(
		minor_verts == want_minor,
		(
			"grid has %d minor line vertices for %d divisions (got %d)"
			% [want_minor, divisions, minor_verts]
		)
	)
	_check(
		axis_verts == want_axes,
		"grid has %d centre-axis vertices (got %d)" % [want_axes, axis_verts]
	)

	# THE EXTENT AND THE CELL SIZE. The vertex count above pins neither: review
	# doubled gridSize's extent and its step together — a grid twice the specified
	# size with twice the specified cell — and every other check here passed,
	# because the count was unchanged and the centre axis still fell on zero.
	# §5 gives "the central 100 x 100 wu, 20 divisions (5 wu cells)": three
	# numbers, and the count alone carries one of them.
	var minor_points := minor.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var half: float = _art.num("gridSize") / 2.0
	var widest: float = 0.0
	for point in minor_points:
		widest = maxf(widest, maxf(absf(point.x), absf(point.z)))
	_check(
		absf(widest - half) < EPSILON,
		"grid spans the specified central extent, +/-%.1f wu (got +/-%.1f)" % [half, widest]
	)

	var want_step: float = _art.num("gridSize") / float(divisions)
	var offsets: Array[float] = []
	for point in minor_points:
		if not offsets.has(point.x):
			offsets.append(point.x)
	offsets.sort()
	var smallest_gap: float = INF
	for i in range(1, offsets.size()):
		smallest_gap = minf(smallest_gap, offsets[i] - offsets[i - 1])
	_check(
		absf(smallest_gap - want_step) < EPSILON,
		"grid cells are the specified size, %.1f wu (got %.1f)" % [want_step, smallest_gap]
	)
	# §5 gives the centre axes and the minor lines DIFFERENT colours, and a test
	# that ignores which is which would pass on a grid drawn entirely in one.
	var axis_material := (
		(_node("GridAxes") as MeshInstance3D).material_override as StandardMaterial3D
	)
	var minor_material := (
		(_node("GridMinor") as MeshInstance3D).material_override as StandardMaterial3D
	)
	_check(
		axis_material.albedo_color == _art.colour("gridAxisColour"),
		"centre axes carry the specified axis colour"
	)
	_check(
		minor_material.albedo_color == _art.colour("gridMinorColour"),
		"minor lines carry the specified minor colour"
	)
	_check(
		axis_material.albedo_color != minor_material.albedo_color,
		"the two grid colours are distinct, as §5 gives them"
	)

	var first: Vector3 = (axes.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array)[0]
	_check(absf(first.y - height) < EPSILON, "grid sits at the specified height above the ground")
	_check(absf(first.x) < EPSILON, "the centre axis passes through zero")


func _test_band_sits_where_the_document_puts_it() -> void:
	var band := _node("StartFinishBand") as MeshInstance3D
	var mesh := band.mesh as PlaneMesh
	_check(
		absf(mesh.size.x - _art.num("startFinishBandWidthX")) < EPSILON,
		"band is the specified width on X"
	)
	_check(
		absf(mesh.size.y - _art.num("startFinishBandDepthZ")) < EPSILON,
		"band is the specified depth on Z"
	)
	_check(
		absf(band.position.z - _art.num("startFinishBandCentreZ")) < EPSILON,
		"band is centred at the specified Z, ahead of the kart's start pose"
	)
	_check(
		absf(band.position.x) < EPSILON,
		"band is centred on X at zero, as §5 places it (got %f)" % band.position.x
	)
	_check(
		absf(band.position.y - _art.num("startFinishBandHeightY")) < EPSILON,
		(
			"band sits at its specified height — the 0.00 / 0.01 / 0.02 layering "
			+ "that keeps ground, grid and band from depth fighting"
		)
	)
	var material := band.material_override as StandardMaterial3D
	_check(
		absf(material.albedo_color.a - _art.num("bandOpacity")) < EPSILON,
		"band carries the specified opacity"
	)
	# Without this the alpha above is INERT: TRANSPARENCY_DISABLED ignores it and
	# renders the band fully opaque, which review demonstrated passing.
	_check(
		material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
		"band's opacity is actually applied, not merely stored in an unused alpha"
	)
	var band_rgb := Color(material.albedo_color, 1.0)
	_check(
		band_rgb == _art.colour("bandColour"),
		"band is the specified colour, not merely translucent"
	)
	# "Visible from both sides" — a player crossing from the south must see the
	# same quad as one crossing from the north.
	_check(material.cull_mode == BaseMaterial3D.CULL_DISABLED, "band is visible from both sides")
	_check(
		material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
		"band is unlit, as §5 specifies"
	)


func _test_fog_and_tonemapping() -> void:
	var env := (_node("WorldEnvironment") as WorldEnvironment).environment
	_check(env.fog_enabled, "fog is on")
	_check(env.fog_mode == Environment.FOG_MODE_DEPTH, "fog is depth-based, so it can be linear")
	_check(
		(
			absf(env.fog_depth_begin - _art.num("fogStart")) < EPSILON
			and absf(env.fog_depth_end - _art.num("fogEnd")) < EPSILON
		),
		"fog spans the specified distances"
	)
	_check(env.fog_light_color == _art.colour("fogColour"), "fog is the specified colour")
	# §5 says LINEAR fog. Godot's depth fog is linear only at curve 1.0; any other
	# value bends it while leaving the start and end distances correct.
	_check(
		absf(env.fog_depth_curve - 1.0) < EPSILON,
		"fog is linear between its two distances (curve %f)" % env.fog_depth_curve
	)
	_check(
		env.ambient_light_color == _art.colour("ambientColour"),
		"ambient is the specified colour — §6 gives it as white"
	)
	# §5 specifies a FLAT sky. Godot applies depth fog to the background by
	# default, which put a visible gradient in this scene's first capture.
	_check(absf(env.fog_sky_affect) < EPSILON, "fog does not tint the sky, which must stay flat")
	# Design D1. A tone curve would make the document's hex colours unreachable.
	_check(
		env.tonemap_mode == Environment.TONE_MAPPER_LINEAR,
		"tonemapping is linear, so specified colours can render as themselves"
	)


## THE RATIOS ARE THE SPECIFICATION; the scale is this port's (ambiguity A9).
## This is the test that would fail if someone "fixed" a light by adjusting it
## alone — which is exactly how the document's ratios would be lost.
func _test_the_lighting_ratios_survive_the_scale() -> void:
	var scale: float = _art.num("lightScale")
	var env := (_node("WorldEnvironment") as WorldEnvironment).environment
	var sun := _node("Sun") as DirectionalLight3D

	_check(
		absf(sun.light_energy - _art.num("sunIntensity") * scale) < EPSILON,
		"the sun is the document's intensity times the shared scale"
	)
	_check(
		absf(env.ambient_light_energy - _art.num("ambientIntensity") * scale) < EPSILON,
		"ambient is the document's intensity times the same scale"
	)

	# The hemisphere is two lights standing in for one specified term (D2a). EACH
	# carries the full specified intensity: a hemisphere light gives an up-facing
	# surface all of its intensity in the sky colour and a down-facing surface all
	# of it in the ground colour, and no surface receives both. Asserting they SUM
	# to the specified value is what an earlier version of this test did, and it
	# encoded a halving bug as the specification — the one test advertised as
	# guarding the ratios could not catch the ratio being wrong.
	var fills: Array[Node] = []
	for child in _world.get_children():
		if child is DirectionalLight3D and child != sun:
			fills.append(child)
	_check(fills.size() == 2, "the hemisphere term is two fill lights (got %d)" % fills.size())
	var want_fill: float = _art.num("hemisphereIntensity") * scale
	for fill in fills:
		var light := fill as DirectionalLight3D
		_check(not light.shadow_enabled, "a hemisphere fill casts no shadow")
		_check(
			absf(light.light_energy - want_fill) < EPSILON,
			(
				"%s carries the FULL specified hemisphere intensity (%f), not a share of it (%f)"
				% [light.name, want_fill, light.light_energy]
			)
		)

	# And the ratio itself, stated the way the document states it, so that a
	# change to the scale alone can never move it.
	# RELATIVE, and not to 1e-9: Godot stores light_energy as 32-bit, so a ratio
	# of two scaled intensities carries about seven significant digits and no
	# more. An exact comparison here failed on the first run — the tolerance is
	# the storage's, not a concession.
	var ratio: float = sun.light_energy / env.ambient_light_energy
	var want: float = _art.num("sunIntensity") / _art.num("ambientIntensity")
	_check(
		absf(ratio - want) / want < 1e-6,
		(
			"sun-to-ambient ratio is the document's, whatever the scale (got %f, want %f)"
			% [ratio, want]
		)
	)

	# Aiming is load-bearing, and so is WHICH WAY each one aims. Counting how many
	# point vertically — which is all this test used to do — passes on two lights
	# both aimed down, and on the two colours swapped. Either is an inverted
	# hemisphere: light from above must carry the sky colour and light from below
	# the ground colour, or undersides are tinted with the sky and the tops with
	# grass. The spike's recorded bug was the horizontal case; these are its
	# neighbours and cost nothing extra to exclude.
	var from_above: int = 0
	var from_below: int = 0
	for fill in fills:
		var light := fill as DirectionalLight3D
		var forward: Vector3 = -light.global_transform.basis.z
		if forward.y < -0.99:
			from_above += 1
			_check(
				light.light_color == _art.colour("hemisphereSkyColour"),
				"the fill shining downward carries the SKY colour, so it tints upward faces"
			)
		elif forward.y > 0.99:
			from_below += 1
			_check(
				light.light_color == _art.colour("hemisphereGroundColour"),
				"the fill shining upward carries the GROUND colour, so it tints undersides"
			)
	_check(
		from_above == 1 and from_below == 1,
		(
			"exactly one hemisphere fill shines down and one shines up (got %d down, %d up)"
			% [from_above, from_below]
		)
	)


## §6 bolds "**Casts shadows.**" for the sun, and CONSTRAINTS §2 Tech stack calls the
## kart's contact shadow load-bearing. Nothing in this scene casts one yet — there are no
## props and no kart — so the CONFIGURATION is what can be checked here, and it is
## the part that carries A7's and A8's decisions.
func _test_the_sun_is_configured_to_cast() -> void:
	var sun := _node("Sun") as DirectionalLight3D
	_check(
		sun.light_color == _art.colour("sunColour"),
		"the sun is the specified colour — §6 gives it as white"
	)
	_check(sun.shadow_enabled, "the sun casts shadows, as §6 specifies")
	_check(
		absf(sun.directional_shadow_max_distance - _art.num("shadowMaxDistance")) < EPSILON,
		"shadow max distance is A7's decision — the ±60 wu volume, not the far plane"
	)
	_check(
		absf(sun.shadow_normal_bias - _art.num("shadowNormalBias")) < EPSILON,
		"normal bias is A8's decision, not Godot's 2.0, which erases the contact shadow"
	)
	# The document states the depth bias as a magnitude with the sign in prose.
	_check(
		absf(sun.shadow_bias + _art.num("shadowDepthBias")) < EPSILON,
		"depth bias is the specified magnitude, applied negative"
	)
	# The sun's DIRECTION, from its specified position toward the origin. Checked
	# as a direction rather than a position: Godot's directional light has no
	# meaningful position, so a mirrored or moved sun would otherwise go unnoticed.
	var want := -(
		Vector3(_art.num("sunPositionX"), _art.num("sunPositionY"), _art.num("sunPositionZ"))
		. normalized()
	)
	var got := -sun.global_transform.basis.z
	_check(
		got.distance_to(want) < 1e-5,
		"the sun aims from its specified position at the origin (want %v, got %v)" % [want, got]
	)


## Design D2a. Sky-sourced ambient makes Godot draw the sky and ignore the flat
## background colour, which cost §5's flat sky. This is the regression guard: it
## fails if someone reintroduces the sky resource.
func _test_the_sky_is_not_drawn() -> void:
	var env := (_node("WorldEnvironment") as WorldEnvironment).environment
	_check(env.background_mode == Environment.BG_COLOR, "the background is a flat colour")
	_check(
		env.background_color == _art.colour("skyColour"),
		"the background is the specified sky colour"
	)
	_check(
		env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR,
		"ambient comes from a colour, not the sky — a sky source draws a gradient (D2a)"
	)
	_check(env.sky == null, "no sky resource is attached, so none can be drawn")


## The spec scenario "A viewpoint exists and is declared temporary" — without a
## camera the scene renders nothing, and every capture this change and the next
## one owe would be impossible.
func _test_a_viewpoint_exists() -> void:
	# Found BY TYPE, not by name. Fetching the node as "PlaceholderCamera" and then
	# asserting its name begins with "Placeholder" is a check that cannot fail, and
	# that is what an earlier version of this test did — review caught it.
	var cameras: Array[Camera3D] = []
	for child in _world.get_children():
		if child is Camera3D:
			cameras.append(child as Camera3D)
	_check(cameras.size() == 1, "the scene has exactly one viewpoint (got %d)" % cameras.size())
	if cameras.is_empty():
		return
	var camera: Camera3D = cameras[0]
	_check(camera.current, "the viewpoint is the active camera")
	_check(
		(
			absf(camera.near - _art.num("nearClip")) < EPSILON
			and absf(camera.far - _art.num("farClip")) < EPSILON
		),
		"the viewpoint uses the specified clip planes"
	)
	# It must ANNOUNCE itself as temporary: a placeholder that stops doing so has
	# quietly become the specification. Note what canNOT distinguish it — its field
	# of view is Godot's default 75, and the document's fovBase is also 75, so the
	# two coincide by accident. The name is the safeguard, and add-chase-camera
	# replacing it is the plan.
	_check(
		camera.name.begins_with("Placeholder"),
		(
			"the viewpoint names itself a placeholder, not the specified chase camera (got %s)"
			% camera.name
		)
	)


## This change renders a static world. The accumulator, step() and interpolation
## belong to add-kart-view-orientation-and-input.
func _test_nothing_advances() -> void:
	var before := (_node("Sun") as DirectionalLight3D).global_transform
	var ground_before := (_node("Ground") as MeshInstance3D).global_transform
	await process_frame
	await process_frame
	_check(
		(
			(_node("Sun") as DirectionalLight3D).global_transform.is_equal_approx(before)
			and (_node("Ground") as MeshInstance3D).global_transform.is_equal_approx(ground_before)
		),
		"nothing in the world moves between frames"
	)
