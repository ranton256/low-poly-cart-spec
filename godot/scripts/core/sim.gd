# The simulation — a worked skeleton of the one decision the rest of this repo
# depends on.
#
# RULES, and they are the whole point:
#
#   1. No engine node dependencies. This file never touches Node, Sprite2D,
#      AudioStreamPlayer, or the scene tree. It can be constructed and stepped
#      by a test, a bot, or a capture harness with no scene loaded at all.
#   2. Fixed timestep. step() advances exactly one tick. Never read `delta`.
#   3. Seeded. All gameplay randomness comes from scripts/core/rng.gd, never
#      from randi(). Cosmetic randomness in the VIEW may use the engine RNG,
#      precisely so it can never perturb this stream.
#   4. One-shot effects are PUBLISHED as data, not played. The view drains
#      `events` each frame and turns them into sound and particles. That is
#      what makes cues assertable without a sound card.
#   5. The view reads this; it never writes back.
#
# Everything in the toolkit — headless suites, a bot that plays the whole game,
# reproducible screenshots, renderer-free motion tests — follows from these.
# Retrofitting them later is expensive; starting with them costs nothing.
#
# Replace the placeholder state below with your game. Keep the shape.

const DT_MS := 1000.0 / 60.0
const DT_S := DT_MS / 1000.0

# --- placeholder tuning: replace with reads from data/tuning.json in M1 ---
const SPEED := 400.0
const WIDTH := 960.0
const HEIGHT := 540.0
const HALF := 16.0

# --- input: set by the view or a harness before each step ---
var in_left := false
var in_right := false
var in_up := false
var in_down := false

# --- outcome: "" while running; your own strings when the run resolves ---
var outcome := ""

# --- one-shot effects for the view/audio layer; the consumer clears them ---
var events: Array[Dictionary] = []

# --- state (placeholder: replace with your game's) ---
var time_ms := 0.0
var px := 0.0
var py := 0.0


func setup() -> void:
	time_ms = 0.0
	outcome = ""
	px = WIDTH / 2.0
	py = HEIGHT - 80.0
	events.clear()


## Publish an effect for the view. The sim never plays a sound itself.
func emit_sfx(id: String, volume: float) -> void:
	events.append({"type": "sfx", "id": id, "volume": volume})


## One tick. The ORDER of operations inside here is part of your balance —
## document it, and change it deliberately rather than incidentally.
func step() -> void:
	if outcome != "":
		return
	time_ms += DT_MS

	var vx := (1.0 if in_right else 0.0) - (1.0 if in_left else 0.0)
	var vy := (1.0 if in_down else 0.0) - (1.0 if in_up else 0.0)
	if vx != 0.0 and vy != 0.0:
		# normalise so diagonals are not faster than cardinals
		vx *= 0.70710678
		vy *= 0.70710678
	px += vx * SPEED * DT_S
	py += vy * SPEED * DT_S

	var clamped_x := clampf(px, HALF, WIDTH - HALF)
	var clamped_y := clampf(py, HALF, HEIGHT - HALF)
	if clamped_x != px or clamped_y != py:
		emit_sfx("bump", 0.3)  # example: an effect the cue tests can assert
	px = clamped_x
	py = clamped_y

	# TODO: your game. Suggested order to preserve:
	#   input -> movement -> spawns -> collisions -> timers -> outcome


## A one-line state summary. Cheap, and far easier to diff between two runs
## than comparing object graphs — determinism tests compare these strings.
func stats_line() -> String:
	return "t=%.2f x=%.2f y=%.2f outcome=%s" % [time_ms / 1000.0, px, py, outcome]
