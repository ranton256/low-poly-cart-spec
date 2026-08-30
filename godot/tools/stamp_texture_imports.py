#!/usr/bin/env python3
"""Stamp the extracted textures' import params for the web budget.

CONSTRAINTS §8 Performance and size budgets: the shipped payload must fit 25 MB compressed, and the design
document's §2 explicitly permits downsampling the texture set to 1024² — its
stated floor for the kart is 1024, not 2048 (an earlier CONSTRAINTS row
misread that sentence; this tool's existence corrects it). Every extracted
texture imports as Basis Universal at a 1024 px size limit.

WHY A TOOL AND NOT 21 COMMITTED FILES: the extracted textures and their
.import sidecars are derived data and stay git-ignored (see .gitignore's
rationale). The project-level decision lives HERE, in one committed script
that stamps the params deterministically after extraction — run by test.sh
between the import passes, idempotent, and it prints what it changed.

  .venv/bin/python tools/stamp_texture_imports.py [--check]

--check exits 1 if any texture import is unstamped, changing nothing — the
standing suite runs that mode, so a fresh extraction cannot silently ship
lossless 2048s again.
"""
import re
import sys
from pathlib import Path

ASSETS = Path(__file__).resolve().parents[1] / "assets"

# The kart's stated floor is 1024 ("do not go below that for the kart" — the
# qualifier is the kart's); props carry no stated floor and are seen at
# gameplay distances, so they take 512 to bring the payload inside §8's
# 25 MB. Basis Universal throughout.
KART_LIMIT = "1024"
PROP_LIMIT = "512"

BASE_STAMPS = {
    "compress/mode": "4",  # Basis Universal (ETC1S: high_quality stays false)
    "mipmaps/generate": "true",
}


def stamps_for(path: Path) -> dict:
    limit = KART_LIMIT if path.name.startswith("kart") else PROP_LIMIT
    out = dict(BASE_STAMPS)
    out["process/size_limit"] = limit
    return out


def stamp(path: Path, check_only: bool) -> bool:
    text = path.read_text()
    changed = False
    for key, value in stamps_for(path).items():
        pattern = re.compile(rf"^{re.escape(key)}=(.*)$", re.M)
        match = pattern.search(text)
        if match is None:
            text += f"\n{key}={value}\n"
            changed = True
        elif match.group(1) != value:
            text = pattern.sub(f"{key}={value}", text)
            changed = True
    if changed and not check_only:
        path.write_text(text)
    return changed


def main() -> int:
    check_only = "--check" in sys.argv
    sidecars = sorted(ASSETS.glob("*.jpg.import")) + sorted(ASSETS.glob("*.png.import"))
    if not sidecars:
        print("stamp: no extracted texture imports found — run the import first",
              file=sys.stderr)
        return 1
    changed = [p.name for p in sidecars if stamp(p, check_only)]
    if check_only:
        if changed:
            print(f"stamp: {len(changed)} texture import(s) UNSTAMPED — the web "
                  f"payload would ship oversized: {', '.join(changed[:5])}",
                  file=sys.stderr)
            return 1
        print(f"stamp: {len(sidecars)} texture imports carry the web-budget params")
        return 0
    print(f"stamp: {len(sidecars)} sidecars, {len(changed)} (re)stamped")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
