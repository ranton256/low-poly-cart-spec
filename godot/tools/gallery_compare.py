#!/usr/bin/env python3
"""Gallery image-diff gate — closes the capture->compare loop that has been
half-open since G5 (tools/gallery.sh has captured states since then; nothing
compared them, and the comparison script quoted in that commit lived in the C
port repo and was never brought over).

Compares a fresh capture against committed baselines, per state, by mean
absolute pixel difference. Reports EVERY state's measured value so drift is
visible before it crosses a threshold, and writes a side-by-side contact sheet
for the states that moved.

  tools/gallery_compare.py                      # compare, exit 1 on drift
  tools/gallery_compare.py --bless              # accept the capture as new truth
  tools/gallery_compare.py --current DIR --baseline DIR

Project settings — capture/baseline paths and the three threshold limits — live
in tools/gallery_config.json, not here, so this file carries no game knowledge
and can be copied to another project verbatim. That config also records how the
limits were calibrated.
"""
import argparse
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw

CONFIG_PATH = "tools/gallery_config.json"

# Fallbacks used only when no config file is present, so the tool still runs in
# a project that has not written one yet.
DEFAULTS = {
    "current": "gallery",
    "baseline": "tests/baselines",
    "sheet": "gallery/_diff_sheet.png",
    "limits": {"mean": 0.50, "changed_pct": 1.00, "strong_pct": 0.10},
    "overrides": {},
}



def load_rgb(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float64)


def compare(cur_path, base_path):
    a, b = load_rgb(base_path), load_rgb(cur_path)
    if a.shape != b.shape:
        return None, f"size changed: baseline {a.shape[1]}x{a.shape[0]}, current {b.shape[1]}x{b.shape[0]}"
    d = np.abs(a - b)
    per_px = d.max(axis=2)
    return {
        "mean": float(d.mean()),
        "max": float(d.max()),
        "changed_pct": float((per_px > 2).mean() * 100.0),
        "strong_pct": float((per_px > 32).mean() * 100.0),
    }, None


def contact_sheet(rows, out_path):
    """baseline | current | amplified difference, one row per changed state."""
    if not rows:
        return
    tiles = []
    for name, cur_path, base_path in rows:
        base = Image.open(base_path).convert("RGB")
        cur = Image.open(cur_path).convert("RGB")
        d = np.abs(np.asarray(base, dtype=np.float64) - np.asarray(cur, dtype=np.float64))
        amp = np.clip(d * 8.0, 0, 255).astype(np.uint8)  # 8x so 1/255 is visible
        diff = Image.fromarray(amp, "RGB")
        w, h = base.size
        row = Image.new("RGB", (w * 3, h + 22), (12, 12, 26))
        row.paste(base, (0, 22))
        row.paste(cur, (w, 22))
        row.paste(diff, (w * 2, 22))
        dr = ImageDraw.Draw(row)
        dr.text((6, 6), f"{name}  |  baseline", fill=(200, 200, 210))
        dr.text((w + 6, 6), "current", fill=(200, 200, 210))
        dr.text((w * 2 + 6, 6), "difference (8x)", fill=(255, 180, 120))
        tiles.append(row)

    width = max(t.width for t in tiles)
    sheet = Image.new("RGB", (width, sum(t.height for t in tiles)), (12, 12, 26))
    y = 0
    for t in tiles:
        sheet.paste(t, (0, y))
        y += t.height
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    sheet.save(out_path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default=CONFIG_PATH)
    ap.add_argument("--current")
    ap.add_argument("--baseline")
    ap.add_argument("--sheet")
    ap.add_argument("--bless", action="store_true",
                    help="copy the current capture over the baselines")
    args = ap.parse_args()

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(root)

    cfg = dict(DEFAULTS)
    if os.path.exists(args.config):
        cfg.update({k: v for k, v in json.load(open(args.config)).items()
                    if not k.startswith("_")})
    # explicit flags win over config, config wins over the built-in fallbacks
    for key in ("current", "baseline", "sheet"):
        if getattr(args, key):
            cfg[key] = getattr(args, key)
    args.current, args.baseline, args.sheet = cfg["current"], cfg["baseline"], cfg["sheet"]
    limits_cfg = {k: v for k, v in cfg["limits"].items() if not k.startswith("_")}
    overrides = {k: v for k, v in cfg.get("overrides", {}).items() if not k.startswith("_")}

    if not os.path.isdir(args.current):
        print(f"no capture directory: {args.current} — capture the states first",
              file=sys.stderr)
        return 1

    cur = {f[:-4] for f in os.listdir(args.current)
           if f.endswith(".png") and not f.startswith("_")}
    os.makedirs(args.baseline, exist_ok=True)
    base = {f[:-4] for f in os.listdir(args.baseline) if f.endswith(".png")}

    if args.bless:
        for name in sorted(cur):
            shutil.copy2(os.path.join(args.current, name + ".png"),
                         os.path.join(args.baseline, name + ".png"))
        for name in sorted(base - cur):
            os.remove(os.path.join(args.baseline, name + ".png"))
            print(f"  removed stale baseline: {name}")
        print(f"blessed {len(cur)} baseline(s) into {args.baseline}/")
        return 0

    if not base:
        print(f"no baselines in {args.baseline}/ — capture and run with --bless first",
              file=sys.stderr)
        return 1

    failures, changed = [], []
    dash = f"{'-':>8} {'-':>9} {'-':>9}"
    print(f"{'state':<24} {'mean':>8} {'changed':>9} {'strong':>9}   verdict")
    print("-" * 72)
    for name in sorted(cur & base):
        cur_path = os.path.join(args.current, name + ".png")
        base_path = os.path.join(args.baseline, name + ".png")
        m, err = compare(cur_path, base_path)
        if err:
            print(f"{name:<24} {dash}   FAIL ({err})")
            failures.append(f"{name}: {err}")
            changed.append((name, cur_path, base_path))
            continue

        limits = dict(limits_cfg, **overrides.get(name, {}))
        broke = [k for k in ("mean", "changed_pct", "strong_pct") if m[k] > limits[k]]
        print(f"{name:<24} {m['mean']:8.4f} {m['changed_pct']:8.3f}% {m['strong_pct']:8.3f}%   "
              f"{'ok' if not broke else 'FAIL'}")
        if broke:
            detail = ", ".join(f"{k} {m[k]:.4f} > {limits[k]:.2f}" for k in broke)
            failures.append(f"{name}: {detail}")
            changed.append((name, cur_path, base_path))

    for name in sorted(cur - base):
        print(f"{name:<24} {dash}   NEW (no baseline)")
        failures.append(f"{name}: captured but has no baseline")
    for name in sorted(base - cur):
        print(f"{name:<24} {dash}   MISSING (not captured)")
        failures.append(f"{name}: baseline exists but the state was not captured")

    if changed:
        contact_sheet(changed, args.sheet)
        print(f"\ncontact sheet: {args.sheet}")

    if failures:
        print(f"\ngallery: {len(failures)} state(s) differ from baseline", file=sys.stderr)
        for f in failures:
            print(f"  FAIL: {f}", file=sys.stderr)
        print("\nReview the contact sheet. If the change is intended, re-bless with:"
              "\n  tools/gallery.sh --bless", file=sys.stderr)
        return 1

    print(f"\ngallery: {len(cur & base)} states match their baselines")
    return 0


if __name__ == "__main__":
    sys.exit(main())
