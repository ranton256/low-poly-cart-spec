#!/usr/bin/env python3
"""Measure the shadow criteria for the renderer spike, from a committed capture.

CONSTRAINTS §12 Review and CLAUDE.md rule 5: a verification used to sign off work
must be committed as a tool. The spike's first run reported "60% of open-ground
luminance retained" from a patch it never named, and the number could not be
reproduced — an independent review measured 47% from three umbra samples. Naming
the regions in code is the fix.

Regions are stated as explicit pixel boxes below and printed on every run, so a
reader can see exactly what was sampled rather than trusting a figure.

  usage: measure_shadow.py <capture.png> [<reference.png>]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

# The lit reference is a fixed box, chosen to sit wholly on open ground away
# from every caster; its own std is reported so a bad choice is visible.
LIT_BOX = (560, 700, 850, 1250)

# The ground beneath and in front of the kart, where its contact shadow must
# fall given a sun at (30,50,30). Named here because A8 — the finding that
# Godot's default shadow_normal_bias erases that shadow — rests on a
# before/after percentage, and an unnamed region is exactly the defect this
# tool was written to fix. The first version of it measured C5 from a patch it
# never defined and could not be reproduced.
KART_BOX = (430, 530, 440, 860)

# The umbra is NOT a hand-picked box. Hand-picking is how the first run of this
# spike reported 60% retention from a patch that straddled the penumbra and could
# not be reproduced. Instead: take the ground band, discard anything as bright as
# open ground, and report the darkest decile — a rule that survives the shadow
# moving when the sun angle is corrected.
GROUND_BAND = (400, 720, 0, 1280)
UMBRA_PERCENTILE = 10.0
LUM = np.array([0.2126, 0.7152, 0.0722])


def stats(img: np.ndarray, box: tuple) -> dict:
    t, b, l, r = box
    patch = img[t:b, l:r]
    flat = patch.reshape(-1, 3)
    lum = patch @ LUM
    return {
        "rgb": flat.mean(axis=0),
        "lum": float(lum.mean()),
        "std": float(lum.std()),
        "min": float(lum.min()),
        "max": float(lum.max()),
        "px": flat.shape[0],
    }


def contact_shadow(img: np.ndarray, lit_lum: float) -> dict:
    """Fraction of ground beneath the kart that is in shadow.

    Ground-only and threshold-based, the same two rules the umbra uses. This is
    the measurement A8 rests on: with shadow_normal_bias at Godot's default of
    2.0 it collapses, and at 0.1 it recovers.
    """
    t, b, l, r = KART_BOX
    patch = img[t:b, l:r].reshape(-1, 3)
    lum = patch @ LUM
    is_ground = (patch[:, 1] > patch[:, 0] * 1.3) & (patch[:, 1] > patch[:, 2] * 1.3)
    ground = int(is_ground.sum())
    if ground == 0:
        return {"pct": 0.0, "shadowed": 0, "ground": 0}
    shadowed = int((is_ground & (lum < lit_lum * 0.95)).sum())
    return {"pct": 100.0 * shadowed / ground, "shadowed": shadowed, "ground": ground}


def umbra(img: np.ndarray, lit_lum: float) -> dict:
    """The darkest decile of ground pixels that are clearly not open ground."""
    t, b, l, r = GROUND_BAND
    patch = img[t:b, l:r].reshape(-1, 3)
    lum = patch @ LUM
    # Ground only. Without this the "darkest shaded pixels" are the kart's black
    # bodywork rather than shadow. Note the filter is justified by the GRASS
    # being strongly green-dominant, not by the casters failing to be — the tree
    # canopy is green too, and is excluded instead by GROUND_BAND starting below
    # it.
    is_ground = (patch[:, 1] > patch[:, 0] * 1.3) & (patch[:, 1] > patch[:, 2] * 1.3)
    shaded = is_ground & (lum < lit_lum * 0.95)
    if not shaded.any():
        return {"rgb": np.zeros(3), "lum": lit_lum, "px": 0}
    cut = np.percentile(lum[shaded], UMBRA_PERCENTILE)
    sel = shaded & (lum <= cut)
    return {"rgb": patch[sel].mean(axis=0), "lum": float(lum[sel].mean()),
            "px": int(sel.sum())}


def report(path: Path) -> dict:
    img = np.array(Image.open(path).convert("RGB"), dtype=float)
    print(f"\n{path.name}  ({img.shape[1]}x{img.shape[0]})")

    lit = stats(img, LIT_BOX)
    print(f"  lit ground   rows {LIT_BOX[0]}-{LIT_BOX[1]} cols {LIT_BOX[2]}-{LIT_BOX[3]} "
          f"({lit['px']} px)  RGB {lit['rgb'].round(1)}  lum {lit['lum']:6.1f}  "
          f"std {lit['std']:5.2f}")

    um = umbra(img, lit["lum"])
    pct = 100.0 * um["lum"] / lit["lum"]
    print(f"  umbra        darkest {UMBRA_PERCENTILE:.0f}% of shaded ground "
          f"({um['px']} px)  RGB {um['rgb'].round(1)}  lum {um['lum']:6.1f}")

    print(f"\n  C3 acne — lit ground std {lit['std']:.2f} "
          f"(min {lit['min']:.1f}, max {lit['max']:.1f}): "
          f"{'SPECKLED' if lit['std'] > 4.0 else 'uniform, no acne'}")
    print(f"  C5 fill — umbra retains {pct:.1f}% of open-ground luminance: "
          f"{'READS AS BLACK' if pct < 10 else 'not black, fill reads'}")

    kart = contact_shadow(img, lit["lum"])
    print(f"  kart contact rows {KART_BOX[0]}-{KART_BOX[1]} cols {KART_BOX[2]}-{KART_BOX[3]}  "
          f"{kart['shadowed']}/{kart['ground']} ground px shadowed = {kart['pct']:.1f}%")

    clipped = int((img.reshape(-1, 3).max(axis=1) >= 255).sum())
    print(f"  exposure — {clipped} px ({100.0 * clipped / (img.shape[0] * img.shape[1]):.1f}%) "
          f"have a channel at 255 (clipped)")
    return {"lit": lit, "umbra": um, "pct": pct, "clipped": clipped, "kart": kart}


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 1
    a = report(Path(sys.argv[1]))
    if len(sys.argv) > 2:
        b = report(Path(sys.argv[2]))
        print(f"\n  exposure: lit-ground luminance {a['lit']['lum']:.1f} vs "
              f"{b['lit']['lum']:.1f} "
              f"({100.0 * a['lit']['lum'] / b['lit']['lum'] - 100:+.0f}%)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
