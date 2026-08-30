#!/usr/bin/env bash
# §14 phase 1: all four targets, one commit.
#
#   tools/export_all.sh [--allow-dirty]
#
# Refuses a dirty tree without the flag, because "built from the same commit"
# is the phase's whole claim — an artifact nobody can rebuild from a hash is
# not a release. Prints the commit, then per-target size and SHA-256.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "${1:-}" != "--allow-dirty" ] && [ -n "$(git status --porcelain)" ]; then
	echo "export_all: the tree is dirty — commit first, or pass --allow-dirty for a trial run" >&2
	exit 1
fi

echo "export_all: HEAD $(git rev-parse HEAD)$(git status --porcelain | grep -q . && echo ' (DIRTY TRIAL)')"

rm -rf build
mkdir -p build/web build/macos build/linux build/windows

godot --headless --export-release "Web" build/web/index.html
godot --headless --export-release "macOS" build/macos/LowPolyCart.app
godot --headless --export-release "Linux" build/linux/lowpolycart.x86_64
godot --headless --export-release "Windows" build/windows/lowpolycart.exe

echo
echo "export_all: artifacts"
for f in build/web/index.wasm build/web/index.pck build/macos/LowPolyCart.app \
	build/linux/lowpolycart.x86_64 build/linux/lowpolycart.pck \
	build/windows/lowpolycart.exe build/windows/lowpolycart.pck; do
	if [ -d "$f" ]; then
		du -sh "$f" | awk '{printf "  %-36s %s (bundle)\n", FILENAME, $1}' FILENAME="$f"
	elif [ -f "$f" ]; then
		printf "  %-36s %8s  sha256 %s\n" "$f" "$(du -h "$f" | cut -f1)" "$(shasum -a 256 "$f" | cut -d' ' -f1)"
	fi
done
