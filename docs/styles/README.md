# Style options for Liam

Set aside on 2026-11-26 for Liam to choose from later. **Nothing here changes the game**: no Studio, `src/` or `art/` changes, and the house style in `art/README.md` stays in force until Liam and Stewart pick.

**Voting page for Liam:** https://claude.ai/artifact/MJJUZdAHyNqWKE5TdgvX8d (big pictures, one line per style, Love it / Maybe / Nope, one favourite, a notes box; picks are saved).

## What we did

1. Picked Google's image model from its own docs and a small pilot: **Nano Banana 2.1 (`gemini-nano-banana-2.1`)**, see [MODEL.md](MODEL.md).
2. Took five real screenshots from `docs/making-of/stills/` (the lake from above, the dock, Cedar Creek, the home pond, the dock at night) and restyled each into six styles we could really build in Roblox: 30 concept images.
3. Wrote a feasibility note per style (what it takes, phone risk, effort, what changes).
4. Had Gemini 4 Neon score each style on beauty, mood, readability on a phone and fit for a kids' fishing game: [scores.md](scores.md).

## The six styles

| Style | One line | Critic overall | Phone risk | Effort | Pipeline change |
|---|---|---|---|---|---|
| [Golden Hour Low-Poly](golden-lowpoly/README.md) | Our current chunky low-poly look, done really well at golden hour. | **8.2** | Low | Small to medium (3 to 5 sessions) | None |
| [Cozy Diorama](diorama/README.md) | The whole place looks like a tiny handmade model on a table. | **8.2** | Low to medium | Medium (4 to 6) | Rounder models; depth of field only in menus and an overview camera |
| [Bright Toon](toon/README.md) | Bold flat colours and dark outlines on the props, like a cartoon. | **8.0** | Low to medium | Medium (4 to 6) | Outline shells in the Blender scripts, louder palette |
| [Storybook](storybook/README.md) | Soft hand-painted textures, like a picture book about a summer by the lake. | **7.9** | Medium | Large (8 to 12) | Painted texture atlases on every model |
| [Misty Morning](moody/README.md) | Mist, dark pines and soft blue light: quiet and a bit mysterious. | **7.9** | Low | Small (2 to 3) | None |
| [Real-ish](pbr/README.md) | Realistic materials (wood grain, wet stones, real grass) with simple shapes. | **7.3** | High | Large (10 to 15) | Replaces the house style with Meshy models and PBR texture sets |

The critic scored concept images, so the scores compare the styles with each other; the real gray-box game scored 2.5 to 3 on the same critic. Readability on a phone was the weakest score for every style except Bright Toon (8.5): the critic kept flagging small bobbers and thin lines lost in busy grass, water glare and dark night water. Whatever Liam picks, the bobber and the line need to glow or carry an outline.

Dropped before generating: pixel or voxel art (fights Roblox's smooth terrain and avatars), anime or painterly brush-stroke looks (need screen shaders Roblox doesn't have), and full photoreal (too heavy for phones and clashes with Roblox avatars; "Real-ish" is the most realistic option that still runs).

## Decision (2026-11-26): Real-ish

Stewart looked at the voting page and picked **Real-ish**, the lake shot above all. Claude's case against it was weaker than the scores made it look:
- The critic gap is small: 7.3 against 8.2, from one model judging AI concept art.
- Its biggest knock was phone readability. Every style shares that problem, and the fix is the same in all of them: a glowing bobber and line.
- The heavy cost in the first note assumed custom textures on every prop. A better split: Roblox's built-in materials for terrain and large surfaces, and custom PBR textures wherever they clearly look better (fish first), held to a phone budget we measure on a full-quality test corner.

It is now the house style on main (`art/README.md`, `DIRECTION.md`, `DECISIONS.md`). Build notes: [pbr/README.md](pbr/README.md). Liam can still vote on the page; if he falls for another style, that is a conversation to have, not a rebuild.

The original recommendation follows for the record.

## Recommendation (before the decision)

**Build on Golden Hour Low-Poly, and borrow from three others.** It tied for the top score (8.2), it is what the house style already is, it needs no change to the Blender pipeline, it has the lowest phone risk, and most of its work is the L5 beauty pass the leg plan already schedules (light, water, shoreline, a horizon full of trees).

Borrow:
- **Misty Morning as a mood, not a style:** a dawn and fog-weather lighting preset, and the deep hole at night. It scored the best mood (9.1) and costs almost nothing on top.
- **Bright Toon's readability:** a glowing or outlined bobber, line and hooked fish (a Highlight on the few things that matter), and its stronger colour contrast on the stands. It was the only style that read well on a phone.
- **Cozy Diorama's cuteness:** rounder, chunkier props and an optional overview camera for the map and journal.

Avoid **Real-ish**: the lowest score, the worst phone readability (5.5), the highest phone risk and the most work, and it fights the blocky avatars. **Storybook** is lovely but would mean texturing every model; it is the one to choose only if Liam falls for it.

That is a recommendation, not a decision: Liam is the creative director, and every style here is buildable. If he picks Toon or Diorama the plan barely changes; Storybook roughly doubles the art work of the beauty pass.

## Files

- `<style>/README.md`: the feasibility note and the five images for that style.
- `<style>/critic.json`: Neon's full verdict for that style.
- `scores.md`: all critic scores in one table.
- `vote.html`: the source of the voting page artifact. Saved votes live in the artifact's database, collection `votes`, one document per viewer (`favourite`, `reactions`, `notes`).
- `pilot/`: the model pilot (Nano Banana 2.1 against Nano Banana Pro) and Neon's ranking.
- `tools/styles/restyle.py`: prompts, generation, critic and the score table. `python tools/styles/restyle.py prompt` prints every prompt.

To read Liam's votes later, ask Claude to read the voting page's saved data (collection `votes`).
