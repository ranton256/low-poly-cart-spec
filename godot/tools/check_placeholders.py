#!/usr/bin/env python3
"""Report TODO placeholders left in the project's own documents.

This skeleton ships VISION, ROADMAP, CONSTRAINTS, GLOSSARY and CLAUDE.md as
WORKED templates: real structure, the genuinely universal content already
written, and marked placeholders everywhere the project must decide for itself.

That is more useful than empty stubs and more dangerous. A document that still
says "TODO: what we will not build" is not merely incomplete — it is a document
that lies to whoever reads it next, and it lies with the authority of a
committed file.

So: this tool is deliberately NOT wired into tools/test.sh, because the
skeleton itself would fail its own gate on the first commit. Uncomment the line
in test.sh once you have filled the templates in. From that point on it fails
the build if a placeholder comes back.

    .venv/bin/python tools/check_placeholders.py            # report
    .venv/bin/python tools/check_placeholders.py --strict   # exit 1 if any
"""

import os
import re
import sys

# No directory walk here — WATCHED is an explicit list, so there is nothing to
# prune. (An earlier SKIP_DIRS constant was dead code and has been removed.)

# Documents whose placeholders matter. Source files may legitimately carry TODOs
# for future work; a shipped design document may not.
# Paths are relative to the REPOSITORY root, not the Godot project: the
# governing documents live above godot/, and the port's own live inside it.
# This project has no VISION.md — CONSTRAINTS §1 Repository shape Repository shape and the
# design document together carry what one would say.
WATCHED = (
    "CONSTRAINTS.md",
    "ROADMAP.md",
    "README.md",
    os.path.join("openspec", "config.yaml"),
    os.path.join("godot", "CLAUDE.md"),
    os.path.join("godot", "docs", "GLOSSARY.md"),
    os.path.join("godot", "docs", "testing_toolkit.md"),
    os.path.join("godot", "docs", "progress", "README.md"),
    os.path.join("godot", "requirements.txt"),
    os.path.join("godot", "GOTCHAS.md"),
    os.path.join("godot", "docs", "AMBIGUITIES.md"),
)

MARKER = re.compile(r"\bTODO\b")


def check(root: str, strict: bool) -> int:
    total = 0
    for rel in WATCHED:
        path = os.path.join(root, rel)
        if not os.path.exists(path):
            print(f"placeholders: {rel} is missing entirely", file=sys.stderr)
            total += 1
            continue
        with open(path, encoding="utf-8") as handle:
            for number, line in enumerate(handle, 1):
                if MARKER.search(line):
                    print(f"{rel}:{number}: {line.strip()[:100]}")
                    total += 1

    if total == 0:
        print("placeholders: none remaining")
        return 0

    print(f"\nplaceholders: {total} remaining", file=sys.stderr)
    if strict:
        print("These documents are committed and are read as authoritative.", file=sys.stderr)
        return 1
    print("Run with --strict once these are filled in, and enable it in test.sh.")
    return 0


if __name__ == "__main__":
    strict = "--strict" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    root = args[0] if args else os.path.join(os.path.dirname(__file__), "..", "..")
    sys.exit(check(root, strict))
