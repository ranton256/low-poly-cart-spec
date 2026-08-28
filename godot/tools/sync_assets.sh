#!/usr/bin/env bash
# Copy the supplied models from the repository-root assets/ into the Godot
# project, so res:// can reach them.
#
# WHY A COPY AND NOT A SYMLINK. Git only materialises symlinks on Windows with
# core.symlinks=true AND Developer Mode; without both, a checkout produces a
# text file containing a path and the project silently has no art. Windows is a
# shipping target. See design D2 in
# openspec/changes/add-godot-project-foundations/design.md.
#
# The .glb files here are git-ignored working copies — the models are
# single-sourced at assets/ in the repository root. The .import presets Godot
# generates beside them ARE committed, so a fresh clone imports with the same
# settings rather than whatever the editor picks that day.
#
# Content hashes, not timestamps: a checkout, a rebase, or a `touch` all move
# mtimes without changing bytes, and a stale copy that looks fresh is the
# failure this script exists to prevent.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="../assets"
DST="assets"

# The seven the design document's §1 inventory names. Listed explicitly so a
# missing model is an error rather than a quietly smaller world.
MODELS=(kart tree rock cone crate tires cottage)

if [ ! -d "$SRC" ]; then
	echo "error: shared asset directory not found at $(cd .. && pwd)/assets" >&2
	echo "       The models are committed at the repository root; check out the repo fully." >&2
	exit 1
fi

mkdir -p "$DST"

copied=0
unchanged=0
missing=()

for name in "${MODELS[@]}"; do
	src="$SRC/$name.glb"
	dst="$DST/$name.glb"

	if [ ! -f "$src" ]; then
		missing+=("$name.glb")
		continue
	fi

	if [ -f "$dst" ] && [ "$(shasum -a 256 <"$src" | cut -d' ' -f1)" = "$(shasum -a 256 <"$dst" | cut -d' ' -f1)" ]; then
		unchanged=$((unchanged + 1))
		continue
	fi

	cp "$src" "$dst"
	copied=$((copied + 1))
done

if [ ${#missing[@]} -gt 0 ]; then
	echo "error: ${#missing[@]} of ${#MODELS[@]} models missing from $SRC:" >&2
	printf '       %s\n' "${missing[@]}" >&2
	echo "       Every model in the design document's §1 inventory must be present." >&2
	exit 1
fi

# A failed import POISONS the committed preset. Godot writes valid=false into
# assets/<name>.glb.import and does not repair it when the source is fixed, so a
# developer who hits one transient bad sync can commit a preset that makes every
# later clone fail. Cheap to detect, expensive to debug.
poisoned=$(grep -l "valid=false" "$DST"/*.glb.import 2>/dev/null || true)
if [ -n "$poisoned" ]; then
	echo "error: import preset(s) record a FAILED import:" >&2
	printf '       %s\n' $poisoned >&2
	echo "       Godot will not repair these. Delete them and re-run:" >&2
	echo "           rm $poisoned && rm -rf .godot && godot --headless --import" >&2
	exit 1
fi

echo "assets: $unchanged unchanged, $copied copied ($((unchanged + copied)) of ${#MODELS[@]})"
