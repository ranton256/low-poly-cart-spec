# Loads godot/data/tuning.json and hands the result to the simulation core.
#
# DELIBERATELY OUTSIDE scripts/core/. The core receives tuning; it does not
# locate or parse anything. FileAccess is not a banned symbol, so the core
# *could* read this file — it should not, because a simulation that needs a
# filesystem is no longer constructible from a test, and because the design
# document requires tuning values to be swappable at runtime rather than
# re-read. See design D2 in
# openspec/changes/add-simulation-tick-core/design.md.
extends RefCounted

const TUNING_PATH := "res://data/tuning.json"
const Tuning := preload("res://scripts/core/tuning.gd")


## Returns a fully populated Tuning, or null with the reason pushed to the
## error log. A partially populated Tuning is treated as failure: a zero accel
## produces a kart that will not move, which is a far more confusing symptom
## than a named missing key.
static func load_tuning(path: String = TUNING_PATH) -> RefCounted:
	if not FileAccess.file_exists(path):
		push_error("tuning: %s not found" % path)
		return null

	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("tuning: %s is not a JSON object" % path)
		return null

	var tuning := Tuning.new()
	tuning.apply_table(parsed as Dictionary)
	var missing: PackedStringArray = tuning.missing_fields()
	if not missing.is_empty():
		push_error("tuning: %s is missing %s" % [path, ", ".join(missing)])
		return null
	return tuning
