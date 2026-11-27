"""Pack short one-shot sounds into one "sound sheet" file (audio/UPLOAD-PLAN.md).

Roblox counts audio uploads, so a sheet holds several sounds and the game plays each as a
region (Shared/SoundSheets.luau). This reads a sheet's cues from SoundSheets.luau, places
each sound at its cue's start with ffmpeg (trimmed to the cue's length, a short fade out so
nothing clicks), and writes one mp3 ready to upload.

    python tools/audio/build_sheet.py sheet-water
    python tools/audio/build_sheet.py sheet-water --map bobber-plop=audio/final/splash-small.mp3
    python tools/audio/build_sheet.py sheet-ui --out artifacts/sheet-ui.mp3

By default each cue's file is audio/final/<cue>.mp3. Missing files are listed and the sheet
is not built unless --allow-gaps is given (gaps stay silent). Needs ffmpeg on PATH.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHEETS = ROOT / "src/ReplicatedStorage/Shared/SoundSheets.luau"


def read_cues(sheet: str) -> dict[str, tuple[float, float]]:
    src = SHEETS.read_text(encoding="utf-8")
    m = re.search(r'\["' + re.escape(sheet) + r'"\]\s*=\s*\{(.*?)\n\t\},', src, re.S)
    if not m:
        sys.exit(f"No sheet named {sheet} in {SHEETS.relative_to(ROOT)}")
    cues = {}
    for name, start, length in re.findall(r'\["([\w-]+)"\]\s*=\s*\{\s*start\s*=\s*([0-9.]+),\s*length\s*=\s*([0-9.]+)', m.group(1)):
        cues[name] = (float(start), float(length))
    return cues


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sheet")
    ap.add_argument("--map", action="append", default=[], help="cue=path to use a different file for a cue")
    ap.add_argument("--out", default="")
    ap.add_argument("--allow-gaps", action="store_true")
    a = ap.parse_args()
    cues = read_cues(a.sheet)
    files = {c: ROOT / "audio" / "final" / f"{c}.mp3" for c in cues}
    for m in a.map:
        c, path = m.split("=", 1)
        files[c] = Path(path) if Path(path).is_absolute() else ROOT / path
    missing = [c for c, f in files.items() if not f.exists()]
    if missing and not a.allow_gaps:
        print("Missing files:", ", ".join(missing))
        return 1
    present = [(c, cues[c], files[c]) for c in cues if c not in missing]
    total = max(s + l for s, l in cues.values()) + 0.2
    out = Path(a.out) if a.out else ROOT / "audio" / "sheets" / f"{a.sheet}.mp3"
    out.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error"]
    for _, _, f in present:
        cmd += ["-i", str(f)]
    parts, labels = [], []
    for i, (c, (start, length), _) in enumerate(present):
        fade = min(0.08, length / 4)
        ms = int(round(start * 1000))
        parts.append(f"[{i}:a]aresample=44100,aformat=channel_layouts=stereo,atrim=0:{length},asetpts=PTS-STARTPTS,"
                     f"afade=t=out:st={max(0.0, length - fade):.3f}:d={fade:.3f},adelay={ms}|{ms}[a{i}]")
        labels.append(f"[a{i}]")
    graph = ";".join(parts) + ";" + "".join(labels) + f"amix=inputs={len(present)}:normalize=0,apad,atrim=0:{total:.2f}[out]"
    cmd += ["-filter_complex", graph, "-map", "[out]", "-ac", "2", "-ar", "44100", "-b:a", "192k", str(out)]
    subprocess.run(cmd, check=True)
    print(f"wrote {out} ({total:.1f} s, {len(present)} of {len(cues)} cues)")
    for c, (start, length), f in present:
        print(f"  {c:<20} {start:>5.2f} s +{length:.2f} s  from {f.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
