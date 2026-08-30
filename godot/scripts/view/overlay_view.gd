# The start-sequence overlay: the loading indicator, its error replacement,
# and the countdown — READY, 3, 2, 1, GO!.
#
# A PURE CONSUMER (godot/race-state): everything shown here is derived each
# frame from the simulation snapshot and the data layer. The only state this
# node owns is its two labels. Glyph colours and the font size come from
# data/tuning.json — the GO! green is the design document's own hex string and
# V23 keeps it out of scripts; `goLinger` is read from the core tuning like
# every other constant.
#
# The design document sizes the face at ~120 px with no design resolution
# named — ambiguity A1, settled in M5 with the rest of the HUD. The value
# lives in data now so M5's settlement is a data edit.
extends CanvasLayer

const RaceState := preload("res://scripts/core/race_state.gd")
const Sim := preload("res://scripts/core/sim.gd")

const COUNTDOWN_GLYPHS: Array[String] = ["READY", "3", "2", "1"]
const LOADING_TEXT := "Loading assets..."
const GO_TEXT := "GO!"

var _countdown: Label = null
var _loading: Label = null
var _styled := false


func _ready() -> void:
	_countdown = _make_label("Countdown")
	_loading = _make_label("Loading")


## Called by the composition root once per rendered frame, after the kart view.
func draw_from(sim: RefCounted, art: RefCounted) -> void:
	if sim == null or art == null or _countdown == null:
		return
	if not _styled:
		_style(art)
		_styled = true

	var race: RefCounted = sim.race
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


func _make_label(label_name: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.label_settings = LabelSettings.new()
	label.visible = false
	add_child(label)
	return label


## Styling waits for the art table, which the root loads after this node's
## _ready. Font size and colours are data; the shadow's black is a Color
## constant, not a specified hex string.
func _style(art: RefCounted) -> void:
	for label: Label in [_countdown, _loading]:
		var settings: LabelSettings = label.label_settings
		settings.font_size = int(art.num("countdownFontPx")) if label == _countdown else 32
		settings.font_color = art.colour("countdownTextColour")
		settings.shadow_color = Color(0, 0, 0)
		settings.shadow_offset = Vector2(4, 4)
