"""Print a small Luau snippet that brings Studio's scripts up to date with src/ by patching
only the changed blocks (find and replace with a few lines of context), plus full text for
new files. Much smaller than push_snippet.py for edits to big files.

    python tools/sync/patch_snippet.py [--base REF] [--out FILE] src/path/a.luau ...

--base is the git ref Studio currently matches (default HEAD). For each file, if it exists
at --base the snippet replaces each changed block (each find text must appear exactly once
in Studio's copy, or the file is reported and left alone); otherwise the whole file is set.
Paste the output into execute_luau (Edit). It returns what it changed and each file's checksum
(compare with tools/sync/verify.py's checksum).
"""
from __future__ import annotations

import argparse
import difflib
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_manifest import ROOT, SRC, classify  # noqa: E402

LEVEL = "=" * 5


def quote(s: str) -> str:
    assert "]" + LEVEL + "]" not in s
    return "[" + LEVEL + "[" + s + "]" + LEVEL + "]"


def at_base(ref: str, rel: str) -> str | None:
    try:
        out = subprocess.check_output(["git", "show", f"{ref}:{rel}"], cwd=ROOT, stderr=subprocess.DEVNULL)
        return out.decode("utf-8").replace("\r\n", "\n")
    except subprocess.CalledProcessError:
        return None


def hunks(old: str, new: str, ctx: int = 3) -> list[tuple[str, str]]:
    a, b = old.split("\n"), new.split("\n")
    out = []
    for group in difflib.SequenceMatcher(None, a, b, autojunk=False).get_grouped_opcodes(ctx):
        i1, i2 = group[0][1], group[-1][2]
        j1, j2 = group[0][3], group[-1][4]
        out.append(("\n".join(a[i1:i2]), "\n".join(b[j1:j2])))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="HEAD")
    ap.add_argument("--out", default="")
    ap.add_argument("files", nargs="+")
    a = ap.parse_args()
    lines = [
        "local NL = string.char(10)",
        "local report = {}",
        "local function node(path, make, cls)",
        "\tlocal n = game:GetService(path[1])",
        "\tlocal i = 2",
        "\tif path[1] == 'StarterPlayer' then n = n:WaitForChild(path[2]) i = 3 end",
        "\tfor j = i, #path - 1 do",
        "\t\tlocal c = n:FindFirstChild(path[j])",
        "\t\tif not c then c = Instance.new('Folder') c.Name = path[j] c.Parent = n end",
        "\t\tn = c",
        "\tend",
        "\tlocal s = n:FindFirstChild(path[#path])",
        "\tif not s and make then s = Instance.new(cls) s.Name = path[#path] s.Parent = n end",
        "\treturn s",
        "end",
        "local function sum(s)",
        "\tlocal src = s.Source:gsub(string.char(13) .. NL, NL)",
        "\tlocal h = 0",
        "\tfor i = 1, #src do h = (h * 31 + string.byte(src, i)) % 4294967296 end",
        "\treturn #src .. ':' .. h",
        "end",
        "local function patch(path, edits)",
        "\tlocal s = node(path, false)",
        "\tif not s then table.insert(report, path[#path] .. ' MISSING') return end",
        "\tlocal src = s.Source:gsub(string.char(13) .. NL, NL)",
        "\tfor k, e in edits do",
        "\t\tlocal i, j = string.find(src, e[1], 1, true)",
        "\t\tlocal again = i and string.find(src, e[1], j + 1, true)",
        "\t\tif not i or again then table.insert(report, path[#path] .. ' hunk ' .. k .. (if i then ' NOT UNIQUE' else ' NOT FOUND')) return end",
        "\t\tsrc = string.sub(src, 1, i - 1) .. e[2] .. string.sub(src, j + 1)",
        "\tend",
        "\ts.Source = src",
        "\ttable.insert(report, path[#path] .. ' ' .. #edits .. ' hunks ' .. sum(s))",
        "end",
        "local function put(path, cls, text)",
        "\tlocal s = node(path, true, cls)",
        "\ts.Source = text",
        "\ttable.insert(report, path[#path] .. ' set ' .. sum(s))",
        "end",
    ]
    for f in a.files:
        full = os.path.abspath(f)
        rel = os.path.relpath(full, ROOT).replace("\\", "/")
        srel = os.path.relpath(full, SRC).replace("\\", "/")
        name, cls = classify(os.path.basename(full))
        parts = srel.split("/")[:-1] + [name]
        path = "{" + ", ".join(repr(p) for p in parts) + "}"
        new = open(full, encoding="utf-8").read().replace("\r\n", "\n")
        old = at_base(a.base, rel)
        if old is None:
            lines.append(f"put({path}, '{cls}', {quote(new)})")
        elif old != new:
            edits = ", ".join("{" + quote(x) + ", " + quote(y) + "}" for x, y in hunks(old, new))
            lines.append(f"patch({path}, {{{edits}}})")
    lines.append("return table.concat(report, ' | ')")
    text = "\n".join(lines)
    if a.out:
        open(a.out, "w", encoding="utf-8").write(text)
        print(f"{a.out}: {len(text)} chars")
    else:
        print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
