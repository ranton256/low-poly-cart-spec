#!/usr/bin/env python3
"""Find the light scale that settles ambiguity A9, by ternary search.

The design document's light intensities are in the reference build's units. Its
RATIOS are normative; the absolute scale is this port's. This tool chooses that
scale as **the value minimising the ground's deviation from its specified
albedo** — criterion C4 in measure_exposure.py, and the thing that makes the
answer determinate rather than preferred. Two people running this get the same
number.

It captures scenes/world.tscn at a candidate scale, measures it, and narrows by
ternary search, which needs only that the deviation be unimodal in the scale — no
assumption about the renderer's response curve.

An earlier version took "the largest scale that clips nothing" and returned
0.6882 — the brightest scale that saturates nothing, which is
not the same question as the one the specification asks. See design D3a.

The result is reported with its NEIGHBOURS: the deviation just below and just
above the answer, because "minimising" is a claim about both sides and a number
without them is an assertion.

  tools/find_light_scale.py                 # search, then verify the minimum
  tools/find_light_scale.py --iterations 8  # fewer steps, coarser answer
  tools/find_light_scale.py --check 0.2809  # measure one scale and stop

WINDOWED, like every capture — see tools/capture.sh. Not part of tools/test.sh.
"""
import argparse
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import measure_exposure  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SCENE = "res://scenes/world.tscn"
SCRATCH = ROOT / "gallery" / "light_scale_probe.png"

# The search interval. The top is the design document's face value, which is
# where A9 starts. The bottom is not zero: a black frame trivially avoids
# saturation, so an interval reaching zero would invite a degenerate answer if
# the deviation measure were ever weakened.
SCALE_LOW = 0.05
SCALE_HIGH = 1.0
SEARCH_STEPS = 14


def capture(scale: float) -> Path:
    env = dict(os.environ, LPC_LIGHT_SCALE=repr(scale))
    SCRATCH.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [str(ROOT / "tools" / "capture.sh"), SCENE, str(SCRATCH), "20"],
        env=env,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 or not SCRATCH.exists():
        print(result.stdout, result.stderr, file=sys.stderr)
        raise SystemExit(f"capture failed at scale {scale}")
    return SCRATCH


def evaluate(scale: float, verbose: bool = True) -> tuple:
    """(deviation, ok, data) at one scale. Deviation is what C4 minimises."""
    data = measure_exposure.report(capture(scale))
    results = measure_exposure.criteria(data)
    ok = all(p for _, p, _ in results)
    dev = measure_exposure.deviation(data["ground"]["median"])
    if verbose:
        failed = [n.split()[0] for n, p, _ in results if not p]
        print(
            "  scale %-9s deviation %.4f  ground %-18s %s"
            % (
                "%.6f" % scale,
                dev,
                data["ground"]["median"].astype(int).tolist(),
                "ok" if ok else "FAIL (" + ", ".join(failed) + ")",
            )
        )
    return dev, ok, data


def main() -> int:
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("--iterations", type=int, default=SEARCH_STEPS)
    parser.add_argument("--check", type=float, default=None)
    args = parser.parse_args()

    if args.check is not None:
        _, ok, _ = evaluate(args.check)
        return 0 if ok else 1

    print(f"light scale: ternary search on [{SCALE_LOW}, {SCALE_HIGH}], "
          f"{args.iterations} steps")
    print("             minimising the ground's deviation from its specified albedo")
    print("             (measure_exposure.py C4; criteria fixed before any capture)")

    # The document's face value must fail, or A9 does not arise and this tool is
    # answering a question nobody has. Checking that is not ceremony.
    _, top_ok, _ = evaluate(SCALE_HIGH)
    if top_ok:
        print("light scale: the document's face value already satisfies every "
              "criterion — A9 does not arise", file=sys.stderr)
        return 1

    low, high = SCALE_LOW, SCALE_HIGH
    for _ in range(args.iterations):
        a = low + (high - low) / 3.0
        b = high - (high - low) / 3.0
        dev_a, _, _ = evaluate(a, verbose=False)
        dev_b, _, _ = evaluate(b, verbose=False)
        if dev_a < dev_b:
            high = b
        else:
            low = a
    best = round((low + high) / 2.0, 4)

    print()
    print("light scale: candidate %.4f — checking it is a minimum, not a stop" % best)
    neighbours = [round(best * f, 6) for f in (0.90, 0.95, 1.0, 1.05, 1.10)]
    results = [(n, *evaluate(n)[:2]) for n in neighbours]
    centre = [d for n, d, _ in results if n == neighbours[2]][0]
    if any(d < centre for n, d, _ in results if n != neighbours[2]):
        print("light scale: a neighbour deviates LESS than the candidate — the search "
              "did not find the minimum and this result is void", file=sys.stderr)
        return 1
    ok = [o for n, _, o in results if n == neighbours[2]][0]
    if not ok:
        print("light scale: the candidate does not satisfy C1-C3 — the minimum of the "
              "deviation is outside the region the other criteria allow, which is a "
              "finding, not a scale", file=sys.stderr)
        return 1

    print()
    print(f"light scale: {best}")
    print(f"             deviation {centre:.4f}, tolerance "
          f"{measure_exposure.albedo_tolerance():.4f}")
    print("             lower and higher neighbours both deviate more — a minimum")
    return 0


if __name__ == "__main__":
    sys.exit(main())
