"""ElevenLabs sound generation (standard library only).

    python tools/audio/eleven.py sfx  --id bite-nibble --variants 3 --seconds 1.5 "prompt..."
    python tools/audio/eleven.py music --id theme-lake --seconds 60 "prompt..."
    python tools/audio/eleven.py batch audio/sounds.json [--only id1,id2]

Writes audio/variants/<id>-<n>.mp3. Pick the best with the critic's rank mode (Hydrogen),
copy it to audio/final/<id>.mp3 and record prompt, choice and asset id in audio/README.md.

Key: ELEVENLABS_API_KEY in the repo's .env (never committed, never printed).
Models (docs/DIRECTION.md): SFX v3 `eleven_text_to_sound_v3`, Eleven Music v2.5 `music_v2_5`.
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "audio" / "variants"
SFX_MODEL = "eleven_text_to_sound_v3"
MUSIC_MODEL = "music_v2_5"
API = "https://api.elevenlabs.io"


def api_key() -> str:
    key = os.environ.get("ELEVENLABS_API_KEY", "")
    env = ROOT / ".env"
    if not key and env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            if line.strip().startswith("ELEVENLABS_API_KEY="):
                key = line.split("=", 1)[1].strip().strip('"').strip("'")
    if not key:
        raise SystemExit("ELEVENLABS_API_KEY is missing: put it in the repo's .env (see .env.example).")
    return key


def post(path: str, body: dict) -> bytes:
    req = urllib.request.Request(
        API + path,
        data=json.dumps(body).encode(),
        method="POST",
        headers={"xi-api-key": api_key(), "Content-Type": "application/json", "Accept": "audio/mpeg"},
    )
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        raise SystemExit(f"ElevenLabs error {e.code} on {path}: {e.read().decode('utf-8', 'replace')[:600]}")


def sfx(prompt: str, seconds: float | None, loop: bool, influence: float) -> bytes:
    body = {"text": prompt, "model_id": SFX_MODEL, "prompt_influence": influence}
    if seconds:
        body["duration_seconds"] = seconds
    if loop:
        body["loop"] = True
    return post("/v1/sound-generation", body)


def music(prompt: str, seconds: float) -> bytes:
    return post("/v1/music", {"prompt": prompt, "music_length_ms": int(seconds * 1000), "model_id": MUSIC_MODEL})


def save(sound_id: str, n: int, data: bytes) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    p = OUT / f"{sound_id}-{n}.mp3"
    p.write_bytes(data)
    return p


def run_one(spec: dict) -> list[Path]:
    paths = []
    for n in range(1, int(spec.get("variants", 3)) + 1):
        if spec.get("kind", "sfx") == "music":
            data = music(spec["prompt"], float(spec.get("seconds", 30)))
        else:
            data = sfx(spec["prompt"], spec.get("seconds"), bool(spec.get("loop")), float(spec.get("influence", 0.5)))
        p = save(spec["id"], n, data)
        paths.append(p)
        print(f"  {p.relative_to(ROOT)} ({len(data) // 1024} KB)")
    return paths


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("kind", choices=["sfx", "music", "batch"])
    ap.add_argument("prompt_or_file")
    ap.add_argument("--id")
    ap.add_argument("--variants", type=int, default=3)
    ap.add_argument("--seconds", type=float)
    ap.add_argument("--loop", action="store_true")
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    if args.kind == "batch":
        specs = json.loads((ROOT / args.prompt_or_file).read_text(encoding="utf-8"))["sounds"]
        only = set(filter(None, args.only.split(",")))
        for spec in specs:
            if only and spec["id"] not in only:
                continue
            print(spec["id"])
            run_one(spec)
    else:
        if not args.id:
            sys.exit("--id is required")
        run_one({"id": args.id, "kind": args.kind, "prompt": args.prompt_or_file, "variants": args.variants, "seconds": args.seconds, "loop": args.loop})


if __name__ == "__main__":
    main()
