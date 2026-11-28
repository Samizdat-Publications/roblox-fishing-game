# Overnight look review for a Roblox fishing game (11/28/2026)

You are reviewing the graphics of a Roblox fishing game that a father is building with Claude for his son. Claude builds it through Roblox Studio's MCP tools; nobody on the project writes code by hand. The house style is "Real-ish Roblox": chunky simple shapes, true materials (MaterialVariant texture families and SurfaceAppearance hero sets), warm atmospheric light, readable on a phone.

Take your time. I want depth and precision over breadth.

## The problem

An automated critic (you, Gemini, with a fixed rubric, median of 3 runs) scores fixed camera shots. The home lake closed its milestone, but the new creek area is stuck:

- Cedar Creek, round 2 (clean desktop frames, `frames/creek-now/`): look 5.5 of 10, identity 4 of 10.
- The target to close the milestone: look 7.5 with no sub-score under 7.
- The identity critic keeps naming the same things as "stock Roblox": the default sky and clouds, terrain grass, sand, ground and cobblestone on banks and paths, the blocky fence and gate arch, boxy lantern posts with flat panes, low-poly pines.
- Measured problems: in shot 09 the sky is 9.6 percent of the frame (target under 8), no white water foam is visible, and two big trunks block the riffle. Shot 10 has a bright yellow-green band of lit grass behind the trunks, a big flare through the crowns, and purple and orange water. Shot 11 has very bright, saturated grass and brown bare patches.

## What is in this zip

- `frames/creek-now/`: the 4 creek shots now (09 riffle dawn, 10 pool golden, 11 gate noon, 12 pool night).
- `frames/creek-before/`: the same 4 shots before this milestone started (the old creek).
- `frames/lake-now/`: the 8 home lake shots as they stand (these passed).
- `frames/ui-now/`: the interface screens (these passed).
- `references/`: target images made for this leg. They are context, not orders: they are denser and more painterly than Roblox can afford on a phone.
- `critic/`: the critic's write-ups for the creek now and the lake's last round.
- `docs/`: the leg plan (read "Visual direction: Real-ish" and N3 first), design decisions so far, performance budgets, the game's direction and design, the art pipeline notes, and your own earlier review.
- `code/`: the Luau modules that make the look: lighting presets per area and time of day (`LookPresets`, `LookDirector`), materials and terrain slots (`MaterialKit`), the creek's layout and dressing (`CreekPlan`, `CreekDress`), white water (`WhiteWater`), banks and scatter (`BankDress`, `Scatter`), water (`WaterLook`), phone foliage hiding (`FoliageTier`), and the shot cameras (`shots.json`).

## Hard limits (do not suggest past these)

- Roblox only. The place's lighting style is Realistic. Terrain materials can carry MaterialVariants, but only 31 slots exist and the home lake uses most of them. Water is Roblox terrain water.
- Phone budget in view: 350,000 triangles, 300 draw calls, 130 MB textures. Desktop: 700,000 triangles, 600 draw calls. The creek's own dressing is about 149,000 triangles of a 160,000 budget.
- No paid assets, no Robux spending, original art only (no copying other games). Kid-friendly (rating Minimal or Mild).
- The custom sky is already planned as its own step (one day skybox, our own sun and moon, Clouds kept), so treat the sky as known.

## What I want back

1. **Diagnosis.** For each creek shot, the three things that cost the most points, in order, with where in the frame.
2. **Why the creek reads as stock Roblox when the lake no longer does.** Compare `lake-now` with `creek-now`. What did the lake get that the creek did not?
3. **A numbered change list for the next round**, most score per effort first. For each: the file and the setting or code change with exact values (colours as RGB, numbers with units), which shot it fixes, and the risk to the phone budget. Separate "change a number" items from "needs new art" items.
4. **New art, if any is worth it,** as short briefs a 3D modeler could build from: the object, size in studs, silhouette, material split, triangle budget. Rank them; at most four.
5. **Camera.** If a shot camera itself is the problem (for example shot 09 sitting under two trunks), say so and give a better camera position and look direction in the same form as `shots.json`, keeping what the shot is meant to show.
6. **What not to do:** anything that would look better in a still but worse in play, or break the phone.

Be concrete. "Add more detail" or "improve the lighting" is not useful; "creek preset ExposureCompensation from 0 to -0.2 in LookPresets AREAS.creek, fixes the blown grass in 11" is.
