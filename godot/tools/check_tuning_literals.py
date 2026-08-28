#!/usr/bin/env python3
"""Refuse a tuning value written as a literal outside godot/data/tuning.json.

CONSTRAINTS §3 Language and style: every tuning constant is referred to by the
design document's name, never by its value. The design document's central
discipline is that every number lives in exactly one table row; a literal in a
script silently forks that contract, and retuning then changes behaviour in one
place and not the other.

THIS GATE IS EASY TO MAKE USELESS. Flag too much and everyone allowlists
reflexively; flag too little and it guards nothing. The first version searched
every value everywhere and produced 20 hits on a tree with no game code in it —
`format=3` in a scene header matched minPropSeparation, loop bounds matched
startClearance. Narrowed on two axes (design D3):

  - SCOPE: godot/scripts/ only. That is where game logic lives and where a
    hardcoded constant actually forks the contract. Tests legitimately contain
    magic numbers as expected values; scenes contain format versions and node
    counts; tools are not the game.
  - VALUES: integers with |value| < 10 are NOT searched. Every small integer
    collides with indices, counts, axis selectors and loop bounds — this is not
    limited to 0/1/-1. They are printed each run with the constants they belong
    to, so the exclusion stays visible rather than assumed.

What survives is the set that matters and is unlikely to be coincidental:
accel 0.008, friction 0.96, turnRate 0.04, steerThreshold 0.01, and the extents.
  - A hit must be removed, or exempted by an entry in
    godot/data/tuning_literal_allowlist.json carrying file, value and a written
    reason. An entry without a reason fails.
  - A stale exemption — one that no longer matches anything — fails, so the
    allowlist cannot quietly accumulate.

Deliberately break it by writing 0.96 into a .gd file.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = ROOT / "godot"
TUNING = GODOT / "data" / "tuning.json"
ALLOWLIST = GODOT / "data" / "tuning_literal_allowlist.json"

SCAN_SUFFIXES = (".gd",)
SCAN_ROOTS = ("scripts",)
SKIP_PARTS = {"templates", ".godot", ".venv", "__pycache__", "data"}

# Integers below this magnitude are indistinguishable from indices, counts,
# axis selectors and loop bounds. Printed every run so the exclusion is visible.
SMALL_INTEGER_LIMIT = 10


def collect(node, prefix=""):
    out = {}
    if isinstance(node, dict):
        for key, value in node.items():
            if key.startswith("_"):
                continue
            out.update(collect(value, f"{prefix}.{key}" if prefix else key))
    elif isinstance(node, (int, float)) and not isinstance(node, bool):
        out[prefix] = float(node)
    return out


def main() -> int:
    if not TUNING.exists():
        print(f"error: {TUNING} is missing", file=sys.stderr)
        return 1
    constants = collect(json.loads(TUNING.read_text()))
    if not constants:
        print("error: no numeric constants found in tuning.json — the format "
              "changed and this gate is searching for nothing", file=sys.stderr)
        return 1

    searchable, unsearchable = {}, {}
    for name, value in constants.items():
        is_small_int = value == int(value) and abs(value) < SMALL_INTEGER_LIMIT
        (unsearchable if is_small_int else searchable)[name] = value

    # Guard on what is actually SEARCHED. An earlier guard tested the total
    # constant count, so a tuning table of nothing but small integers left the
    # gate reporting "0 values searched" and exiting 0 — passing while guarding
    # nothing, which is the defect class this change exists to close.
    if not searchable:
        print(f"error: none of the {len(constants)} tuning constants are "
              f"searchable (all excluded as small integers) — this gate is "
              f"looking for nothing", file=sys.stderr)
        return 1

    allow = []
    if ALLOWLIST.exists():
        allow = json.loads(ALLOWLIST.read_text()).get("exemptions", [])

    failures, unreasoned = [], []
    for i, entry in enumerate(allow):
        if not str(entry.get("reason", "")).strip():
            unreasoned.append(f"entry {i} for {entry.get('file', '?')} "
                              f"value {entry.get('value', '?')} has no reason")

    files = []
    for root_name in SCAN_ROOTS:
        root = GODOT / root_name
        if not root.exists():
            continue
        files.extend(p for p in sorted(root.rglob("*"))
                     if p.suffix in SCAN_SUFFIXES and not (SKIP_PARTS & set(p.parts)))
    if not files:
        print(f"error: no GDScript found under godot/{'/, godot/'.join(SCAN_ROOTS)}/ "
              f"— the layout changed and this gate is inspecting nothing",
              file=sys.stderr)
        return 1

    # Group constants by value: 0.2 is both maxSpeed and hitboxContraction, and
    # reporting one hit twice reads as two problems.
    by_value = {}
    for name, value in searchable.items():
        by_value.setdefault(abs(value), []).append(name)

    # Parse every numeric token and compare NUMERICALLY, rather than matching the
    # value's string form. Text matching let 0.960, .96 and 9.6e-1 all past the
    # gate for friction=0.96.
    #
    # KNOWN LIMITS, stated rather than implied:
    #   96.0 / 100.0   an expression — needs evaluation, not matching
    #   0x3E8          hex literal form, not matched by NUMBER below
    #   1_000.0        GDScript's underscore separator, likewise
    #   "…#…"          a '#' inside a string ends the line for this gate, so a
    #                  literal after it is unseen. Same trade-off documented in
    #                  check_boundaries.py, and it errs toward missing, never
    #                  toward a false positive.
    NUMBER = re.compile(r"(?<![\w.])(\d+\.\d*|\.\d+|\d+)(?:[eE][+-]?\d+)?(?![\w.])")

    used_exemptions = set()
    hits = []

    for path in files:
        rel = str(path.relative_to(ROOT))
        text = path.read_text(encoding="utf-8", errors="replace")
        for lineno, line in enumerate(text.split("\n"), 1):
            code = line.split("#", 1)[0]
            for m in NUMBER.finditer(code):
                try:
                    found = abs(float(m.group(0)))
                except ValueError:
                    continue
                for value, names in by_value.items():
                    if abs(found - value) > 1e-12:
                        continue
                    literal = f"{value:g}"
                    # Compare magnitudes deliberately: the scan itself works on
                    # abs(), so bounceFactor -0.3 and pushDistance 0.3 are one
                    # value here. An exemption therefore covers both signs, which
                    # the allowlist _meta states.
                    exempt = next((j for j, e in enumerate(allow)
                                   if e.get("file") == rel
                                   and abs(abs(float(e.get("value", "nan"))) - value) < 1e-12), None)
                    if exempt is not None:
                        used_exemptions.add(exempt)
                        continue
                    hits.append(f"{rel}:{lineno}: literal {m.group(0)} is the tuning "
                                f"constant {' / '.join(sorted(names))} ({literal}) "
                                f"— refer to it by name")

    stale = [f"entry {i} ({e.get('file')} value {e.get('value')}) matches nothing"
             for i, e in enumerate(allow) if i not in used_exemptions]

    if unreasoned:
        failures.append("allowlist entries without a reason:\n  " + "\n  ".join(unreasoned))
    if hits:
        failures.append(f"{len(hits)} tuning literal(s):\n  " + "\n  ".join(hits))
    if stale:
        failures.append("stale allowlist entries:\n  " + "\n  ".join(stale))

    if failures:
        for f in failures:
            print(f"tuning literals: {f}", file=sys.stderr)
        return 1

    note = ""
    if unsearchable:
        note = (f"; {len(unsearchable)} not searchable (small integers): "
                + ", ".join(f"{n}={v:g}" for n, v in sorted(unsearchable.items())))
    print(f"tuning literals: {len(searchable)} values searched across {len(files)} "
          f"files, 0 hits, {len(used_exemptions)} exemption(s){note}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
