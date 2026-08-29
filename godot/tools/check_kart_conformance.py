#!/usr/bin/env python3
"""Check the built kart against the DESIGN DOCUMENT, not against our own data.

Every other numeric gate in this project bottoms out in godot/data/tuning.json,
which is this port's transcription of the document. That is the right check for
values check_tuning_transcription.py already compares against their source — but
it cannot catch a transcription that misread the document, because the scene and
the test read the same file.

The kart is the one place where the document states the ANSWER as well as the
inputs: section 1 gives its authored bounding box, and section 3 gives the final
dimensions and the world footprint the normalisation contract must produce. Those
are the document's numbers. This gate reads them from the document and compares
them against what Godot actually built, so the two sides have no common ancestor.

  tools/check_kart_conformance.py

Runs headless and needs no renderer, so it belongs in tools/test.sh.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = ROOT / "godot"
GDD = ROOT / "low-poly-cart-game-design-document.md"
MEASURE = "tools/measure_kart.gd"

INVENTORY_SECTION = "### 1. Supplied model inventory"
NORMALISATION_SECTION = "### 3. Asset normalisation contract"
ORIENTATION_SECTION = "### 4. Kart orientation contract"

# The document writes its authored boxes to three decimals and its final
# dimensions to two, so the comparison is at the precision the document states —
# not tighter, which would fail on the document's own rounding, and not looser.
AUTHORED_TOLERANCE = 0.0005
FINAL_TOLERANCE = 0.005


def section(text: str, heading: str) -> str:
    if heading not in text:
        return ""
    return re.split(r"\n### ", text.split(heading)[1])[0]


def authored_box(text: str) -> list:
    """The kart's authored dimensions from the section 1 inventory table."""
    for line in section(text, INVENTORY_SECTION).splitlines():
        match = re.match(
            r"\|\s*`kart`\s*\|[^|]*\|[^|]*\|\s*([\d.]+)\s*×\s*([\d.]+)\s*×\s*([\d.]+)\s*\|",
            line,
        )
        if match:
            return [float(g) for g in match.groups()]
    return []


def final_dimensions(text: str) -> dict:
    """Target height and final footprint from the section 3 table, plus the world
    extents the section's prose states for the kart standing at the start line.

    The prose figures matter as much as the table's: they are the document
    saying, in world axes, what the table says in mesh-local ones, and getting
    the yaw correction backwards transposes exactly those two numbers while
    leaving the table's own figures correct.
    """
    body = section(text, NORMALISATION_SECTION)
    out = {}
    for line in body.splitlines():
        match = re.match(
            r"\|\s*`kart`\s*\|\s*([\d.]+)\s*\|[^|]*\|\s*([\d.]+)\s*\|"
            r"\s*([\d.]+)\s*×\s*([\d.]+)\s*\|",
            line,
        )
        if match:
            out["target_height"] = float(match.group(1))
            out["final_height"] = float(match.group(2))
            out["footprint"] = [float(match.group(3)), float(match.group(4))]
    world = re.search(
        r"\*\*([\d.]+) wu on X and ([\d.]+) wu on Z\*\*|"
        r"\*\*([\d.]+) wu across world X and ([\d.]+) wu along world Z\*\*",
        body,
    )
    if world:
        groups = [g for g in world.groups() if g is not None]
        out["world_extent"] = [float(groups[0]), float(groups[1])]
    return out


def stated_correction(text: str) -> float:
    """The yaw correction section 4 states, in degrees.

    Read and CHECKED, never transcribed into the code. Ambiguity A6 records why
    the figure could not simply be copied: it is stated in the reference build's
    frame, and this engine's differs, so the port derives its own correction from
    the imported bounds. Having done that independently, the two agreeing is a
    fact worth pinning — and if they ever diverge, that is A6 reopening and needs
    to be loud rather than silent.

    It is also, as it happens, the only automated check that notices a nose sign
    wrong by half a turn: the 16-heading travel test derives the nose from the
    same constant it tests, and the footprint is unchanged by a 180 degree turn.
    """
    body = section(text, ORIENTATION_SECTION)
    match = re.search(r"\*\*([+-]?\d+)°\s+yaw correction", body)
    return float(match.group(1)) if match else None


def measure() -> dict:
    result = subprocess.run(
        ["godot", "--headless", "-s", MEASURE],
        cwd=GODOT,
        capture_output=True,
        text=True,
    )
    for line in result.stdout.splitlines():
        line = line.strip()
        if line.startswith("{"):
            return json.loads(line)
    print("error: measure_kart.gd produced no JSON", file=sys.stderr)
    print(result.stdout, result.stderr, file=sys.stderr)
    return {}


def close(a: float, b: float, tolerance: float) -> bool:
    return abs(a - b) <= tolerance


def main() -> int:
    if not GDD.exists():
        print(f"error: design document not found at {GDD}", file=sys.stderr)
        return 1
    text = GDD.read_text()

    authored = authored_box(text)
    final = final_dimensions(text)
    if len(authored) != 3:
        print(f"error: could not read the kart's authored box from "
              f"{INVENTORY_SECTION!r} — the table changed shape and this gate is "
              f"no longer reading the document", file=sys.stderr)
        return 1
    for key in ("target_height", "final_height", "footprint", "world_extent"):
        if key not in final:
            print(f"error: could not read {key!r} from {NORMALISATION_SECTION!r} "
                  f"— this gate is no longer reading the document", file=sys.stderr)
            return 1

    built = measure()
    if not built:
        return 1

    failures = []

    for axis, want, got in zip("XYZ", authored, built["authored"]):
        if not close(want, got, AUTHORED_TOLERANCE):
            failures.append(f"authored {axis} is {got:.4f}, the document says {want}")

    if not close(final["final_height"], built["normalised"][1], FINAL_TOLERANCE):
        failures.append(f"final height is {built['normalised'][1]:.4f}, the document "
                        f"says {final['final_height']}")

    # The footprint, in the mesh-local axes the section 3 table uses.
    local = sorted([built["normalised"][0], built["normalised"][2]], reverse=True)
    want_local = sorted(final["footprint"], reverse=True)
    for want, got in zip(want_local, local):
        if not close(want, got, FINAL_TOLERANCE):
            failures.append(f"final footprint has {got:.4f} where the document says {want}")

    # THE ORIENTATION CHECK. In world axes at the start line the document is
    # explicit about which number goes on which axis, and a kart turned a quarter
    # turn has exactly these two transposed.
    want_x, want_z = final["world_extent"]
    got_x, got_z = built["world_extent"]
    if not close(want_x, got_x, FINAL_TOLERANCE) or not close(want_z, got_z, FINAL_TOLERANCE):
        transposed = close(want_x, got_z, FINAL_TOLERANCE) and close(want_z, got_x, FINAL_TOLERANCE)
        failures.append(
            f"world extent at the start line is {got_x:.4f} on X and {got_z:.4f} on Z; "
            f"the document says {want_x} on X and {want_z} on Z"
            + (" — those are TRANSPOSED, which is a kart turned a quarter turn"
               if transposed else "")
        )

    stated = stated_correction(text)
    if stated is None:
        failures.append(f"could not read the yaw correction from "
                        f"{ORIENTATION_SECTION!r} — this gate is no longer checking "
                        f"the sign against the document")
    elif not close(stated, built["yaw_correction_degrees"], 0.5):
        failures.append(
            f"the derived yaw correction is {built['yaw_correction_degrees']:+.1f} "
            f"degrees but the document states {stated:+.0f}. A difference of 180 is "
            f"a kart driving tail-first, which no other automated check here "
            f"notices; any other difference means the two frames have diverged and "
            f"ambiguity A6 needs reopening"
        )

    if not close(built["lowest_y"], 0.0, 1e-6):
        failures.append(f"the kart's lowest point is at {built['lowest_y']:.6f}, not ground level")

    if failures:
        for f in failures:
            print(f"kart: {f}", file=sys.stderr)
        print(f"\nkart: {len(failures)} conformance problem(s)", file=sys.stderr)
        return 1

    print(
        f"kart: authored {built['authored'][0]:.3f}x{built['authored'][1]:.3f}x"
        f"{built['authored'][2]:.3f}, scaled x{built['scale']:.5f} to "
        f"{final['final_height']} tall, world extent {built['world_extent'][0]:.2f} on X "
        f"and {built['world_extent'][1]:.2f} on Z, correction "
        f"{built['yaw_correction_degrees']:+.1f} deg — all checked against the design "
        f"document, not against tuning.json"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
