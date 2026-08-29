# The simulation's tuning values, as a plain object.
#
# NO DEFAULTS AND NO LITERALS. Every value the design document names lives in
# godot/data/tuning.json and nowhere else (CONSTRAINTS §3 Language and style);
# a default here would be a second copy that silently disagrees after a retune.
# The fields start at zero, which is not a plausible tuning value, so a caller
# that forgets to supply one gets an obviously broken simulation rather than a
# subtly wrong one.
#
# The core never reads a file. A loader outside scripts/core/ parses the JSON
# and hands the result here, which is what lets a test construct a Tuning
# directly and drive the tick with synthetic values. See design D2 in
# openspec/changes/add-simulation-tick-core/design.md.
extends RefCounted

# --- physics ---
var accel: float = 0.0
var max_speed: float = 0.0
var reverse_factor: float = 0.0
var friction: float = 0.0
var turn_rate: float = 0.0
var steer_threshold: float = 0.0
var bounce_factor: float = 0.0

# --- world ---
var drivable_extent: float = 0.0

# --- chase camera ---
# In the core because the camera is a fixed-step recurrence and its specified
# properties are numbers — see scripts/core/chase_camera.gd and design D1 of
# add-chase-camera. Not because it is gameplay; it is not.
var chase_back: float = 0.0
var chase_up: float = 0.0
var aim_ahead: float = 0.0
var aim_up: float = 0.0
var chase_smoothing: float = 0.0
var fov_base: float = 0.0
var fov_max: float = 0.0

# --- dial ---
var speedo_max: float = 0.0

# --- per-asset target heights, from the design document's §3 table ---
# A dictionary rather than named fields: the asset set is data, and M3 adds
# prop counts alongside these. Empty until apply_table() fills it.
var asset_target_heights: Dictionary = {}


## Populate from the design document's nested tuning table.
## A method rather than a static factory: a static one would have to load() its
## own script to construct an instance, which is both a file operation inside
## scripts/core/ and untypeable without a class_name.
## A missing key leaves its field at zero, which missing_fields() then reports,
## so the failure names itself rather than surfacing as a kart that will not move.
func apply_table(table: Dictionary) -> void:
	var physics: Dictionary = table.get("physics", {})
	var world: Dictionary = table.get("world", {})
	var hud: Dictionary = table.get("camera_and_hud", {})
	accel = float(physics.get("accel", 0.0))
	max_speed = float(physics.get("maxSpeed", 0.0))
	reverse_factor = float(physics.get("reverseFactor", 0.0))
	friction = float(physics.get("friction", 0.0))
	turn_rate = float(physics.get("turnRate", 0.0))
	steer_threshold = float(physics.get("steerThreshold", 0.0))
	bounce_factor = float(physics.get("bounceFactor", 0.0))
	drivable_extent = float(world.get("drivableExtent", 0.0))
	chase_back = float(hud.get("chaseBack", 0.0))
	chase_up = float(hud.get("chaseUp", 0.0))
	aim_ahead = float(hud.get("aimAhead", 0.0))
	aim_up = float(hud.get("aimUp", 0.0))
	chase_smoothing = float(hud.get("chaseSmoothing", 0.0))
	fov_base = float(hud.get("fovBase", 0.0))
	fov_max = float(hud.get("fovMax", 0.0))
	speedo_max = float(hud.get("speedoMax", 0.0))
	var heights: Dictionary = table.get("asset_target_heights", {})
	asset_target_heights = {}
	for asset in heights:
		if not str(asset).begins_with("_"):
			asset_target_heights[asset] = float(heights[asset])


## The target height for an asset, or zero if it is not in the table. Callers
## pass this to the normalisation rather than compiling a literal.
func target_height(asset: String) -> float:
	return float(asset_target_heights.get(asset, 0.0))


## Names any field still at zero. Used by the loader and by tests; a simulation
## stepped with an incomplete Tuning is a defect, not a degraded mode.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	for field in [
		"accel",
		"max_speed",
		"reverse_factor",
		"friction",
		"turn_rate",
		"steer_threshold",
		"bounce_factor",
		"drivable_extent",
		"chase_back",
		"chase_up",
		"aim_ahead",
		"aim_up",
		"chase_smoothing",
		"fov_base",
		"fov_max",
		"speedo_max",
	]:
		if float(get(field)) == 0.0:
			missing.append(field)
	return missing
