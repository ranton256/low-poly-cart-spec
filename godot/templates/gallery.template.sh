#!/usr/bin/env bash
# TEMPLATE — capture the canonical states and diff them against baselines.
#
# WINDOWED, not headless: Godot's headless mode has no renderer and cannot
# screenshot. This is why the visual gate is separate from the standing suite
# rather than part of it.
#
#   tools/gallery.sh              capture, then compare — non-zero on drift
#   tools/gallery.sh --bless      capture, then accept the result as truth
#   tools/gallery.sh --no-compare capture only
set -euo pipefail
cd "$(dirname "$0")/.."

# Python runs from .venv, never system Python — see ../CONSTRAINTS.md 1.
PY=".venv/bin/python"
if [ ! -x "$PY" ]; then
  echo "error: .venv not found. python3 -m venv .venv && .venv/bin/pip install -r requirements.txt" >&2
  exit 1
fi

BLESS=0
COMPARE=1
OUT="gallery"
for arg in "$@"; do
  case "$arg" in
    --bless) BLESS=1 ;;
    --no-compare) COMPARE=0 ;;
    -*) echo "unknown option: $arg" >&2; exit 2 ;;
    *) OUT="$arg" ;;
  esac
done

# Redirect the save. A capture run that writes the real save file will
# eventually destroy someone's progress.
export LPC_SAVE_FILE="user://save_test.cfg"

# Start from empty. A stale state left behind is one a reviewer mistakes for
# current, and one the comparator has nothing to diff against.
rm -rf "$OUT"
mkdir -p "$OUT"
TSV="$OUT/.manifest.tsv"
: > "$TSV"

# NAME states, do not number them. Numbering seems tidy until content is
# inserted in the middle: every later state renames, every baseline churns, and
# the old files sit beside the new ones looking equally current.
cap_scene() {
  local name="$1"; shift
  godot -s tests/capture_scene.gd -- "$@" --out "$OUT/$name.png" >/dev/null 2>&1
  printf '%s\tcapture_scene\t%s\n' "$name" "$*" >> "$TSV"
}

cap_game() {
  local name="$1"; shift
  godot -s tests/capture_game.gd -- "$@" --out "$OUT/$name.png" >/dev/null 2>&1
  printf '%s\tcapture_game\t%s\n' "$name" "$*" >> "$TSV"
}

# TODO: your states. Cover every screen a player sees, plus the feedback states
# that are easy to break and hard to notice (damage flash, pause, game over).
cap_scene main-menu --scene menu
# cap_game level-01 --level 1 --seed 1234 --frames 212 --fire

"$PY" - "$OUT" "$TSV" <<'PYEOF'
import json, sys
out, tsv = sys.argv[1], sys.argv[2]
states = [dict(zip(("state", "harness", "args"), line.rstrip("\n").split("\t", 2)))
          for line in open(tsv)]
for s in states:
    s["file"] = s["state"] + ".png"
json.dump({"states": states}, open(f"{out}/manifest.json", "w"), indent=1)
print(f"captured {len(states)} states into {out}/")
PYEOF
rm -f "$TSV"

if [ "$BLESS" = "1" ]; then
  "$PY" tools/gallery_compare.py --current "$OUT" --bless
elif [ "$COMPARE" = "1" ]; then
  "$PY" tools/gallery_compare.py --current "$OUT"
fi
