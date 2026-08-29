#!/usr/bin/env python3
"""Verify godot/data/tuning.json against the design document's constant tables.

The design document's central discipline is that every number lives in exactly
one table row and scenarios refer to it by name. tuning.json is the single
transcription of those tables, so a drifted, renamed, or missing key silently
forks the contract — and nothing else in the suite would notice.

Checks, against the four tables under "# Tuning Constants", the per-asset target
heights in "### 3. Asset normalisation contract", AND the environment and
lighting tables in sections 5 and 6:
  1. Every backticked `name` in a leftmost table cell is present.
  2. No key is renamed — anything outside the named set must be declared in
     the unnamed_in_spec group, which exists for table rows the document does
     not name.
  3. Derived quantities stay out. The document lists steady-state speeds and
     the collision velocity result as NOT independently tunable; transcribing
     them invites two sources of truth that disagree after a retune.

Sections 5 and 6 are prose-in-cells rather than name/value rows, so each value
is pulled by an explicit pattern naming where it comes from. That is deliberate:
a key nobody extracts is a key nobody checks, and an unchecked transcription
reads as coverage while being none. Every key in the environment and lighting
groups must be covered by an extractor or the white-word set, or this gate fails.

port_decisions is exempt BY DESIGN — those values are this port's, not the
document's, and checking them against it would be checking it against itself.

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
ENV_SECTION = "### 5. Environment art"
LIGHT_SECTION = "### 6. Lighting"

# Groups whose keys this port names because the design document names none.
# unnamed_in_spec came first, for unnamed rows in the four Tuning Constants
# tables; sections 5 and 6 name nothing at all.
PORT_NAMED_GROUPS = ("unnamed_in_spec", "environment", "lighting", "port_decisions")

# Keys the document specifies with the word "white" rather than a hex value.
# Checked separately: the document is confirmed to say white, and the
# transcription to say #FFFFFF. Neither half is assumed.
WHITE_KEYS = ("ambientColour", "sunColour", "bandColour")
# Which section states each one's "white". The band's is section 5's "flat unlit
# white quad"; the two lights are section 6's table.
WHITE_KEY_SECTIONS = {
    "ambientColour": LIGHT_SECTION,
    "sunColour": LIGHT_SECTION,
    "bandColour": ENV_SECTION,
}

# (key, section, pattern). One capture group each, except the sun position.
# Extracted from prose, so each pattern quotes enough of its sentence to be
# unambiguous — a looser pattern would match the first number in the table and
# drift silently when a neighbouring row is reworded.
ENV_LIGHT_PATTERNS = [
    ("skyColour", "env", r"Flat sky blue `(#[0-9A-Fa-f]{6})`"),
    ("fogColour", "env", r"Linear fog, colour `(#[0-9A-Fa-f]{6})`"),
    ("fogStart", "env", r"starting at (\d+(?:\.\d+)?) wu"),
    ("fogEnd", "env", r"fully opaque at (\d+(?:\.\d+)?) wu"),
    ("groundColour", "env", r"Grass green `(#[0-9A-Fa-f]{6})`"),
    ("groundRoughness", "env", r"roughness (\d+(?:\.\d+)?)"),
    ("groundMetalness", "env", r"metalness (\d+(?:\.\d+)?)"),
    ("gridHeight", "env", r"drawn (\d+(?:\.\d+)?) wu above the ground"),
    ("gridAxisColour", "env", r"Centre-axis lines `(#[0-9A-Fa-f]{6})`"),
    ("gridMinorColour", "env", r"minor lines `(#[0-9A-Fa-f]{6})`"),
    ("bandOpacity", "env", r"(\d+)% opaque"),
    ("ambientIntensity", "light", r"\|\s*Ambient\s*\|\s*white\s*\|\s*(\d+(?:\.\d+)?)\s*\|"),
    ("hemisphereSkyColour", "light", r"sky `(#[0-9A-Fa-f]{6})`"),
    ("hemisphereGroundColour", "light", r"ground `(#[0-9A-Fa-f]{6})`"),
    ("hemisphereIntensity", "light", r"\|\s*Hemisphere\s*\|[^|]*\|\s*(\d+(?:\.\d+)?)\s*\|"),
    ("sunIntensity", "light", r"\|\s*Directional[^|]*\|\s*white\s*\|\s*(\d+(?:\.\d+)?)\s*\|"),
    ("shadowMapSize", "light", r"(\d+)\s*\u00d7\s*\d+ shadow map"),
    ("shadowVolumeExtent", "light", r"\*\*\u00b1(\d+(?:\.\d+)?) wu\*\*"),
    ("shadowNear", "light", r"near (\d+(?:\.\d+)?) / far"),
    ("shadowFar", "light", r"near \d+(?:\.\d+)? / far (\d+(?:\.\d+)?)"),
    ("shadowDepthBias", "light", r"depth bias \(\u2248 [\u2212-](\d+(?:\.\d+)?)\)"),
]
SUN_POSITION_PATTERN = r"Positioned at \((\d+), (\d+), (\d+)\)"
# 21 patterns + 3 sun-position components. Guards against a reworded document
# quietly reducing what this gate inspects.
EXPECTED_ENV_LIGHT_COUNT = 24
ASSET_SECTION = "### 3. Asset normalisation contract"
# The design document's §1 inventory and §3 table both list seven models.
EXPECTED_ASSET_COUNT = 7


def asset_target_heights(text: str) -> dict:
    """Per-asset target heights from the design document's section 3 table.

    A FIFTH source of named constants, outside the four Tuning Constants tables.
    Added when add-asset-normalisation-contract transcribed these values: a gate
    that silently ignores newly added data is worse than no gate, because it
    reads as coverage. If this section is ever renamed, the empty result trips
    the guard in main() rather than passing quietly.
    """
    if ASSET_SECTION not in text:
        return {}
    # Split on the NEXT heading of any kind, not on the literal "### 4.".
    # Renaming section 4 used to break the fence, letting this "section" run to
    # the end of the document, scrape rows out of the Tuning Constants tables,
    # and silently report a phantom eighth asset — while overriding legitimate
    # constants' expected values via the update() below.
    rest = text.split(ASSET_SECTION)[1]
    section = re.split(r"\n### ", rest)[0]
    out = {}
    for line in section.splitlines():
        match = re.match(r"\|\s*`(\w+)`\s*\|\s*(\d+(?:\.\d+)?)\s*\|", line)
        if match:
            out[match.group(1)] = float(match.group(2))
    return out


def section_text(text: str, heading: str) -> str:
    """One numbered section of the art specification, fenced at the next heading.

    Split on the NEXT heading of any kind rather than on a literal successor —
    the same trap asset_target_heights() fell into, where renaming section 4 let
    a section run to the end of the document and scrape unrelated tables.
    """
    if heading not in text:
        return ""
    return re.split(r"\n### ", text.split(heading)[1])[0]


def environment_and_lighting(text: str) -> dict:
    """Values from sections 5 and 6, each pulled by a named pattern.

    Percentages are normalised to fractions ("80% opaque" -> 0.8) because that
    is what a renderer takes; the document's own number is still what the
    pattern matched.
    """
    sections = {"env": section_text(text, ENV_SECTION),
                "light": section_text(text, LIGHT_SECTION)}
    out = {}
    for key, which, pattern in ENV_LIGHT_PATTERNS:
        match = re.search(pattern, sections[which])
        if not match:
            continue
        raw = match.group(1)
        out[key] = raw if raw.startswith("#") else float(raw)
        if key == "bandOpacity":
            out[key] = out[key] / 100.0
    sun = re.search(SUN_POSITION_PATTERN, sections["light"])
    if sun:
        for axis, value in zip("XYZ", sun.groups()):
            out["sunPosition" + axis] = float(value)
    return out


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

    gdd_text = GDD.read_text()
    names = named_constants(gdd_text)
    assets = asset_target_heights(gdd_text)
    if len(assets) != EXPECTED_ASSET_COUNT:
        print(f"error: expected {EXPECTED_ASSET_COUNT} per-asset target heights "
              f"under {ASSET_SECTION!r}, found {len(assets)} — the table changed "
              f"shape and this gate's scope moved with it", file=sys.stderr)
        return 1
    if not assets:
        print(f"error: no per-asset target heights found under "
              f"{ASSET_SECTION!r} — the table format changed and this gate is "
              f"no longer checking them", file=sys.stderr)
        return 1
    env_light = environment_and_lighting(gdd_text)
    if len(env_light) != EXPECTED_ENV_LIGHT_COUNT:
        print(f"error: expected {EXPECTED_ENV_LIGHT_COUNT} values from "
              f"{ENV_SECTION!r} and {LIGHT_SECTION!r}, extracted "
              f"{len(env_light)} — a pattern stopped matching, so this gate is "
              f"no longer checking what it reports. Missing: "
              + ", ".join(k for k, _, _ in ENV_LIGHT_PATTERNS if k not in env_light)
              + (", sun position" if "sunPositionX" not in env_light else ""),
              file=sys.stderr)
        return 1

    names = names + sorted(assets)
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
    unnamed = {
        key
        for group in PORT_NAMED_GROUPS
        for key in tuning.get(group, {})
        if not key.startswith("_")
    }

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
                        f"design document and are not in a port-named group "
                        f"({', '.join(PORT_NAMED_GROUPS)}): " + ", ".join(renamed))

    blob = json.dumps(tuning)
    leaked = [m for m in DERIVED_MARKERS if m in blob]
    if leaked:
        failures.append("derived quantities transcribed as if tunable: " + ", ".join(leaked))

    # Values, not just names. CONSTRAINTS §3 Language and style makes tuning.json the only file
    # allowed to hold the numbers, so the numbers are exactly what needs a gate.
    table = table_values(gdd_text)
    table["values"].update(assets)
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

    # Sections 5 and 6: colours compare as strings, numbers as magnitudes.
    art = {}
    for group in ("environment", "lighting"):
        art.update({k: v for k, v in tuning.get(group, {}).items() if not k.startswith("_")})
    art_drifted = []
    for name, expected in env_light.items():
        if name not in art:
            art_drifted.append(f"{name} is missing from tuning.json but section 5 or 6 states it")
        elif isinstance(expected, str):
            if str(art[name]).upper() != expected.upper():
                art_drifted.append(f"{name} is {art[name]!r} but the document says {expected!r}")
        elif abs(abs(float(art[name])) - expected) > 1e-9:
            art_drifted.append(f"{name} is {art[name]} but the document says {expected}")
    for name in WHITE_KEYS:
        if name not in art:
            continue
        if str(art[name]).upper() != "#FFFFFF":
            art_drifted.append(f"{name} is {art[name]!r} but the document says white")
    # Each white-word key is pinned to the section that actually states it:
    # ambient and sun are §6's table, but the band's "flat unlit white quad" is
    # §5's. Guarding all three against §6 meant bandColour was checked against
    # prose that never mentioned it.
    for key, section in WHITE_KEY_SECTIONS.items():
        if "white" not in section_text(gdd_text, section):
            art_drifted.append(f"{section!r} no longer says 'white' — {key} is "
                               f"transcribed against a phrase that has moved")
    if art_drifted:
        failures.append("section 5/6 value(s) drifted: " + "; ".join(art_drifted))

    # A key nobody extracts is a key nobody checks. Adding one to the data
    # without adding its pattern would otherwise read as coverage.
    unchecked = sorted(set(art) - set(env_light) - set(WHITE_KEYS))
    if unchecked:
        failures.append(f"{len(unchecked)} environment/lighting key(s) have no extractor "
                        f"and are therefore transcribed but unverified: " + ", ".join(unchecked))

    if failures:
        for f in failures:
            print(f"tuning: {f}", file=sys.stderr)
        return 1

    print(f"tuning: {len(names)} named constants transcribed "
          f"({len(assets)} of them per-asset target heights), "
          f"{len(table['values'])} values checked against the document "
          f"({len(table['unattributable'])} multi-name rows not attributable), "
          f"{len(unnamed)} port-named rows, {len(occurrences)} entries each appearing once, "
          f"{len(env_light)} section 5/6 values checked + {len(WHITE_KEYS)} stated white, "
          f"{len([k for k in tuning.get('port_decisions', {}) if not k.startswith('_')])} "
          f"port decisions not checked against the document, no derived values")
    return 0


if __name__ == "__main__":
    sys.exit(main())
