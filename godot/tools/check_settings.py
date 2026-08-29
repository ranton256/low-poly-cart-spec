#!/usr/bin/env python3
"""Assert the pinned project settings and the committed model import presets.

Godot rewrites project.godot when the editor saves, and re-imports assets without
asking. Both are silent, and a reverted setting invalidates every measurement
taken against it — acceptance item 14's frame-rate independence depends on the
physics step never being adjusted, and the visual baselines depend on the renderer.

Reads project.godot as TEXT rather than booting the engine and dumping
ProjectSettings. Less faithful — it would not catch a setting overridden at
runtime — but the failure mode being guarded is the editor rewriting the file,
which text inspection catches exactly, and it costs milliseconds. See design D4.

Deliberately break it by setting physics_jitter_fix to 0.5, or deleting a preset.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = ROOT / "godot"
PROJECT = GODOT / "project.godot"
ASSETS = GODOT / "assets"

# key -> (expected value, why it is pinned)
REQUIRED = {
    "common/physics_ticks_per_second": (
        "60", "the fixed simulation step — CONSTRAINTS §6 Determinism and the reference frame"),
    "common/physics_jitter_fix": (
        "0.0", "Godot's 0.5 default perturbs the physics delta and drifts the race "
               "clock against wall time"),
    "renderer/rendering_method": (
        '"gl_compatibility"', "one renderer on every target — CONSTRAINTS §2 Tech stack"),
    "renderer/rendering_method.mobile": (
        '"gl_compatibility"', "must match the base renderer"),
    "lights_and_shadows/directional_shadow/size": (
        "2048", "the design document's specified shadow map. Godot's desktop "
                "default is 4096, and leaving this unset once invalidated an "
                "entire renderer spike — see docs/progress/2026-08-28-renderer-spike.md"),
    "lights_and_shadows/directional_shadow/soft_shadow_filter_quality": (
        "3", "the document asks for soft/percentage-closer filtering"),
}

MODELS = ("kart", "tree", "rock", "cone", "crate", "tires", "cottage")


def main() -> int:
    if not PROJECT.exists():
        print(f"error: {PROJECT} is missing", file=sys.stderr)
        return 1
    text = PROJECT.read_text()

    failures = []
    checked_settings = 0

    for key, (expected, why) in REQUIRED.items():
        match = re.search(rf"^{re.escape(key)}\s*=\s*(.+?)\s*$", text, re.M)
        checked_settings += 1
        if not match:
            failures.append(f"{key} is absent from project.godot — required: "
                            f"{expected} ({why})")
            continue
        found = match.group(1)
        if found != expected:
            failures.append(f"{key} is {found}, required {expected} — {why}")

    checked_presets = 0
    for name in MODELS:
        preset = ASSETS / f"{name}.glb.import"
        checked_presets += 1
        if not preset.exists():
            failures.append(f"{name}.glb.import is missing — the import contract "
                            f"for a supplied model is committed, not regenerated "
                            f"at whatever settings the editor picks")
            continue
        body = preset.read_text()
        if "valid=false" in body:
            failures.append(f"{name}.glb.import records a FAILED import "
                            f"(valid=false). Godot does not repair this once the "
                            f"source is fixed; delete the preset and re-import")
            continue
        # A zero-byte or truncated preset has no valid=false either, and would
        # otherwise pass as "present and valid".
        for key in ("[remap]", "importer=", "path="):
            if key not in body:
                failures.append(f"{name}.glb.import is truncated or malformed — "
                                f"missing '{key}'. Delete it and re-import")
                break

    # A gate that inspects nothing reports success and guards nothing. These
    # counts come from module-level constants, so they can only be zero if
    # REQUIRED or MODELS was emptied — checked at import rather than pretending
    # a loop over a literal could yield nothing.
    if not REQUIRED or not MODELS:
        print("error: settings gate has an empty REQUIRED or MODELS list — it "
              "would inspect nothing", file=sys.stderr)
        return 1

    if failures:
        for f in failures:
            print(f"settings: {f}", file=sys.stderr)
        print(f"\nsettings: {len(failures)} problem(s)", file=sys.stderr)
        return 1

    print(f"settings: {checked_settings} pinned settings correct, "
          f"{checked_presets} import presets present and valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
