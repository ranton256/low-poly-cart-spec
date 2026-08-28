# The test harness, in one place.
#
# Every headless suite in this directory is a `SceneTree` entry point run as
#   godot --headless -s tests/<suite>.gd
# and every one of them needs the same three things: an assertion that records
# rather than aborts, a failure count, and an exit code the shell can act on.
# That is the whole framework — no addon, no dependency, no test runner.
#
# Suites keep a two-line `_check` that delegates here, so their assertion call
# sites read exactly as they always have:
#
#   func _check(cond: bool, msg: String) -> void:
#       RVTest.check(cond, msg)
#
# and close with:
#
#   RVTest.finish(self, "<what passed>", "<thing>(s)")
#
# Static state is safe because each suite is its own process; `reset()` exists
# for a driver that runs several suites in one.
#
# Deliberately NOT a `class_name`. Global class names are resolved from a cache
# the EDITOR writes; a class added without opening the editor is invisible to
# `godot -s` and every suite dies with "Identifier not declared". preload has no
# such dependency and works on a fresh clone.

static var failures := 0


static func reset() -> void:
	failures = 0


## Record a failure and keep going. Suites report every problem in one run —
## aborting on the first would hide the rest, and a list is what a fix needs.
static func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: " + msg)


## Numeric assertion with a tolerance, reporting got/want/tolerance together —
## a bare "expected 12, got 20" costs a trip back to the source to learn how
## close was close enough.
static func close(got: float, want: float, tol: float, what: String) -> void:
	check(absf(got - want) <= tol, "%s: got %.4f, want %.4f (+/- %.4f)" % [what, got, want, tol])


## Print the verdict and exit. `failure_noun` completes "%d <noun> failed",
## e.g. "balance invariant(s)" or "motion check(s)".
static func finish(tree: SceneTree, ok_message: String, failure_noun: String) -> void:
	if failures > 0:
		printerr("%d %s failed" % [failures, failure_noun])
		tree.quit(1)
	else:
		print(ok_message)
		tree.quit(0)
