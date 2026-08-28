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

godot -s tests/capture_scene.gd -- \
	--scene "$SCENE" --out "$OUT" --frames "$FRAMES"

# The Godot side prints its own success line, but a missing file must not pass
# quietly — the same lesson as the suite runner.
if [ ! -s "$OUT" ]; then
	echo "error: $OUT was not written, or is empty" >&2
	exit 1
fi
