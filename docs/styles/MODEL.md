# Which Gemini model made the concept images

Researched 2026-11-26 from Google's own docs:
- image generation: https://ai.google.dev/gemini-api/docs/image-generation (redirects to aistudio.google.com/docs/image-generation)
- pricing: https://ai.google.dev/gemini-api/docs/pricing

## What Google offers now ("Nano Banana")

| Model id | Name | What the docs say | Price per image (paid tier) |
|---|---|---|---|
| `gemini-nano-banana-2.1` | Nano Banana 2.1 | The current workhorse for generation and conversational editing; "recommended for all new projects". Thinking levels minimal, medium (default) or high. 1K, 2K, 4K. Up to 14 reference images. | about $0.034 at 1K, $0.050 at 2K |
| `gemini-3-pro-image` | Nano Banana Pro | Premium model with heavier reasoning, best for complex instructions and text. Takes up to 3 style reference images. | about $0.134 at 1K or 2K |
| `gemini-3.1-flash-image` | Nano Banana 2 | The previous workhorse; the docs point new work to 2.1. | |
| `gemini-3.1-flash-lite-image` | Nano Banana 2 Lite | Fastest and cheapest; not tuned for multi-turn editing. | |
| `gemini-2.5-flash-image` | Nano Banana | Legacy. | |

Imagen is listed as shut down. All outputs carry Google's SynthID watermark. The docs' recipe for our job is "style transfer": give the image and ask for the same composition in a new style. Our API key lists all of the models above (checked with `models.list`).

## The pilot

Two styles (Storybook, Golden Hour Low-Poly) on two screenshots (the lake and the dock), with both Nano Banana 2.1 (thinking high) and Nano Banana Pro, same prompt. Gemini 4 Neon ranked the 8 results for faithfulness to our layout, buildability in Roblox on a phone, and beauty (`pilot/ranking.json`):

- Nano Banana 2.1 took the top three places (7.2, 6.9, 6.6).
- Pro kept the layout well in some shots but looked washed out, and flipped the dock scene left to right in one (3.8).

**Picked: `gemini-nano-banana-2.1`, thinking level high, 2K, aspect 5:4** (our stills are 1215 x 951). It won the pilot, it is Google's recommended model, and it costs about a third of Pro. The 30 final images cost roughly $1.50.

## Known limits of the images

- The model invents detail: extra trees, signs, flowers, a curvier shoreline, sometimes a moved stand or a different camera height. Treat each image as a mood target, not a layout.
- It cannot know Roblox's real limits. Every prompt asked for "a real-time Roblox game on a phone" and named the tools we have, and the feasibility notes in each style folder say what we really could and could not match.

The script is `tools/styles/restyle.py` (prompts, models, critic). Rerun one style: `python tools/styles/restyle.py gen --styles toon --force`.
