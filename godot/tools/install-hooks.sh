#!/usr/bin/env bash
# Point git's hooks at the committed ones, so a hook is reviewable like source.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
ln -sf ../../godot/tools/pre-commit .git/hooks/pre-commit
chmod +x godot/tools/pre-commit
echo "installed: .git/hooks/pre-commit -> godot/tools/pre-commit"
