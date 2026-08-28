# Asset suite — proves the seven supplied models actually import and load.
#
#   godot --headless -s tests/assets_test.gd
#
# WHY THIS EXISTS AS A SUITE. `godot --headless --import` exits 0 even when a
# model fails to import, so `set -euo pipefail` in tools/test.sh cannot catch an
# import failure and a bare --import step is decorative. Loading each model and
# asserting on the result is the only thing that actually fails.
#
# tools/sync_assets.sh proves the models are PRESENT and byte-correct; this
# proves the engine can turn them into scenes. Different failures.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")

# The design document's §1 inventory. Listed explicitly so a missing model is a
# failure rather than a quietly smaller world.
const MODELS := ["kart", "tree", "rock", "cone", "crate", "tires", "cottage"]


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_test_every_model_loads()
	_test_every_model_is_single_mesh()
	RVTest.finish(self, "assets: %d models import and load" % MODELS.size(), "asset check(s)")


func _test_every_model_loads() -> void:
	for name in MODELS:
		var path := "res://assets/%s.glb" % name
		_check(ResourceLoader.exists(path), "%s is importable at %s" % [name, path])
		_check(load(path) != null, "%s loads as a resource" % name)


## The design document specifies one mesh and one material per model. A model
## that imports but arrives as an empty scene would otherwise pass.
func _test_every_model_is_single_mesh() -> void:
	for name in MODELS:
		var packed = load("res://assets/%s.glb" % name)
		if packed == null:
			continue
		var root = packed.instantiate()
		var meshes := 0
		for child in root.get_children():
			if child is MeshInstance3D:
				meshes += 1
		_check(meshes == 1, "%s instantiates exactly one mesh (got %d)" % [name, meshes])
		root.free()
