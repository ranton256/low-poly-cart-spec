#!/usr/bin/env bash
# Regenerate the evidence that design D2a rests on.
#
# D2 originally expressed the design document's two fill terms as ONE Godot
# ambient whose sky contribution is their ratio. That mapping was rejected
# because setting ambient_light_source = SKY makes Godot draw the sky and ignore
# background_mode = BG_COLOR, so the flat sky section 5 requires becomes a
# gradient with the hemisphere's GROUND colour banded across the horizon.
#
# An approved design decision was overturned on that measurement, so the
# measurement has to be re-runnable — CLAUDE.md rule 5. This script rebuilds the
# rejected configuration, captures it, and reports the band. It is NOT part of
# tools/test.sh: it mutates a script, and it needs a renderer.
#
#   tools/check_sky_ambient.sh
#
# Expected: the row-230 median is (32, 139, 32), against the hemisphere ground
# colour (34, 139, 34), where a flat sky would read
# (135, 206, 235). tests/world_test.gd guards the outcome on every run; this
# reproduces the finding behind it.
set -euo pipefail
cd "$(dirname "$0")/.."

BUILDER="scripts/world/world_builder.gd"
OUT="${1:-docs/progress/2026-08-29-m2-sky-ambient-rejected.png}"
BACKUP="$(mktemp)"
cp "$BUILDER" "$BACKUP"
# Restore whatever happens next: this edits a tracked source file.
trap 'cp "$BACKUP" "$BUILDER"; rm -f "$BACKUP"' EXIT

.venv/bin/python - "$BUILDER" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = s.replace("env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR",
              "env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY")
# The sky resource D2 called for, rebuilt inline so the rejected configuration is
# complete rather than half-applied.
s = s.replace("\tenv.fog_enabled = true", """\tvar sky_material := ProceduralSkyMaterial.new()
\tsky_material.sky_top_color = art.colour("hemisphereSkyColour")
\tsky_material.sky_horizon_color = art.colour("hemisphereSkyColour")
\tsky_material.ground_bottom_color = art.colour("hemisphereGroundColour")
\tsky_material.ground_horizon_color = art.colour("hemisphereGroundColour")
\tvar rejected_sky := Sky.new()
\trejected_sky.sky_material = sky_material
\tenv.sky = rejected_sky
\tenv.fog_enabled = true""")
p.write_text(s)
PY

./tools/capture.sh res://scenes/world.tscn "$OUT" 30

.venv/bin/python - "$OUT" <<'PY'
import sys
import numpy as np
from PIL import Image
img = np.asarray(Image.open(sys.argv[1]).convert("RGB"))
print("sky-ambient rejected configuration:")
# The band is dithered, so a single pixel is not a measurement. BAND_ROW's median
# across the full width is: a named region, printed, reproducible.
BAND_ROW = 230
for row in (50, 150, BAND_ROW, 260):
    median = np.median(img[row].astype(float), axis=0).astype(int).tolist()
    print(f"  row {row:4}: median across the full width {median}")
print("  a flat sky would read [135, 206, 235] at every row above the horizon;")
print("  the hemisphere's ground colour is [34, 139, 34]")
PY
