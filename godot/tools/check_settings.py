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
    "window/size/viewport_width": (
        "1280", "ambiguity A1's foundation: HUD px are literal at the 1280x720 "
                "design viewport (M5 Critic finding 6 — a drive-by resolution "
                "change would silently invalidate the register entry)"),
    "window/size/viewport_height": (
        "720", "the other half of A1's design resolution"),
    "window/stretch/mode": (
        '"canvas_items"', "what scales A1's literal px for other window sizes"),
    "window/stretch/aspect": (
        '"expand"', "the stretch aspect A1's resolution records"),
    "textures/default_filters/anisotropic_filtering_level": (
        "4", "16x anisotropic filtering, the document's section 2. The LEVEL "
             "alone is inert — materials must request the anisotropic sampler "
             "mode, which scripts/view/anisotropy.gd applies to every "
             "imported model and tests assert; a dedicated grazing-angle "
             "gallery state is a Backlog item"),
}

MODELS = ("kart", "tree", "rock", "cone", "crate", "tires", "cottage")

SIM = GODOT / "scripts" / "core" / "sim.gd"

# The design document's control table, Feature: Input Handling / Mapping the
# control scheme. action -> the physical keycodes it must be bound to, both sets
# equivalent. Pinned because project.godot is rewritten by the editor AND by
# ProjectSettings.save(), and both drop things — see GOTCHAS.md.
KEY_W, KEY_A, KEY_S, KEY_D, KEY_R, KEY_P, KEY_G = 87, 65, 83, 68, 82, 80, 71
KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN = 4194319, 4194320, 4194321, 4194322
REQUIRED_ACTIONS = {
    "accelerate": {KEY_W, KEY_UP},
    "reverse": {KEY_S, KEY_DOWN},
    "steer_left": {KEY_A, KEY_LEFT},
    "steer_right": {KEY_D, KEY_RIGHT},
    # Bound and inert until M7 — the document's table lists them, so the binding
    # is part of the specification even while the action is not.
    "reset_kart": {KEY_R},
    "save_layout": {KEY_P},
    # The design document gives Regenerate World NO required binding — "how a
    # port exposes it is unspecified" — so G is this port's choice, and pinned
    # here for the same reason as the rest: project.godot is rewritten by the
    # editor and by ProjectSettings.save(), and both have dropped things from it.
    "regenerate_world": {KEY_G},
}


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

    # THE FIXED RATE IS DECLARED TWICE, in two files, and until now nothing
    # noticed a divergence — at which point every timing figure in the design
    # document silently stops applying. project.godot drives Godot's fixed-rate
    # loop; sim.gd's constant is what the core converts ticks to seconds with.
    checked_settings += 1
    sim_rate = None
    if SIM.exists():
        rate_match = re.search(r"^const TICKS_PER_SECOND\s*:?=\s*(\d+)", SIM.read_text(), re.M)
        if rate_match:
            sim_rate = rate_match.group(1)
    if sim_rate is None:
        failures.append("could not read TICKS_PER_SECOND from scripts/core/sim.gd — "
                        "the cross-check against project.godot's physics rate is "
                        "no longer running")
    else:
        pinned = REQUIRED["common/physics_ticks_per_second"][0]
        if sim_rate != pinned:
            failures.append(f"the simulation declares TICKS_PER_SECOND={sim_rate} but "
                            f"project.godot pins physics_ticks_per_second={pinned}. "
                            f"Two declarations of one rate; every per-tick constant in "
                            f"the design document is stated at it")

    # Bindings, action by action and key by key.
    checked_actions = 0
    for action, keys in REQUIRED_ACTIONS.items():
        checked_actions += 1
        block = re.search(rf"^{re.escape(action)}=\{{(.*?)^\}}", text, re.M | re.S)
        if not block:
            failures.append(f"input action {action!r} is not bound in project.godot — "
                            f"the design document's control table names it")
            continue
        found = {int(k) for k in re.findall(r'"physical_keycode":(\d+)', block.group(1))}
        missing = keys - found
        if missing:
            failures.append(f"input action {action!r} is missing key(s) "
                            f"{sorted(missing)} — the document's table binds "
                            f"{sorted(keys)}, and both sets are equivalent")

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

    print(f"settings: {checked_settings} pinned settings correct, {checked_actions} input actions bound, "
          f"{checked_presets} import presets present and valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
