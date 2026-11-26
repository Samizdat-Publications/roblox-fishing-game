# Overnight work for Claude Duet (cloud)

Written 2026-11-25, evening. Window: now until about 1 pm on 2026-11-26, when the local Claude Code session (which drives Roblox Studio) comes back. Read `CLAUDE.md`, `docs/PROGRESS.md`, `docs/DESIGN.md` and `docs/RESEARCH.md` first.

## The one big constraint

You are in the cloud. **Roblox Studio is not available to you**, so nothing you write can be playtested tonight. The local session will review, push into Studio and playtest your work tomorrow. So:

- Work on a branch, **never on `main`**: `duet/overnight-2026-11-25`. Push it and open one pull request into `main` (draft is fine), titled "Overnight: economy, boat prep, art pass models". The local session merges it after testing in Studio.
- Prefer work that is complete without Studio: data, pure logic with tests that run outside Studio, design specs, task plans, and 3D models. Keep changes to Studio-only scripts (`src/ServerScriptService/Server/*`, client UI) out of tonight's work, except where a task below says otherwise.
- Mark everything you could not verify as **unverified** in the PR description and in `docs/PROGRESS.md` (under a new "Overnight, unverified" heading). Don't claim something works in game.
- House rules from `CLAUDE.md` apply: no em dashes in anything a person reads, server-authoritative economy, no Robux items, no trading, original names and art only, no real place or family names. End each commit message with a `Co-Authored-By:` line naming the model you are.

## Tasks, in priority order

Do them in this order. Each ends in a commit. If a task gets stuck, write down where it stands and move to the next one.

### 1. Economy check (about an hour)

Is the money curve fun? Prices and numbers live in `src/ReplicatedStorage/Shared/` (`FishData.luau`, `BaitData.luau`, `RodData.luau`, `PondLogic.luau`, `Config.luau`) and the server services.

- Write `tools/econ/sim.py`: a simple simulation of a player fishing the right spot with the right bait vs a player fishing at random, using the real bite weights, sizes, prices, bait costs and the 16 minute day. Estimate coins per real-time minute, and minutes to afford the Fiberglass Rod (120), the Creek Pass (250) and the Graphite Rod (350). Include the pond's growth and breeding income.
- Write `docs/ECONOMY.md`: the results in a small table, what feels too slow or too fast for a kid playing 20 to 30 minute sessions, and 3 to 6 concrete number changes, each with its reason. **Don't change the game's numbers yourself**; tomorrow's session applies the ones Stewart approves.

Done when: the script runs, the doc has the table and the proposed changes.

### 2. Boat: plan it so tomorrow is fast (about 1 to 2 hours)

The boat is next on the roadmap (see `DESIGN.md`, "Later versions", item 2).

- Write a task plan in `docs/superpowers/plans/2026-11-26-boat.md` in the same style as the existing plans in that folder. Cover:
  - where you buy the boat and what it costs;
  - how you board it, steer it and dock it, on keyboard, touch and gamepad;
  - casting from the boat;
  - new open-water or big-lake spots it reaches, with 2 or 3 real fish, their habits and best baits (following the pattern in `FishData.luau`);
  - how it saves;
  - how it stays server-authoritative;
  - how each step gets verified in a Studio playtest.
  
  Use Roblox's current docs for the vehicle approach and avoid deprecated body movers. If you can reach create.roblox.com, read it; if not, say which parts need checking.
- You may add pure data and logic for it, with tests, where it needs no Studio: a `BoatData.luau` in `src/ReplicatedStorage/Shared/`, new species entries in `FishData.luau` for the new spot, and specs in `src/ServerScriptService/Tests/` following the existing `*.spec.luau` style. Keep them small and clearly marked unverified.

Done when: the plan is committed and any data or logic has tests.

### 3. Art pass: our own models (the rest of the night)

The long-term goal is to publish with lots of our own models. Tonight, build the first set from script in Blender, so they can be regenerated and tweaked.

1. **Check Roblox's current import rules first**: triangle limits per mesh, texture size limits, the file formats Studio's 3D Importer takes, and how scale maps to studs. Write what you find in `art/README.md` with links, and follow it.
2. **Set up headless Blender.** If you can install it (download the official Linux build), generate with `blender -b -P <script>`. If you can't, still write the scripts and say so; the local machine has Blender 5.1.
3. **Make one script per model** in `art/scripts/`, all writing to `art/models/` (GLB and FBX) plus a preview render to `art/previews/` (PNG, 1024 px). Keep the look consistent: low-poly, chunky and friendly, flat colours with a little shading, readable from a distance and on a phone.
4. **Match the gray-box sizes.** They are in `src/ServerScriptService/Server/WorldBuilder.luau`: the dock is about 30 by 46 studs, and the water is 220 by 160. Use those so models drop straight in.

Models, in order:
1. **Dock** with posts, planks and two lamp posts.
2. **Fish Buyer stand**, with an awning and a counter.
3. **Bait and Tackle stand**, with a rod rack and bait tubs.
4. **Pond rim**: stone, matching the pond size in the world builder.
5. **Fallen logs** (3 variants), **a buoy**, **reeds and lily pads**, **2 pine trees and 1 leafy tree**, **rocks** (3 sizes).
6. **The 11 fish** in `FishData.luau` (8 lake, 3 creek), each with its real colours and markings, at true relative size. These will replace the shadow blobs and the catch held on the line. Name each file after the species id.
7. **The three rods** in `RodData.luau` (Willow, Fiberglass, Graphite) and **a bobber**.

Finish with a contact sheet of all previews in `art/previews/contact-sheet.png`.

Done when: models and previews are committed, each one under the limits from step 1, and `art/README.md` lists every model with its size in studs, triangle count, and the gray-box part it replaces. **Do not try to import anything into Studio**; tomorrow's session does that.

### 4. Weather spec (if time is left)

Write `docs/WEATHER.md`: weather that acts like real fishing, not luck boosts.
- **Kinds:** overcast pushes fish shallow, a cold front slows the bite, the hour before a storm is a feeding rush, wind on a point, fog, a full moon.
- **For each kind:** how it changes bites per species, how often it happens, how the player can read it coming (sky, wind, a barometer at the bait shop), and what never to do (it is never sold as a boost).
- **Finish with a data table** in the style of `FishData.luau` that tomorrow's session can drop in.

### 5. Tests outside Studio (if time is left)

The pure modules in `src/ReplicatedStorage/Shared/` (`FishLogic`, `FightModel`, `PondLogic`, `Inventory`) could be tested outside Studio, so every push gets checked.
- **Try it:** with Lune (a Luau runtime) or `luau` CLI, plus a GitHub Actions workflow that also runs StyLua (format check) and Selene (lint).
- **If the specs depend on Roblox-only APIs**, write down which ones, and keep the workflow to what can run.
- **Don't reformat the codebase**: report what the format check would change.

## What to leave alone

- **Studio and the place itself** (you can't reach them), the `tools/sync/` push tools, and the making-of page. Don't add making-of entries for work that hasn't been seen in the game. One entry with Blender previews of the models is fine, marked as an art preview (see `docs/making-of/HOW-TO-ADD-A-STEP.md`, skipping the Studio capture and the page republish).
- **`planner/`**, which is Liam's planning page.
- **Any account, publishing, or money decision.**

## Hand-off for tomorrow

Before stopping, update `docs/PROGRESS.md` under "Overnight, unverified" with:
- what you finished;
- what is half done;
- what tomorrow's local session must test in Studio first;
- any questions only Stewart can answer.

Put the same summary at the top of the pull request.
