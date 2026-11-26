"""Rank every sound's variants with the cheap critic (Gemini 4 Hydrogen), copy each winner to
audio/final/<id>.mp3 and write one report to docs/critic/<date>-sound-variants-hydrogen.md.

    python tools/audio/rank_all.py [--only id1,id2]
"""
import argparse
import datetime as dt
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "critic"))
import critic  # noqa: E402
import gemini  # noqa: E402

VARIANTS = ROOT / "audio" / "variants"
FINAL = ROOT / "audio" / "final"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    only = set(filter(None, args.only.split(",")))
    specs = json.loads((ROOT / "audio" / "sounds.json").read_text(encoding="utf-8"))["sounds"]
    FINAL.mkdir(parents=True, exist_ok=True)
    rows = []
    for spec in specs:
        if only and spec["id"] not in only:
            continue
        files = sorted(VARIANTS.glob(f"{spec['id']}-*.mp3"))
        if not files:
            continue
        uploaded: list[str] = []
        try:
            parts = [
                {"text": critic.CONTEXT},
                {
                    "text": (
                        f"These are {len(files)} variants of one game sound, '{spec['id']}'. What it should be: "
                        f"{spec['prompt']}. Rank them best first for use in the game: fits the description, clean "
                        "(no artifacts, clicks, voices or music where none belongs), right length and loudness, "
                        "and for loops, whether the end joins the start smoothly. Use each file's name as given."
                    )
                },
            ]
            parts += critic.media_parts(files, uploaded)
            verdict = gemini.generate(gemini.MODELS["hydrogen"], parts, critic.RANK_SCHEMA)
        finally:
            for name in uploaded:
                gemini.delete(name)
        best = verdict["ranking"][0]
        src = next((f for f in files if f.name == best["file"]), files[0])
        shutil.copyfile(src, FINAL / f"{spec['id']}.mp3")
        rows.append((spec["id"], src.name, best["score"], best["note"], verdict["summary"]))
        print(f"{spec['id']}: {src.name} ({best['score']})")
    out = ROOT / "docs" / "critic" / f"{dt.date.today().isoformat()}-sound-variants-hydrogen.md"
    lines = [
        "# Critic: sound variants (rank, gemini-4-hydrogen)",
        "",
        "Each sound in `audio/sounds.json` was generated in 2 or 3 variants with ElevenLabs; Hydrogen listened to them and the winner was copied to `audio/final/`.",
        "",
        "| Sound | Winner | Score | Why |",
        "|---|---|---|---|",
        *[f"| {r[0]} | `{r[1]}` | {r[2]} | {r[3]} |" for r in rows],
        "",
        "Action taken: winners copied to `audio/final/`; Neon reviews them in context once they play in the game.",
        "",
    ]
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
