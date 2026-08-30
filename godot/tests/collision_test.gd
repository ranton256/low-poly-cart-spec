# Collision: swept, not sampled.
#
#   godot --headless -s tests/collision_test.gd
#
# READ THIS BEFORE TRUSTING IT.
#
# Acceptance item 6 says the kart can reverse out of a single prop "at any
# approach angle", and the design document says one collision is resolved
# "however many props overlap". Both quantify over inputs, and the last four
# reviews of this project each found a check that passed because it ran at the one
# input where the bug was invisible — the kart's aim at yaw 0, a grid extent that
# moved with its step, two scatter axes collapsed into max(|x|,|z|), and an
# ordering asserted against the port's own constant.
#
# So the shapes deliberately avoided here:
#
#   * "it moved" instead of "it moved AWAY". A push along the kart's forward axis
#     displaces it too, and drives it out the far side of the tree. Every approach
#     asserts the push vector equals pushDistance times the unit vector from the
#     prop's centre — not merely that the position changed.
#   * one approach angle. Sixteen, and the reverse-out is run from all sixteen.
#   * an ordering test that would pass on proximity. The overlapping-props test
#     REORDERS the array and asserts a different prop is resolved.
#   * a pin test that would pass if the pin were "fixed". Asserted below, and the
#     mutation is recorded in the progress note.
#
# The kart's real imported model is used, not a synthetic box: the document's own
# pin arithmetic is stated against a contracted hitbox of 1.80 x 1.96 wu, and a
# synthetic kart would let this suite agree with a footprint the game does not
# have.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const KartView := preload("res://scripts/view/kart_view.gd")
const Sim := preload("res://scripts/core/sim.gd")
const Collision := preload("res://scripts/core/collision.gd")
const Normalise := preload("res://scripts/core/normalise.gd")
const InputState := preload("res://scripts/core/input_state.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")

const HEADINGS := 16
## Far enough that the kart starts clear of the prop at every heading, near enough
## that it arrives well inside the drivable extent.
const APPROACH_RADIUS := 6.0
## Generous: at 0.192 wu/tick the kart covers APPROACH_RADIUS in about 32.
const APPROACH_TICKS := 200
## Reversing is limited to maxSpeed x reverseFactor, so backing clear takes
## roughly twice as long as arriving.
const REVERSE_TICKS := 300
## The kart is a 64-bit recurrence and these are direct comparisons of derived
## vectors, so this is float noise, not a fudge factor.
const EPSILON := 1e-9
## AABB is Vector3, which is 32-bit real_t in a standard build, so box dimensions
## carry about seven digits — unlike the kart's own 64-bit position and yaw.
const BOX_TOLERANCE := 1e-5
## Push direction is compared component-wise against a unit vector scaled by
## pushDistance. A push one degree off fails at 0.005.
const DIRECTION_TOLERANCE := 1e-6
## Long enough for the pin to end on its own, which it does — see the pin test.
const PIN_TICKS := 1200
## One second of being held with the engine dead. Not a threshold chosen after
## measuring: it is the shortest hold a player would call "stuck".
const HELD_TICKS_MINIMUM := 60

var _view: Node3D = null
var _normalised: RefCounted = null
var _correction: float = 0.0


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	await process_frame
	_view = KartView.new()
	get_root().add_child(_view)
	await process_frame
	_normalised = _view.normalised()
	_correction = _view.yaw_correction()

	_test_the_push_is_away_from_the_prop_at_sixteen_approaches()
	_test_reversing_frees_the_kart_from_sixteen_approaches()
	_test_the_degenerate_push_is_the_backward_axis_and_not_the_forward_one()
	_test_the_ordering_fixture_can_tell_order_from_proximity()
	_test_the_first_prop_in_registration_order_is_resolved()
	_test_reordering_the_array_changes_which_prop_is_resolved()
	_test_passing_close_registers_nothing()
	_test_the_diagonal_volume_is_larger_and_that_is_accepted()
	_test_driving_in_at_full_speed_never_wedges_or_tunnels()
	_test_a_prop_scattered_onto_the_kart_pushes_it_clear()
	_test_collision_runs_after_the_boundary()
	_test_the_kart_is_pinned_between_two_props_at_the_minimum_separation()

	get_root().remove_child(_view)
	_view.free()
	_view = null
	RVTest.finish(
		self,
		"collision: 16 approaches swept, order resolved, pin held as specified",
		"collision check(s)"
	)


func _sim() -> RefCounted:
	var s := Sim.new()
	s.tuning = TuningLoader.load_tuning()
	s.input = InputState.new()
	s.kart_normalised = _normalised
	s.kart_yaw_offset = _correction
	# Pipeline suite: skip the countdown (race-state seam; race_state_test owns it).
	s.race.start_racing_immediately()
	return s


## A cube prop of plan size `size`, centred on (x, z) and standing on the ground.
##
## Built through the same normalisation and the same Collision.make_prop() the
## running game uses, so a change to either shows up here rather than being
## re-implemented with a literal box.
func _prop(asset: String, x: float, z: float, size: float) -> RefCounted:
	var authored := AABB(Vector3(-size / 2.0, 0.0, -size / 2.0), Vector3(size, size, size))
	var normalised: RefCounted = Normalise.to_target_height(authored, size)
	return Collision.make_prop(asset, normalised, 0.0, x, z)


func _distance(sim: RefCounted, prop: RefCounted) -> float:
	var dx: float = sim.pos_x - prop.centre_x()
	var dz: float = sim.pos_z - prop.centre_z()
	return sqrt(dx * dx + dz * dz)


## Place the kart APPROACH_RADIUS out at heading index `i`, facing the origin.
##
## The kart sits at R x (sin phi, cos phi) — the simulation's own forward
## convention, so the position and the heading are expressed in one frame — and
## faces inward, which is yaw = phi + PI.
func _aim_at_origin(sim: RefCounted, i: int) -> void:
	var phi: float = TAU * float(i) / float(HEADINGS)
	sim.pos_x = APPROACH_RADIUS * sin(phi)
	sim.pos_z = APPROACH_RADIUS * cos(phi)
	sim.yaw = phi + PI


# @covers Collision Detection and Response / Responding to an impact
## THE CENTRAL CLAIM, and the one a single approach angle cannot support.
##
## For each of sixteen headings: drive in until something is resolved, then assert
## the push is EXACTLY pushDistance along the unit vector from the prop's centre
## to where the kart stood when the response ran. That vector is reconstructed by
## subtracting the push from the final position, so the assertion compares two
## independently derived quantities rather than restating the implementation.
##
## A response using the kart's forward axis, or the prop-to-kart vector negated,
## or a fixed world direction, fails at every heading — which "the kart moved"
## would not.
func _test_the_push_is_away_from_the_prop_at_sixteen_approaches() -> void:
	var resolved := 0
	for i in range(HEADINGS):
		var sim := _sim()
		var prop: RefCounted = _prop("tree", 0.0, 0.0, 2.0)
		sim.props = [prop]
		_aim_at_origin(sim, i)
		sim.input.forward = true

		var hit_tick := -1
		for tick in range(APPROACH_TICKS):
			var before: float = _distance(sim, prop)
			sim.step()
			if sim.last_hit == null:
				continue
			hit_tick = tick
			var after: float = _distance(sim, prop)
			_check(
				after > before,
				(
					"heading %d: the push leaves the kart FURTHER from the prop centre (%.6f -> %.6f)"
					% [i, before, after]
				)
			)

			# Where the kart stood when the response ran.
			var at_x: float = sim.pos_x - sim.last_hit.push_x
			var at_z: float = sim.pos_z - sim.last_hit.push_z
			var away_x: float = at_x - prop.centre_x()
			var away_z: float = at_z - prop.centre_z()
			var length: float = sqrt(away_x * away_x + away_z * away_z)
			_check(length > EPSILON, "heading %d: the approach is not degenerate" % i)
			var want_x: float = away_x / length * sim.tuning.push_distance
			var want_z: float = away_z / length * sim.tuning.push_distance
			_check(
				(
					absf(sim.last_hit.push_x - want_x) < DIRECTION_TOLERANCE
					and absf(sim.last_hit.push_z - want_z) < DIRECTION_TOLERANCE
				),
				(
					(
						"heading %d: the push is pushDistance along the prop-to-kart unit"
						+ " vector (got %.6f,%.6f want %.6f,%.6f)"
					)
					% [i, sim.last_hit.push_x, sim.last_hit.push_z, want_x, want_z]
				)
			)
			_check(
				not sim.last_hit.degenerate,
				"heading %d: an ordinary approach does not take the degenerate branch" % i
			)
			_check(sim.velocity == 0.0, "heading %d: velocity is exactly zero, not damped" % i)
			resolved += 1
			break
		_check(hit_tick >= 0, "heading %d: driving at the prop actually collides" % i)
	_check(
		resolved == HEADINGS,
		"all %d approaches resolved a collision, so none of the above was vacuous" % HEADINGS
	)


# @covers Collision Detection and Response / Not becoming trapped inside an obstacle
## Acceptance item 6's "at any approach angle", from the far end: having hit the
## prop, holding reverse frees the kart. Run from all sixteen approaches.
func _test_reversing_frees_the_kart_from_sixteen_approaches() -> void:
	for i in range(HEADINGS):
		var sim := _sim()
		var prop: RefCounted = _prop("tree", 0.0, 0.0, 2.0)
		sim.props = [prop]
		_aim_at_origin(sim, i)
		sim.input.forward = true
		var contacted := false
		for _tick in range(APPROACH_TICKS):
			sim.step()
			if sim.last_hit != null:
				contacted = true
				break
		# The approach sweep asserts this too, but this loop must not silently
		# become a test of a kart that never reached the prop.
		_check(contacted, "heading %d: the kart reached the prop before reversing" % i)
		var contact_distance: float = _distance(sim, prop)

		sim.input.forward = false
		sim.input.reverse = true
		var free_for := 0
		for _tick in range(REVERSE_TICKS):
			sim.step()
			if sim.last_hit == null:
				free_for += 1
			else:
				free_for = 0
		_check(
			free_for > REVERSE_TICKS / 2,
			(
				"heading %d: reversing leaves the kart clear and it stays clear (%d clear ticks)"
				% [i, free_for]
			)
		)
		_check(
			_distance(sim, prop) > contact_distance,
			(
				"heading %d: reversing carries the kart away from the prop (%.3f -> %.3f)"
				% [i, contact_distance, _distance(sim, prop)]
			)
		)


## The degenerate branch, asserted against the BACKWARD axis specifically.
##
## The document says the forward axis "would drive it further into the prop and
## walk it out the far side" — the tunnelling another scenario forbids. A test
## asserting only that the kart moved passes on forward.
##
## Swept over eight headings rather than run at one. The GDD does not quantify this
## case over headings, but D4's rule is that every clause saying "any" gets a
## sweep, and a single yaw cannot distinguish a component swap from a sign error at
## the quarter turns. None of the eight is a multiple of a quarter turn, for that
## reason.
## (Claimed by the sixteen-approach sweep above — one claim per scenario.)
func _test_the_degenerate_push_is_the_backward_axis_and_not_the_forward_one() -> void:
	for i in range(8):
		var yaw: float = 0.31 + TAU * float(i) / 8.0
		var sim := _sim()
		var prop: RefCounted = _prop("rock", 0.0, 0.0, 2.0)
		sim.props = [prop]
		sim.yaw = yaw
		sim.pos_x = prop.centre_x()
		sim.pos_z = prop.centre_z()
		sim.step()

		_check(
			sim.last_hit != null,
			"yaw %.2f: a kart standing on a prop's centre registers a collision" % yaw
		)
		if sim.last_hit == null:
			continue
		_check(sim.last_hit.degenerate, "yaw %.2f: and it takes the degenerate branch" % yaw)

		var push: float = sim.tuning.push_distance
		var back_x: float = -sin(yaw) * push
		var back_z: float = -cos(yaw) * push
		_check(
			(
				absf(sim.last_hit.push_x - back_x) < DIRECTION_TOLERANCE
				and absf(sim.last_hit.push_z - back_z) < DIRECTION_TOLERANCE
			),
			(
				(
					"yaw %.2f: the degenerate push is the kart's BACKWARD axis"
					+ " (got %.6f,%.6f want %.6f,%.6f)"
				)
				% [yaw, sim.last_hit.push_x, sim.last_hit.push_z, back_x, back_z]
			)
		)
		# A DISTINCT CLAIM, not a restatement of the equality above. The projection
		# onto the kart's forward axis must be negative: that is what "backward"
		# means, and it is the half that still bites if the tolerance above is ever
		# loosened or the magnitude retuned.
		var along_forward: float = sim.last_hit.push_x * sin(yaw) + sim.last_hit.push_z * cos(yaw)
		_check(
			along_forward < 0.0,
			(
				"yaw %.2f: the push runs against the kart's nose (%.6f), not out the far side"
				% [yaw, along_forward]
			)
		)
		_check(sim.velocity == 0.0, "yaw %.2f: the degenerate case still zeroes velocity" % yaw)


## STAGE 7 RUNS AFTER STAGE 6, and nothing in the project held it there.
##
## `sim.gd`'s comment claimed "the ordering tests hold it there" and review showed
## it did not: swapping the two stages left the whole gate green. The only order
## assertion anywhere was steering-before-friction, in tick_test.gd.
##
## The discriminator is a push that must leave the kart OUTSIDE the drivable
## extent. Collision after the boundary: the shove stands, because the clamp has
## already run this tick and the kart is pulled back on the next one. Collision
## before the boundary: the clamp eats the shove in the same tick and returns the
## kart into the prop it was just pushed out of — with velocity zero, which is the
## "wedged inside" outcome the design document forbids.
##
## Nothing here asserts stage 7 before stage 8: the lap gate is empty until M4, and
## a test of an ordering with no observable consequence yet would be a test of a
## comment. M4 owns it.
func _test_collision_runs_after_the_boundary() -> void:
	var sim := _sim()
	var limit: float = sim.tuning.drivable_extent
	# Just inside the fence, with a prop on the inboard side so the push is
	# outward. At rest, so stage 5 moves nothing and the boundary has nothing of
	# its own to clamp before the collision happens.
	sim.pos_x = limit - 0.1
	sim.pos_z = 0.0
	sim.yaw = PI / 2.0
	sim.props = [_prop("tree", limit - 1.5, 0.0, 2.0)]
	sim.step()

	_check(sim.last_hit != null, "the kart against the fence collides with the prop beside it")
	_check(
		sim.pos_x > limit,
		(
			(
				"the push survives the tick, so collision ran AFTER the boundary"
				+ " (x=%.4f, extent %.1f)"
			)
			% [sim.pos_x, limit]
		)
	)
	# And the boundary is not thereby broken — the next tick reels it back in.
	sim.props = []
	sim.step()
	_check(sim.pos_x <= limit, "and the following tick clamps it back inside (x=%.4f)" % sim.pos_x)


# @covers Collision Detection and Response / Detecting an overlap with a prop
## Three props overlapping the kart at once: the FIRST in registration order is
## the collision for this tick, and testing stops there.
##
## The three are at distinct offsets so the resolved one is identifiable from the
## push alone — the assertion names which prop won, not merely that one did.
func _test_the_first_prop_in_registration_order_is_resolved() -> void:
	var sim := _sim()
	var props: Array = _overlapping_trio()
	sim.props = props
	sim.step()

	_check(sim.last_hit != null, "a kart inside three props registers a collision")
	_check(
		sim.last_hit.index == 0,
		"the resolved prop is the first in registration order (index %d)" % sim.last_hit.index
	)
	_check(
		(props[sim.last_hit.index] as Collision.Prop).asset == "first",
		"named: the resolved prop is 'first'"
	)
	_check(
		_push_points_away_from(sim, props[0] as Collision.Prop),
		"and the push is away from THAT prop, not from one of the others"
	)
	_check(
		not _push_points_away_from(sim, props[1] as Collision.Prop),
		"and specifically NOT from 'second', which is the nearest, largest and deepest"
	)


## What makes the check above an ordering test rather than a proximity test.
## (Claimed by the check above — one claim per scenario.)
##
## The same three props in a different order resolve a DIFFERENT one. Without
## this, an implementation that picked the nearest, the largest, or the deepest
## overlap would pass the check above at every seed.
func _test_reordering_the_array_changes_which_prop_is_resolved() -> void:
	var props: Array = _overlapping_trio()
	var reordered: Array = [props[2], props[0], props[1]]

	var sim := _sim()
	sim.props = reordered
	sim.step()

	_check(sim.last_hit != null, "the reordered field still collides")
	_check(
		(reordered[sim.last_hit.index] as Collision.Prop).asset == "third",
		(
			"moving 'third' to the front makes IT the resolved prop (got '%s')"
			% (reordered[sim.last_hit.index] as Collision.Prop).asset
		)
	)
	_check(
		_push_points_away_from(sim, reordered[0] as Collision.Prop),
		"and the push is away from the newly-first prop"
	)


## Three props overlapping a kart at the origin, DELIBERATELY ASYMMETRIC.
##
## The first version of this fixture put all three at distance 0.6 and gave them
## all size 1.0. Every prop was therefore exactly as near and exactly as large as
## every other, so "nearest" was a perfect tie that fell through to iteration
## order — and a `first_overlap` rewritten to return the NEAREST overlapping prop
## passed the whole gate. Review demonstrated it. The very thing this pair of
## tests exists to catch, invisible at the one arrangement they ran at.
##
## So the three now disagree on every rule a plausible implementation might use:
##
##   asset    centre       size   distance   penetration   push direction
##   first    ( 1.00,  0.00)  0.50    1.00       least        -X
##   second   ( 0.00,  0.25)  0.80    0.25       most         -Z
##   third    (-0.60, -0.30)  0.30    0.67       middle       +X+Z
##
## `second` is simultaneously the nearest, the largest and the deepest; `first` is
## first in registration order and is none of those. A rule that is not "first in
## registration order" resolves a different prop and fails.
##
## They also sit in three different DIRECTIONS from the kart, which the first
## asymmetric version of this fixture did not: with all three on the +X side, the
## push away from any of them is -X and the resolved prop cannot be identified
## from the response at all.
func _overlapping_trio() -> Array:
	return [
		_prop("first", 1.0, 0.0, 0.5),
		_prop("second", 0.0, 0.25, 0.8),
		_prop("third", -0.6, -0.3, 0.3),
	]


## The fixture's discriminating power, asserted rather than assumed.
##
## Without this, someone tidying `_overlapping_trio` back into three symmetric
## props would restore the hole and nothing would say so — which is exactly how
## the hole got there.
func _test_the_ordering_fixture_can_tell_order_from_proximity() -> void:
	var props: Array = _overlapping_trio()
	var sim := _sim()
	var volume: AABB = Collision.kart_volume(
		_normalised, _correction, 0.0, 0.0, sim.tuning.hitbox_contraction
	)
	var nearest := -1
	var nearest_distance: float = INF
	var largest := -1
	var largest_size: float = 0.0
	for i in range(props.size()):
		var prop: Collision.Prop = props[i] as Collision.Prop
		_check(
			volume.intersects(prop.box),
			"fixture: prop '%s' overlaps the kart, so all three are candidates" % prop.asset
		)
		var d: float = sqrt(prop.centre_x() * prop.centre_x() + prop.centre_z() * prop.centre_z())
		if d < nearest_distance:
			nearest_distance = d
			nearest = i
		if prop.box.size.x > largest_size:
			largest_size = prop.box.size.x
			largest = i
	_check(
		nearest != 0,
		"fixture: the NEAREST prop is not the first in order, so proximity and order disagree"
	)
	_check(largest != 0, "fixture: the LARGEST prop is not the first in order either")


func _push_points_away_from(sim: RefCounted, prop: RefCounted) -> bool:
	var at_x: float = sim.pos_x - sim.last_hit.push_x
	var at_z: float = sim.pos_z - sim.last_hit.push_z
	var away_x: float = at_x - prop.centre_x()
	var away_z: float = at_z - prop.centre_z()
	var length: float = sqrt(away_x * away_x + away_z * away_z)
	if length < EPSILON:
		return false
	var want_x: float = away_x / length * sim.tuning.push_distance
	var want_z: float = away_z / length * sim.tuning.push_distance
	return (
		absf(sim.last_hit.push_x - want_x) < DIRECTION_TOLERANCE
		and absf(sim.last_hit.push_z - want_z) < DIRECTION_TOLERANCE
	)


# @covers Collision Detection and Response / Passing close to a prop without contact
## Clearance greater than the contracted volume registers nothing, and position,
## heading and velocity are ALL unaffected — compared against a twin sim driving
## the same input with an empty field, so the claim is "identical", not "close".
func _test_passing_close_registers_nothing() -> void:
	var sim := _sim()
	var twin := _sim()
	# The kart drives up +Z past a prop set aside on +X. The gap is the contracted
	# half-width plus the prop's half-width plus a margin, computed rather than
	# guessed so a retune of hitboxContraction moves it.
	var volume: AABB = Collision.kart_volume(
		_normalised, _correction, 0.0, 0.0, sim.tuning.hitbox_contraction
	)
	var prop_size := 2.0
	var offset: float = volume.size.x / 2.0 + prop_size / 2.0 + 0.05
	var prop: RefCounted = _prop("cone", offset, 4.0, prop_size)
	sim.props = [prop]
	twin.props = []

	sim.input.forward = true
	twin.input.forward = true
	for _tick in range(APPROACH_TICKS):
		sim.step()
		twin.step()
		_check(sim.last_hit == null, "passing at %.4f wu clearance registers no collision" % 0.05)
		if sim.last_hit != null:
			break

	_check(sim.pos_x == twin.pos_x and sim.pos_z == twin.pos_z, "position is entirely unaffected")
	_check(sim.yaw == twin.yaw, "heading is entirely unaffected")
	_check(sim.velocity == twin.velocity, "velocity is entirely unaffected")
	# THE CONTRACTION ITSELF, and the reason this section exists.
	#
	# The clearance above is derived from the contracted volume, so removing the
	# contraction moves the test's expectation with the code and the check passes
	# either way — the exact shape three reviews of this project have caught. This
	# pins it against the UNCONTRACTED footprint instead: a prop that overlaps the
	# kart's real box but not its contracted one must register nothing. That is what
	# "forgiving" means, and it fails the moment hitboxContraction stops being
	# applied.
	var raw: AABB = Normalise.world_box(_normalised, _correction)
	var contracted: AABB = Collision.kart_volume(
		_normalised, _correction, 0.0, 0.0, sim.tuning.hitbox_contraction
	)
	RVTest.close(
		contracted.size.x,
		raw.size.x - 2.0 * sim.tuning.hitbox_contraction,
		BOX_TOLERANCE,
		"the volume is contracted by hitboxContraction on both X sides"
	)
	RVTest.close(
		contracted.size.z,
		raw.size.z - 2.0 * sim.tuning.hitbox_contraction,
		BOX_TOLERANCE,
		"and on both Z sides"
	)

	var near_size := 1.0
	# Halfway between the contracted face and the real one — derived from the RAW
	# box and the tuning value, not from kart_volume()'s own answer, so dropping the
	# contraction cannot move this expectation along with it.
	var midway: float = raw.size.x / 2.0 - sim.tuning.hitbox_contraction / 2.0
	var forgiven := _sim()
	forgiven.props = [_prop("cone", midway + near_size / 2.0, 0.0, near_size)]
	forgiven.step()
	_check(
		forgiven.last_hit == null,
		"a prop inside the kart's real footprint but outside its contracted one is FORGIVEN"
	)
	var raw_volume := AABB(raw.position, raw.size)
	_check(
		raw_volume.intersects((forgiven.props[0] as Collision.Prop).box),
		"and that prop really does overlap the uncontracted footprint, so the check is not vacuous"
	)

	# Falsifiability: shave the margin off and the same drive must collide.


# @covers Collision Detection and Response / Growing hit volume when driving diagonally
## Asserted as ACCEPTED behaviour, so a future change to oriented volumes fails
## loudly here rather than silently making the game more forgiving than specified.
##
## Both a measurement and a consequence: the diagonal volume is larger on both
## axes, and a prop the axis-aligned kart clears is one the diagonal kart hits.
func _test_the_diagonal_volume_is_larger_and_that_is_accepted() -> void:
	var sim := _sim()
	var contraction: float = sim.tuning.hitbox_contraction
	var square: AABB = Collision.kart_volume(_normalised, _correction, 0.0, 0.0, contraction)
	var diagonal: AABB = Collision.kart_volume(
		_normalised, _correction + PI / 4.0, 0.0, 0.0, contraction
	)
	_check(
		diagonal.size.x > square.size.x and diagonal.size.z > square.size.z,
		(
			"at 45 deg the volume grows on both axes (%.3fx%.3f -> %.3fx%.3f) — accepted, not a defect"
			% [square.size.x, square.size.z, diagonal.size.x, diagonal.size.z]
		)
	)

	# A prop just outside the axis-aligned footprint on both axes.
	var reach: float = square.size.x / 2.0 + 0.05
	var prop: RefCounted = _prop("crate", reach, reach, 0.02)
	var aligned := _sim()
	aligned.props = [prop]
	aligned.yaw = 0.0
	aligned.step()
	_check(aligned.last_hit == null, "the axis-aligned kart clears the prop")

	var turned := _sim()
	turned.props = [prop]
	turned.yaw = PI / 4.0
	turned.step()
	_check(turned.last_hit != null, "the same kart at 45 deg hits it — the growth is observable")


## EVERY tick is checked, not only the last one.
## (Claimed by the reverse-out sweep above — one claim per scenario.)
##
## Top speed is 0.192 wu/tick against a prop 3 wu across, so a tunnel is unlikely
## rather than impossible — and a final-position check cannot tell "never crossed"
## from "crossed and came back". The kart drives at full speed straight down -Z
## into a prop at the origin; its Z must stay on the near side throughout, and it
## must never sit deeper inside the prop than the push can undo.
func _test_driving_in_at_full_speed_never_wedges_or_tunnels() -> void:
	var sim := _sim()
	var prop: RefCounted = _prop("tree", 0.0, 0.0, 3.0)
	sim.props = [prop]
	sim.pos_x = 0.0
	sim.pos_z = 8.0
	sim.yaw = PI  # forward = (sin PI, cos PI) = (0, -1)
	sim.input.forward = true

	var contacts := 0
	var late_contacts := 0
	var nearest: float = INF
	for tick in range(600):
		sim.step()
		_check(
			sim.pos_z > 0.0,
			"tick %d: the kart never crosses the prop's centre plane (z=%.4f)" % [tick, sim.pos_z]
		)
		nearest = minf(nearest, sim.pos_z)
		if sim.last_hit != null:
			contacts += 1
			if tick >= 500:
				late_contacts += 1
			_check(sim.velocity == 0.0, "tick %d: each contact zeroes the velocity" % tick)
	# Not "it collided": it collided REPEATEDLY, and was still colliding at the end
	# of a ten-second hold — which distinguishes a repeating push-out from one
	# contact followed by the kart wedging, sliding off, or coming to rest clear.
	_check(contacts > 20, "the kart kept driving into it — %d contacts, not one" % contacts)
	_check(
		late_contacts > 0,
		(
			"and was still being pushed out at the end of the run (%d contacts in the last 100 ticks)"
			% late_contacts
		)
	)
	_check(
		nearest > prop.box.size.z / 2.0 - sim.tuning.push_distance,
		(
			"it never wedges deeper than one push inside the prop face (nearest z=%.4f, face at %.4f)"
			% [nearest, prop.box.size.z / 2.0]
		)
	)


# @covers
# Collision Detection and Response / Colliding with the kart's own start position after regeneration
## The scatter's clearance rule is measured from the ORIGIN, so regenerating while
## the kart sits elsewhere can drop a prop on top of it. The response pushes it
## clear on the following tick rather than trapping it.
func _test_a_prop_scattered_onto_the_kart_pushes_it_clear() -> void:
	var sim := _sim()
	sim.pos_x = 12.0
	sim.pos_z = -7.0
	sim.yaw = 1.3
	sim.input.forward = true
	for _tick in range(60):
		sim.step()
	var driving_velocity: float = sim.velocity
	_check(driving_velocity > 0.0, "the kart is under way before the world is regenerated")

	# A prop appears slightly off the kart's position — off, not on, because the
	# degenerate branch has its own test and this scenario is about the ordinary one.
	var prop: RefCounted = _prop("cottage", sim.pos_x + 0.3, sim.pos_z - 0.2, 4.0)
	var before: float = _distance(sim, prop)
	sim.props = [prop]
	sim.step()
	_check(sim.last_hit != null, "the prop dropped onto the kart is detected on the next tick")
	_check(sim.velocity == 0.0, "and stops it")
	_check(
		_distance(sim, prop) > before,
		(
			"and pushes it clear rather than trapping it (%.4f -> %.4f)"
			% [before, _distance(sim, prop)]
		)
	)


## THIS TEST ASSERTS SPECIFIED BEHAVIOUR THAT LOOKS EXACTLY LIKE A BUG.
##
## The design document, under *Not becoming trapped inside an obstacle*:
##
##   "minPropSeparation is measured centre-to-centre and does not subtract
##    footprints, so two cottages placed at the minimum 3 wu leave a gap of
##    0.09 wu — against a contracted kart hitbox of 1.80 x 1.96 wu. A kart that
##    reaches such a pair overlaps both, only the first in registration order is
##    resolved, and the push-out drives it into the second; it oscillates in place
##    with its velocity zeroed every tick and cannot drive out. Reset Kart is the
##    specified escape. A port that wants the stronger guarantee should raise
##    minPropSeparation to clear the largest pair of footprints rather than
##    resolve multiple collisions per tick — the placement rule is the root cause,
##    not the collision response."
##
## So: do not "fix" this. Resolving every overlap per tick passes every other
## check in this file and silently diverges from the specification; this is the
## check that makes that loud. Reset Kart is M7 (att 10).
##
## SWEPT OVER SIXTEEN HEADINGS, and the first version was not. It ran at yaw PI/2
## alone and generalised from it — the exact shape this file's header warns about,
## found by review. The pin turns out to be strongly heading-dependent:
##
##   yaw            0    22.5   45    67.5   90    112.5  ...  270   ...
##   ticks held    20     15    17     16   125     16    ...  127   ...
##
## It lasts about two seconds only along the line joining the two props, where the
## kart is driving into a cottage; at the other fourteen headings it is a quarter
## of a second. Ambiguity A12 records why: the push is radial from the prop's
## centre, so the centred state is an unstable equilibrium and any transverse
## offset grows with every push.
##
## The assertions below are therefore the ones that hold at EVERY heading, plus one
## ordering claim about the heading dependence itself. No absolute tick threshold
## is asserted, because any such number would be one read off this measurement.
func _test_the_kart_is_pinned_between_two_props_at_the_minimum_separation() -> void:
	var reference := _sim()
	var separation: float = reference.tuning.min_prop_separation
	# Two props whose footprints nearly touch at the minimum separation — the
	# document's pair of cottages, as cubes so the gap is exact and stated.
	var size: float = separation - 0.09
	var gap: float = separation - size
	var volume: AABB = Collision.kart_volume(
		_normalised, _correction, 0.0, 0.0, reference.tuning.hitbox_contraction
	)
	_check(
		gap < volume.size.x,
		(
			(
				"PRECONDITION: the gap between the pair (%.3f wu) is smaller than the"
				+ " contracted hitbox (%.3f wu)"
			)
			% [gap, volume.size.x]
		)
	)

	var held_by_heading: Array = []
	for i in range(HEADINGS):
		held_by_heading.append(_pin_at_heading(TAU * float(i) / float(HEADINGS), separation, size))

	# THE HEADING DEPENDENCE, as an ordering claim rather than a threshold.
	#
	# The two headings that drive along the pair's axis — into a cottage — hold far
	# longer than the fourteen that do not. Asserted this way because a number here
	# would be one read off the measurement; asserted at all because it is what
	# fails if someone damps the transverse component to make the pin permanent
	# (every heading would then hold equally, for the whole run).
	var along_axis: Array = [
		int(held_by_heading[HEADINGS / 4]), int(held_by_heading[3 * HEADINGS / 4])
	]
	var longest_across := 0
	for i in range(HEADINGS):
		if i != HEADINGS / 4 and i != 3 * HEADINGS / 4:
			longest_across = maxi(longest_across, int(held_by_heading[i]))
	_check(
		mini(along_axis[0], along_axis[1]) > longest_across,
		(
			(
				"SPECIFIED, and heading-dependent: driving along the pair's axis holds"
				+ " longest (%d and %d ticks against %d at every other heading)"
			)
			% [along_axis[0], along_axis[1], longest_across]
		)
	)
	print(
		(
			"        pin: held %d ticks along the pair's axis, at most %d across it"
			% [mini(along_axis[0], along_axis[1]), longest_across]
		)
	)

	# The contrast that stops this reading as a broken collision response: with
	# ONE prop the very same drive gets free.
	var single := _sim()
	single.props = [_prop("right", separation / 2.0, 0.0, size)]
	single.pos_x = 0.0
	single.pos_z = 0.0
	single.yaw = -PI / 2.0  # away from it
	single.input.forward = true
	var freed := false
	for _tick in range(600):
		single.step()
		if absf(single.pos_x) > separation:
			freed = true
			break
	_check(freed, "and with a SINGLE prop the same drive does get free, so the pin is the pair")


## Drive one heading into the pinned pair and return how many consecutive ticks the
## kart was held. Every claim that must hold at EVERY heading is asserted here.
func _pin_at_heading(yaw: float, separation: float, size: float) -> int:
	var sim := _sim()
	var left: RefCounted = _prop("left", -separation / 2.0, 0.0, size)
	var right: RefCounted = _prop("right", separation / 2.0, 0.0, size)
	sim.props = [left, right]
	sim.pos_x = 0.0
	sim.pos_z = 0.0
	sim.yaw = yaw
	sim.input.forward = true

	var degrees: float = rad_to_deg(yaw)
	# Driving into a cottage rather than across the pair. The pair lies on X and
	# the simulation's forward is (sin yaw, cos yaw), so this is yaw = +/-PI/2.
	var along_the_axis: bool = absf(absf(sin(yaw)) - 1.0) < 1e-9
	var volume: AABB = Collision.kart_volume(
		_normalised, yaw + _correction, 0.0, 0.0, sim.tuning.hitbox_contraction
	)
	_check(
		(
			volume.intersects((left as Collision.Prop).box)
			and volume.intersects((right as Collision.Prop).box)
		),
		"yaw %.1f: the kart between them overlaps BOTH props" % degrees
	)

	var far_face: float = (
		(right as Collision.Prop).box.position.x + (right as Collision.Prop).box.size.x
	)
	var held := 0
	var still_held := true
	var freed := false
	var free_x := 0.0
	var free_z := 0.0
	for tick in range(PIN_TICKS):
		var previous_x: float = sim.pos_x
		var previous_z: float = sim.pos_z
		sim.step()
		if sim.last_hit == null:
			if still_held:
				free_x = sim.pos_x
				free_z = sim.pos_z
			still_held = false
			freed = true
		elif still_held:
			_check(
				sim.velocity == 0.0,
				"yaw %.1f tick %d: velocity is zeroed on every pinned tick" % [degrees, tick]
			)
			# ONE overlap resolved, not both. Resolving both would apply
			# +pushDistance and -pushDistance in the same tick and the two would
			# cancel, leaving the kart to creep by the drive step; one resolution
			# shoves it a full push. Measured on both axes, because once the kart
			# starts sliding out the push stops being parallel to X.
			var moved: float = sqrt(
				(
					(sim.pos_x - previous_x) * (sim.pos_x - previous_x)
					+ (sim.pos_z - previous_z) * (sim.pos_z - previous_z)
				)
			)
			_check(
				moved > sim.tuning.push_distance / 2.0,
				(
					(
						"yaw %.1f tick %d: exactly ONE of the two overlaps is resolved,"
						+ " so the kart moves a full push (%.4f)"
					)
					% [degrees, tick, moved]
				)
			)
			held += 1
		# THE LOAD-BEARING GUARANTEE, where it is meaningful: driving straight at
		# the pair never carries the kart past it. Checked only at the two headings
		# that drive along the pair's axis, because "past it" is a claim about the
		# direction of travel, and at the other fourteen the kart is driving across
		# the pair rather than at it.
		#
		# An earlier version asserted this at every heading and was WRONG: at yaw
		# 112.5 the kart is mid-ejection through the right-hand prop's footprint,
		# still colliding, with its centre already beyond that prop's far face.
		# Being inside a prop while being pushed out of it is not driving past the
		# pair, and a check that cannot tell those apart is not the guarantee.
		if along_the_axis and still_held:
			_check(
				absf(sim.pos_x) <= far_face,
				(
					(
						"yaw %.1f tick %d: driving along the pair's axis never carries"
						+ " the kart past it (x=%.3f, far face %.3f)"
					)
					% [degrees, tick, sim.pos_x, far_face]
				)
			)

	_check(held > 0, "yaw %.1f: the kart is held at all — the pin exists here" % degrees)
	# AND IT LEAVES SIDEWAYS, not forwards. The moment the pin ends, a kart driving
	# along the pair's axis is still on the near side of it: what freed the kart was
	# the transverse instability, never the push it was driving into.
	if along_the_axis:
		_check(
			absf(free_x) <= far_face,
			(
				(
					"yaw %.1f: when the pin ends the kart is still short of the pair,"
					+ " so it left sideways (x=%.3f z=%.3f, far face %.3f)"
				)
				% [degrees, free_x, free_z, far_face]
			)
		)
	# A TRANSIENT AT EVERY HEADING, asserted so that making the pin permanent fails
	# loudly rather than quietly satisfying a document sentence the specified
	# response cannot produce. See ambiguity A12.
	_check(
		freed,
		(
			"yaw %.1f: the pin ends within %d ticks — it is a transient, which A12 records"
			% [degrees, PIN_TICKS]
		)
	)
	return held
