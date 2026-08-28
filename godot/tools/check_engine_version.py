#!/usr/bin/env python3
"""Verify the Godot version is recorded in exactly one place and agreed everywhere.

godot/.godot-version holds the full version this project is developed against.
It is the single source of truth, because project.godot CANNOT be one: Godot
stores only major.minor in config/features ("4.6"), so the patch version — the
part that actually differs between builds — is unrepresentable there.

Checks:
  1. .godot-version is a full major.minor.patch version.
  2. project.godot's config/features carries its major.minor, so the engine
     itself agrees with the file.
  3. No watched document states a DIFFERENT Godot version. Prose may say "Godot
     4.6" or "Godot 4.6.1"; it may not say "4.5" or "4.7".

Deliberately break it by editing .godot-version, or by writing a wrong version
into one of the watched documents.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERSION_FILE = ROOT / "godot" / ".godot-version"
PROJECT = ROOT / "godot" / "project.godot"

WATCHED = [
    "CONSTRAINTS.md",
    "ROADMAP.md",
    "openspec/config.yaml",
    "godot/CLAUDE.md",
    "godot/docs/testing_toolkit.md",
]

# "Godot 4.6", "Godot **4.6.1**", "Godot v4.6.1" — only where Godot is named, so
# a version-shaped number belonging to something else is not swept up.
MENTION = re.compile(r"Godot\s*\*{0,2}v?(\d+\.\d+(?:\.\d+)?)", re.I)


def main() -> int:
    if not VERSION_FILE.exists():
        print(f"error: {VERSION_FILE} is missing — it is the source of truth for "
              f"the engine version", file=sys.stderr)
        return 1

    declared = VERSION_FILE.read_text().strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", declared):
        print(f"engine version: .godot-version must be major.minor.patch, got "
              f"{declared!r}", file=sys.stderr)
        return 1
    series = ".".join(declared.split(".")[:2])

    failures = []

    features = re.search(r'config/features\s*=\s*PackedStringArray\(([^)]*)\)',
                         PROJECT.read_text())
    if not features:
        failures.append("project.godot has no config/features entry to check")
    elif f'"{series}"' not in features.group(1):
        failures.append(f'project.godot config/features does not carry "{series}" '
                        f'(from .godot-version {declared}): {features.group(1).strip()}')

    for rel in WATCHED:
        path = ROOT / rel
        if not path.exists():
            failures.append(f"{rel} is missing entirely")
            continue
        text = path.read_text()
        for match in MENTION.finditer(text):
            found = match.group(1)
            if found != declared and found != series:
                line = text.count("\n", 0, match.start()) + 1
                failures.append(f"{rel}:{line}: says Godot {found}, but "
                                f".godot-version is {declared}")

    if failures:
        for f in failures:
            print(f"engine version: {f}", file=sys.stderr)
        return 1

    print(f"engine version: {declared} in .godot-version, series {series} in "
          f"config/features, {len(WATCHED)} documents agree")
    return 0


if __name__ == "__main__":
    sys.exit(main())
