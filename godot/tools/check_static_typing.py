#!/usr/bin/env python3
"""Verify every GDScript function signature carries types.

CONSTRAINTS §3 Language and style requires static typing on every function
signature. gdlint cannot enforce this — it ships no typing rules at all
(`gdlint --dump-default-config` lists none), so naming it as the gate left the
constraint unenforced. This is that gate.

Checks every `func` in the scanned files for:
  - a return type (`-> Type`)
  - a type on every parameter (`name: Type`)

Parameters with a default that makes the type unambiguous to a reader still
need the annotation; GDScript infers them, but the constraint is about the
signature being readable without inference.

Deliberately break it by removing a `-> void` or a parameter annotation.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCAN = [ROOT / "godot" / "scripts", ROOT / "godot" / "tests"]

# templates/ ships intentionally incomplete example suites
SKIP_PARTS = {"templates", ".venv", ".godot"}

# [ \t]* not \s* — \s matches newlines, which drags match.start() back over
# preceding blank lines and reports the wrong line number.
FUNC = re.compile(r"^[ \t]*(?:static[ \t]+)?func[ \t]+(\w+)[ \t]*\((.*?)\)[ \t]*(->[ \t]*[\w\[\], ]+)?[ \t]*:", re.M)


def param_untyped(params: str) -> list[str]:
    bad = []
    depth = 0
    current = ""
    parts = []
    for ch in params:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(current)
            current = ""
        else:
            current += ch
    if current.strip():
        parts.append(current)
    for part in parts:
        name = part.split("=")[0].strip()
        if not name:
            continue
        if ":" not in name:
            bad.append(name)
    return bad


def main() -> int:
    files = []
    for root in SCAN:
        if not root.exists():
            continue
        for path in sorted(root.rglob("*.gd")):
            if SKIP_PARTS & set(path.parts):
                continue
            files.append(path)

    if not files:
        print("error: no GDScript files found to check — the layout changed and "
              "this checker is now inspecting nothing", file=sys.stderr)
        return 1

    failures = []
    checked = 0
    for path in files:
        text = path.read_text()
        for match in FUNC.finditer(text):
            checked += 1
            name, params, ret = match.group(1), match.group(2), match.group(3)
            line = text.count("\n", 0, match.start()) + 1
            rel = path.relative_to(ROOT)
            if ret is None:
                failures.append(f"{rel}:{line}: func {name}() has no return type")
            for p in param_untyped(params):
                failures.append(f"{rel}:{line}: func {name}() parameter '{p}' has no type")

    if failures:
        for f in failures:
            print(f"static typing: {f}", file=sys.stderr)
        print(f"\nstatic typing: {len(failures)} untyped signature(s) in "
              f"{checked} functions", file=sys.stderr)
        return 1

    print(f"static typing: {checked} function signatures fully typed across "
          f"{len(files)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
