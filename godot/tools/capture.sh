#!/usr/bin/env bash
# Capture a scene to a PNG — the visual-proof tool.
#
# WINDOWED, not headless, and deliberately NOT part of tools/test.sh. Godot's
# headless mode has no renderer and returns no image, so the moment a capture
# lands in the standing suite that suite stops working over SSH and needs a
# virtual framebuffer. Keep the split — this project has no CI, and the
# standing suite must stay runnable over a plain SSH session.
#
#   tools/capture.sh                                    # main scene -> gallery/
#   tools/capture.sh res://scenes/main.tscn out.png     # explicit
#   tools/capture.sh res://scenes/main.tscn out.png 60  # more settle frames
#
# Visual proof is MANDATORY for a milestone and expected for any task that
# changes what the player sees. See CONSTRAINTS section 12 Review.
# Committed proof belongs in docs/progress/; gallery/ is scratch and ignored.
#
# Game-agnostic. The only thing to change is the default scene below.
set -euo pipefail
cd "$(dirname "$0")/.."

# Never touch a real save file, even from a capture. GOTCHAS.md records a suite
# that destroyed a fully-equipped campaign by using the real path; a capture
# harness is no different.
export LPC_SAVE_FILE="user://save_test.cfg"

SCENE="${1:-res://scenes/main.tscn}"
OUT="${2:-gallery/capture.png}"
FRAMES="${3:-30}"

if [ "${DISPLAY_REQUIRED:-1}" = "1" ] && [ "$(uname)" != "Darwin" ] && [ -z "${DISPLAY:-}" ]; then
	echo "error: no display. This is a windowed capture; headless has no renderer." >&2
	echo "       On a headless machine, run it under a virtual framebuffer (e.g. xvfb-run)." >&2
	exit 1
fi

mkdir -p "$(dirname "$OUT")"

# Launch WITHOUT stealing focus.
#
# macOS activates a foreground app when it launches, which raises its window over
# whatever the person running this is doing. Godot has no flag for it, and the
# NO_FOCUS window flag set in capture_scene.gd stops keyboard focus but NOT app
# activation — verified the hard way, twice. `open -g` is the macOS-level answer:
# -g leaves the app in the background, -n forces a new instance rather than
# activating a running editor, -W waits for it to exit.
#
# The cost is that `open` does not pipe stdout, so a failing run says nothing.
# Hence the pattern: quiet in the background on success, and on failure re-run
# attached so the error is actually visible. Set LPC_CAPTURE_FOREGROUND=1 to skip
# the quiet path entirely.
BUNDLE=""
if [ "$(uname)" = "Darwin" ]; then
	RESOLVED="$(readlink "$(command -v godot)" 2>/dev/null || command -v godot)"
	case "$RESOLVED" in
		*.app/Contents/MacOS/*) BUNDLE="${RESOLVED%%.app/Contents/MacOS/*}.app" ;;
	esac
fi

# `open` runs the app from a different working directory, so every path it is
# given must be absolute.
PROJECT="$(pwd)"
case "$OUT" in
	/*) ABS_OUT="$OUT" ;;
	*) ABS_OUT="$PROJECT/$OUT" ;;
esac

# Remove any previous file at the target FIRST.
#
# This is the only thing standing between a failed capture and a silent pass.
# `open -g` does not carry Godot's exit status, so the sole failure signal is
# "no file at the output path" — and a stale file from an earlier run satisfies
# that check while containing the WRONG frame. Review reproduced it: a capture
# of a non-existent scene exited 0 and left the old bytes in place.
#
# It matters most where it is least visible. tools/find_light_scale.py reuses one
# scratch path for every candidate scale of a search, so a failed capture midway
# would have been measured as the previous scale's image, and the search would
# have reported a scale it never rendered. check_sky_ambient.sh writes over a
# COMMITTED capture, so the same failure would have re-presented an old file as
# freshly regenerated evidence.
rm -f "$ABS_OUT"

run_attached() {
	godot -s tests/capture_scene.gd -- \
		--scene "$SCENE" --out "$ABS_OUT" --frames "$FRAMES"
}

if [ -n "$BUNDLE" ] && [ "${LPC_CAPTURE_FOREGROUND:-0}" != "1" ]; then
	open -g -n -W -a "$BUNDLE" --args \
		--path "$PROJECT" -s tests/capture_scene.gd -- \
		--scene "$SCENE" --out "$ABS_OUT" --frames "$FRAMES"
	if [ ! -s "$ABS_OUT" ]; then
		echo "capture: background run produced nothing — repeating in the foreground" >&2
		echo "         so the error is visible." >&2
		run_attached
	fi
else
	run_attached
fi

# The Godot side prints its own success line, but a missing file must not pass
# quietly — the same lesson as the suite runner.
if [ ! -s "$ABS_OUT" ]; then
	echo "error: $OUT was not written, or is empty" >&2
	exit 1
fi
