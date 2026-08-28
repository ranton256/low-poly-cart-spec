#!/usr/bin/env python3
"""Verify that every "CONSTRAINTS §N" reference names the section it means.

Committed because a code review caught a break this class of check exists for:
inserting a new section renumbered "Release and packaging" from 10 to 11, and
ROADMAP.md went on pointing at 10 — which by then was "Automation and gates".

Worth knowing how this tool was got wrong the first time. Version one only
checked that the referenced section NUMBER existed, passed a clean tree, and
then failed to catch the very break above — because after a renumber a stale
"section 10" still names a real section, just the wrong one. Requiring the
title is what makes the reference self-checking. A gate that has not been seen
to fail is not evidence.

Game-agnostic apart from TARGET and LABEL below.

tools/check_links.py cannot catch this. The link target is the file, and the
file still resolves; only the section number inside the anchor text is wrong.

Every reference must carry the section title, not just the number:

    <LABEL> §11 Release and packaging    -> ok
    <LABEL> §11 Release                  -> ok, leading words must match
    <LABEL> §11                          -> REJECTED, a bare number is the
                                                form that renumbering breaks
                                                silently

    .venv/bin/python tools/check_section_refs.py
"""

import os
import re
import sys

TARGET = "CONSTRAINTS.md"  # at the repository root, not under godot/docs/
LABEL = "CONSTRAINTS"

SKIP_DIRS = {".git", ".godot", ".claude", ".cursor", ".agents", ".venv",
             "godot-game-skeleton", "exports", "gallery", "templates",
             "__pycache__", "node_modules"}

# Not just Markdown. A stale "§9 Review" in a shell script, a project file or a
# backlog entry rots exactly as badly as one in a document, and scanning only
# .md is why a batch of them survived a review. .att/ is included for the same
# reason and is therefore NOT skipped above.
SCANNED_SUFFIXES = (".md", ".py", ".sh", ".gd", ".toml", ".godot", ".yaml", ".yml")

HEADING = re.compile(r"^## (\d+)\.\s+(.+?)\s*$", re.MULTILINE)
# "<LABEL> §11 Release and packaging" — the title is REQUIRED. A bare number
# is rejected precisely because it is the form that renumbering breaks silently:
# after inserting a section, a stale "§10" still names a real section, just the
# wrong one. Carrying the title makes the reference self-checking.
REFERENCE = re.compile(rf"{LABEL} (?:§|section )(\d+)((?:\s+[A-Za-z]+){{0,4}})", re.I)


def sections(root: str) -> dict:
    path = os.path.join(root, TARGET)
    with open(path, encoding="utf-8") as handle:
        return {m.group(1): m.group(2) for m in HEADING.finditer(handle.read())}


def find_markdown(root: str):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if name.endswith(SCANNED_SUFFIXES) or name == "pre-commit":
                yield os.path.join(dirpath, name)


def check(root: str) -> int:
    known = sections(root)
    if not known:
        print(f"error: no numbered sections found in {TARGET}", file=sys.stderr)
        return 1

    problems = []
    checked = 0
    for path in sorted(find_markdown(root)):
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        for match in REFERENCE.finditer(text):
            number = match.group(1)
            trailing = match.group(2).strip()
            checked += 1
            line = text.count("\n", 0, match.start()) + 1
            rel = os.path.relpath(path, root)

            if number not in known:
                problems.append(f"{rel}:{line}: §{number} does not exist")
                continue

            actual = known[number]
            if not trailing:
                problems.append(
                    f'{rel}:{line}: §{number} has no title — write "{LABEL} §{number} {actual}". '
                    "A bare number still resolves after a renumber, just to the wrong section."
                )
                continue

            # The words after the number run into ordinary prose ("§7 Verification
            # criteria is ✅"), so compare leading words rather than the whole
            # capture: at least the first word must match the real title.
            # "§11 Release" is fine; "§10 Release" against "Automation and gates"
            # matches nothing and fails.
            ref_words = trailing.lower().split()
            title_words = actual.lower().split()
            matched = 0
            for ref_word, title_word in zip(ref_words, title_words):
                if ref_word != title_word:
                    break
                matched += 1
            if matched == 0:
                problems.append(
                    f'{rel}:{line}: §{number} is "{actual}", but the reference says "{trailing}"'
                )

    for entry in problems:
        print(f"stale section reference: {entry}", file=sys.stderr)

    if problems:
        print(f"\nsection refs: {len(problems)} of {checked} are stale", file=sys.stderr)
        return 1

    print(f"section refs: {checked} references resolve")
    return 0


if __name__ == "__main__":
    # The repository root — see check_links.py.
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..")
    sys.exit(check(root))
