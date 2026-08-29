# Builds the design document's §5 environment and §6 lighting, from data.
#
# EVERY VALUE COMES FROM data/tuning.json. Nothing here is a literal that the
# design document states — CONSTRAINTS §3 Language and style, enforced by
# tools/check_tuning_literals.py. The few numbers that do appear are geometry
# this port chose (a plane has four corners) or the placeholder camera, which is
# marked as such below.
#
# The scene is BUILT IN CODE rather than authored in the .tscn because the grid
# is generated geometry and because a .tscn full of hand-typed colours would be
# a second home for values that already have one.
#
# Nothing here steps. The simulation, its accumulator, and render interpolation
# arrive with add-kart-view-orientation-and-input.
extends Node3D

const ArtTuning := preload("res://scripts/art_tuning.gd")

# A PLACEHOLDER, replaced by add-chase-camera.
#
# Written down rather than nudged into place so every capture this change and
# the next one produce is reproducible. It is deliberately NOT the specified
# chase camera: that camera trails the kart, and there is no kart yet.
#
# Its field of view is left at Godot's default, which is 75 — and the design
# document's fovBase is also 75. They COINCIDE, by accident, and an earlier
# version of this comment claimed the opposite as if it were a safeguard. What
# keeps the placeholder from quietly becoming the specification is that it is
# named as one and that add-chase-camera replaces it, not a number that happens
# to differ.
const PLACEHOLDER_CAMERA_POSITION := Vector3(0.0, 16.0, -34.0)
const PLACEHOLDER_CAMERA_TARGET := Vector3(0.0, 0.0, 12.0)

# Overridable so a capture can look at the world from somewhere other than the
# default viewpoint — scenes/boundary_view.tscn sets these to stand at the
# drivable boundary and look outward, which is how acceptance item 7's "grass
# still visible beyond" is shown. Defaults are the placeholder pose above.
@export var camera_position: Vector3 = PLACEHOLDER_CAMERA_POSITION
@export var camera_target: Vector3 = PLACEHOLDER_CAMERA_TARGET

var art: RefCounted = null


func _ready() -> void:
	art = ArtTuning.load_art()
	if art == null:
		push_error("world: no art tuning; nothing built")
		return
	build()


## Split from _ready() so a test or a measurement tool can build the world into
## a tree it owns, without going through scene instantiation.
func build() -> void:
	add_child(_environment())
	add_child(_ground())
	add_child(_grid_minor())
	add_child(_grid_axes())
	add_child(_start_finish_band())
	add_child(_sun())
	for fill in _hemisphere_fills():
		add_child(fill)
	add_child(_placeholder_camera())


# --- environment ------------------------------------------------------------


## Sky, fog, ambient and tonemapping.
##
## The background is a FLAT COLOUR, not the sky resource: §5 specifies a flat
## sky with no gradient, and Godot's procedural sky always produces one. The sky
## resource exists only where the ambient term can read it.
##
## Tonemapping is LINEAR and the white point is 1.0. The design document
## specifies its look as exact hex colours, so a filmic or ACES curve would make
## the specified albedo unreachable by construction — see design D1. That choice
## is what makes the exposure scale something to measure rather than assume.
func _environment() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = art.colour("skyColour")
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_white = 1.0

	var scale: float = art.light_scale()
	var ambient: float = art.num("ambientIntensity")

	# The document's 0.60 ambient term, and ONLY that term (design D2a). The 0.40
	# hemisphere term is two directional lights — see _hemisphere_fills().
	#
	# NOT sky-sourced ambient, which is what D2 originally specified. Setting
	# ambient_light_source = SKY makes Godot draw the sky and ignore
	# background_mode = BG_COLOR: verified by setting the background to magenta
	# and capturing a frame that was still sky blue. The visible cost was a band
	# of the hemisphere's ground colour across the horizon where §5 requires a
	# flat sky. The `hemisphere` local below is read by _hemisphere_fills(), not
	# here, which is why the ratio still cannot drift.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = art.colour("ambientColour")
	env.ambient_light_energy = ambient * scale

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = art.colour("fogColour")
	env.fog_depth_begin = art.num("fogStart")
	env.fog_depth_end = art.num("fogEnd")
	env.fog_depth_curve = 1.0
	# Fog must NOT tint the sky. Godot applies depth fog to the background by
	# default (fog_sky_affect defaults to 1.0), which produced a visible
	# horizon-to-zenith gradient in the first capture of this scene — and §5
	# specifies a FLAT sky with no gradient, in the same sentence that gives its
	# colour. It also makes the exposure criterion "the unlit sky renders exactly
	# its specified colour" unmeetable, because the sky would no longer be unlit.
	env.fog_sky_affect = 0.0

	var holder := WorldEnvironment.new()
	holder.name = "WorldEnvironment"
	holder.environment = env
	return holder


# --- geometry ---------------------------------------------------------------


func _ground() -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	var size: float = art.num("groundSize")
	mesh.size = Vector2(size, size)

	var material := StandardMaterial3D.new()
	material.albedo_color = art.colour("groundColour")
	material.roughness = art.num("groundRoughness")
	material.metallic = art.num("groundMetalness")

	var node := MeshInstance3D.new()
	node.name = "Ground"
	node.mesh = mesh
	node.material_override = material
	# §5: receives shadows, does not cast. A ground plane casting into its own
	# shadow map spends texels on a surface nothing is ever behind.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## The reference grid, as line geometry (design D6).
##
## Two meshes rather than one, because §5 gives the centre axes and the minor
## lines different colours and an unlit material carries one colour. Both sit at
## the specified height above the ground to avoid depth fighting.
func _grid_minor() -> MeshInstance3D:
	return _grid_mesh(false, "GridMinor", art.colour("gridMinorColour"))


func _grid_axes() -> MeshInstance3D:
	return _grid_mesh(true, "GridAxes", art.colour("gridAxisColour"))


func _grid_mesh(axes_only: bool, node_name: String, colour: Color) -> MeshInstance3D:
	var extent: float = art.num("gridSize") / 2.0
	var divisions: int = int(art.num("gridDivisions"))
	var step: float = art.num("gridSize") / float(divisions)
	var height: float = art.num("gridHeight")

	var points := PackedVector3Array()
	for i in range(divisions + 1):
		var offset: float = -extent + float(i) * step
		# The centre axes are the lines through zero, identified by INDEX rather
		# than by comparing the float offset against an epsilon. Integer
		# arithmetic is exact, and it gets the odd-division case right for free:
		# a grid with an odd division count has no line at zero, so i * 2 never
		# equals divisions and no line is miscoloured as an axis.
		var is_axis: bool = i * 2 == divisions
		if is_axis != axes_only:
			continue
		points.append(Vector3(offset, height, -extent))
		points.append(Vector3(offset, height, extent))
		points.append(Vector3(-extent, height, offset))
		points.append(Vector3(extent, height, offset))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour

	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## The start/finish band: the timing gate, and the only track furniture in the
## game. Unlit, partially transparent, and visible from both sides, because a
## player crossing it from the south must see the same quad as one crossing
## from the north.
func _start_finish_band() -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(art.num("startFinishBandWidthX"), art.num("startFinishBandDepthZ"))

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var colour: Color = art.colour("bandColour")
	colour.a = art.num("bandOpacity")
	material.albedo_color = colour
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var node := MeshInstance3D.new()
	node.name = "StartFinishBand"
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = Vector3(
		0.0, art.num("startFinishBandHeightY"), art.num("startFinishBandCentreZ")
	)
	return node


# --- lighting ---------------------------------------------------------------


## The sun. Shadow settings carry the two decisions the renderer spike settled:
## A7 (the ±60 wu volume becomes max_distance, not the far plane) and A8
## (normal bias 0.1, not Godot's 2.0, which erases the kart's contact shadow).
## The map size is pinned in project.godot, not here — Godot resolves an unset
## size to its 4096 desktop default rather than the specified 2048.
func _sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = art.colour("sunColour")
	sun.light_energy = art.num("sunIntensity") * art.light_scale()
	sun.shadow_enabled = true
	# The document states the depth bias as a magnitude with the sign in prose,
	# exactly as it does for friction; Godot's parameter takes the signed value.
	sun.shadow_bias = -art.num("shadowDepthBias")
	sun.shadow_normal_bias = art.num("shadowNormalBias")
	sun.directional_shadow_max_distance = art.num("shadowMaxDistance")
	sun.look_at_from_position(
		Vector3(art.num("sunPositionX"), art.num("sunPositionY"), art.num("sunPositionZ")),
		Vector3.ZERO,
		Vector3.UP
	)
	return sun


## The design document's hemisphere term, as two directional lights (design D2a).
##
## Godot has no hemisphere light, and its two ambient sources each cost one of
## the two properties §5 and §6 specify together: sky-sourced ambient tints
## undersides but draws a gradient sky, and colour-sourced ambient keeps the sky
## flat but tints nothing. This is the renderer spike's approximation, already
## prior art in scenes/renderer_probe.tscn — one light aimed DOWN carrying the
## sky colour, one aimed UP carrying the ground colour.
##
## AIMING THEM IS THE POINT. The spike records an earlier version with both
## horizontal, where the ground plane received nothing from either and undersides
## went untinted — a hemisphere that lit nothing while looking configured.
##
## EACH CARRIES THE FULL SPECIFIED INTENSITY, not half of it. A hemisphere light
## gives an up-facing surface the whole of its intensity in the sky colour, and a
## down-facing surface the whole of it in the ground colour — no surface receives
## both, so there is nothing to divide. An earlier version here halved them on an
## energy-conservation argument, which is the wrong argument for a per-surface
## irradiance: it delivered the ground half the fill the document specifies, and
## review measured the difference (deviation 0.0220 halved against 0.0973 full at
## the same scale, which moved the chosen scale itself). The renderer spike used
## full intensity on both, and was right.
##
## Neither casts: they are a fill, and §6 gives exactly one shadow-casting light.
func _hemisphere_fills() -> Array[DirectionalLight3D]:
	var each: float = art.num("hemisphereIntensity")
	var scale: float = art.light_scale()
	var down := DirectionalLight3D.new()
	down.name = "HemisphereSky"
	down.light_color = art.colour("hemisphereSkyColour")
	down.light_energy = each * scale
	down.shadow_enabled = false
	down.rotation_degrees = Vector3(-90.0, 0.0, 0.0)

	var up := DirectionalLight3D.new()
	up.name = "HemisphereGround"
	up.light_color = art.colour("hemisphereGroundColour")
	up.light_energy = each * scale
	up.shadow_enabled = false
	up.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	return [down, up] as Array[DirectionalLight3D]


# --- viewpoint --------------------------------------------------------------


func _placeholder_camera() -> Camera3D:
	var camera := Camera3D.new()
	camera.name = "PlaceholderCamera"
	camera.near = art.num("nearClip")
	camera.far = art.num("farClip")
	camera.look_at_from_position(camera_position, camera_target, Vector3.UP)
	camera.current = true
	return camera
