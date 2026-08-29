#!/usr/bin/env python3
"""Measure the kart's contact shadow, from a committed overhead capture.

The design document calls that shadow "the primary cue for where the kart
actually is on the ground". Ambiguities A7 and A8 were settled to protect it —
A8 lowered Godot's shadow_normal_bias from 2.0 to 0.1 on the evidence that the
default erased it — but both were measured on the renderer spike's scene. This
re-checks the decision against the world M2 builds.

  tools/measure_contact_shadow.py docs/progress/2026-08-29-m2-kart-contact-shadow.png

THE DARKEST DECILE, NOT A MEDIAN, AND NOT A HAND-PICKED PATCH. Both rules are
inherited from tools/measure_shadow.py, and both were re-learned the hard way
here: a first pass at this measurement took the median of a hand-picked box
beneath the kart, got -3%, and concluded the shadow was missing. It was not. At
a sun elevation of 49.7 degrees the shadow is offset barely 1 wu from a kart
2.2 wu wide, so it falls largely under the kart's own footprint and a box big
enough to hand-pick is mostly lit ground. The spike's notes say the same thing
about its own first run; this is the second time the project has paid for it.

Regions are named constants, printed on every run.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

# Where the kart sits in a 1280x720 capture of scenes/kart_overhead_view.tscn,
# and how far out to look. The kart is about 76 px per world unit at that
# framing, so the ring below spans roughly 0.8 to 1.2 wu from its centre — where
# a shadow offset ~1 wu must fall.
KART_CENTRE = (390, 640)
SHADOW_RING = (60, 90)
OPEN_GROUND_MIN_RADIUS = 320

# The umbra is the darkest decile of the ring, for the reason in the docstring.
UMBRA_PERCENTILE = 10.0

# Coverage: how much ground near the kart is meaningfully shadowed. Reported,
# not gated. It is the metric A8 used — the spike measured shadowed ground
# beneath the kart rising from 6.5% to 27.2% when the normal bias was lowered —
# and it is the one sensitive to that decision, because the bias erodes the thin
# contact region rather than the broad shadow the depth check sees.
#
# In THIS scene the same change is worth far less: 10.2% against 8.0%. A8's
# decision still helps and still stands, but the margin that justified it does
# not reproduce at this framing, and a threshold tuned to a 2-point gap would be
# a brittle gate rather than a real one. Stated here so the number is not
# mistaken for a guard.
COVERAGE_RADIUS = 140
COVERAGE_DARKER_THAN = 0.85

# What the shadow must be worth. Computed, not chosen: on a horizontal surface
# the sun contributes cos(elevation-complement) of its intensity against the two
# fill terms, so from the design document's own 0.60 / 0.40 / 1.00 the sun is
# 1.00 * 0.7625 / (0.60 + 0.40 + 1.00 * 0.7625) = 43% of the light. Fully
# shadowed ground therefore reads about 43% darker. Half of that is the floor:
# below it the shadow is being washed out rather than merely softened.
SUN_COSINE = 50.0 / (30.0**2 + 50.0**2 + 30.0**2) ** 0.5
AMBIENT, HEMISPHERE, SUN = 0.60, 0.40, 1.00
FULL_SHADOW_FRACTION = SUN * SUN_COSINE / (AMBIENT + HEMISPHERE + SUN * SUN_COSINE)
MINIMUM_DEPTH = FULL_SHADOW_FRACTION / 2.0

LUM = np.array([0.2126, 0.7152, 0.0722])


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__.strip().splitlines()[5].strip(), file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    if not path.exists():
        print(f"error: {path} not found", file=sys.stderr)
        return 1

    img = np.asarray(Image.open(path).convert("RGB")).astype(float)
    lum = img @ LUM
    red, green, blue = img[..., 0], img[..., 1], img[..., 2]
    # Ground only: the kart is near-black and the sky is blue, and including
    # either would report the kart's own darkness as shadow.
    ground = (green > red + 15) & (green > blue + 15)

    rows, cols = np.mgrid[0 : img.shape[0], 0 : img.shape[1]]
    distance = np.hypot(rows - KART_CENTRE[0], cols - KART_CENTRE[1])

    open_mask = ground & (distance > OPEN_GROUND_MIN_RADIUS)
    ring_mask = ground & (distance >= SHADOW_RING[0]) & (distance < SHADOW_RING[1])

    print(f"contact shadow: {path}")
    print(f"  KART_CENTRE {KART_CENTRE}, SHADOW_RING {SHADOW_RING} px, "
          f"open ground beyond {OPEN_GROUND_MIN_RADIUS} px")
    if ring_mask.sum() < 200 or open_mask.sum() < 200:
        print(f"error: too few ground pixels to measure (ring {ring_mask.sum()}, "
              f"open {open_mask.sum()}) — the framing moved and these named "
              f"regions no longer describe the image", file=sys.stderr)
        return 1

    open_lum = float(np.median(lum[open_mask]))
    umbra = float(np.percentile(lum[ring_mask], UMBRA_PERCENTILE))
    depth = 1.0 - umbra / open_lum

    print(f"  open ground {open_lum:.1f}, umbra (darkest {UMBRA_PERCENTILE:.0f}%) {umbra:.1f}")
    print(f"  shadow depth {depth * 100:.1f}%  (full shadow would be "
          f"{FULL_SHADOW_FRACTION * 100:.1f}%, floor {MINIMUM_DEPTH * 100:.1f}%)")

    near = ground & (distance < COVERAGE_RADIUS)
    covered = near & (lum < open_lum * COVERAGE_DARKER_THAN)
    coverage = covered.sum() / max(near.sum(), 1)
    print(f"  shadowed ground within {COVERAGE_RADIUS} px: {coverage * 100:.2f}% "
          f"(reported, not gated — see COVERAGE_RADIUS)")

    if depth < MINIMUM_DEPTH:
        print(f"\ncontact shadow: {depth * 100:.1f}% is below the {MINIMUM_DEPTH * 100:.1f}% "
              f"floor — the cue the design document calls primary is being washed "
              f"out. Ambiguities A7 and A8 were settled to prevent exactly this, "
              f"on a different scene", file=sys.stderr)
        return 1
    print("  the primary cue survives in this scene, as A7 and A8 intended")
    return 0


if __name__ == "__main__":
    sys.exit(main())
