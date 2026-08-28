# TEMPLATE — verify motion and animation timing WITHOUT a renderer.
#
# Prerequisite, and it is the same one that makes screenshots reproducible:
# view animation must be driven by the SIMULATION clock, not wall time. Then a
# scroll offset or frame index is a pure function of sim time and can be read
# exactly — no capture, no pixels, no display.
#
#   BAD:   position.y += speed * delta            # wall clock: untestable, and
#                                                 # screenshots never reproduce
#   GOOD:  position.y = f(sim.time_ms)            # exact, reproducible
#
# What this catches: a scroll coefficient fat-fingered from 0.012 to 0.12, a
# layer re-parented out of depth order, an animation retimed, a speed constant
# edited. All invisible to gameplay tests and all obvious on screen.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")

# Put the SPEC values here, named, so the test reads as the specification it is.
const SPEC_MID_PX_S := 12.0
const SPEC_FORE_PX_S := 140.0


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _close(got: float, want: float, tol: float, what: String) -> void:
	RVTest.close(got, want, tol, what)


## Build the real view, with THIS script owning the stepping so nothing races.
func _make_view() -> Node2D:
	var view: Node2D = load("res://scenes/game.tscn").instantiate()
	view.external_drive = true   # the view renders; the harness steps
	# view.sim.setup(...)
	root.add_child(view)
	return view


func _advance(view: Node2D, ticks: int) -> void:
	for i in range(ticks):
		view.sim.step()
		view.sim.events.clear()
	view._sync()


func _init() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)

	# SHAPE 1 — rates, measured as displacement over a known interval. Pick an
	# interval short enough that a wrapping layer does not wrap.
	#   var before := view._bg_mid.region_rect.position.y
	#   _advance(view, 60)
	#   var rate := absf(view._bg_mid.region_rect.position.y - before) / elapsed_s
	#   _close(rate, SPEC_MID_PX_S, 0.1, "mid layer scroll rate (px/s)")

	# SHAPE 2 — relationships between layers, which is what parallax IS. A layer
	# that is meant to read as distant must move slower than everything nearer.

	# SHAPE 3 — bounded motion. Anything meant to DRIFT rather than scroll should
	# be asserted to stay inside its bounds AND to actually move (a frozen layer
	# passes a bounds check trivially).

	# SHAPE 4 — animation timing: N frames across the stated lifetime, and the
	# thing expires when it should.

	# SHAPE 5 — depth order, read from child indices. Cheap, and it catches a
	# whole class of "why is the ship behind the background" regressions.

	RVTest.finish(self, "motion: <what was checked> ok", "motion check(s)")


## Worked example: tests/motion_test.gd in the project this kit came from.
