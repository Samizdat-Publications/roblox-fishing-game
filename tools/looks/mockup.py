"""Five looks for the beauty pass (L5), each one we can really build in Roblox with the models
we already have: light, water, shoreline, hills, season and time of day. Gemini's image model
restyles today's stills; Gemini 4 Neon judges each look and how buildable it is.

    python tools/looks/mockup.py gen [--looks a,b] [--bases a,b] [--force]
    python tools/looks/mockup.py critic [--looks a,b]
    python tools/looks/mockup.py prompt --looks a --bases b

Images go to docs/looks/<look>/<base>.jpg, verdicts to docs/looks/<look>/critic.json.
The key comes from GEMINI_API_KEY, this checkout's .env or the main folder's .env. Never printed.
Adapted from tools/styles/restyle.py on the style-options branch (PR #3).
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
OUT = ROOT / "docs" / "looks"
STILLS = ROOT / "docs" / "making-of" / "stills"
MAIN_ENV = Path(r"C:\Users\stewa\Documents\Claude\Roblox\.env")
IMAGE_MODEL = "gemini-nano-banana-2.1"

BASES = {
    "lake": ("2026-11-26-all-models-overview.jpg",
             "the whole lake from high above the spawn: a wide lake with a wooden plank dock with two lamp posts, a bait shop "
             "stand and a fish buyer stand on the near shore, the player's small stone-rimmed home pond in front, reeds at a "
             "weed bed on the left, sunken logs on the right, a fenced gate to Cedar Creek at the back left with pines"),
    "creek": ("2026-11-26-all-models-creek.jpg",
              "Cedar Creek: a narrow stream with rocks and pines on its banks and a path beside it"),
    "logs": ("2026-11-26-all-models-logs.jpg",
             "fallen logs lying half sunk in the lake near the east shore, a good fishing spot"),
    "bite": ("2026-11-26-all-models-bobber-bite.jpg",
             "the moment of a bite: the fishing line runs out from the bottom left to a small red and white bobber being pulled "
             "under the water, a yellow exclamation mark above it, a red and white buoy behind, the far shore with one tree"),
}

ROBLOX = (
    "It must look like a real-time screenshot of THIS Roblox game on a phone, built only with what Roblox has: "
    "Terrain water (its built-in waves, colour and reflections), Terrain grass, sand, mud and rock with sloped natural "
    "banks, our existing chunky low-poly flat-colour models (dock, stands, pines, leafy trees, reeds, lily pads, rocks, logs), "
    "simple low-poly hills and treelines on the horizon, Lighting with Atmosphere haze, Sky, Bloom, ColorCorrection and "
    "SunRays, and simple particles. Keep every model's chunky low-poly shapes and flat colours: do not turn them realistic, "
    "painted or cartoon-outlined. No textures beyond Roblox terrain materials, no lens effects."
)

# The house style since 2026-11-26 (art/README.md): chunky simple shapes, realistic materials.
REALISH = (
    "It must look like a real-time screenshot of THIS Roblox game, in its Real-ish house style: chunky, simple "
    "shapes with realistic materials. Roblox Terrain water (its built-in waves, colour and reflections, clear teal in the "
    "shallows), Terrain grass, sand, mud and rock with sloped natural banks, Roblox's built-in materials on large surfaces, "
    "and realistic PBR textures (SurfaceAppearance: colour, normal, roughness) on the hero props: real wood grain on the dock "
    "planks, posts and stands, wet stone on the pond rim and rocks, bark on the logs, natural foliage on the trees. Keep "
    "every model's simple, slightly chunky shapes and proportions: the realism comes from materials and light, not from "
    "more detail or more polygons. Simple hills and treelines on the horizon, Lighting with Atmosphere haze, Sky, Bloom, "
    "ColorCorrection and SunRays, and simple particles. Not a photograph: it should still read as a well-made Roblox "
    "game. No lens effects. The bobber and line stay bright and easy to see against the textures."
)
STYLE_TEXT = {"lowpoly": ROBLOX, "realish": REALISH}
STYLE_NAME = {"lowpoly": "the old flat low-poly style", "realish": "the Real-ish house style (chunky shapes, realistic materials)"}
STYLE = "lowpoly"


def out_dir() -> Path:
    return OUT if STYLE == "lowpoly" else OUT / STYLE

LOOKS = {
    "golden": {
        "name": "Golden Afternoon",
        "line": "Late sun, long shadows, warm light dancing on real water.",
        "prompt": "late afternoon golden hour: a low warm sun to one side, long soft shadows, warm gold light and gentle haze, "
        "sparkling sun glints on deep blue-green water that is lighter and clearer in the shallows, grassy banks sloping into "
        "the water with sandy edges, a ring of low green hills and a treeline all around the horizon.",
        "build": "Lighting presets by hour, Terrain water and sloped banks, a ring of hills and treeline.",
    },
    "dawn": {
        "name": "Misty Dawn",
        "line": "Cool pink morning, mist on the water, the lake waking up.",
        "prompt": "early dawn: a soft pink and pale blue sky with the sun just rising, low mist lying on the water and in the "
        "trees (Atmosphere haze), glassy calm water with soft reflections, dark green pines fading into the mist on the far "
        "shore, dew-cool colours with one warm glow from the sunrise, the dock lamps still faintly lit.",
        "build": "Atmosphere density by hour, a mist particle layer on the water, the same shoreline and hills as Golden.",
    },
    "summer": {
        "name": "Bright Summer Day",
        "line": "Clear blue sky, puffy clouds, bright and easy to read.",
        "prompt": "a bright clear summer midday: deep blue sky with big puffy white clouds, crisp bright light with clean short "
        "shadows, saturated grass and flowers, water that goes from turquoise in the shallows to deep blue in the middle, a "
        "darker patch over the deep hole, the bobber and line bright and easy to see.",
        "build": "Sky with clouds, ColorCorrection, water colour by depth from Terrain, a brighter bobber and line.",
    },
    "autumn": {
        "name": "Autumn Lake",
        "line": "Orange and red trees, leaves on the water, cozy fall colours.",
        "prompt": "a cozy autumn afternoon: the leafy trees in orange, red and gold with the pines still dark green, fallen "
        "leaves floating on calm deep teal water and scattered on the grass, a soft warm overcast light with a little haze, "
        "slightly golden grass, pumpkins or hay bales by the stands.",
        "build": "Recolour the leafy trees, a leaf particle and floating leaf decals, a warm overcast Lighting preset.",
    },
    "night": {
        "name": "Moonlit Night",
        "line": "Blue moonlight, lamp light on the dock, fireflies, a glowing bobber.",
        "prompt": "a clear night: a big moon and stars, cool blue moonlight on the water with a moon reflection path, the two "
        "dock lamps throwing warm pools of light on the dock and water, fireflies glowing in the reeds and grass, the bobber "
        "with a soft glowing tip so it is easy to see, dark but readable shapes, never pitch black.",
        "build": "Night Lighting preset with moon and stars, lamp PointLights, a firefly particle, a glowing bobber tip.",
    },
    "winter": {
        "name": "Frozen Winter",
        "line": "The lake freezes over: snow on the banks, ice fishing through a hole.",
        "prompt": "a crisp sunny winter day: the lake and the creek frozen over with thick blue-white ice and patches of snow "
        "on it, snow covering the banks, the hills and the pine boughs, the leafy trees bare, the dock and stands with snow on "
        "their roofs and rails, a pale blue sky and low winter sun with long blue shadows. For ice fishing: a small round hole "
        "cut in the ice with dark water in it, a short ice-fishing rod and a small bright bobber in the hole, and a little "
        "wooden shelter on the ice. In the bite view the bobber sits in a round hole cut in the ice instead of open water.",
        "build": "A winter Lighting preset, snow terrain and a frozen water swap, snow caps on props, a later ice-fishing mode.",
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


def prompt_for(look: str, base: str) -> str:
    s = LOOKS[look]
    _, desc = BASES[base]
    keep_ui = (" Keep the bobber, the line, the buoy and the yellow exclamation mark exactly where they are; remove only the "
               "coin bar and the caption text.") if base == "bite" else " Remove the floating name signs."
    return (
        "Restyle this screenshot from our Roblox fishing game. It shows " + desc + ". "
        "Keep the same camera angle, framing and layout: the same places for the water, the dock, the stands, the paths, the "
        "logs, the creek and the player." + keep_ui + " "
        "Replace the hard square gray-box edges of the lake and creek with natural sloped banks, and the empty flat horizon "
        "and edge of the world with low hills and trees. "
        "Render it as " + s["prompt"] + " " + STYLE_TEXT[STYLE] + " It is a calm but exciting fishing game for kids."
    )


def gen_one(look: str, base: str, force: bool):
    dest = out_dir() / look / f"{base}.jpg"
    if dest.exists() and not force:
        print(f"skip {dest.relative_to(ROOT)}")
        return dest
    src = STILLS / BASES[base][0]
    parts = [
        {"text": prompt_for(look, base)},
        {"inline_data": {"mime_type": "image/jpeg", "data": base64.b64encode(src.read_bytes()).decode()}},
    ]
    cfg = {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": "16:9", "imageSize": "2K"},
           "thinkingConfig": {"thinkingLevel": "high"}}
    body = {"contents": [{"role": "user", "parts": parts}], "generationConfig": cfg}
    _, _, data = gemini._request("POST", f"{gemini.API}/v1beta/models/{IMAGE_MODEL}:generateContent",
                                 json.dumps(body).encode(), {"Content-Type": "application/json"})
    out = json.loads(data)
    img = None
    for c in out.get("candidates", []):
        for p in c.get("content", {}).get("parts", []):
            d = p.get("inlineData") or p.get("inline_data")
            if d and not p.get("thought"):
                img = d["data"]
    if not img:
        print(f"NO IMAGE for {look}/{base}: {json.dumps(out)[:300]}")
        return None
    im = Image.open(io.BytesIO(base64.b64decode(img))).convert("RGB")
    im.thumbnail((1600, 1600))
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest, "JPEG", quality=86)
    print(f"wrote {dest.relative_to(ROOT)} {im.size}")
    return dest


CRITIC_SCHEMA = {
    "type": "object",
    "properties": {
        "beauty": {"type": "number"},
        "mood": {"type": "number"},
        "readability": {"type": "number", "description": "would the water, the bobber, the dock and the player read clearly on a small phone"},
        "kids_fit": {"type": "number", "description": "does it suit a calm-but-tense fishing game for kids about 8 to 13"},
        "buildable": {"type": "number", "description": "how faithfully a small team could reach this in real Roblox on a phone with the listed tools"},
        "overall": {"type": "number"},
        "one_line": {"type": "string", "description": "one plain sentence a kid could read about what this look feels like"},
        "strengths": {"type": "array", "items": {"type": "string"}},
        "risks": {"type": "array", "items": {"type": "string"}},
        "made_up": {"type": "array", "items": {"type": "string"}, "description": "things the image invented that the real build could not or would not have"},
    },
    "required": ["beauty", "mood", "readability", "kids_fit", "buildable", "overall", "one_line", "strengths", "risks", "made_up"],
}


def critic(look: str) -> dict:
    s = LOOKS[look]
    files = sorted((out_dir() / look).glob("*.jpg"))
    parts = [{"text": (
        "You are an art director reviewing concept images for a Roblox fishing game made by a father and his son. "
        f"Each image restyles a real screenshot of the game into one candidate look called '{s['name']}': {s['line']} "
        f"The team plans to build it with: {s['build']} plus Terrain water and sloped banks, using their existing chunky "
        "models, drawn in " + STYLE_NAME[STYLE] + ". Judge the look across all images from 0 to 10 on beauty, mood, readability on a small "
        "phone (water, bobber, dock, player), kids_fit, and buildable (how faithfully this team could really reach it in "
        "Roblox on a phone with those tools). Then an overall score. List what the images made up that the real build "
        "could not have. Be honest and specific; do not give everything the same score. Do not use em dashes.")}]
    for f in files:
        parts += [{"text": f"Image: {f.name}"}, gemini.part_for(f, [])]
    v = gemini.generate(gemini.MODELS["neon"], parts, CRITIC_SCHEMA)
    v["model"] = gemini.MODELS["neon"]
    v["images"] = [f.name for f in files]
    (out_dir() / look / "critic.json").write_text(json.dumps(v, indent=2), encoding="utf-8")
    return v


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["gen", "critic", "prompt"])
    ap.add_argument("--looks", default=",".join(LOOKS))
    ap.add_argument("--bases", default=",".join(BASES))
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--style", default="lowpoly", choices=list(STYLE_TEXT))
    a = ap.parse_args()
    global STYLE
    STYLE = a.style
    load_key()
    looks = [x for x in a.looks.split(",") if x]
    bases = [x for x in a.bases.split(",") if x]
    if a.mode == "prompt":
        for s in looks:
            for b in bases:
                print(f"--- {s}/{b}\n{prompt_for(s, b)}\n")
    elif a.mode == "gen":
        for s in looks:
            for b in bases:
                try:
                    gen_one(s, b, a.force)
                except SystemExit as e:
                    print(f"FAILED {s}/{b}: {e}")
    else:
        for s in looks:
            v = critic(s)
            print(f"{s}: overall {v['overall']} beauty {v['beauty']} mood {v['mood']} read {v['readability']} "
                  f"kids {v['kids_fit']} buildable {v['buildable']}")


if __name__ == "__main__":
    main()
