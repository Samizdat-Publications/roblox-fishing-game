# Cedar Creek Look Review & Fix Plan (11/28/2026)

**Reviewed Snapshot:** `roblox-fishing-game-neon-looks-2026-11-28` (Cedar Creek N3 round 2 clean desktop frames: look `5.5/10`, identity `4/10`; passing home lake set `lake-now`; `docs/PERF.md`, `docs/DECISIONS.md`, and Luau modules `CreekPlan`, `CreekDress`, `WhiteWater`, `LookPresets`, `LookDirector`, `MaterialKit`, `BankDress`, `WaterLook`, `FoliageTier`, `shots.json`).
**Target:** Look `7.5+` with no sub-score under `7`, while staying inside `CreekPlan.BUDGET = 160,000` tris and phone budgets (`350,000` tris, `300` draw calls, `130 MB` texture memory).

---

## 1. Shot-by-Shot Diagnosis (Top 3 Point Losers, in Order)

### `09-riffle-dawn.jpg` (Look & Composition Failure)
1. **Two massive `scale = 1.5` cedar trunks wall off the center of the frame (center-left to center-right, 55% of image area).** `CreekPlan.FRAME_CEDARS` places `{ x = -218.5, z = 37 }` and `{ x = -211, z = 40.5 }` only **12.4 studs** in front of the camera (`eye = [-210, 7, 28]`). Instead of framing the thirds, they sit directly between the camera and the riffle chute (`x = -237..-223, z = 30..75`), completely blocking the water, emergent wet-slate rocks, and foam.
2. **The riffle reads as a dry cobble ditch with almost no visible water or white-water foam (right third and bottom-right corner).** Because the camera sits 13 studs east of the water on the high bank (`x = -210, y = 7`) and `CreekPlan.REVIEW1_FOAM` is still `false` (`WhiteWater.SURFACE = 0.06`, `TEXTURE_TRANSPARENCY = 0.25`, `riffleW = { 0.7, 1.4 }`), only a tiny triangle of blue reflection peeks out at the bottom-right corner, and zero foam is visible.
3. **Unshaded stock-looking meadow grass and open sky leak into the left third (left 30%, foreground to horizon).** `CreekPlan.MOSS_REGION` stops at `z2 = 80` and `CreekPlan.mossBand` skips `KEEP_BOXES.BankPath` (`x = -209.5..-196.5`). That leaves bright spiky `slot 2` (`MeadowGrass`) in the immediate bottom-left foreground and a bare, grass-bladed hill under open sky behind it (`9.6%` sky), breaking the enclosed woodland stream illusion.

### `10-pool-golden.jpg` (Lighting, Water & Bare Bank Failure)
1. **Oily purple-and-orange water soup (left and center 55% of frame).** `LookPresets.REVIEW1_CREEK` is still `false`, so `AREAS.creek.water` runs `WaterTransparency = 0.8`, `WaterReflectance = 0.12`, and `WaterWaveSpeed = 12` at golden hour. At `0.8` transparency, `WaterColor (64, 84, 58)` barely tints the water: you see raw dark brown `LakeMud` through high-frequency ripples (`WaveSpeed 12`), while cool creek `ambient (236, 246, 255)` and `tint (244, 250, 255)` push sky Fresnel reflections violet-purple against harsh orange golden-sun specular (`PRESETS.golden` has `EnvironmentSpecularScale = 1.0`).
2. **A huge, ruler-straight, bare gravel/sand ramp fills the entire right third (right 35%, bottom-center to upper-right).** `CreekPlan.SHAPE` puts the Pool's east wall at `x2 = -207.1`, right against `KEEP_BOXES.BankPath` (`x1 = -209.5`). `CreekDress.reshape` skips every footpath column (`skippedPath`), leaving the straight embankment intact, and `BankPath` blocks all rocks, ferns, and trees from touching it. Only two tiny reed tufts and one crooked boxy lantern pole sit on 50 studs of bare ramp.
3. **Radioactive yellow-green grass strip and blown sun glare behind the far trunks (upper half, full width behind the trunks).** `CreekPlan.MOSS_REGION` ends at `z1 = -84` (only 13 studs north of the pool) and `backWest` places 40 tall bare-trunked trees with zero low bushes underneath them. The low western sun (`clock = 17.4`) shines straight into the lens through the upper-left canopy (aggravated by `AREAS.creek.exposure = +0.15` undoing part of golden hour's `-0.4` grade) and lights up the bare `slot 2` spiky grass behind the trunks like a neon strip.

### `11-gate-noon.jpg` (Identity Failure - Reads Most Like Stock Roblox)
1. **Blindingly saturated spiky `slot 2` grass and jagged brown `slot 25` mud puddles dominate the foreground (bottom 40%, full width).** Two root causes: (a) the camera (`eye = [-129, 7, 15]`) sits 31 studs **outside** `LookPresets.ZONES.creek` (`x2 = -160`) and inside `home`, so it gets zero creek shade; (b) `x = -172..-129` is a **dead zone** between `CreekPlan.PROPS` (`x2 = -172`) and the home lake's `BankDress` seams, so the flat beige gravel path and brown `ForestFloor` blobs have zero seam ferns, stones, or bushes breaking up the jagged voxel borders.
2. **Primitive blocky gate arch, ruler-straight fence, and boxy lantern post (dead center, middle band).** The arch is 3 sharp-edged beams with a flat dark SurfaceGui rectangle hanging under it; the fence is an identical grid of sharp posts sitting on bare ground; the lamp beside the gate is a flat tan rectangle on a square post. All three sit in harsh flat noon sun with almost no ground clutter at their footings.
3. **Evenly spaced low-poly cone pines against a bright cyan stock skybox with empty bright green lawn showing under the trunks (upper 60%).** Without a low bush/fern understory behind the fence line, the viewer looks straight underneath the pine trunks at bright open grass meadow, making the woods read like scattered Roblox toolbox trees instead of a forest edge.

### `12-pool-night.jpg` (Flat, Cold & Over-Exposed Gravel Bank)
1. **Chalk-white/pale-grey glowing gravel ramp on the right third (right 35%, bottom to upper-right).** At `clock = 22.0`, `PRESETS.night` sets `ExposureCompensation = 0.8` and `OutdoorAmbient = (112, 128, 176)`, and `AREAS.creek` adds `+0.15` exposure on top (`+0.95` net). That blasts the bare east `FootpathGravel` bank until it looks like a concrete sidewalk or snow bank at night.
2. **Dead, unlit pool lantern (upper-right on the bank, `x = -205, z = -52`).** Unlike `creek-before/12-pool-night.jpg` (which had a warm pool of light on the bank) and `lake-now/04-dockend-night.jpg` (warm lit buoy), the crooked lantern in `creek-now/12-pool-night.jpg` shows only a flat pale box with zero warm `PointLight` spill onto the bank or water. Without a warm focal accent, the shot has no focal hierarchy.
3. **Noisy grey-white specular static across the pool water (center 50%).** Because `LookPresets.areaMix` only applies `WATER_BY_TIME` to `home` (never to `creek`), the creek pool at night still runs `WaterWaveSpeed = 12` and `WaterTransparency = 0.8`, producing blotchy pale grey surface static while the `MossyLog` in the back disappears into dark mud.

---

## 2. Why the Creek Reads as Stock Roblox When the Lake No Longer Does

Comparing `frames/lake-now/` (`01`, `02`, `05`, `08`) directly against `frames/creek-now/` (`09`, `10`, `11`, `12`) reveals six exact systems the lake got that the creek missed:

1. **The lake got seam dressing (`Scatter.seams`) and horizon closure (`Scatter.crestPines`); the creek did not.** In `05-weedbed-golden.jpg`, chunky textured boulders and dense cattails hide the water-to-sand-to-grass border, and the distant ridge is capped with trees. In `10`, `11`, and `12`, bare voxel borders between `FootpathGravel`, `ForestFloor`, `CreekPebble`, and `MeadowGrass` sit completely naked in the foreground.
2. **The lake got bladeless ground (`MaterialKit.paintLawns`, `slot 26` and `slot 27`); the creek leaks raw spiky `slot 2` grass into every shot.** Around the stands (`01`, `02`, `08`), `slot 2` grass blades were replaced by `MeadowLawn` (`slot 26`) and green hill floor (`slot 27`). Around the creek, `CreekPlan.MOSS_REGION` stops right behind the pool (`z = -84`) and skips the gate corridor (`x > -172`), putting huge spiky `slot 2` grass blades right in front of lenses `09` and `11` and lighting a yellow-green strip behind the trunks in `10`.
3. **The lake got time-of-day water (`LookPresets.WATER_BY_TIME`); the creek is locked to one static water config 24/7.** Line 887 of `LookPresets.luau` (`if id == "home" and homeWater then homeWater else a.water`) bypasses time-of-day water for `creek`. The lake gets glassy dawn (`WaveSize 0.03, WaveSpeed 3`), calm golden (`WaveSpeed 6, Transparency 0.42`), and subdued night (`Reflectance 0.25`). The creek stays stuck at `WaterTransparency = 0.8, WaterWaveSpeed = 12` at golden hour and midnight.
4. **The lake has hero-set craft filling the foreground (`Dock`, `BaitShopStand`, `FishBuyerStand`); the creek's only human-made props are leftover gray-box geometry.** In `08-stands-noon.jpg`, the weathered plank dock with nail heads and cleats anchors the entire image. In `10`, `11`, and `12`, the only human-made objects are the 3-beam primitive gate, straight fence, and crooked boxy lantern posts.
5. **The lake's camera framing follows the 3-layer rule (close foreground frame, clear water subject, hazed background); the creek cameras actively sabotage the scene.** `09` stares into two trunks 12 studs away; `10` and `12` stare down from a bare gravel road into a low sun; `11` sits 31 studs outside the creek look zone staring across an undressed meadow.
6. **Three already-built N3 fixes were left switched OFF in the round 2 captures:** `LookPresets.REVIEW1_CREEK = false`, `CreekPlan.REVIEW1_FOAM = false`, and `CreekPlan.TUNING.boughsPer = 0` (even though `CedarBough` is already uploaded in `ServerStorage.Art`).

---

## 3. Numbered Change List for Next Round (Most Score per Effort First)

### Part A: Code & Number Changes Only (Zero New Art Required)

1. **Fix `09-riffle-dawn`, `10-pool-golden`, `11-gate-noon`, and `12-pool-night` camera positions in `tools/shots/shots.json` (and mirror in `Scatter.SHOT_CAMS`) and move `CreekPlan.FRAME_CEDARS` out of the riffle chute.**
   - **Files:** `src/ReplicatedStorage/Shared/CreekPlan.luau` (lines 528-531), `tools/shots/shots.json` (lines 150-220), `src/ReplicatedStorage/Shared/Scatter.luau` (`SHOT_CAMS`).
   - **Exact changes:**
     - Replace `CreekPlan.FRAME_CEDARS` with `{ { x = -238.5, z = 42, scale = 1.3 }, { x = -220.5, z = 40, scale = 1.3 } }` (flanking the riffle banks instead of standing 12 studs in front of the camera).
     - Apply the four camera coordinates in Section 5 below.
   - **Fixes:** Shots `09`, `10`, `11`, `12`.
   - **Phone budget risk:** Zero (same triangle count; lowers near-plane overdraw on `09`).

2. **Turn on held N3 switches and add time-of-day water modulation (`CREEK_WATER_BY_TIME`) for `creek`.**
   - **Files:** `src/ReplicatedStorage/Shared/LookPresets.luau`, `src/ReplicatedStorage/Shared/CreekPlan.luau`, `src/StarterPlayer/StarterPlayerScripts/ClientModules/WhiteWater.luau`.
   - **Exact changes:**
     - `CreekPlan.luau` line 51: `CreekPlan.REVIEW1_FOAM = true` (`riffleW = { 1.6, 3.0 }`).
     - `WhiteWater.luau` line 31: Set `REVIEW1 = { SURFACE = 0.14, TEXTURE_TRANSPARENCY = 0.08 }` and `FOAM_COLOR = Color3.fromRGB(242, 246, 240)` so riffle streaks read clearly over dawn ripples.
     - `CreekPlan.luau` line 513: Set `TUNING.boughsPer = 2` (activates the uploaded `CedarBough` sprays over the riffle; ~8k tris, keeping creek near ~157k inside the `160k` budget).
     - `LookPresets.luau` lines 664-682 & 724: Set `REVIEW1_CREEK = true`, and update `AREAS.creek`:
       - `exposure = -0.10` (was `+0.15`; fixes blown noon grass in `11`, golden flare in `10`, and chalk-white night gravel in `12`; keep `exposureFloor = -0.25`).
       - `ambient = rgb(242, 246, 244)` (was `236, 246, 255`; removes blue cast that turned golden pool water purple).
       - `tint = rgb(248, 252, 248)` (was `244, 250, 255`; cool woodland green-neutral).
       - `saturation = -0.06` (was `+0.02`; tames neon grass saturation in `10` and `11`).
       - `dawnMist = { density = 0.12, haze = 1.2 }` (gives `09` woodland mist without whiteout).
     - **Add `LookPresets.CREEK_WATER_BY_TIME` and wire it inside `LookPresets.areaMix` when `id == "creek"` and `clock ~= nil`:**
       - `dawn`: `WaterColor = rgb(54, 76, 56)`, `WaterTransparency = 0.62`, `WaterReflectance = 0.18`, `WaterWaveSize = 0.07`, `WaterWaveSpeed = 9`.
       - `day`: `WaterColor = rgb(56, 78, 56)`, `WaterTransparency = 0.58`, `WaterReflectance = 0.20`, `WaterWaveSize = 0.08`, `WaterWaveSpeed = 9`.
       - `golden`: `WaterColor = rgb(44, 68, 54)`, `WaterTransparency = 0.48`, `WaterReflectance = 0.30`, `WaterWaveSize = 0.05`, `WaterWaveSpeed = 5`.
       - `dusk`: `WaterColor = rgb(38, 60, 56)`, `WaterTransparency = 0.45`, `WaterReflectance = 0.30`, `WaterWaveSize = 0.05`, `WaterWaveSpeed = 5`.
       - `night`: `WaterColor = rgb(24, 44, 48)`, `WaterTransparency = 0.42`, `WaterReflectance = 0.18`, `WaterWaveSize = 0.04`, `WaterWaveSpeed = 3`.
   - **Fixes:** Shots `09`, `10`, `11`, `12`.
   - **Phone budget risk:** Very low (`WhiteWater` is off on phone tier; `CedarBough` hides with its parent `Cedar` in `FoliageTier`).

3. **Eliminate the glowing yellow-green grass strip behind the trunks (`10`), the foreground spike grass (`09`, `11`), and the bright midday gate transition (`11`).**
   - **Files:** `src/ReplicatedStorage/Shared/CreekPlan.luau`, `src/ServerScriptService/Server/CreekDress.luau`, `src/ReplicatedStorage/Shared/LookPresets.luau`, `src/ServerScriptService/Server/MaterialKit.luau`.
   - **Exact changes:**
     - `CreekPlan.luau` lines 267-268: Expand `CreekPlan.MOSS_D = 52` (was `30`) and `CreekPlan.MOSS_REGION = { x1 = -320, x2 = -152, z1 = -125, z2 = 115 }` (was `x2 = -172, z1 = -84, z2 = 80`) to convert the sunlit `slot 2` grass behind the pool (`z = -125..-84`), behind the riffle head (`z = 80..115`), and up to the gate (`x = -172..-152`) into bladeless `slot 31` (`Moss`).
     - `CreekPlan.luau` line 271: Remove `and not CreekPlan.kept(x, z, 1)` from `mossBand` (rely on `MOSS_OVER` `{ 2, 19, 25, 26, 27 }`, which already never touches gravel slots `14`/`24`) so the spiky `slot 2` grass right beside the bank path in Shot `09` becomes moss.
     - `MaterialKit.luau` line 376: Tint `slot 31` (`Moss`) to `Color3.fromRGB(200, 210, 195)` (was `255, 255, 255`) for deeper woodland shade. Also repaint `slot 2` in the gate foreground (`x = -155..-120, z = -25..25`) to bladeless `slot 27` (`LeafNeedle` green `78, 105, 65`) or `slot 26` (`MeadowLawn`) so Shot `11` loses the neon spiky wall.
     - `LookPresets.luau` lines 764-765: Shift the look-zone boundary east so the gate sits inside the forest transition: `home.x1 = -135` (was `-150`) and `creek.x2 = -145` (was `-160`).
   - **Fixes:** Shots `09`, `10`, `11`.
   - **Phone budget risk:** **Positive gain** (replaces `Terrain.Decoration` grass blades on `slot 2` with bladeless `LeafyGrass`-based slots `31`/`27`).

4. **Break up the bare east pool ramp (`10`, `12`), close the bare-trunk gap (`09`, `10`, `11`), and dress the gate corridor dead zone (`11`) using existing kit props.**
   - **Files:** `src/ReplicatedStorage/Shared/CreekPlan.luau`, `src/ServerScriptService/Server/CreekDress.luau`.
   - **Exact changes:**
     - `CreekPlan.luau` line 306: Trim `KEEP_BOXES.BankPath` east edge along the Pool from `x1 = -209.5` to `x1 = -207`, and add a bank-lip dressing pass (`x = -210..-206, z = -66..-16`, keeping the 3 cast-lane foot circles clear) placing 8 to 10 `RockMedium` (`scale 0.45..0.85`, `WetSlate`), 6 `CreekFern1`/`CreekFern2` clumps, and 3 `ReedClump1` clusters along the straight gravel-to-water lip.
     - `CreekPlan.luau` line 46: Extend `CreekPlan.PROPS.x2` from `-172` to `-138` for **undergrowth and shore stones only**, placing 12 to 16 existing `Fern1`/`Bush1`/`ShoreStone` props along the `FootpathGravel` / `ForestFloor` voxel seams beside `GateWalk` (keeping `z = -4.5..4.5` clear) and along the fence base (`x = -158, z = -35..35`).
     - `CreekPlan.luau` line 502: Add 16 existing `Bush1`/`Bush2` copies into `backWest` and `backEast` (`D = 6..24`) under the tall cedar trunks, and trim `backWest` from `40` to `34` trees (saving ~7.5k tris so total creek dressing stays under `160k` tris).
   - **Fixes:** Shots `09`, `10`, `11`, `12`.
   - **Phone budget risk:** Low (~10-12k tris added, offset by -7.5k from `backWest`, and all new undergrowth tagged `FoliageUnder` so hidden past 40 studs on phone).

5. **Fix `PoolLantern` & `GateLantern` lighting/tilt and `MossyLog` visibility (`10`, `11`, `12`).**
   - **Files:** `src/ServerScriptService/Server/Scenery.luau` / `WorldBuilder.luau`, `src/StarterPlayer/StarterPlayerScripts/ClientModules/Lanterns.luau`, `src/ReplicatedStorage/Shared/CreekPlan.luau`.
   - **Exact changes:**
     - Straighten `PoolLantern` (pitch = `0`, roll = `0`; remove the ~12-degree lean in `10` and `12`).
     - Verify `PoolLantern`'s night `PointLight` fires at `clock = 22.0` (`Color = rgb(255, 186, 108)`, `Brightness = 2.6`, `Range = 22`, `Shadows = true` on desktop / `false` on phone) so Shot `12` gets a warm light pool on the east bank and water surface.
     - Shift `CreekPlan.logPlacement` search box (lines 921-922) to `cx = -250..-234, cz = -62..-42` and lighten `MossyLog`'s bark tint to `rgb(138, 122, 104)` with `MossProp` top `rgb(88, 118, 60)` so it reads clearly against the dark bank in Shots `10` and `12`.
   - **Fixes:** Shots `10`, `11`, `12`.
   - **Phone budget risk:** Zero (lantern shadows off on phone tier).

6. **Dampen golden-hour sun flare inside `AREAS.creek` (`10-pool-golden.jpg`).**
   - **File:** `src/ReplicatedStorage/Shared/LookPresets.luau` (`AREAS.creek` & `blendAreas`).
   - **Exact change:** Support optional `sunRaysMult = 0.45` and `bloomThresholdOffset = 0.3` on `AREAS.creek` inside `blendAreas`, preventing low golden sun through dense pine crowns from blooming into a bright white orb in `10` while keeping the home lake untouched.
   - **Fixes:** Shot `10`.
   - **Phone budget risk:** Zero (SunRays off on phone).

---

### Part B: Needs New Art (Ranked Briefs for `modeler`, Max 4)

All four reuse existing `MaterialKit` variants (`CedarBark`, `WeatheredPlank`, `PaintedWood`, `WetSlate`, `LeafNeedle`, `MossProp`, `Aluminium`) so they add **0 MB** to texture memory. Build in rank order if Part A still leaves `identity` under bar on Shot `11` or the lantern posts.

#### Rank 1: Hero Cedar Creek Gate Arch & Split-Rail Fence (`CreekGateArch`, `CreekFenceSection`)
- **Size:** `CreekGateArch`: `14` studs wide (`10`-stud clear opening), `11.5` studs tall, `3.2` studs deep. `CreekFenceSection`: `10` studs long, `3.6` studs tall, `1.2` studs deep.
- **Silhouette:**
  - `CreekGateArch`: Two stout peeled-log posts with flared mossy stone footings, angled timber knee braces under a heavy rough-hewn crossbeam with overhanging notched log ends, a shallow pitched cedar-shingle cap roof, and a shaped live-edge carved wooden hanging sign board on iron S-hooks for `"Cedar Creek"`.
  - `CreekFenceSection`: Irregular hand-split rails (slight organic bow/taper, never identical rulers) mortised into chamfered rough timber posts.
- **Material split (3 meshes max):** `_bark` (`CedarBark`), `_wood` (`WeatheredPlank` / `PaintedWood`), `_stone` (`ShoreStone` plinths).
- **Triangle budget:** `CreekGateArch`: `1,100` tris (1 copy). `CreekFenceSection`: `220` tris per 10-stud section (~12 copies in view = `2,640` tris).

#### Rank 2: Rustic Creek Timber Lantern Post (`CreekLanternPost`)
- **Size:** `1.4` studs wide x `7.5` studs tall x `2.4` studs deep (arm extends `1.6` studs toward path/water).
- **Silhouette:** Tapered rough-hewn timber post with a mossy stone collar at the base, angled diagonal timber brace, and a hanging 4-sided pitched-roof wrought-iron lantern cage with corner mullions surrounding a recessed warm glass core (replaces the flat unshaded tan pane on a square stick in `10`, `11`, `12`).
- **Material split (3 meshes):** `_bark` (`CedarBark` / `WeatheredPlank`), `_metal` (`Aluminium` tinted dark iron `rgb(42, 44, 48)`), `_glass` (warm glowing core toggled by `Lanterns.luau`).
- **Triangle budget:** `360` tris per post (~4 copies = `1,440` tris).

#### Rank 3: Low Woodland Understory Shrub (`CreekShrub1`, `CreekShrub2`)
- **Size:** `CreekShrub1`: `5.5 x 3.5 x 5.0` studs. `CreekShrub2`: `6.5 x 2.6 x 5.5` studs (lower, wider mounding huckleberry/salal clump).
- **Silhouette:** Asymmetrical layered clumps of chunky faceted leaf pads radiating from 2-3 gnarled dark woody base stems (never spherical/conical). Vertex colors shaded deep forest green at the core (`rgb(32, 48, 28)`) to warm olive tips (`rgb(78, 102, 54)`).
- **Material split (2 meshes):** `_bark` (`Bark`), `_leaf` (`LeafNeedle`).
- **Triangle budget:** `260` tris each (20 copies = `5,200` tris; tagged `FoliageUnder`, hidden past 40 studs on phone).

#### Rank 4: Wet Creek Cobble & Bank-Edge Rock Cluster (`CreekCobbleCluster`)
- **Size:** `6.0` studs long x `1.8` studs tall x `3.2` studs deep.
- **Silhouette:** Low elongated cluster of 4 to 5 river-worn rounded boulders (one `2.4`-stud anchor rock flanked by smooth cobbles) with flat-buriable base (`0.5` stud bury) and two mossy caps to dress the steep east gravel bank lip (`10`, `12`) and riffle edge (`09`).
- **Material split (2 meshes):** `_stone` (`WetSlate`, vertex shades `rgb(68, 76, 82)` to `rgb(92, 96, 94)`), `_moss` (`MossProp`, `rgb(78, 104, 52)`).
- **Triangle budget:** `240` tris per cluster (10 copies = `2,400` tris; tagged `FoliageStone`, halved past 80 studs on phone).

---

## 4. Camera Fixes (`tools/shots/shots.json` & `Scatter.SHOT_CAMS`)

```json
{
  "id": "09-riffle-dawn",
  "set": "A",
  "group": "creek",
  "place": "creek",
  "clock": 6.6,
  "eye": [-223.5, 4.5, 25],
  "look": [-231, 1.5, 68],
  "what": "Low angler view from the riffle mouth looking straight up the white-water chute and emergent boulders under the cedar canopy at dawn"
},
{
  "id": "10-pool-golden",
  "set": "A",
  "group": "creek",
  "place": "creek",
  "clock": 17.4,
  "eye": [-210, 5.2, -16],
  "look": [-236, 0.5, -54],
  "what": "From the pool's east bank edge looking across the deep pool toward the mossy log, cut-bank roots and overhanging cedars at golden hour"
},
{
  "id": "11-gate-noon",
  "set": "A",
  "group": "creek",
  "place": "creek",
  "clock": 12.0,
  "eye": [-140, 5.5, 8],
  "look": [-166, 3.8, -1],
  "what": "Approaching the Cedar Creek gate arch and split-rail fence down the gravel walk at noon, looking into the shaded forest beyond"
},
{
  "id": "12-pool-night",
  "set": "A",
  "group": "creek",
  "place": "creek",
  "clock": 22.0,
  "eye": [-210, 5.2, -16],
  "look": [-236, 0.5, -54],
  "what": "The deep pool at night with the pool lantern lit on the east bank"
}
```

- **`09-riffle-dawn`:** Drops off the dry east bank down to the riffle mouth, putting the white-water tongue (`z = 28..32`), emergent wet-slate rocks (`z = 36..70`), and foaming chute front and center while bank cedars + `CedarBough` sprays close the canopy overhead (sky drops from `9.6%` to `< 4%`).
- **`10-pool-golden` & `12-pool-night`:** Steps 4 studs closer to the water off the bare gravel road and lowers `eye.Y` from `8` to `5.2` while lifting `look.Y` from `-8` to `0.5`, shrinking the right-side bare bank from 35% to ~12%, showcasing the `MossyLog` and cut-bank roots, and angling away from the direct low golden sun glare.
- **`11-gate-noon`:** Steps 13 studs closer down the gravel path into the expanded `creek` look blend zone (`x2 = -145`), making the gate arch and shaded woodland beyond the true focal subject instead of an open bright meadow.

---

## 5. What NOT to Do (Stills Traps & Phone Breakers)

1. **Do NOT add more `Cedar` (`1,272` tris) copies to close gaps behind the trunks.** The creek is already at `149k / 160k` tris (`157k` with `CedarBough`). Use `260`-tri `CreekShrub`/`Bush1` clumps (hidden past 40 studs on phone) and swap distant backing trees (`D > 20`) to `FarPine1`/`FarPine2` (`FoliageFar`).
2. **Do NOT drop `AREAS.creek.exposureFloor` below `-0.25` or crush night `OutdoorAmbient` to make `12-pool-night` moodier.** Players need to see dark approaching fish shadows (`WaitScene`) and a 24-px bobber on a phone screen at night. Fix `12` via `AREAS.creek.exposure = -0.10`, east bank rock/fern dressing, and warm `PoolLantern` light spill.
3. **Do NOT lower `CedarBough` below `boughHeight[1] = 0.55` (~10 studs) or put trunks inside `CreekPlan.LANES`.** Low branches look cinematic in a still but clip into `BobberCam` and the player's camera orbit while casting across the narrow 14-stud riffle. Keep `boughHeight = { 0.58, 0.85 }`.
4. **Do NOT enable `WhiteWater` foam strips or spray particles on the phone tier.** Stacked scrolling transparent `Texture` quads over Terrain Water hurt mobile fill rate; keep `LookTierActive == "phone"` off in `WhiteWater.luau` and rely on emergent `WetSlate` rocks on phones.
5. **Do NOT disable `Terrain.Decoration` globally.** The passing home lake shots rely on meadow blades. Fix spiky grass locally by painting creek/gate terrain to bladeless `LeafyGrass`-based slots (`31` `Moss`, `27` hill floor, `26` `MeadowLawn`).
6. **Do NOT raise `WaterTransparency` above `0.65` in the pool (`10`, `12`).** High transparency strips out `WaterColor` over the 9.6-stud-deep dark mud pool and amplifies Roblox's oily Fresnel reflection bands; keep `0.62` at dawn and `0.42-0.48` at golden hour and night.
