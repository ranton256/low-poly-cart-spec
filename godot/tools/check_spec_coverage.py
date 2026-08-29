#!/usr/bin/env python3
"""G1 — every scenario in the design document is accounted for.

CONSTRAINTS §5 Conformance to the specification names this as the gate that makes
a milestone's "done" claim honest: a specified behaviour nobody verified should
fail the suite rather than sit unnoticed until M8.

Every `### Scenario:` heading must be claimed exactly once, as one of:

  verified   a test claims it, with a `# @covers <Feature> / <Scenario>` line
             beside the function. Beside the code, so it moves with the code.
  visual     godot/data/scenario_register.json, with a reason it cannot be
             checked headlessly and the capture that covers it (or the
             milestone that will produce one). An entry may also set
             "unmet": true, meaning the capture shows the scenario FAILING —
             evidence worth committing, but never counted as coverage.
  deferred   the same register, with the milestone that owns it.

MATCHING IS VERBATIM. Rewording a heading in the design document breaks every
claim on it, on purpose: a fuzzy match would absorb the rename silently, and the
document is normative. The same reasoning makes CONSTRAINTS §13 Automation and
gates require section references carry their titles.

WHAT THIS GATE CANNOT DO. It cannot tell whether a `verified` claim's test
actually tests that scenario, or whether a `deferred` scenario really belongs to
the milestone named. It raises the floor from "nobody knows" to "every scenario
has a named owner and a named status" — no further. Deferrals are therefore
counted per milestone on every run, so a milestone's completion claim has to
answer to its own number.

Deliberately break it by removing a @covers line, claiming one scenario twice, or
rewording a heading in the design document.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GDD = ROOT / "low-poly-cart-game-design-document.md"
REGISTER = ROOT / "godot" / "data" / "scenario_register.json"
TESTS = ROOT / "godot" / "tests"

FEATURE = re.compile(r"^## Feature:\s*(.+?)\s*$", re.M)
SCENARIO = re.compile(r"^### Scenario(?: Outline)?:\s*(.+?)\s*$", re.M)
# Two forms. Inline for short headings; a continuation for long ones, because
# gdlint caps a line at 100 characters and some headings do not fit beside the
# marker. The claim text itself is never abbreviated — it must match the design
# document verbatim.
#
#   # @covers Feature / Scenario
#
#   # @covers
#   #   Feature / Scenario
COVERS_INLINE = re.compile(r"^\s*#\s*@covers[ \t]+(\S.*?)\s*$", re.M)
COVERS_BLOCK = re.compile(r"^\s*#\s*@covers[ \t]*\n((?:\s*#[ \t]+.+\n)+)", re.M)


def document_scenarios(text: str) -> list[str]:
    """Every scenario in the document, as 'Feature / Scenario'."""
    out = []
    feature = None
    for line in text.split("\n"):
        fm = FEATURE.match(line)
        if fm:
            feature = fm.group(1)
            continue
        sm = SCENARIO.match(line)
        if sm and feature:
            out.append(f"{feature} / {sm.group(1)}")
    return out


def test_claims() -> dict:
    """claim -> list of files claiming it. Discovered by scanning, not a list."""
    claims: dict = {}
    if not TESTS.exists():
        return claims
    for path in sorted(TESTS.rglob("*.gd")):
        text = path.read_text(encoding="utf-8", errors="replace")
        rel = str(path.relative_to(ROOT))
        for match in COVERS_INLINE.finditer(text):
            claims.setdefault(match.group(1), []).append(rel)
        for match in COVERS_BLOCK.finditer(text):
            for line in match.group(1).strip().split("\n"):
                claim = line.strip().lstrip("#").strip()
                if claim:
                    claims.setdefault(claim, []).append(rel)
    return claims


def main() -> int:
    if not GDD.exists():
        print(f"error: {GDD} not found", file=sys.stderr)
        return 1

    scenarios = document_scenarios(GDD.read_text())
    if not scenarios:
        print("error: no scenarios found in the design document — the heading "
              "format changed and this gate is inspecting nothing", file=sys.stderr)
        return 1

    dupes_in_doc = [s for s in set(scenarios) if scenarios.count(s) > 1]
    claims = test_claims()
    register = json.loads(REGISTER.read_text()) if REGISTER.exists() else {"entries": []}
    entries = register.get("entries", [])

    failures = []
    claimed: dict = {}

    for claim, files in claims.items():
        for f in files:
            claimed.setdefault(claim, []).append(f"test {f}")

    for i, entry in enumerate(entries):
        key = f"{entry.get('feature', '?')} / {entry.get('scenario', '?')}"
        kind = entry.get("kind")
        claimed.setdefault(key, []).append(f"register[{i}] ({kind})")
        if kind == "deferred" and not str(entry.get("milestone", "")).strip():
            failures.append(f"register[{i}] defers {key!r} without naming a milestone")
        elif kind == "visual":
            if not str(entry.get("reason", "")).strip():
                failures.append(f"register[{i}] marks {key!r} visual without a reason")
            # A capture can show a scenario FAILING. That is evidence, and it is
            # worth committing — but counting it as coverage would let the gate
            # report a scenario as covered while the project knows it is not met.
            # An entry that says so must name the milestone that owns the fix, and
            # is counted as unmet rather than visual.
            if entry.get("unmet"):
                if not str(entry.get("milestone", "")).strip():
                    failures.append(f"register[{i}] marks {key!r} unmet without naming "
                                    f"the milestone that owns the fix")
                if not str(entry.get("capture", "")).strip():
                    failures.append(f"register[{i}] marks {key!r} unmet without the "
                                    f"capture that shows it")
            if not str(entry.get("capture", "")).strip() and not str(entry.get("milestone", "")).strip():
                failures.append(f"register[{i}] marks {key!r} visual with neither a "
                                f"capture nor the milestone that will produce one")
        elif kind not in ("visual", "deferred"):
            failures.append(f"register[{i}] has unknown kind {kind!r} for {key!r}")

    known = set(scenarios)
    unclaimed = [s for s in scenarios if s not in claimed]
    doubled = {k: v for k, v in claimed.items() if len(v) > 1}
    stale = [k for k in claimed if k not in known]

    if dupes_in_doc:
        failures.append("the design document itself repeats a scenario heading, so a "
                        "claim on it is ambiguous: " + "; ".join(sorted(dupes_in_doc)))
    for s in unclaimed:
        failures.append(f"unclaimed: {s}")
    for k, v in sorted(doubled.items()):
        failures.append(f"claimed {len(v)} times: {k} — by {', '.join(v)}")
    for k in sorted(stale):
        failures.append(f"claims a scenario the document does not contain: {k} "
                        f"— by {', '.join(claimed[k])}")

    verified = sum(1 for k in claimed if k in known and any(c.startswith("test ") for c in claimed[k]))
    visual = sum(1 for e in entries if e.get("kind") == "visual" and not e.get("unmet"))
    unmet = sum(1 for e in entries if e.get("unmet"))
    deferred_by_ms: dict = {}
    for e in entries:
        if e.get("kind") == "deferred":
            deferred_by_ms.setdefault(e.get("milestone", "?"), 0)
            deferred_by_ms[e.get("milestone", "?")] += 1

    if failures:
        for f in failures:
            print(f"coverage: {f}", file=sys.stderr)
        print(f"\ncoverage: {len(failures)} problem(s) across {len(scenarios)} "
              f"scenarios", file=sys.stderr)
        return 1

    by_ms = ", ".join(f"{m}:{n}" for m, n in sorted(deferred_by_ms.items()))
    unmet_note = f", {unmet} UNMET" if unmet else ""
    print(f"coverage: {len(scenarios)} scenarios — {verified} verified, {visual} visual{unmet_note}, "
          f"{sum(deferred_by_ms.values())} deferred ({by_ms})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
