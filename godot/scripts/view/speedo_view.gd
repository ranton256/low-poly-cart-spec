# The speedometer — §7's 160×90 half-dial, drawn in screen space.
#
# The port decisions (godot/hud): the needle eases ON THE SIMULATION CLOCK —
# advance_to() takes a tick count, never a frame delta, so the needle's angle
# at any tick is reproducible and a frame without a tick redraws the same
# needle. The readout is the core's own speedo_readout(); this file computes
# no game number, only where to point a polygon.
#
# Every colour and px value comes from the data layer — 90 alone would
# collide with drivableExtent and fovMax as a literal.
extends Control

const Sim := preload("res://scripts/core/sim.gd")

var _rim_colour := Color.WHITE
var _needle_base := Color.WHITE
var _needle_tip := Color.WHITE
var _rim_px := 0.0
var _needle_len := 0.0
var _needle_w := 0.0

## Eased 0..1 dial position, advanced per simulation tick.
var _ratio := 0.0
## Per-tick easing factor derived from needleEaseSeconds (~0.1 s constant).
var _alpha := 0.0


## One-time styling from the art table; builds the KM/H and readout labels.
func configure(art: RefCounted) -> void:
	custom_minimum_size = Vector2(art.num("speedoDialWidthPx"), art.num("speedoDialHeightPx"))
	size = custom_minimum_size
	_rim_colour = art.colour("speedoRimColour")
	_needle_base = art.colour("needleBaseColour")
	_needle_tip = art.colour("needleTipColour")
	_rim_px = art.num("speedoRimPx")
	_needle_len = art.num("needleLengthPx")
	_needle_w = art.num("needleWidthPx")
	_alpha = 1.0 - exp(-1.0 / (float(Sim.TICKS_PER_SECOND) * art.num("needleEaseSeconds")))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var unit_px: int = int(art.num("speedoUnitPx"))
	var readout_px: int = int(art.num("speedoReadoutPx"))
	# Stacked at the pivot end INSIDE the 160×90 rect (the M5 Critic's finding
	# 1: a first draft parked these below the control, off a screen the dial
	# is inset 16 px from). Offsets are set after add_child, against the real
	# parent — the anchors-vs-position trap, third appearance.
	_make_label(
		"Readout", "0", art.colour("speedoReadoutColour"), readout_px, unit_px + readout_px + 6
	)
	_make_label("Unit", "KM/H", art.colour("speedoUnitColour"), unit_px, unit_px)


## Ease toward a target ratio across `ticks` simulation ticks. The caller
## passes the tick delta since it last drew; zero ticks means zero motion.
func advance_to(target: float, ticks: int) -> void:
	for _i in range(ticks):
		_ratio += (clampf(target, 0.0, 1.0) - _ratio) * _alpha


func needle_angle_deg() -> float:
	return _ratio * 180.0 - 90.0


## Called by the overlay once per rendered frame with the current snapshot.
func draw_from(sim: RefCounted, ticks_elapsed: int) -> void:
	advance_to(sim.speed_ratio(), ticks_elapsed)
	(get_node("Readout") as Label).text = str(sim.speedo_readout())
	queue_redraw()


func _draw() -> void:
	var pivot := Vector2(size.x / 2.0, size.y)
	var radius: float = size.x / 2.0 - _rim_px / 2.0
	# The rim: the top half of a 160 px circle, 8 px, bottom half clipped away
	# by drawing only the upper arc.
	draw_arc(pivot, radius, PI, TAU, 48, _rim_colour, _rim_px)
	# The needle: a 4×70 px quad from the pivot, red at the base to yellow at
	# the tip, swept (ratio × 180°) − 90° — pointing left at rest.
	var angle := deg_to_rad(needle_angle_deg())
	var dir := Vector2(sin(angle), -cos(angle))
	var side := Vector2(-dir.y, dir.x) * (_needle_w / 2.0)
	var tip := pivot + dir * _needle_len
	draw_polygon(
		[pivot - side, pivot + side, tip + side, tip - side],
		[_needle_base, _needle_base, _needle_tip, _needle_tip]
	)


## `bottom_up` is the label's baseline zone measured up from the dial's
## bottom edge; offsets land only after the label has its real parent.
func _make_label(
	label_name: String, text: String, colour: Color, px: int, bottom_up: float
) -> void:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.label_settings = LabelSettings.new()
	label.label_settings.font_color = colour
	label.label_settings.font_size = px
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	# Full-width rects with ALL FOUR offsets explicit: the preset alone left
	# the horizontal offsets untouched and each label collapsed to minimum
	# width at the left anchor — centre-alignment then centred text inside an
	# 11 px box (the M5 Critic's re-review). The centring is asserted now.
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_left = 0.0
	label.offset_right = 0.0
	label.offset_top = -bottom_up - 4.0
	label.offset_bottom = -bottom_up + float(px)
