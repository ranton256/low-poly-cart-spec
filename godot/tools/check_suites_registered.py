#!/usr/bin/env python3
"""Every test suite under godot/tests/ is actually run by tools/test.sh.

THIS GATE EXISTS BECAUSE THE PROJECT SHIPPED WITHOUT IT. Commit 3f43233 added
tests/driver_test.gd, tests/kart_test.gd and tests/input_test.gd and registered
none of them; they passed when run by hand and protected nothing on any later
run. 20e61fa fixed it by hand, which fixes the instance and not the class.

A suite that is not registered is worse than no suite: it reads as coverage, it
passes when someone runs it directly, and it is silent for everyone else.

  tools/check_suites_registered.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TESTS = ROOT / "tests"
RUNNER = ROOT / "tools" / "test.sh"

# Files under tests/ that are NOT suites. Each needs a reason, so that adding a
# name here is a decision rather than a way to silence the gate.
NOT_SUITES = {
    "harness.gd": "the assertion helper every suite imports",
    "capture_scene.gd": "the windowed capture entry point, driven by tools/capture.sh",
}


def main() -> int:
    if not RUNNER.exists():
        print(f"error: {RUNNER} is missing", file=sys.stderr)
        return 1

    runner = RUNNER.read_text()
    # Only lines that actually RUN a suite. A commented-out line is not a run,
    # and test.sh carries a block of them as a roadmap of suites still to come.
    registered = set()
    for line in runner.splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        # The line must actually RUN the suite. Matching a bare mention anywhere on
        # a non-comment line let `echo skipping   # tests/foo_test.gd` count as
        # registration — review demonstrated it. A run is godot invoked with -s.
        if not re.search(r"\bgodot\b.*(-s|--script)\s", stripped):
            continue
        for match in re.finditer(r"tests/(\w+\.gd)", stripped):
            registered.add(match.group(1))

    present = {p.name for p in TESTS.glob("*.gd")}
    suites = {name for name in present if name not in NOT_SUITES}
    if not suites:
        print(f"error: no suites found under {TESTS} — the layout changed and "
              f"this gate is inspecting nothing", file=sys.stderr)
        return 1

    unregistered = sorted(suites - registered)
    if unregistered:
        for name in unregistered:
            print(f"suites: tests/{name} is never run by tools/test.sh — it reads "
                  f"as coverage and is silent for everyone who does not run it by "
                  f"hand", file=sys.stderr)
        print(f"\nsuites: {len(unregistered)} unregistered suite(s)", file=sys.stderr)
        return 1

    # A registered suite that no longer exists fails too: test.sh would die on it,
    # but naming it here says why rather than leaving a bare "no such file".
    missing = sorted(name for name in registered if name not in present)
    if missing:
        for name in missing:
            print(f"suites: tools/test.sh runs tests/{name}, which does not exist",
                  file=sys.stderr)
        return 1

    print(f"suites: {len(suites)} suites under tests/, all registered in test.sh "
          f"({len(NOT_SUITES)} helpers excluded by name)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
