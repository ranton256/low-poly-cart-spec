# The HUD — the design document's §7 art specification and the last
# Heads-Up Display scenario, plus godot/hud's port decisions: px literal at
# the 1280×720 design resolution (A1), the needle eased on the simulation
# clock, the HUD drawing core values and computing none.
#
#   godot --headless -s tests/hud_test.gd
#
# EXPECTED VALUES COME FROM THE DESIGN DOCUMENT's §7 table and the tuning
# tables: dial 160×90 with an 8 px #444444 rim, needle 4×70 red→yellow easing
# ~0.1 s, TIME green at 24 px over a 12 px label, BEST yellow, readout 115 at
# steady state, KM/H in grey.
extends SceneTree

const RVTest := preload("res://tests/harness.gd")
const ArtTuning := preload("res://scripts/art_tuning.gd")
const SpeedoView := preload("res://scripts/view/speedo_view.gd")

var _root: Node3D = null
var _art: RefCounted = null


func _check(cond: bool, msg: String) -> void:
	RVTest.check(cond, msg)


func _init() -> void:
	_art = ArtTuning.load_art()
	_test_needle_easing_is_deterministic_and_settles()
	await process_frame
	_root = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	get_root().add_child(_root)
	await process_frame
	_root.sim.race.start_racing_immediately()
	await _test_timer_block_is_top_right_to_spec()
	await _test_speedometer_reads_the_core_at_steady_state()
	_test_title_and_hints_present()
	_test_no_hud_element_intercepts_pointer_input()
	get_root().remove_child(_root)
	_root.free()
	RVTest.finish(
		self, "hud: timer block, dial, needle, title, pointer-transparent ok", "hud check(s)"
	)


## Pure unit test — no scene. Two needles fed the same tick sequence agree
## exactly; the easing settles in about 0.1 s of ticks and never overshoots.
func _test_needle_easing_is_deterministic_and_settles() -> void:
	var a: Control = SpeedoView.new()
	var b: Control = SpeedoView.new()
	for view: Control in [a, b]:
		view.configure(_art)
	for _i in range(10):
		a.advance_to(0.96, 1)
		b.advance_to(0.96, 1)
	_check(a.needle_angle_deg() == b.needle_angle_deg(), "same ticks, same needle — deterministic")
	_check(
		a.needle_angle_deg() < 0.96 * 180.0 - 90.0,
		"ten ticks in, the needle is still easing (%.1f°)" % a.needle_angle_deg()
	)
	a.advance_to(0.96, 30)  # ~0.5 s of ticks in total
	RVTest.close(
		a.needle_angle_deg(),
		0.96 * 180.0 - 90.0,
		1.0,
		"the needle settles to (ratio × 180°) − 90° within half a second"
	)
	a.advance_to(0.0, 300)
	RVTest.close(a.needle_angle_deg(), -90.0, 0.5, "at rest it points left: −90°")
	a.free()
	b.free()


# @covers Heads-Up Display / Driving the speedometer needle
func _test_speedometer_reads_the_core_at_steady_state() -> void:
	var speedo: Control = _root.overlay.get_node("Speedo") as Control
	_check(speedo != null, "the overlay has the speedometer")
	var width: float = _art.num("speedoDialWidthPx")
	var height: float = _art.num("speedoDialHeightPx")
	_check(
		speedo.size == Vector2(width, height),
		"the dial is the data layer's 160×90 at design resolution (%s)" % speedo.size
	)
	# Drive to steady state through the real input path — the dial must SHOW
	# the core's 115, not compute its own. Steady state arrives by ~2.6 s; 220
	# ticks leaves easing margin.
	for _i in range(220):
		Input.action_press("accelerate")
		await physics_frame
	await process_frame
	var readout: Label = speedo.get_node("Readout") as Label
	_check(readout.text == "115", "the readout settles at the core's 115 (%s)" % readout.text)
	var unit: Label = speedo.get_node("Unit") as Label
	_check(unit.text == "KM/H", "labelled KM/H")
	_check(
		unit.label_settings.font_color.is_equal_approx(_art.colour("speedoUnitColour")),
		"the unit label wears the data layer's grey"
	)
	RVTest.close(
		speedo.needle_angle_deg(),
		minf(_root.sim.speed_ratio(), 1.0) * 180.0 - 90.0,
		3.0,
		"the needle is at the formula's angle, within easing"
	)
	Input.action_release("accelerate")


func _test_timer_block_is_top_right_to_spec() -> void:
	var overlay: CanvasLayer = _root.overlay
	for _i in range(3):
		await process_frame
	var time_value: Label = overlay.get_node("TimeValue") as Label
	var best_value: Label = overlay.get_node("BestValue") as Label
	var time_label: Label = overlay.get_node("TimeLabel") as Label
	_check(time_value.visible, "the timer block shows while racing")
	_check(
		time_value.text.match("*.??") and not time_value.text.begins_with("TIME"),
		"the value is bare two-decimal time under its label (%s)" % time_value.text
	)
	_check(time_label.text == "TIME", "the 12 px label reads TIME")
	_check(
		time_value.label_settings.font_color.is_equal_approx(_art.colour("timeValueColour")),
		"TIME's value is the specified green"
	)
	_check(
		best_value.label_settings.font_color.is_equal_approx(_art.colour("bestTextColour")),
		"BEST's value is the specified yellow"
	)
	_check(best_value.text == "--.--", "and holds the placeholder before a first lap")
	_check(
		(
			int(time_value.label_settings.font_size) == int(_art.num("timerValuePx"))
			and int(time_label.label_settings.font_size) == int(_art.num("timerLabelPx"))
		),
		"value and label sizes come from the data layer"
	)
	_check(
		time_value.anchor_left == 1.0 and time_value.anchor_right == 1.0,
		"the block anchors to the top-RIGHT corner — its specified home"
	)


func _test_title_and_hints_present() -> void:
	var title: Label = _root.overlay.get_node("Title") as Label
	var hints: Label = _root.overlay.get_node("Hints") as Label
	_check(title != null and title.visible, "the title is on screen")
	_check(
		title.label_settings.font_color.is_equal_approx(_art.colour("titleColour")),
		"in the specified bright green"
	)
	_check(hints != null and hints.visible and hints.modulate.a < 1.0, "hints beneath, dimmed")
	_check(title.anchor_left == 0.0 and title.anchor_top == 0.0, "anchored to the top-left corner")


func _test_no_hud_element_intercepts_pointer_input() -> void:
	var blockers: Array = []
	for child in _root.overlay.get_children():
		if child is Control and (child as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			blockers.append(child.name)
	_check(blockers.is_empty(), "no HUD element intercepts pointer input (§7): %s" % str(blockers))
