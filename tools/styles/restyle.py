"""Style options for Liam: restyle our real screenshots with Gemini's image model, then have
Gemini 4 Neon score each style. Set aside work; nothing here touches the game.

    python tools/styles/restyle.py gen [--model nano] [--styles a,b] [--bases a,b] [--force]
    python tools/styles/restyle.py critic [--styles a,b]
    python tools/styles/restyle.py report      (scores.md and the vote page's style data)

Images go to docs/styles/<style>/<base>.jpg; critic verdicts to docs/styles/<style>/critic.json
and a summary row in docs/styles/scores.md. The key comes from GEMINI_API_KEY in the
environment, the repo's .env, or the main checkout's .env (worktrees have none). Never printed.
"""
import argparse
import base64
import io
import json
import os
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "critic"))
import gemini  # noqa: E402

ROOT = gemini.ROOT
OUT = ROOT / "docs" / "styles"
STILLS = ROOT / "docs" / "making-of" / "stills"
MAIN_ENV = Path(r"C:\Users\stewa\Documents\Claude\Roblox\.env")

IMAGE_MODELS = {
    "nano": "gemini-nano-banana-2.1",  # Nano Banana 2.1: Google's recommended image model (docs, 2026-11-26)
    "pro": "gemini-3-pro-image",  # Nano Banana Pro: reasoning-heavy, 4x the price
}

BASES = {
    "lake": ("2026-11-25-m1-lake-overview.jpg", "the lake seen from high above the spawn: a wide lake with a wooden dock reaching into it from the near shore, a bait shop stand and a fish buyer stand on the shore by the dock, a weed bed on the left, sunken logs on the right"),
    "dock": ("2026-11-26-models-dock-after.jpg", "the lake shore by the bait shop: a long wooden plank dock with lamp posts at the far end runs out into the lake, a sandy path along the shore, the striped awning of the bait shop stand in the near corner, reeds in the water on the left, the sign to Cedar Creek in the distance"),
    "creek": ("2026-11-25-creek-riffle.jpg", "Cedar Creek: a narrow clear stream running away from the camera over rounded stones, grassy banks, a few trees, a dirt path on the right"),
    "pond": ("2026-11-25-pond-full.jpg", "the player's home pond: a small stone-rimmed fish pond with a few fish visible in it, the player character (a blocky Roblox avatar in a Santa hat holding a fishing rod) standing on its far rim, the big lake behind"),
    "night": ("2026-11-25-polish-night-after.jpg", "the dock at night: a wooden dock with two lamp posts at its end throwing a pool of light on the dark water, the player character (blocky Roblox avatar in a Santa hat) on the dock, reeds on the left"),
}

ROBLOX = (
    "It must still look like a real-time screenshot of a Roblox game that runs on a phone: "
    "Roblox terrain (grass, sand, rock, water with its built-in waves and reflections), simple meshes, "
    "Roblox lighting (sun, shadows, Atmosphere haze, Bloom, ColorCorrection, SunRays, DepthOfField), "
    "particles and decals. No offline-render tricks, no photographic lens effects beyond those, "
    "no painted brush strokes on the screen itself."
)

STYLES = {
    "golden-lowpoly": {
        "name": "Golden Hour Low-Poly",
        "line": "Our current chunky low-poly look, done really well at golden hour.",
        "prompt": "chunky low-poly style with flat vertex colours and faceted shapes (like a polished indie low-poly game), "
        "at golden hour: a low warm sun, long soft shadows, warm haze, glints on the water, saturated but natural colours, "
        "low-poly pines and leafy trees, reeds, lily pads, rocks and logs along a natural shoreline.",
    },
    "storybook": {
        "name": "Storybook",
        "line": "Soft hand-painted textures, like a picture book about a summer by the lake.",
        "prompt": "a storybook, hand-painted look: soft rounded shapes, gentle painted textures on the ground, wood and rocks "
        "(texture maps on simple meshes, like a cosy hand-painted 3D game), a warm pastel palette, fluffy rounded tree crowns, "
        "wildflowers, soft morning light with a light haze.",
    },
    "toon": {
        "name": "Bright Toon",
        "line": "Bold flat colours and dark outlines on the props, like a cartoon.",
        "prompt": "a bright toon look: bold saturated flat colours, very simple shapes, dark outlines on props and trees only "
        "(outline shells built into the models), clean smooth surfaces, a vivid blue sky with big puffy clouds, "
        "bright midday light, crisp water colour.",
    },
    "diorama": {
        "name": "Cozy Diorama",
        "line": "The whole place looks like a tiny handmade model on a table.",
        "prompt": "a cozy miniature diorama look: everything looks like a small handmade tabletop model, slightly toy-like rounded "
        "props, tiny felt-like trees, a gentle tilt-shift blur at the top and bottom of the frame (Roblox DepthOfField), "
        "warm afternoon light, soft shadows, a playful saturated palette.",
    },
    "moody": {
        "name": "Misty Morning",
        "line": "Mist, dark pines and soft blue light: quiet and a bit mysterious.",
        "prompt": "a moody atmospheric look: thick soft mist over the water (Atmosphere haze and fog), dark pine trees fading into "
        "the mist, a cool blue-green palette with one warm light source (a lamp or a low sun glow), calm glassy water with "
        "soft reflections, a quiet, slightly mysterious mood, still friendly for kids.",
    },
    "pbr": {
        "name": "Real-ish",
        "line": "Realistic materials (wood grain, wet stones, real grass) with simple shapes.",
        "prompt": "a realistic-ish look with physically based materials: real wood grain on the dock, wet stones, detailed "
        "grass and sand terrain textures, realistic water colour and reflections, natural daylight, simple but well-proportioned "
        "shapes (realistic Roblox game, not a photo).",
    },
}


def load_key():
    if os.environ.get("GEMINI_API_KEY"):
        return
    for env in (ROOT / ".env", MAIN_ENV):
        if env.exists():
            for line in env.read_text(encoding="utf-8").splitlines():
                if line.strip().startswith("GEMINI_API_KEY="):
                    os.environ["GEMINI_API_KEY"] = line.split("=", 1)[1].strip().strip('"').strip("'")
                    return


def prompt_for(style: str, base: str) -> str:
    s = STYLES[style]
    _, desc = BASES[base]
    return (
        "Restyle this screenshot from our Roblox fishing game. It shows " + desc + ". "
        "Keep the same camera angle, framing and layout: the same places for the water, the dock, the stands, the paths and "
        "the player. Remove the on-screen interface (coin bar, buttons, captions, floating name signs). "
        "Soften the hard square gray-box edges into natural shorelines and banks, and dress the scene with props a small "
        "team could model: trees, reeds, lily pads, rocks, logs, grass tufts, flowers. "
        "Render it in " + s["prompt"] + " " + ROBLOX + " It is a calm, beautiful fishing game for kids."
        + NIGHT.get(base, "")
    )


# The night shot must stay night whatever time of day a style names.
NIGHT = {
    "night": " IMPORTANT: this shot is at NIGHT and must stay night: a dark sky with stars and a moon, moonlight on the "
    "water, and the two dock lamps as the main warm light pooling on the dock and water. Ignore any time of day "
    "named in the style above and keep only its materials, shapes and colour treatment."
}


def gen_one(model: str, style: str, base: str, force: bool) -> Path | None:
    dest = OUT / style / f"{base}.jpg"
    if dest.exists() and not force:
        print(f"skip {dest.relative_to(ROOT)}")
        return dest
    src = STILLS / BASES[base][0]
    parts = [
        {"text": prompt_for(style, base)},
        {"inline_data": {"mime_type": "image/jpeg", "data": base64.b64encode(src.read_bytes()).decode()}},
    ]
    cfg = {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": "5:4", "imageSize": "2K"}}
    if model == IMAGE_MODELS["nano"]:
        cfg["thinkingConfig"] = {"thinkingLevel": "high"}
    body = {"contents": [{"role": "user", "parts": parts}], "generationConfig": cfg}
    _, _, data = gemini._request(
        "POST", f"{gemini.API}/v1beta/models/{model}:generateContent", json.dumps(body).encode(), {"Content-Type": "application/json"}
    )
    out = json.loads(data)
    img = None
    for c in out.get("candidates", []):
        for p in c.get("content", {}).get("parts", []):
            d = p.get("inlineData") or p.get("inline_data")
            if d and not p.get("thought"):
                img = d["data"]
    if not img:
        print(f"NO IMAGE for {style}/{base}: {json.dumps(out)[:400]}")
        return None
    im = Image.open(io.BytesIO(base64.b64decode(img))).convert("RGB")
    im.thumbnail((1600, 1600))
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest, "JPEG", quality=86)
    usage = out.get("usageMetadata", {})
    print(f"wrote {dest.relative_to(ROOT)} {im.size} tokens={usage.get('candidatesTokenCount')}")
    return dest


CRITIC_SCHEMA = {
    "type": "object",
    "properties": {
        "beauty": {"type": "number"},
        "mood": {"type": "number"},
        "readability": {"type": "number", "description": "would the scene read clearly on a small phone screen"},
        "kids_fit": {"type": "number", "description": "does it suit a calm fishing game for kids about 8 to 13"},
        "overall": {"type": "number"},
        "one_line": {"type": "string", "description": "one plain sentence a kid could read about what this style feels like"},
        "strengths": {"type": "array", "items": {"type": "string"}},
        "risks": {"type": "array", "items": {"type": "string"}, "description": "what would be hard or could go wrong in a real Roblox game on a phone"},
        "weakest_image": {"type": "string"},
    },
    "required": ["beauty", "mood", "readability", "kids_fit", "overall", "one_line", "strengths", "risks"],
}


def critic(style: str) -> dict:
    files = sorted((OUT / style).glob("*.jpg"))
    s = STYLES[style]
    parts = [
        {"text": "You are an art director reviewing concept images for a Roblox fishing game made by a father and his "
         "11-year-old son. Each image restyles a real gray-box screenshot of the same game into one candidate visual "
         f"style called '{s['name']}': {s['line']} Judge the style as a whole, across all images, from 0 to 10 on: "
         "beauty; mood; readability (would the scene, the water, the dock and the player read clearly on a small phone "
         "screen); kids_fit (does it suit a calm-but-tense fishing game for kids about 8 to 13). Then an overall score. "
         "Be honest and specific; do not give everything the same score. Do not use em dashes."},
    ]
    for f in files:
        parts += [{"text": f"Image: {f.name}"}, gemini.part_for(f, [])]
    v = gemini.generate(gemini.MODELS["neon"], parts, CRITIC_SCHEMA)
    v["model"] = gemini.MODELS["neon"]
    v["images"] = [f.name for f in files]
    (OUT / style / "critic.json").write_text(json.dumps(v, indent=2), encoding="utf-8")
    return v


def report() -> None:
    """Write docs/styles/scores.md and refresh the style data inside docs/styles/vote.html."""
    rows, data = [], []
    for sid, s in STYLES.items():
        f = OUT / sid / "critic.json"
        if not f.exists():
            continue
        v = json.loads(f.read_text(encoding="utf-8"))
        rows.append((v["overall"], sid, s, v))
        data.append({"id": sid, "name": s["name"], "line": s["line"], "critic": {k: v[k] for k in ("overall", "beauty", "mood", "readability", "kids_fit", "one_line")}})
    rows.sort(key=lambda r: -r[0])
    lines = [
        "# Critic scores for the style options",
        "",
        "Gemini 4 Neon (`gemini-4-neon`) looked at all five images of each style together and scored it 0 to 10. "
        "Made by `python tools/styles/restyle.py critic`; the full verdicts are in each style's `critic.json`.",
        "",
        "| Style | Overall | Beauty | Mood | Reads on a phone | Suits kids | Critic's line |",
        "|---|---|---|---|---|---|---|",
    ]
    for overall, sid, s, v in rows:
        lines.append(f"| [{s['name']}]({sid}/README.md) | **{overall}** | {v['beauty']} | {v['mood']} | {v['readability']} | {v['kids_fit']} | {v['one_line']} |")
    text = "\n".join(lines) + "\n"
    (OUT / "scores.md").write_text(text.replace("\u2014", " - "), encoding="utf-8")
    page = OUT / "vote.html"
    html = page.read_text(encoding="utf-8")
    start = html.index('<script id="styles-data" type="application/json">') + len('<script id="styles-data" type="application/json">')
    end = html.index("</script>", start)
    blob = json.dumps(data, ensure_ascii=False).replace("<", "\\u003c").replace("\u2014", " - ")
    page.write_text(html[:start] + blob + html[end:], encoding="utf-8")
    print(text)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["gen", "critic", "report", "prompt"])
    ap.add_argument("--model", default="nano", choices=list(IMAGE_MODELS))
    ap.add_argument("--styles", default=",".join(STYLES))
    ap.add_argument("--bases", default=",".join(BASES))
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--out", default="", help="gen: write to docs/styles/<out>/ instead of each style's folder (pilot runs)")
    args = ap.parse_args()
    load_key()
    styles = [s for s in args.styles.split(",") if s]
    bases = [b for b in args.bases.split(",") if b]
    if args.mode == "prompt":
        for s in styles:
            for b in bases:
                print(f"--- {s}/{b}\n{prompt_for(s, b)}\n")
    elif args.mode == "gen":
        for s in styles:
            for b in bases:
                try:
                    p = gen_one(IMAGE_MODELS[args.model], s, b, args.force)
                    if p and args.out:
                        tgt = OUT / args.out / f"{s}-{b}-{args.model}.jpg"
                        tgt.parent.mkdir(parents=True, exist_ok=True)
                        p.replace(tgt)
                        print(f"  moved to {tgt.relative_to(ROOT)}")
                except SystemExit as e:
                    print(f"FAILED {s}/{b}: {e}")
    elif args.mode == "report":
        report()
    else:
        for s in styles:
            v = critic(s)
            print(f"{s}: overall {v['overall']} beauty {v['beauty']} mood {v['mood']} read {v['readability']} kids {v['kids_fit']}")


if __name__ == "__main__":
    main()
