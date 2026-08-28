#!/usr/bin/env python3
"""Verify that every relative link in every Markdown file resolves.

Committed because it caught a real break: a GOTCHAS.md link that was correct at
the repo root and silently broke when its file moved into docs/. Nothing about
that failure was visible in a diff or a test run.

Game-agnostic. Copy verbatim; there is nothing to configure but SKIP_DIRS.

Checks relative link and image targets, and the file half of a #fragment link.
Skips absolute URLs and mailto:. Exits non-zero listing every break.

    python3 tools/check_links.py
"""

import os
import re
import sys

# Directories that are not ours to police: vendored, generated, or tool-owned.
SKIP_DIRS = {".git", ".godot", ".claude", ".cursor", ".agents", ".att", ".venv",
             "godot-game-skeleton", "exports", "gallery", "templates",
             "__pycache__", "node_modules"}

LINK = re.compile(r"!?\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


def is_external(target: str) -> bool:
    return target.startswith(("http://", "https://", "mailto:", "#"))


def find_markdown(root: str):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if name.endswith(".md"):
                yield os.path.join(dirpath, name)


def check(root: str) -> int:
    breaks = []
    checked = 0
    for path in sorted(find_markdown(root)):
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        for match in LINK.finditer(text):
            target = match.group(1)
            if is_external(target):
                continue
            checked += 1
            # A #fragment is not resolvable here; check the file half only.
            relative = target.split("#", 1)[0]
            if not relative:
                continue
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), relative))
            if not os.path.exists(resolved):
                line = text.count("\n", 0, match.start()) + 1
                breaks.append(f"{path}:{line}: {target} -> {resolved}")

    for entry in breaks:
        print(f"broken link: {entry}", file=sys.stderr)

    if breaks:
        print(f"\nlinks: {len(breaks)} of {checked} relative links are broken", file=sys.stderr)
        return 1

    print(f"links: {checked} relative links ok")
    return 0


if __name__ == "__main__":
    # The repository root, not the Godot project: CONSTRAINTS.md, ROADMAP.md,
    # the design document, and openspec/ all live one level above godot/.
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..")
    sys.exit(check(root))
