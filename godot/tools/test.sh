#!/usr/bin/env bash
# The standing suite: headless, no display, safe to run on every change.
# `set -euo pipefail` means any check exiting non-zero fails the run.
#
# There is no CI. Nothing runs this automatically — it is the gate that decides
# whether work is done, and running it is carried by review (CONSTRAINTS §12 Review).
#
# Keep this display-free. The moment a screenshot lands here, the suite stops
# working over SSH and needs a virtual framebuffer. Visual checks live in the windowed
# gate: tools/capture.sh now, tools/gallery.sh when M6 adds it.
set -euo pipefail
cd "$(dirname "$0")/.."

# Never touch a real save file from a test. See GOTCHAS.md.
export LPC_SAVE_FILE="user://save_test.cfg"
export LPC_LAYOUT_FILE="user://layout_test.json"

# Python tooling runs from .venv, never system Python — so the package versions
# that gate a change are the ones recorded in requirements.txt, not whatever
# happens to be installed on the machine.
PY=".venv/bin/python"
if [ ! -x "$PY" ]; then
	echo "error: .venv not found. Create it before running the suite:" >&2
	echo "    python3 -m venv .venv" >&2
	echo "    .venv/bin/pip install -r requirements.txt" >&2
	exit 1
fi

# An empty .venv satisfies the check above but fails the moment a tool needs a
# package. Verify the environment actually matches requirements.txt.
if ! "$PY" -c "import PIL, numpy, yaml" 2>/dev/null; then
	echo "error: .venv is missing required packages. Install them:" >&2
	echo "    .venv/bin/pip install -r requirements.txt" >&2
	"$PY" -c "import PIL, numpy, yaml" 2>&1 | tail -1 >&2
	exit 1
fi

# gdlint/gdformat are console scripts, not importable modules, so the check
# above cannot see them. Named here so a missing gdtoolkit fails at the guard
# with instructions rather than later inside a check.
for tool in gdlint gdformat; do
	if [ ! -x ".venv/bin/$tool" ]; then
		echo "error: .venv is missing $tool (gdtoolkit). Install it:" >&2
		echo "    .venv/bin/pip install -r requirements.txt" >&2
		exit 1
	fi
done

# A GDScript RUNTIME error inside a _test_ function aborts that function,
# returns to _init, and the suite still prints its success line and exits 0 —
# a half-run suite reads as green (former att 19; the same hole bit the
# sibling course repos). So every suite runs through this wrapper: it fails
# the run, naming the suite, on a non-zero exit OR on the error markers Godot
# prints while exiting 0.
run_suite() {
	local suite="$1" out
	if ! out=$(godot --headless -s "$suite" 2>&1); then
		printf '%s\n' "$out"
		echo "error: $suite exited non-zero" >&2
		exit 1
	fi
	printf '%s\n' "$out"
	if printf '%s' "$out" | grep -qE 'SCRIPT ERROR|Parse Error|Failed to load script'; then
		echo "error: $suite hit a script error mid-run — its assertions after that line never ran" >&2
		exit 1
	fi
}

# Art is single-sourced at the repository root and copied in here. Runs first
# so a stale or missing model is an explicit failure rather than a confusing
# one inside a later check. Idempotent; compares content hashes, not mtimes.
tools/sync_assets.sh

# Import them, then prove they loaded. `godot --headless -s <script>` does not
# trigger import, and `--import` exits 0 even when a model fails — so the import
# step alone is decorative and assets_test.gd is what actually fails. Together
# they back the delta spec's "all seven models resolve and import successfully".
godot --headless --import >/dev/null

# The web-budget texture params (CONSTRAINTS §8 Performance and size budgets): extraction writes default
# sidecars, the stamp rewrites them, and a re-import applies them. Idempotent
# after the first pass; the --check keeps a fresh clone from silently
# shipping lossless 2048s again.
STAMP_OUT=$("$PY" tools/stamp_texture_imports.py)
echo "$STAMP_OUT"
if [[ "$STAMP_OUT" != *" 0 (re)stamped" ]]; then
	godot --headless --import >/dev/null
fi
"$PY" tools/stamp_texture_imports.py --check

run_suite tests/assets_test.gd
run_suite tests/smoke_test.gd

# The simulation core — the design document's tick order, the boundary, and the
# reproducibility every other headless suite rests on.
run_suite tests/tick_test.gd
run_suite tests/race_state_test.gd
run_suite tests/lap_gate_test.gd
run_suite tests/hud_test.gd
run_suite tests/minimap_test.gd

# The step-cost budget as a standing check (CONSTRAINTS §8 Performance and
# size budgets) — headless and fast; the frame-time half needs a window and
# lives in tools/fps_probe.gd.
run_suite tests/layout_test.gd
run_suite tests/conformance_test.gd
run_suite tools/step_bench.gd
run_suite tests/boundary_test.gd
run_suite tests/determinism_test.gd

# The SHIPPED tuning table against acceptance item 4. Every suite above builds
# tuning from inline literals, so without this a retuned data/tuning.json would
# leave them all green while the game violated the acceptance checklist.
run_suite tests/tuning_loader_test.gd

# The design document's §3 asset normalisation contract — the arithmetic that
# decides whether props stand on the ground or in it.
run_suite tests/normalise_test.gd

# The environment, checked in a headless scene tree — everything about §5 and §6
# except the pixels. The captures in docs/progress/ carry the other half.
run_suite tests/world_test.gd

# Acceptance 14a: one input sequence, three tick batchings, one outcome.
run_suite tests/replay_test.gd

# The running game rather than the core: the composition root, the kart's
# orientation against the design document, and input. All headless — a scene
# tree needs no renderer.
run_suite tests/driver_test.gd
run_suite tests/kart_test.gd
run_suite tests/input_test.gd
run_suite tests/camera_test.gd
run_suite tests/scatter_test.gd
run_suite tests/prop_field_test.gd
run_suite tests/collision_test.gd


# Lint and format. Fast, and they keep the diff about behaviour.
# Every .gd under scripts/ and tests/, not a fixed list of directories — an
# earlier version named scripts/core/ explicitly, so a future scripts/view/
# would have been linted by the commit hook and missed by the gate.
# templates/ is excluded: its suites are deliberately incomplete examples.
GD_FILES=$(find scripts tests -name '*.gd' | sort)   # templates/ is a sibling, not under these roots
if [ -z "$GD_FILES" ]; then
	echo "error: no GDScript found under scripts/ or tests/ — the layout changed" >&2
	echo "       and the lint step is now checking nothing." >&2
	exit 1
fi
# shellcheck disable=SC2086
.venv/bin/gdlint $GD_FILES
# shellcheck disable=SC2086
.venv/bin/gdformat --check $GD_FILES

# Documentation gates. Cheap, display-free, and they catch a class of rot that
# no diff review reliably does. All three are rooted at the REPOSITORY root, not
# this directory — the design document, CONSTRAINTS.md and ROADMAP.md live above
# godot/, and a checker pointed at a directory that does not exist passes by
# examining nothing.
"$PY" tools/check_links.py
"$PY" tools/check_section_refs.py
"$PY" tools/check_placeholders.py --strict

# The tuning table is the single transcription of the design document's constant
# tables. A renamed or missing key silently forks the contract and nothing else
# in this suite would notice.
"$PY" tools/check_tuning_transcription.py

# The engine version is recorded once and asserted everywhere. project.godot
# cannot be the source of truth: config/features stores only major.minor.
"$PY" tools/check_engine_version.py

# Static typing on every signature. gdlint cannot do this — it ships no typing
# rules — so naming it as the gate left CONSTRAINTS §3 Language and style unenforced.
"$PY" tools/check_static_typing.py

# G1 — every scenario in the design document is claimed by a test, the visual
# register, or a dated deferral. CONSTRAINTS §5 Conformance to the specification.
"$PY" tools/check_spec_coverage.py

# Architectural boundaries. The simulation core stays free of the engine, and the
# Godot physics engine appears nowhere — over the WHOLE tree, not just staged
# files, which is what the commit hook alone cannot give us. Both read the same
# godot/data/banned_symbols.json the hook does.
"$PY" tools/check_boundaries.py

# Tuning values are referred to by name, never written as literals in game logic.
"$PY" tools/check_tuning_literals.py

# The pinned settings and the committed import presets, both of which Godot
# rewrites without asking.
# The kart against the DESIGN DOCUMENT rather than against tuning.json — the one
# check in this project whose expected values have no common ancestor with the
# thing they check. It shells out to Godot to measure, so it is slower than the
# other Python gates and still headless.
"$PY" tools/check_kart_conformance.py

# The generated field against the design document's own population table and
# rejection rules — the second gate whose expectations share no ancestor with the
# thing they check. Shells out to Godot to generate, and stays headless.
"$PY" tools/check_scatter_conformance.py
# Every suite under tests/ is actually run by this file. 3f43233 shipped three
# that were not, and they were dark until 20e61fa.
"$PY" tools/check_suites_registered.py
"$PY" tools/check_settings.py

# Uncomment each as you add it (see docs/testing_toolkit.md, "As the game grows"):
# run_suite tests/balance_test.gd
# run_suite tests/rng_test.gd
# run_suite tests/av_event_test.gd
# run_suite tests/motion_test.gd
# run_suite tests/flow_test.gd

echo "All suites passed."
