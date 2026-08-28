#!/usr/bin/env python3
"""Enforce the architectural boundaries in CONSTRAINTS §4 Architectural boundaries.

Two rules, one mechanism:

  core_purity      godot/scripts/core/ may not touch the engine. The simulation
                   must be constructible and steppable with no scene loaded.
  physics_engine   nowhere in godot/ may touch the Godot physics engine. The
                   design document's tick is a scalar recurrence with no solver.

Both symbol lists live in godot/data/banned_symbols.json, which the commit hook
reads too — a private copy in each tool is how the two drift apart.

MATCHING IS WHOLE-WORD, AND THAT IS LOAD-BEARING. rng.gd defines randf01(),
which contains the banned substring "randf"; rng.gd and sim.gd both mention
randi() in comments saying not to use it. A substring grep flags the very files
these rules exist to mandate. So:

  - comments are stripped before matching (a warning about a symbol is not a use)
  - string literals are NOT stripped: get_node("...") style dynamic access is
    precisely what core purity exists to prevent
  - "call" symbols require a following "(", "namespace" symbols a following "."
  - everything is anchored on word boundaries

Deliberately break it by adding get_tree() to a core script, or a physics body
anywhere under godot/.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = ROOT / "godot"
DATA = GODOT / "data" / "banned_symbols.json"

# Every text format Godot can carry a node or resource type in — not just .gd
# and .tscn. A saved CollisionShape3D lives in a .tres; .escn is Blender's
# exporter format; project.godot itself can name a class. An earlier version
# scanned two suffixes while V4 claimed "anywhere under godot/", which is the
# same over-claim as enumerating directories, one level down. Compared
# case-insensitively: EVIL.GD is a GDScript file.
SCAN_SUFFIXES = (".gd", ".tscn", ".tres", ".escn", ".godot", ".cfg", ".import")
# Caches and the tooling virtualenv only. NOT templates/ — an earlier version
# skipped it, and skipping any authored directory is how "anywhere" quietly
# becomes "four directories I happened to name".
SKIP_PARTS = {".godot", ".venv", "__pycache__"}

# The core-purity rule is scoped; the physics rule is not. An earlier version
# enumerated four roots for the physics walk, so godot/addons/ and godot/*.gd at
# the top level were unscanned — the staged-only commit hook caught a violation
# the "full tree" gate missed. Walk godot/ itself.
CORE_ROOT = "scripts/core"


def strip_comments(text: str, suffix: str = ".gd") -> str:
    """Blank out # comments in GDScript, preserving line count and columns.

    Only for .gd. In .tscn, '#' is not a comment character — stripping from it
    would blind the gate to anything after a '#' in a scene file.

    Not a GDScript parser: a '#' inside a string literal is treated as a comment
    start. That direction is safe — it can only cause a missed detection inside
    a string, never a false positive — and the alternative is parsing GDScript.
    """
    if suffix.lower() != ".gd":
        return text
    out = []
    for line in text.split("\n"):
        idx = line.find("#")
        out.append(line if idx < 0 else line[:idx] + " " * (len(line) - idx))
    return "\n".join(out)


def pattern_for(symbol: str, kind: str) -> re.Pattern:
    name = re.escape(symbol)
    if kind == "call":
        return re.compile(rf"\b{name}\s*\(")
    if kind == "namespace":
        return re.compile(rf"\b{name}\s*\.")
    if kind == "sigil":
        # $Node or $"Node Name" — but NOT a bare "$" inside a string, which is
        # why the quote must be followed by an identifier character.
        return re.compile(r"\$\s*(?:[A-Za-z_]|[\"'][A-Za-z_])")
    return re.compile(rf"\b{name}\b")


def files_under(root: Path) -> list[Path]:
    if not root.exists():
        return []
    found = []
    # os.walk with followlinks, because Path.rglob does not descend symlinked
    # directories — a symlinked source tree would have been invisible.
    import os
    paths = []
    for dirpath, dirnames, filenames in os.walk(root, followlinks=True):
        dirnames[:] = [d for d in dirnames if d not in SKIP_PARTS]
        for name in filenames:
            paths.append(Path(dirpath) / name)
    for path in sorted(paths):
        if path.suffix.lower() not in SCAN_SUFFIXES:
            continue
        if SKIP_PARTS & set(path.parts):
            continue
        found.append(path)
    return found


def check(rule: dict, roots: list[Path], label: str) -> tuple[list[str], int, int]:
    findings = []
    compiled = [(s["name"], pattern_for(s["name"], s["kind"]), s["reason"])
                for s in rule["symbols"]]
    files = []
    for root in roots:
        files.extend(files_under(root))
    for path in files:
        text = strip_comments(path.read_text(encoding="utf-8", errors="replace"), path.suffix)
        for name, pattern, reason in compiled:
            for match in pattern.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                rel = path.relative_to(ROOT)
                findings.append(f"{label}: {rel}:{line}: '{name}' — {reason}")
    return findings, len(files), len(compiled)


def check_staged(stage_dir: Path, display_paths: list[str]) -> int:
    """Check blobs extracted from the git index, reporting their real paths.

    The commit hook calls this rather than re-implementing the matching in bash.
    An earlier hook built a bare alternation from the same symbol list — same
    data, different semantics — so it refused a COMMENT mentioning
    move_and_slide while the suite passed the identical file. Sharing the list
    is not enough; the matcher has to be shared too.
    """
    data = json.loads(DATA.read_text())
    findings = []
    unresolved = []
    for display in display_paths:
        blob = stage_dir / display
        if blob.suffix.lower() not in SCAN_SUFFIXES:
            continue
        if not blob.is_file():
            # Silently skipping a path we were HANDED is how a bypass hides: a
            # word-split filename arrived as two nonexistent paths and the
            # commit sailed through. Treat it as a failure, like the hook does
            # when git show cannot read a staged blob.
            unresolved.append(display)
            continue
        text = strip_comments(blob.read_text(encoding="utf-8", errors="replace"), blob.suffix)
        rules = [("physics engine", data["physics_engine"])]
        if display.startswith(f"godot/{CORE_ROOT}/"):
            rules.append(("core purity", data["core_purity"]))
        for label, rule in rules:
            for sym in rule["symbols"]:
                pattern = pattern_for(sym["name"], sym["kind"])
                for match in pattern.finditer(text):
                    line = text.count("\n", 0, match.start()) + 1
                    findings.append(f"{label}: {display}:{line}: "
                                    f"'{sym['name']}' — {sym['reason']}")
    for f in unresolved:
        print(f"boundaries: cannot resolve staged path {f!r} — refusing rather "
              f"than skipping it", file=sys.stderr)
    for f in findings:
        print(f, file=sys.stderr)
    return 1 if (findings or unresolved) else 0


def main() -> int:
    if "--staged" in sys.argv:
        i = sys.argv.index("--staged")
        return check_staged(Path(sys.argv[i + 1]), sys.argv[i + 2:])

    if not DATA.exists():
        print(f"error: {DATA} is missing — the shared banned-symbol list is the "
              f"single definition both this gate and the commit hook read",
              file=sys.stderr)
        return 1
    data = json.loads(DATA.read_text())

    core_findings, core_files, core_syms = check(
        data["core_purity"], [GODOT / CORE_ROOT], "core purity")
    phys_findings, phys_files, phys_syms = check(
        data["physics_engine"], [GODOT], "physics engine")

    # A gate that inspects nothing reports success and guards nothing. This
    # project has shipped that failure twice; it is now an explicit error.
    if core_files == 0:
        print("error: core purity gate found no files under godot/scripts/core/ — "
              "the layout changed and this gate is inspecting nothing", file=sys.stderr)
        return 1
    if phys_files == 0:
        print("error: physics gate found no files under godot/ — the layout "
              "changed and this gate is inspecting nothing", file=sys.stderr)
        return 1

    findings = core_findings + phys_findings
    if findings:
        for f in findings:
            print(f, file=sys.stderr)
        print(f"\nboundaries: {len(findings)} violation(s)", file=sys.stderr)
        return 1

    print(f"boundaries: core purity clean ({core_files} files under "
          f"godot/{CORE_ROOT}/ vs {core_syms} symbols), physics engine clean "
          f"({phys_files} files under godot/ vs {phys_syms} symbols)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
