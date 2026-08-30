# The screen-space HUD: the start-sequence overlay (loading indicator, its
# error replacement, the countdown), the §7 timer block, the title and control
# hints, and the speedometer.
#
# A PURE CONSUMER (godot/race-state, godot/lap-timing, godot/hud): everything
# shown is derived each frame from the simulation snapshot and the data layer.
# The only state this node owns is its labels and the speedometer's eased
# needle — which advances on the simulation clock, fed the tick delta below.
# Colours and px values come from data/tuning.json (V23 keeps the document's
# hex strings out of scripts); px are literal at the 1280×720 design
# resolution (ambiguity A1), scaled by the project's canvas_items stretch.
#
# Faces per §7 via SystemFont — the repo ships no font asset; a system
# monospace/sans request is the lightest conforming choice. No HUD element
# intercepts pointer input.
extends CanvasLayer

const RaceState := preload("res://scripts/core/race_state.gd")
const Sim := preload("res://scripts/core/sim.gd")
const SpeedoView := preload("res://scripts/view/speedo_view.gd")
const GateChevronView := preload("res://scripts/view/gate_chevron_view.gd")

const COUNTDOWN_GLYPHS: Array[String] = ["READY", "3", "2", "1"]
const LOADING_TEXT := "Loading assets..."
const GO_TEXT := "GO!"
const TITLE_TEXT := "LOW POLY CART"
## §7's hint line, verbatim — it names the objective, which is why the amended
## document spells it out rather than leaving the wording to the port.
const HINTS_TEXT := "W/S drive · A/D steer · G restart · follow the gates"
## The gate counter's own format, §7's "GATE n/N in the timer label style".
const GATE_FORMAT := "GATE %d/%d"

var _countdown: Label = null
var _loading: Label = null
var _time_label: Label = null
var _time_value: Label = null
var _best_label: Label = null
var _best_value: Label = null
var _gate_label: Label = null
var _medal: Label = null
var _title: Label = null
var _hints: Label = null
var _speedo: Control = null
var _chevron: Control = null
var _styled := false
var _last_tick := 0

var _mono := SystemFont.new()
var _sans := SystemFont.new()
var _heavy := SystemFont.new()


func _ready() -> void:
	_mono.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono", "monospace"])
	_sans.font_names = PackedStringArray(["Helvetica Neue", "Arial", "sans-serif"])
	# §7's "Heavy black sans face" — weight, not just family (M5 Critic 4).
	_heavy.font_names = _sans.font_names
	_heavy.font_weight = 900
	_countdown = _make_label("Countdown", Control.PRESET_FULL_RECT)
	_loading = _make_label("Loading", Control.PRESET_FULL_RECT)
	_time_label = _make_label("TimeLabel", Control.PRESET_TOP_RIGHT)
	_time_value = _make_label("TimeValue", Control.PRESET_TOP_RIGHT)
	_best_label = _make_label("BestLabel", Control.PRESET_TOP_RIGHT)
	_best_value = _make_label("BestValue", Control.PRESET_TOP_RIGHT)
	_gate_label = _make_label("GateCounter", Control.PRESET_TOP_RIGHT)
	_medal = _make_label("Medal", Control.PRESET_TOP_RIGHT)
	_title = _make_label("Title", Control.PRESET_TOP_LEFT)
	_hints = _make_label("Hints", Control.PRESET_TOP_LEFT)
	_speedo = SpeedoView.new()
	_speedo.name = "Speedo"
	add_child(_speedo)
	_chevron = GateChevronView.new()
	_chevron.name = "GateChevron"
	add_child(_chevron)


## Called by the composition root once per rendered frame, after the kart view.
## `camera` is the live chase camera, read only for the off-screen gate
## chevron's projection; optional so a headless suite can bind the overlay to a
## bare simulation as it always could.
func draw_from(sim: RefCounted, art: RefCounted, camera: Camera3D = null) -> void:
	if sim == null or art == null or _countdown == null:
		return
	if not _styled:
		_style(art)
		_styled = true
	var ticks_elapsed: int = maxi(sim.ticks - _last_tick, 0)
	_last_tick = sim.ticks

	var race: RefCounted = sim.race
	_draw_readouts(sim, art, race, ticks_elapsed)
	if race.state == RaceState.RACING:
		_chevron.draw_from(sim, camera)
	else:
		_chevron.visible = false
	_loading.visible = race.state == RaceState.LOADING
	if race.state == RaceState.LOADING:
		# The error replaces the indicator; the underlying cause is already in
		# the developer log (Failing to load an asset).
		_loading.text = race.error_message if race.error_message != "" else LOADING_TEXT
		_countdown.visible = false
		return

	if race.state == RaceState.STARTING:
		_countdown.visible = true
		_countdown.text = COUNTDOWN_GLYPHS[race.countdown_index()]
		_countdown.label_settings.font_color = art.colour("countdownTextColour")
		return

	# RACING: GO! lingers `goLinger` past the handover — the kart is already
	# drivable — then the overlay hides and resets to white for the next use.
	var linger_ticks: int = int(roundf(sim.tuning.go_linger * Sim.TICKS_PER_SECOND))
	if race.ticks_in_state < linger_ticks:
		_countdown.visible = true
		_countdown.text = GO_TEXT
		_countdown.label_settings.font_color = art.colour("countdownGoColour")
	else:
		_countdown.visible = false
		_countdown.label_settings.font_color = art.colour("countdownTextColour")


## The §7 timer block and the speedometer, racing only. TIME and BEST derive
## from the lap module's counters; the dial from the core's ratio and readout.
func _draw_readouts(sim: RefCounted, art: RefCounted, race: RefCounted, ticks_elapsed: int) -> void:
	var racing: bool = race.state == RaceState.RACING
	for element: Control in [
		_time_label, _time_value, _best_label, _best_value, _gate_label, _speedo
	]:
		element.visible = racing
	if not racing:
		_medal.visible = false
		return
	var lap: RefCounted = sim.lap
	_time_value.text = "%.2f" % lap.display_seconds()
	_best_value.text = "--.--" if lap.best_seconds < 0.0 else "%.2f" % lap.best_seconds
	var flash: bool = lap.best_flash_ticks > 0
	_best_value.label_settings.font_color = art.colour(
		"bestFlashColour" if flash else "bestTextColour"
	)
	# GATE n/N: the cursor against the gate count, both the core's. A threaded
	# course holds at N — the cursor runs one past the final gate, and "GATE 7/6"
	# would be arithmetic the HUD invented.
	var circuit: RefCounted = sim.circuit
	_gate_label.visible = racing and circuit.has_gates()
	if circuit.has_gates():
		_gate_label.text = (
			GATE_FORMAT % [mini(circuit.cursor, circuit.gate_count()), circuit.gate_count()]
		)
	# The medal joins the HELD readout, for exactly the hold window, in its own
	# colour — the core decided which medal at bank time; this only names it.
	var medal: String = lap.banked_medal
	_medal.visible = lap.hold_ticks > 0 and medal != ""
	if _medal.visible:
		_medal.text = medal.to_upper()
		_medal.label_settings.font_color = art.colour("medal%sColour" % medal.capitalize())
	_speedo.draw_from(sim, ticks_elapsed)


func _make_label(label_name: String, preset: int) -> Label:
	var label := Label.new()
	label.name = label_name
	label.set_anchors_preset(preset)
	if preset == Control.PRESET_FULL_RECT:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.label_settings = LabelSettings.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	add_child(label)
	return label


## Styling waits for the art table, which the root loads after this node's
## _ready. §7's geometry at the 1280×720 design resolution: the timer block's
## right edge insets 16 px; the title block sits 16 px from the top-left; the
## speedometer's dial insets 16 px from the bottom-right. The shadow's black
## is a Color constant, not a specified hex string.
func _style(art: RefCounted) -> void:
	for label: Label in [_countdown, _loading]:
		var settings: LabelSettings = label.label_settings
		settings.font = _mono if label == _loading else _heavy
		settings.font_size = (
			int(art.num("countdownFontPx")) if label == _countdown else int(art.num("loadingPx"))
		)
		settings.font_color = art.colour("countdownTextColour")
		settings.shadow_color = Color(0, 0, 0)
		settings.shadow_offset = Vector2(4, 4) if label == _countdown else Vector2(2, 2)

	var label_px: int = int(art.num("timerLabelPx"))
	var value_px: int = int(art.num("timerValuePx"))
	var block: Array = [
		[_time_label, "TIME", label_px, art.colour("countdownTextColour"), 16.0],
		[_time_value, "", value_px, art.colour("timeValueColour"), 32.0],
		[_best_label, "BEST", label_px, art.colour("countdownTextColour"), 64.0],
		[_best_value, "--.--", value_px, art.colour("bestTextColour"), 80.0],
	]
	# The gate counter is IN the timer block (§7 puts it there), in the timer
	# LABEL style, under BEST. The medal sits beside the held TIME value, left of
	# it, at the value's own size — the readout it joins.
	block.append(
		[_gate_label, GATE_FORMAT % [1, 1], label_px, art.colour("countdownTextColour"), 112.0]
	)
	for row: Array in block:
		var label: Label = row[0]
		label.text = row[1]
		label.label_settings.font = _mono
		label.label_settings.font_size = row[2]
		label.label_settings.font_color = row[3]
		label.label_settings.shadow_color = Color(0, 0, 0)
		label.label_settings.shadow_offset = Vector2(2, 2)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		# Layout, not spec: a right-aligned column inset 16 px from the edge.
		# OFFSETS, not position — position is relative to the parent's
		# top-left whatever the anchors say, which parked the first draft of
		# this block off-screen; the milestone capture caught it.
		label.offset_left = -164.0
		label.offset_right = -16.0
		label.offset_top = row[4]
		label.offset_bottom = row[4] + float(row[2]) + 8.0
	_time_label.modulate.a = art.num("timerLabelOpacity")
	_best_label.modulate.a = art.num("timerLabelOpacity")
	_gate_label.modulate.a = art.num("timerLabelOpacity")

	_medal.label_settings.font = _mono
	_medal.label_settings.font_size = value_px
	_medal.label_settings.shadow_color = Color(0, 0, 0)
	_medal.label_settings.shadow_offset = Vector2(2, 2)
	_medal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_medal.offset_left = -340.0
	_medal.offset_right = -176.0
	_medal.offset_top = 32.0
	_medal.offset_bottom = 32.0 + float(value_px) + 8.0

	_title.text = TITLE_TEXT
	_title.label_settings.font = _sans
	_title.label_settings.font_size = int(art.num("titlePx"))
	_title.label_settings.font_color = art.colour("titleColour")
	_title.label_settings.shadow_color = Color(0, 0, 0)
	_title.label_settings.shadow_offset = Vector2(2, 2)
	_title.position = Vector2(16, 16)
	_title.visible = true
	_hints.text = HINTS_TEXT
	_hints.label_settings.font = _sans
	_hints.label_settings.font_size = int(art.num("hintPx"))
	_hints.label_settings.font_color = art.colour("hintColour")
	_hints.label_settings.shadow_color = Color(0, 0, 0)
	_hints.label_settings.shadow_offset = Vector2(2, 2)
	_hints.position = Vector2(16, 44)
	_hints.modulate.a = art.num("hintOpacity")
	_hints.visible = true

	_chevron.configure(art)
	_speedo.configure(art)
	_speedo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_speedo.offset_left = -_speedo.custom_minimum_size.x - 16.0
	_speedo.offset_right = -16.0
	_speedo.offset_top = -_speedo.custom_minimum_size.y - 16.0
	_speedo.offset_bottom = -16.0
