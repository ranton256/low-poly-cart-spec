#!/usr/bin/env python3
"""Check a generated field against the DESIGN DOCUMENT, not against our own data.

tests/scatter_test.gd drives the generator with synthetic boxes and reads its
expectations from tuning.json — the same file the generator reads. That is the
right test for the placement arithmetic and it cannot catch a transcription that
misread the document, because both sides share a source.

This reads the populations table out of "Scattering the standard prop population"
and the rules out of "Rejecting a candidate placement", generates a field from the
six real models, and compares. The two sides have no common ancestor.

Same pattern as tools/check_kart_conformance.py, and the same reason.

  tools/check_scatter_conformance.py

Runs headless and needs no renderer, so it belongs in tools/test.sh.
"""
import json
import re
import subprocess
import sys
from math import hypot
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = ROOT / "godot"
GDD = ROOT / "low-poly-cart-game-design-document.md"
MEASURE = "tools/measure_scatter.gd"

POPULATION_SCENARIO = "### Scenario: Scattering the standard prop population"
REJECTION_SCENARIO = "### Scenario Outline: Rejecting a candidate placement"
EXPECTED_ASSETS = 6

# Placements are floats through a scale and a square root, so exact equality is
# the wrong test for a distance. One part in a million of a world unit is far
# tighter than any rule here and far looser than float noise.
DISTANCE_TOLERANCE = 1e-6
# The design document requires every instance to rest exactly at Y = 0
# (acceptance item 2). "Exactly" is meant, so this is the arithmetic's own limit.
GROUND_TOLERANCE = 1e-6


def section(text: str, heading: str) -> str:
    if heading not in text:
        return ""
    return re.split(r"\n### ", text.split(heading)[1])[0]


def populations(text: str) -> dict:
    """asset -> (count, target height, clearance radius), from the document."""
    out = {}
    for line in section(text, POPULATION_SCENARIO).splitlines():
        match = re.match(
            r"\s*\|\s*`(\w+)`\s*\|\s*(\d+)\s*\|\s*([\d.]+)\s*\|\s*([\d.]+)\s*\|", line
        )
        if match:
            out[match.group(1)] = (
                int(match.group(2)),
                float(match.group(3)),
                float(match.group(4)),
            )
    return out


def named_rule_constants(text: str) -> set:
    """The constants the rejection rules name, so a reworded rule is visible.

    The rules are prose, not a table, and the values they refer to live in the
    Tuning Constants tables where check_tuning_transcription.py already compares
    them. What matters here is that the rules still NAME those constants: if the
    document starts rejecting on something else, this gate is checking a rule the
    document no longer states.
    """
    # ONLY THE EXAMPLES TABLE, not the whole section. The scenario is followed by an
    # explanatory paragraph that also mentions cottageClearance and startClearance,
    # so scanning the section let a rule row be stripped while the gate still found
    # the names in the prose below it — review demonstrated it passing that way. The
    # rules live in table rows; those are what this reads.
    rows = [
        line
        for line in section(text, REJECTION_SCENARIO).splitlines()
        if line.strip().startswith("|")
    ]
    return set(re.findall(r"`(\w+)`", "\n".join(rows)))


def measure() -> dict:
    result = subprocess.run(
        ["godot", "--headless", "-s", MEASURE], cwd=GODOT, capture_output=True, text=True
    )
    for line in result.stdout.splitlines():
        if line.strip().startswith("{"):
            return json.loads(line.strip())
    print("error: measure_scatter.gd produced no JSON", file=sys.stderr)
    print(result.stdout, result.stderr, file=sys.stderr)
    return {}


def main() -> int:
    if not GDD.exists():
        print(f"error: design document not found at {GDD}", file=sys.stderr)
        return 1
    text = GDD.read_text()

    wanted = populations(text)
    if len(wanted) != EXPECTED_ASSETS:
        print(f"error: expected {EXPECTED_ASSETS} assets under "
              f"{POPULATION_SCENARIO!r}, read {len(wanted)} — the table changed "
              f"shape and this gate is no longer reading the document",
              file=sys.stderr)
        return 1

    rules = named_rule_constants(text)
    for constant in ("startClearance", "cottageClearance", "minPropSeparation"):
        if constant not in rules:
            print(f"error: {REJECTION_SCENARIO!r} no longer names {constant!r} — the "
                  f"rules this gate checks are not the rules the document states",
                  file=sys.stderr)
            return 1

    field = measure()
    if not field:
        return 1

    failures = []
    placements = field["placements"]

    # Counts, against the document's table.
    for asset, (count, _height, _clearance) in wanted.items():
        got = field["achieved"].get(asset, 0)
        if got != count:
            failures.append(f"{asset}: placed {got}, the document asks for {count}")

    # Clearance from the origin, per asset, against the document's own column.
    for placement in placements:
        asset = placement["asset"]
        if asset not in wanted:
            failures.append(f"placed a {asset!r}, which the document's table does not list")
            continue
        clearance = wanted[asset][2]
        distance = hypot(placement["x"], placement["z"])
        if distance < clearance - DISTANCE_TOLERANCE:
            failures.append(
                f"{asset} sits {distance:.4f} from the origin, inside its stated "
                f"clearance of {clearance}"
            )

    # Acceptance item 2, on the real models rather than synthetic boxes.
    for placement in placements:
        if abs(placement["lowest"]) > GROUND_TOLERANCE:
            failures.append(
                f"{placement['asset']} at scale {placement['scale']:.4f} rests at "
                f"{placement['lowest']:.9f}, not at ground level"
            )

    # Registration order: the document's table order, contiguous per asset. The
    # next change resolves collisions by this.
    #
    # FROM THE DOCUMENT, not from the port's own constant. This line used to read
    # `[a for a in field["emitted_order"] if a in wanted]`, and `field["emitted_order"]` is
    # Scatter.ASSET_ORDER — so the check compared the port against itself, passed
    # on any permutation of the six assets, and reported it as document-conformant
    # while this file's docstring claimed the two sides shared no ancestor.
    # populations() returns an insertion-ordered dict built from the document's
    # table, so its key order IS the document's order.
    document_order = list(wanted)
    seen = []
    for placement in placements:
        if not seen or seen[-1] != placement["asset"]:
            if placement["asset"] in seen:
                failures.append(f"{placement['asset']}'s placements are not contiguous")
                break
            seen.append(placement["asset"])
    if seen != [a for a in document_order if a in seen]:
        failures.append(f"assets are emitted as {seen}, the document's table order is "
                        f"{document_order}")

    if failures:
        for f in failures[:12]:
            print(f"scatter: {f}", file=sys.stderr)
        if len(failures) > 12:
            print(f"scatter: ... and {len(failures) - 12} more", file=sys.stderr)
        print(f"\nscatter: {len(failures)} conformance problem(s)", file=sys.stderr)
        return 1

    summary = ", ".join(f"{a} {field['achieved'][a]}" for a in document_order)
    print(
        f"scatter: seed {field['seed']} placed {len(placements)} props ({summary}) — "
        f"counts, clearances, grounding and order all checked against the design "
        f"document, not against tuning.json"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
