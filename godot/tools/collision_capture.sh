#!/usr/bin/env bash
# Windowed capture of a staged collision.
#
#   tools/collision_capture.sh <mode> <out.png> [ticks-after-contact] [nojolt]
#
#   mode: contact | shudder | pin
#
# NEVER in test.sh. Headless has no renderer, so this is a separate gate — the
# same rule tools/capture.sh states.
#
# The launch mechanics are tools/capture.sh's, for the reason recorded there:
# macOS activates a foreground app when it launches and raises its window over
# whatever the person running this is doing. The NO_FOCUS window flag stops
# keyboard focus and NOT app activation; `open -g -n -W` is the answer. Running
# `godot -s tools/collision_capture.gd` directly works and steals focus, which is
# why this wrapper exists rather than a line in a progress note.
set -euo pipefail

cd "$(dirname "$0")/.."

MODE="${1:-contact}"
OUT="${2:-gallery/collision.png}"
AFTER="${3:-0}"
# "1" suppresses the collision jolt, for the paired shudder capture.
NOJOLT="${4:-0}"

if [ "$(uname)" != "Darwin" ] && [ -z "${DISPLAY:-}" ]; then
	echo "error: no display. This is a windowed capture; headless has no renderer." >&2
	exit 1
fi

mkdir -p "$(dirname "$OUT")"

PROJECT="$(pwd)"
case "$OUT" in
	/*) ABS_OUT="$OUT" ;;
	*) ABS_OUT="$PROJECT/$OUT" ;;
esac

# First, so that a failed run cannot pass by leaving a stale file in place —
# tools/capture.sh records why this is the only failure signal `open -g` leaves.
rm -f "$ABS_OUT"

BUNDLE=""
if [ "$(uname)" = "Darwin" ]; then
	RESOLVED="$(readlink "$(command -v godot)" 2>/dev/null || command -v godot)"
	case "$RESOLVED" in
		*.app/Contents/MacOS/*) BUNDLE="${RESOLVED%%.app/Contents/MacOS/*}.app" ;;
	esac
fi

run_attached() {
	godot -s tools/collision_capture.gd -- \
		--mode "$MODE" --out "$ABS_OUT" --after "$AFTER" --nojolt "$NOJOLT"
}

if [ -n "$BUNDLE" ] && [ "${LPC_CAPTURE_FOREGROUND:-0}" != "1" ]; then
	open -g -n -W -a "$BUNDLE" --args \
		--path "$PROJECT" -s tools/collision_capture.gd -- \
		--mode "$MODE" --out "$ABS_OUT" --after "$AFTER" --nojolt "$NOJOLT"
	if [ ! -s "$ABS_OUT" ]; then
		echo "collision_capture: background run produced nothing — repeating in the" >&2
		echo "                   foreground so the error is visible." >&2
		run_attached
	fi
else
	run_attached
fi

if [ ! -s "$ABS_OUT" ]; then
	echo "error: $OUT was not written, or is empty" >&2
	exit 1
fi
