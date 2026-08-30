#!/usr/bin/env bash
# The windowed visual gallery (V9): capture the fixed state set into gallery/
# and compare against the committed baselines in tests/baselines/.
#
#   tools/gallery.sh              # capture + compare, exit 1 on drift
#   tools/gallery.sh --bless      # capture, then accept as the new baselines
#   tools/gallery.sh --capture-only DIR   # capture the set into DIR and stop
#
# WINDOWED, never part of test.sh — headless Godot has no renderer. Every
# state is deterministic: named seed, fixed tick counts, and the post-draw
# capture path (tools/drive_capture.gd / lap_capture.gd), so two runs differ
# only by the recorded noise floor in tools/gallery_config.json.
set -euo pipefail
cd "$(dirname "$0")/.."

export LPC_SAVE_FILE="user://save_test.cfg"
PY=".venv/bin/python"

OUT="gallery"
MODE="compare"
if [ "${1:-}" = "--bless" ]; then MODE="bless"; fi
if [ "${1:-}" = "--capture-only" ]; then MODE="capture"; OUT="${2:?--capture-only needs a directory}"; fi
mkdir -p "$OUT"

# The seven states. Tick counts are sim-exact: READY at 30, GO! inside the
# 30-tick linger at 250, the HUD at speed at 330, the boundary pin at 850,
# and the banked lap via the lap suite's own phase table; the grazing-angle
# cone row (M8) is fully staged, no drive at all. gate_next (M9) is tick 336 of
# the throttle-held drive — 96 ticks after the handover, with the shipped
# circuit's first gate a few world units ahead. 336 is an exact multiple of the
# 48-tick pulse period (gatePulseSeconds at 60 Hz), so the next gate sits at
# FULL gateNextColour: the phase is chosen rather than caught, and it is the
# same in every run because the pulse is a function of the tick.
godot -s tools/drive_capture.gd -- --out "$OUT/boot_ready.png"     --ticks 30
godot -s tools/drive_capture.gd -- --out "$OUT/countdown_go.png"   --ticks 250
godot -s tools/drive_capture.gd -- --out "$OUT/hud_at_speed.png"   --ticks 330 --hold accelerate
godot -s tools/drive_capture.gd -- --out "$OUT/boundary_skirt.png" --ticks 850 --hold accelerate
godot -s tools/lap_capture.gd  -- --out "$OUT/lap_banked.png"
godot -s tools/graze_capture.gd -- --out "$OUT/graze_cones.png"
godot -s tools/drive_capture.gd -- --out "$OUT/gate_next.png"      --ticks 336 --hold accelerate

case "$MODE" in
	capture) echo "gallery: captured the set into $OUT" ;;
	bless)   "$PY" tools/gallery_compare.py --bless ;;
	compare) "$PY" tools/gallery_compare.py ;;
esac
