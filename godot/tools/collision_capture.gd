# Capture a staged collision, through the real game.
#
#   godot -s tools/collision_capture.gd -- --mode contact --out docs/progress/x.png
#
# WINDOWED, like every capture in this project, and unfocused so it does not
# interrupt whoever is running it.
#
# WHY NOT tools/drive_capture.gd. That drives the scattered field, where what the
# kart meets depends on the seed and where it happens to be pointing. A capture of
# "the kart stopped against a tree" has to be a capture of the kart stopped against
# a tree, so this tool REPLACES the field with a staged arrangement and drives into
# it. Everything else is the shipped game: the same scene, the same tick, the same
# collision code, the same chase camera.
#
# It reports the kart's state, the resolved prop and the camera's displacement at
# the moment of the grab, so a reader can check the frame against what it claims —
# and, for the shudder, so the choice of frame is stated rather than eyeballed.
extends SceneTree

const Scatter := preload("res://scripts/core/scatter.gd")
const Normalise := preload("res://scripts/core/normalise.gd")
const ChaseCamera := preload("res://scripts/core/chase_camera.gd")

## Rendered frames to wait before grabbing. Same reason as drive_capture.gd: a
## capture taken before the renderer catches up looks like evidence and is not.
const SETTLE_FRAMES := 12
const MAX_BLACK_FRACTION := 0.20

## Ticks to drive before giving up on reaching the staged prop.
const DRIVE_LIMIT := 400
## Where the staged prop stands, straight ahead of the kart down +Z.
const PROP_Z := 10.0
## The elevated viewpoint the pin capture uses. See _lift_the_camera().
const PIN_EYE_BACK := 6.0
const PIN_EYE_HEIGHT := 9.0


func _init() -> void:
	var options := _parse()
	var mode: String = str(options.get("mode", "contact"))
	var out_path: String = str(options.get("out", "gallery/collision.png"))
	# For the shudder: how many ticks after the collision to grab. Stated on the
	# command line so the frame's provenance is in the command, not in a memory.
	var after: int = int(options.get("after", 0))
	# Suppress the jolt. THE SHUDDER IS 0.17 wu ON A CAMERA 8 wu BACK — about a
	# degree of view — so a single frame captioned "mid-shudder" is a claim nobody
	# can check. Run the same command twice, once with --nojolt 1, and the two
	# frames differ by the jolt and by nothing else.
	var nojolt: bool = str(options.get("nojolt", "0")) == "1"

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	await process_frame

	var root: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	get_root().add_child(root)
	await process_frame

	if nojolt:
		root.sim.tuning.shake_horizontal = 0.0
		root.sim.tuning.shake_vertical = 0.0

	var staged: Array = _stage(root, mode)
	if staged.is_empty():
		printerr("collision_capture: unknown mode '%s'" % mode)
		quit(1)
		return

	var report: String = await _drive(root, mode, after)
	if mode == "pin":
		_lift_the_camera(root)

	for _i in range(SETTLE_FRAMES):
		await process_frame

	var image := get_root().get_texture().get_image()
	if image == null:
		printerr("collision_capture: no image — this needs a WINDOWED run")
		quit(1)
		return
	var black: float = _black_fraction(image)
	if black > MAX_BLACK_FRACTION:
		printerr(
			(
				(
					"collision_capture: %.1f%% of the frame is pure black — the"
					+ " renderer had not caught up. Nothing written."
				)
				% (black * 100.0)
			)
		)
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	if image.save_png(out_path) != OK:
		printerr("collision_capture: could not write %s" % out_path)
		quit(1)
		return
	print("collision_capture: %s — %s" % [out_path, report])
	quit()


## Replace the scattered field with the arrangement this mode needs, and hand the
## simulation the props in registration order exactly as main.gd does.
func _stage(root: Node3D, mode: String) -> Array:
	var field: Node3D = root.get_node_or_null("PropField") as Node3D
	if field == null:
		return []
	var boxes: Dictionary = field.authored_boxes()
	if boxes.is_empty():
		return []

	var placements: Array = []
	if mode == "contact" or mode == "shudder":
		placements.append(_placement("tree", 0.0, PROP_Z, boxes, root.sim.tuning, 0))
	elif mode == "pin":
		# The design document's own pair: two cottages at exactly minPropSeparation,
		# with the kart between them.
		var separation: float = root.sim.tuning.min_prop_separation
		placements.append(
			_placement("cottage", -separation / 2.0, PROP_Z, boxes, root.sim.tuning, 0)
		)
		placements.append(
			_placement("cottage", separation / 2.0, PROP_Z, boxes, root.sim.tuning, 1)
		)
	else:
		return []

	# THROUGH main.gd's own method, not by repeating it. An earlier version set
	# root.sim.props here, which meant this capture would have shown a kart stopped
	# against a tree in a build where the shipped game wired no props at all.
	root.build_field(placements)
	return placements


## One placement, built the way scatter.gd builds one: normalise to the target
## height, then derive the grounding offset from the resulting box. No variation —
## a staged capture wants a known size.
func _placement(
	asset: String, x: float, z: float, boxes: Dictionary, tuning: RefCounted, sequence: int
) -> RefCounted:
	var authored: AABB = boxes[asset] as AABB
	var normalised: RefCounted = Normalise.to_target_height(authored, tuning.target_height(asset))
	var placement := Scatter.Placement.new()
	placement.asset = asset
	placement.x = x
	placement.z = z
	placement.yaw = 0.0
	placement.scale = normalised.scale
	placement.offset_x = normalised.box.position.x - authored.position.x * normalised.scale
	placement.offset_y = normalised.box.position.y - authored.position.y * normalised.scale
	placement.offset_z = normalised.box.position.z - authored.position.z * normalised.scale
	placement.sequence = sequence
	return placement


## Drive into the staged arrangement and stop at the frame this mode wants.
func _drive(root: Node3D, mode: String, after: int) -> String:
	if mode == "pin":
		# Put the kart between the pair rather than driving it in from outside: the
		# gap is 0.09 wu and nothing can drive through it. This is the regeneration
		# case — props scattered around a kart that was already there.
		root.sim.pos_z = PROP_Z
		root.sim.pos_x = 0.0
		# Driving ALONG the pair's axis, into the right-hand cottage. This is the
		# heading where the pin lasts: about 125 ticks here against 15-20 at the
		# other fourteen of sixteen headings, which collision_test.gd sweeps. The
		# capture shows the long case because it is the one a player notices.
		root.sim.yaw = PI / 2.0
		root.camera.reset()

	# A SECOND CAMERA, stepped identically and never jolted.
	#
	# "Camera 1.5 wu from its trailing target" is not evidence of a shudder: the
	# camera lags by design, so most of that number is the lag it would have had
	# with no collision at all. The difference between the real camera and this one
	# is the jolt and nothing else, which is the number that makes "mid-shudder" a
	# claim a reader can check rather than take on trust.
	var unjolted: RefCounted = ChaseCamera.new()
	unjolted.tuning = root.sim.tuning

	var collided_at := -1
	var resolved := ""
	for tick in range(DRIVE_LIMIT):
		Input.action_press("accelerate")
		await physics_frame
		unjolted.step(root.sim.pos_x, root.sim.pos_z, root.sim.yaw, root.sim.speed_ratio())
		if root.sim.last_hit != null and collided_at < 0:
			collided_at = tick
			resolved = (root.sim.props[root.sim.last_hit.index]).asset
		if collided_at >= 0 and tick >= collided_at + after:
			break
	Input.action_release("accelerate")

	var dx: float = root.camera.pos_x - unjolted.pos_x
	var dy: float = root.camera.pos_y - unjolted.pos_y
	var dz: float = root.camera.pos_z - unjolted.pos_z
	var shudder: float = sqrt(dx * dx + dy * dy + dz * dz)
	return (
		(
			"mode=%s collided at tick %d against '%s', grabbed %d tick(s) later;"
			+ " kart x=%.3f z=%.3f v=%.5f; camera %.4f wu from its trailing target,"
			+ " of which %.4f wu is the shudder (against an identical camera never jolted)"
		)
		% [
			mode,
			collided_at,
			resolved,
			after,
			root.sim.pos_x,
			root.sim.pos_z,
			root.sim.velocity,
			_camera_offset(root),
			shudder
		]
	)


## The ONE capture in this project not taken through the game's own camera, and
## the reason is stated rather than left to be noticed.
##
## The pin lasts longest when the kart drives ALONG the line joining the two props
## — which is exactly when the chase camera, sitting chaseBack behind the kart on
## that same line, has the near prop filling the frame and the kart hidden behind
## it. The frame is then a photograph of a cottage. Lifting the camera to an
## elevated three-quarter view shows what the capture is for: the kart stopped
## between two cottages with the gap it cannot pass through.
##
## The simulation is frozen first so the view survives the settle frames; nothing
## about the kart's state is touched, and the numbers in the report were taken
## before this ran.
func _lift_the_camera(root: Node3D) -> void:
	root.set_physics_process(false)
	# Behind on Z and high: the pair lies along X, so this puts them side by side
	# with the kart between them rather than one in front of the other.
	root.camera.pos_x = root.sim.pos_x
	root.camera.pos_y = PIN_EYE_HEIGHT
	root.camera.pos_z = root.sim.pos_z - PIN_EYE_BACK
	root.camera.aim_x = root.sim.pos_x
	root.camera.aim_y = 0.0
	root.camera.aim_z = root.sim.pos_z


## How far the camera sits from where it would rest with no jolt. This is the
## number that says whether a "mid-shudder" frame really is one.
func _camera_offset(root: Node3D) -> float:
	var tuning: RefCounted = root.sim.tuning
	var target_x: float = root.sim.pos_x - tuning.chase_back * sin(root.sim.yaw)
	var target_z: float = root.sim.pos_z - tuning.chase_back * cos(root.sim.yaw)
	var dx: float = root.camera.pos_x - target_x
	var dy: float = root.camera.pos_y - tuning.chase_up
	var dz: float = root.camera.pos_z - target_z
	return sqrt(dx * dx + dy * dy + dz * dz)


func _black_fraction(image: Image) -> float:
	var black: int = 0
	var total: int = 0
	var step: int = 8
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			total += 1
			var pixel := image.get_pixel(x, y)
			if pixel.r == 0.0 and pixel.g == 0.0 and pixel.b == 0.0:
				black += 1
	return float(black) / float(maxi(total, 1))


func _parse() -> Dictionary:
	var options := {}
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size():
		if arguments[index].begins_with("--") and index + 1 < arguments.size():
			options[arguments[index].substr(2)] = arguments[index + 1]
			index += 2
		else:
			index += 1
	return options
