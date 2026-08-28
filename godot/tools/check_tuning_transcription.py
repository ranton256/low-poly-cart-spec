#!/usr/bin/env python3
"""Verify godot/data/tuning.json against the design document's constant tables.

The design document's central discipline is that every number lives in exactly
one table row and scenarios refer to it by name. tuning.json is the single
transcription of those tables, so a drifted, renamed, or missing key silently
forks the contract — and nothing else in the suite would notice.

Checks, against the four tables under "# Tuning Constants":
  1. Every backticked `name` in a leftmost table cell is present.
  2. No key is renamed — anything outside the named set must be declared in
     the unnamed_in_spec group, which exists for table rows the document does
     not name.
  3. Derived quantities stay out. The document lists steady-state speeds and
     the collision velocity result as NOT independently tunable; transcribing
     them invites two sources of truth that disagree after a retune.

To re-verify after a design-document change, run this. To deliberately break
it and confirm it works, rename a key in tuning.json.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GDD = ROOT / "low-poly-cart-game-design-document.md"
TUNING = ROOT / "godot" / "data" / "tuning.json"

DERIVED_MARKERS = ("steadyState", "steady_state", "collisionVelocity")


def named_constants(text: str) -> list[str]:
    section = text.split("# Tuning Constants")[1].split("# Acceptance Checklist")[0]
    names = []
    for line in section.splitlines():
        if not line.startswith("|"):
            continue
        first_cell = line.split("|")[1].strip()
        for match in re.findall(r"`([A-Za-z][A-Za-z0-9]*)`", first_cell):
            if match != "name":
                names.append(match)
    return names


def table_values(text: str) -> dict:
    """Leading numeric magnitude from each single-name row's value cell.

    Only rows naming exactly one constant are usable: a row like
    `gridSize` / `gridDivisions` carries two numbers in one cell and cannot be
    attributed without guessing. Those are reported as unattributable rather
    than silently skipped, so the count is visible and cannot quietly drift to
    zero. Magnitude only — the document writes friction as "x0.96 per tick" and
    bounceFactor as "x-0.3", so the sign is prose, not data.
    """
    section = text.split("# Tuning Constants")[1].split("# Acceptance Checklist")[0]
    values, unattributable = {}, []
    for line in section.splitlines():
        if not line.startswith("|"):
            continue
        cells = line.split("|")
        if len(cells) < 4:
            continue
        first, value_cell = cells[1].strip(), cells[2].strip()
        names = [m for m in re.findall(r"`([A-Za-z][A-Za-z0-9]*)`", first) if m != "name"]
        if len(names) != 1:
            if names:
                unattributable.extend(names)
            continue
        number = re.search(r"(\d+(?:\.\d+)?)", value_cell.replace("x", "").replace("\u00d7", ""))
        if number:
            values[names[0]] = float(number.group(1))
    return {"values": values, "unattributable": sorted(set(unattributable))}


def main() -> int:
    if not GDD.exists():
        print(f"error: design document not found at {GDD}", file=sys.stderr)
        return 1
    if not TUNING.exists():
        print(f"error: tuning file not found at {TUNING}", file=sys.stderr)
        return 1

    names = named_constants(GDD.read_text())
    if not names:
        print("error: no named constants found in the design document — the "
              "table format changed and this checker is now inspecting nothing",
              file=sys.stderr)
        return 1

    tuning = json.loads(TUNING.read_text())

    # A LIST, not a set. The design document requires each constant to appear
    # exactly once; collecting into a set made a constant duplicated across two
    # groups invisible, so "present exactly once" had no enforcement.
    occurrences = [
        (group, key)
        for group, values in tuning.items()
        if not group.startswith("_")
        for key in values
        if not key.startswith("_")
    ]
    present = {key for _, key in occurrences}
    unnamed = {k for k in tuning.get("unnamed_in_spec", {}) if not k.startswith("_")}

    failures = []

    missing = [n for n in names if n not in present]
    if missing:
        failures.append(f"{len(missing)} named constant(s) missing from tuning.json: "
                        + ", ".join(missing))

    seen = {}
    duplicated = []
    for group, key in occurrences:
        if key in seen:
            duplicated.append(f"{key} appears in both '{seen[key]}' and '{group}'")
        else:
            seen[key] = group
    if duplicated:
        failures.append(f"{len(duplicated)} constant(s) transcribed more than once: "
                        + "; ".join(duplicated))

    renamed = sorted(present - set(names) - unnamed)
    if renamed:
        failures.append(f"{len(renamed)} key(s) in tuning.json are not named in the "
                        f"design document and are not declared unnamed_in_spec: "
                        + ", ".join(renamed))

    blob = json.dumps(tuning)
    leaked = [m for m in DERIVED_MARKERS if m in blob]
    if leaked:
        failures.append("derived quantities transcribed as if tunable: " + ", ".join(leaked))

    # Values, not just names. CONSTRAINTS §3 Language and style makes tuning.json the only file
    # allowed to hold the numbers, so the numbers are exactly what needs a gate.
    table = table_values(GDD.read_text())
    flat = {
        key: val
        for group, values in tuning.items()
        if not group.startswith("_")
        for key, val in values.items()
        if not key.startswith("_") and isinstance(val, (int, float))
    }
    drifted = []
    for name, expected in table["values"].items():
        if name not in flat:
            continue
        if abs(abs(flat[name]) - expected) > 1e-9:
            drifted.append(f"{name} is {flat[name]} but the document says {expected}")
    if drifted:
        failures.append("value(s) drifted from the design document: " + "; ".join(drifted))

    if failures:
        for f in failures:
            print(f"tuning: {f}", file=sys.stderr)
        return 1

    print(f"tuning: {len(names)} named constants transcribed, "
          f"{len(table['values'])} values checked against the document "
          f"({len(table['unattributable'])} multi-name rows not attributable), "
          f"{len(unnamed)} unnamed table rows, {len(occurrences)} entries each appearing once, no derived values")
    return 0


if __name__ == "__main__":
    sys.exit(main())
