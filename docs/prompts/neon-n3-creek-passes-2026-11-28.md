# Instructions for Claude Code (N3 Cedar Creek Round 3)

Unpack this zip into the repo root so the full technical review lands at `docs/reviews/2026-11-28-gemini-n3-creek-review.md`.

Read `docs/reviews/2026-11-28-gemini-n3-creek-review.md` and run N3 Round 3 in two clean passes (respecting `docs/ROUTING.md`, `fable-advisor` look gates, and `docs/PERF.md` budgets):

## Pass 1: Code, Numbers & Cameras First (Part A + Section 4 - zero new art)
1. **Cameras & `FRAME_CEDARS`:**
   - Move `CreekPlan.FRAME_CEDARS` to `{ { x = -238.5, z = 42, scale = 1.3 }, { x = -220.5, z = 40, scale = 1.3 } }` so the two `scale = 1.5` trunks stop blocking the riffle 12 studs in front of shot 09.
   - Update `09-riffle-dawn`, `10-pool-golden`, `11-gate-noon`, and `12-pool-night` in `tools/shots/shots.json` and `Scatter.SHOT_CAMS` to the exact coordinates in Section 4 of the review.
2. **Flip held switches & add `CREEK_WATER_BY_TIME`:**
   - Set `CreekPlan.REVIEW1_FOAM = true`, `WhiteWater.REVIEW1 = { SURFACE = 0.14, TEXTURE_TRANSPARENCY = 0.08 }`, `WhiteWater.FOAM_COLOR = Color3.fromRGB(242, 246, 240)`, and `CreekPlan.TUNING.boughsPer = 2` (with `boughHeight = { 0.58, 0.85 }`).
   - Set `LookPresets.REVIEW1_CREEK = true`, update `AREAS.creek` (`exposure = -0.10`, `ambient = rgb(242, 246, 244)`, `tint = rgb(248, 252, 248)`, `saturation = -0.06`, `dawnMist = { density = 0.12, haze = 1.2 }`, plus `sunRaysMult = 0.45` and `bloomThresholdOffset = 0.3` in `blendAreas`), and add `LookPresets.CREEK_WATER_BY_TIME` in `areaMix` (exact RGB/wave values in Section 3, item 2).
3. **Kill spiky yellow-green `slot 2` leaks & shift gate look zone:**
   - Expand `CreekPlan.MOSS_D = 52` and `CreekPlan.MOSS_REGION = { x1 = -320, x2 = -152, z1 = -125, z2 = 115 }`, remove `and not CreekPlan.kept(x, z, 1)` from `mossBand` (since `MOSS_OVER` already skips gravel slots), tint `slot 31` (`Moss`) to `rgb(200, 210, 195)` in `MaterialKit.luau`, repaint `slot 2` in the gate foreground (`x = -155..-120, z = -25..25`) to bladeless `slot 27`/`26`, and shift `LookPresets.ZONES` (`home.x1 = -135`, `creek.x2 = -145`).
4. **Dress the bare east pool bank (`10`, `12`), understory gap (`09`, `10`, `11`), and gate corridor (`11`):**
   - Trim `KEEP_BOXES.BankPath` east edge along the pool to `x1 = -207` and place 8-10 `RockMedium` (`WetSlate`), 6 `CreekFern1`/`CreekFern2`, and 3 `ReedClump1` along `x = -210..-206, z = -66..-16` (clear of cast-lane feet).
   - Extend `CreekPlan.PROPS.x2` to `-138` for undergrowth/stones only to dress the fence footings and gravel/forest-floor voxel seams in Shot 11.
   - Add 16 `Bush1`/`Bush2` copies under `backWest`/`backEast` trunks and reduce `backWest` from `40` to `34` trees so total creek triangles stay inside `160k`.
5. **Fix `PoolLantern`, `GateLantern`, and `MossyLog`:**
   - Straighten `PoolLantern` (0 tilt), confirm its warm `PointLight` (`rgb(255, 186, 108)`, `Brightness = 2.6`, `Range = 22`) burns at `clock = 22.0` on desktop (shadows off on phone), and shift `MossyLog` search box to `cx = -250..-234, cz = -62..-42` with lighter bark tint `rgb(138, 122, 104)`.
6. Re-apply `CreekDress`, capture clean desktop frames (Level 21, `>= 1280x720`, non-touch), probe both desktop and phone tiers, and score with Neon + `fable-advisor`.

## Pass 2: Modeler Art Briefs (Only If Identity or Shot 11 Still Needs the Push)
If Pass 1 clears `look 7.5+` (all sub-scores `>= 7`) and passes `fable-advisor`, close N3 without extra uploads. Otherwise dispatch `modeler` (Fable) on the ranked briefs in Section 3 Part B (zero new textures - all reuse existing `MaterialKit` variants):
1. `CreekGateArch` (`1,100` tris) + `CreekFenceSection` (`220` tris)
2. `CreekLanternPost` (`360` tris)
3. `CreekShrub1` / `CreekShrub2` (`260` tris each)
4. `CreekCobbleCluster` (`240` tris)

Run `python tools/check.py` (specs, em-dash lint, econ) before committing.
