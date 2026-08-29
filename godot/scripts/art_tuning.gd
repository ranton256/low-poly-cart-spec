# The environment, lighting and port-decision values, as a plain object.
#
# A SIBLING OF tuning_loader.gd, NOT AN EXTENSION OF IT. The core Tuning holds
# what the simulation needs; the simulation has no use for a sky colour, and
# putting one there would widen the object every view concern touches. Both read
# godot/data/tuning.json, so the "exactly one home" requirement in
# openspec/specs/godot/project-configuration/spec.md still holds — one file, two
# readers with different needs.
#
# LOOKUP IS FLAT ACROSS GROUPS, and that is sound rather than sloppy:
# tools/check_tuning_transcription.py fails when a key appears in two groups, so
# a name resolves to exactly one value or the gate is already red. The grouping
# in the JSON records where a value came from; it is not a namespace. This also
# means the view does not need to know that the band's dimensions sit in
# unnamed_in_spec while its opacity sits in environment — an accident of which
# table the design document put them in.
#
# NO DEFAULTS. A missing key is an error with a name, never a fallback: a
# silently defaulted sky colour is a look nobody chose and nobody can trace.
extends RefCounted

const TUNING_PATH := "res://data/tuning.json"

# The bisection hook for ambiguity A9. tools/find_light_scale.py sweeps the
# scale by setting this, so the search never has to rewrite the committed data
# file in a loop. Unset — the normal case, including every shipped run — means
# "use the committed value". Precedent: LPC_SAVE_FILE, which exists for the same
# reason.
const SCALE_OVERRIDE_ENV := "LPC_LIGHT_SCALE"

var values: Dictionary = {}


## Returns a populated ArtTuning, or null with the reason pushed to the error
## log. Partial population is treated as failure for the same reason the
## simulation's loader treats it so: a half-lit scene is a more confusing symptom
## than a named missing key.
static func load_art(path: String = TUNING_PATH) -> RefCounted:
	if not FileAccess.file_exists(path):
		push_error("art tuning: %s not found" % path)
		return null

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("art tuning: %s is not a JSON object" % path)
		return null

	var table := parsed as Dictionary
	var required := ["environment", "lighting", "port_decisions"]
	var missing := PackedStringArray()
	for group in required:
		if not table.has(group):
			missing.append(group)
	if not missing.is_empty():
		push_error("art tuning: %s is missing group(s) %s" % [path, ", ".join(missing)])
		return null

	var art := load("res://scripts/art_tuning.gd").new() as RefCounted
	for group in table:
		if (group as String).begins_with("_"):
			continue
		for key in table[group] as Dictionary:
			if not (key as String).begins_with("_"):
				art.values[key] = (table[group] as Dictionary)[key]
	return art


## A number, by name. Missing is fatal rather than zero — see the file header.
func num(key: String) -> float:
	if not values.has(key) or values[key] == null:
		push_error("art tuning: %s is not in the tuning data" % key)
		return 0.0
	return float(values[key])


## A colour, by name, from the design document's own hex string.
func colour(key: String) -> Color:
	if not values.has(key):
		push_error("art tuning: %s is not in the tuning data" % key)
		return Color.MAGENTA
	return Color.html(str(values[key]))


## The single factor converting the design document's intensities into Godot's
## units — ambiguity A9. The document's ratios are preserved by construction,
## because every caller scales all three lights by this and nothing scales one
## alone.
func light_scale() -> float:
	var override: String = OS.get_environment(SCALE_OVERRIDE_ENV)
	if override != "":
		return float(override)
	if values.get("lightScale") == null:
		push_error(
			(
				(
					"art tuning: lightScale is not set. It is the outcome of the A9 "
					+ "measurement — run tools/find_light_scale.py, or set %s to sweep it."
				)
				% SCALE_OVERRIDE_ENV
			)
		)
		return 0.0
	return float(values["lightScale"])
