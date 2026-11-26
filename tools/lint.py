"""House-rule lint: no em dashes in anything a person reads.

  python tools/lint.py

Checks docs, READMEs, planner and making-of pages, critic reports, and the text inside Luau
strings (player-facing UI text). Luau comments are allowed to have them. Exits 1 on any hit.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BAD = ("—", "&mdash;", "&#8212;", "&#x2014;")
TEXT_GLOBS = ["*.md", "docs/**/*.md", "art/**/*.md", "audio/**/*.md", "tools/**/*.md",
              "planner/**/*.html", "docs/**/*.html", "docs/**/*.json"]
SKIP_PARTS = {"node_modules", "artifacts", "build", ".git"}


def luau_string_hits(text: str) -> list[int]:
    """Line numbers where an em dash sits inside a Luau string (not a comment)."""
    hits: list[int] = []
    i, line, n = 0, 1, len(text)
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
        elif text.startswith("--", i):
            if text.startswith("--[", i) and (j := text.find("[", i + 3)) != -1 and set(text[i + 3:j]) <= {"="}:
                close = "]" + "=" * (j - i - 3) + "]"
                end = text.find(close, j)
                end = n if end == -1 else end + len(close)
            else:
                end = text.find("\n", i)
                end = n if end == -1 else end
            line += text.count("\n", i, end)
            i = end
        elif c in "\"'`":
            j = i + 1
            while j < n and text[j] != c and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            if any(b in text[i:j] for b in BAD):
                hits.append(line)
            i = j + 1
        elif c == "[" and (j := text.find("[", i + 1)) != -1 and set(text[i + 1:j]) <= {"="} and (j - i - 1) == text[i + 1:j].count("="):
            close = "]" + "=" * (j - i - 1) + "]"
            end = text.find(close, j)
            end = n if end == -1 else end + len(close)
            if any(b in text[i:end] for b in BAD):
                hits.append(line)
            line += text.count("\n", i, end)
            i = end
        else:
            i += 1
    return hits


def main() -> int:
    problems: list[str] = []
    seen: set[Path] = set()
    for g in TEXT_GLOBS:
        for p in ROOT.glob(g):
            if p in seen or SKIP_PARTS & set(p.relative_to(ROOT).parts) or not p.is_file():
                continue
            seen.add(p)
            for k, ln in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                if any(b in ln for b in BAD):
                    problems.append(f"{p.relative_to(ROOT)}:{k}: em dash in reader-facing text")
    for p in ROOT.glob("src/**/*.luau"):
        for k in luau_string_hits(p.read_text(encoding="utf-8", errors="replace")):
            problems.append(f"{p.relative_to(ROOT)}:{k}: em dash inside a string (player text)")
    for x in problems:
        print(x)
    print(f"lint: {len(seen)} text files and the Luau strings in src/ checked, {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
