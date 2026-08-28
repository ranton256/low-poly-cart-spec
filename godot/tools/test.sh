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

# Art is single-sourced at the repository root and copied in here. Runs first
# so a stale or missing model is an explicit failure rather than a confusing
# one inside a later check. Idempotent; compares content hashes, not mtimes.
tools/sync_assets.sh

# Import them, then prove they loaded. `godot --headless -s <script>` does not
# trigger import, and `--import` exits 0 even when a model fails — so the import
# step alone is decorative and assets_test.gd is what actually fails. Together
# they back the delta spec's "all seven models resolve and import successfully".
godot --headless --import >/dev/null

godot --headless -s tests/assets_test.gd
godot --headless -s tests/smoke_test.gd

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

# Uncomment each as you add it (see docs/testing_toolkit.md, "As the game grows"):
# godot --headless -s tests/balance_test.gd
# godot --headless -s tests/rng_test.gd
# godot --headless -s tests/av_event_test.gd
# godot --headless -s tests/motion_test.gd
# godot --headless -s tests/flow_test.gd

echo "All suites passed."
