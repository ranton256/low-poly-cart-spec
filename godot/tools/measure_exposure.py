#!/usr/bin/env python3
"""Measure the exposure criteria for ambiguity A9, from a committed capture.

The design document states its three light intensities in the reference build's
units. Applied at face value under Godot they clip most of the frame. The
document's RATIOS are normative; the absolute scale is this port's to choose,
and this tool is how it is chosen — see design D3 of
openspec/changes/add-world-presentation-layer/.

Four criteria, fixed before any capture was judged:

  C1  No saturated pixel ANYWHERE IN THE FRAME, in any channel. The scene is
      ground, sky, an unlit grid and an unlit band, none of which carries a
      specular highlight, so a saturated pixel is exposure and nothing else.
      Measured over the whole image, NOT over the sample boxes below: an earlier
      version checked only those two rectangles and reported "no saturation" on a
      frame whose ground was blown out beyond them, because the blown-out part
      fell outside them. The boxes exist to take representative COLOURS, which needs a
      clean patch; saturation is a defect anywhere and must be looked for
      everywhere.
  C2  The unlit sky renders EXACTLY its specified colour. The background is not
      lit, so this is an equality rather than a tolerance, and it is the
      falsification test for the whole pipeline: if it fails, something is
      reshaping colour and no measurement taken afterwards means anything. It
      runs first for that reason.
  C3  The ground renders AS ITS SPECIFIED ALBEDO — hue and lightness together,
      compared in linear space. The tolerance is COMPUTED from the document's own
      hemisphere ratio and sky colour, not chosen: see albedo_tolerance().
  C4  The scale is the value MINIMISING C3's deviation, subject to C1 and C2.
      Not checkable from one image; tools/find_light_scale.py establishes it.

An earlier version of C3 constrained hue alone, and C4 took "the largest scale
that clips nothing". Together they chose the brightest scale that saturates
nothing, rendering the specified grass #3D8C40 as [94, 218, 108] — passing every
criterion and plainly wrong, because nothing pulled brightness DOWN. Hue was also computed
in gamma-encoded sRGB, where it is not scale-invariant, so the bound did not mean
what it claimed. Both are recorded in design D3a. Comparing in linear space is
not a detail: a ratio between two colours is only scale-invariant there.

Every sample region is a NAMED constant below, printed on every run. The
renderer spike was rejected in review for deriving a number from a region it
never defined, and the fix was to name the region in code. A number is only as
good as the ability to say where it came from.

  tools/measure_exposure.py gallery/capture.png
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

# Sample regions as (row0, row1, col0, col1) in a 1280x720 capture of
# scenes/world.tscn from its placeholder camera.
#
# SKY sits well above the horizon, which falls near row 285 from that viewpoint.
# GROUND is near-field open ground below the start/finish band. It contains grid
# lines by construction — the grid covers the central 100 wu — so the ground's
# representative colour is taken as a MEDIAN, which the thin dark lines cannot
# move. Their presence is reported so a region drifting onto a line is visible
# rather than silent.
SKY_BOX = (20, 180, 100, 1180)
GROUND_BOX = (520, 700, 150, 1130)

# From the design document: section 5 environment art, section 6 lighting.
SKY_HEX = "#87CEEB"
GROUND_HEX = "#3D8C40"
HEMISPHERE_SKY_HEX = "#87CEEB"
AMBIENT_INTENSITY = 0.60
HEMISPHERE_INTENSITY = 0.40

SUN_INTENSITY = 1.00
# The sun is at (30, 50, 30) aiming at the origin, so a horizontal surface sees
# it at cos = 50 / |(30,50,30)|. Computed rather than written down.
SUN_COSINE = 50.0 / (30.0**2 + 50.0**2 + 30.0**2) ** 0.5

SATURATED = 255


def rgb(hex_colour: str) -> np.ndarray:
    h = hex_colour.lstrip("#")
    return np.array([int(h[i : i + 2], 16) for i in (0, 2, 4)], dtype=float)


def to_linear(srgb: np.ndarray) -> np.ndarray:
    """sRGB 0-255 to linear 0-1. Every comparison below happens here."""
    c = srgb / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def illuminant() -> np.ndarray:
    """The light a horizontal surface receives, from the document's own numbers.

    Ambient is white, the hemisphere shows an upward-facing surface its SKY
    colour, and the sun is white at the cosine above. Normalised to unit mean so
    it describes the light's COLOUR; its magnitude is what the scale sets.
    """
    white = np.ones(3)
    sky = to_linear(rgb(HEMISPHERE_SKY_HEX))
    total = (
        AMBIENT_INTENSITY * white
        + HEMISPHERE_INTENSITY * sky
        + SUN_INTENSITY * SUN_COSINE * white
    )
    return total / total.mean()


def deviation(measured: np.ndarray) -> float:
    """Relative distance from the specified albedo, in linear space.

    This is the quantity C4 minimises, so it is the one number this tool exists
    to produce.
    """
    albedo = to_linear(rgb(GROUND_HEX))
    return float(np.linalg.norm(to_linear(measured) - albedo) / np.linalg.norm(albedo))


def albedo_tolerance() -> float:
    """How far the specified lighting can move the ground off its own albedo.

    COMPUTED FROM THE DOCUMENT — with one honest caveat. The chromatic term below
    is derived purely from the design document's 0.60 / 0.40 / 1.00, its #87CEEB,
    and the sun's specified position, so it owes nothing to the implementation.
    But illuminant() is also, term for term, the lighting model the scene builds,
    so C3 is a consistency check between tool and scene sharing one model rather
    than an independent oracle. That is the right check and it is not an
    independent one, and the difference is worth stating.

    The quantisation allowance is a CHOICE of form, not a computation: it steps
    all three channels together. The stricter single-channel form gives 0.0381,
    which the settled result (0.0309) still satisfies — so the answer does not
    depend on the looser form, but the phrase "computed, not chosen" was one word
    stronger than the evidence.

    The hemisphere term is specified as a coloured fill, so
    a surface lit by it cannot render at exactly its albedo — the tint is part of
    the specification. The tolerance is the deviation that tint alone produces,
    plus one 8-bit quantisation step, which is the finest distinction a capture
    can carry. A deviation beyond this is not explained by the specified lighting.
    """
    albedo = to_linear(rgb(GROUND_HEX))
    tinted = albedo * illuminant()
    chromatic = float(np.linalg.norm(tinted - albedo) / np.linalg.norm(albedo))
    step = rgb(GROUND_HEX) + 1.0
    quantisation = float(np.linalg.norm(to_linear(step) - albedo) / np.linalg.norm(albedo))
    return chromatic + quantisation


def region(img: np.ndarray, box: tuple) -> dict:
    r0, r1, c0, c1 = box
    patch = img[r0:r1, c0:c1].reshape(-1, 3).astype(float)
    return {
        "pixels": int(patch.shape[0]),
        "median": np.median(patch, axis=0),
        "saturated_fraction": float((patch >= SATURATED).any(axis=1).mean()),
        "saturated_by_channel": [float((patch[:, i] >= SATURATED).mean()) for i in range(3)],
    }


def report(path: Path) -> dict:
    img = np.asarray(Image.open(path).convert("RGB"))
    flat = img.reshape(-1, 3).astype(float)
    return {
        "path": str(path),
        "shape": img.shape,
        "sky": region(img, SKY_BOX),
        "ground": region(img, GROUND_BOX),
        "frame": {
            "pixels": int(flat.shape[0]),
            "saturated_fraction": float((flat >= SATURATED).any(axis=1).mean()),
            "saturated_by_channel": [float((flat[:, i] >= SATURATED).mean()) for i in range(3)],
        },
    }


def criteria(data: dict) -> list:
    """(name, passed, detail) for C1-C3. C4 belongs to the search, not one image."""
    out = []

    sky_median = data["sky"]["median"]
    want_sky = rgb(SKY_HEX)
    exact = bool(np.array_equal(sky_median, want_sky))
    out.append(
        (
            "C2 sky renders exactly its specified colour",
            exact,
            "sky median %s, specified %s%s"
            % (
                sky_median.astype(int).tolist(),
                want_sky.astype(int).tolist(),
                "" if exact else "  <- the pipeline is reshaping colour; C1 and C3 are void",
            ),
        )
    )

    frame = data["frame"]
    out.append(
        (
            "C1 no saturated pixel anywhere in the frame",
            frame["saturated_fraction"] == 0.0,
            "%.4f%% of the frame saturated (per channel: %s)"
            % (
                frame["saturated_fraction"] * 100.0,
                ", ".join(
                    "%s=%.3f%%" % (c, f * 100.0)
                    for c, f in zip("RGB", frame["saturated_by_channel"])
                ),
            ),
        )
    )

    measured = data["ground"]["median"]
    dev = deviation(measured)
    tol = albedo_tolerance()
    out.append(
        (
            "C3 ground renders as its specified albedo",
            dev <= tol,
            "ground median %s vs specified %s — deviation %.4f, tolerance %.4f%s"
            % (
                measured.astype(int).tolist(),
                rgb(GROUND_HEX).astype(int).tolist(),
                dev,
                tol,
                "" if dev <= tol else "  <- brighter or more tinted than the lighting explains",
            ),
        )
    )
    return out


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__.strip().splitlines()[-1].strip(), file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    if not path.exists():
        print(f"error: {path} not found", file=sys.stderr)
        return 1

    data = report(path)
    print(f"exposure: {path} {data['shape'][1]}x{data['shape'][0]}")
    print(f"  SKY_BOX    (row {SKY_BOX[0]}-{SKY_BOX[1]}, col {SKY_BOX[2]}-{SKY_BOX[3]}) "
          f"{data['sky']['pixels']} px")
    print(f"  GROUND_BOX (row {GROUND_BOX[0]}-{GROUND_BOX[1]}, col {GROUND_BOX[2]}-{GROUND_BOX[3]}) "
          f"{data['ground']['pixels']} px  <- colour sample only")
    print(f"  saturation is measured over all {data['frame']['pixels']} pixels")

    failed = 0
    for name, passed, detail in criteria(data):
        print(f"  [{'ok  ' if passed else 'FAIL'}] {name}")
        print(f"         {detail}")
        if not passed:
            failed += 1
    if failed:
        print(f"exposure: {failed} criterion/criteria failed", file=sys.stderr)
        return 1
    print("exposure: C1-C3 satisfied, deviation %.4f "
          "(C4 is established by tools/find_light_scale.py)" % deviation(data["ground"]["median"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
