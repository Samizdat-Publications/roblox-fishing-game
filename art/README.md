# Art: our own models

Made overnight 2026-11-26 by script in Blender 5.1.2 (the `bpy` module, headless, in the cloud). **Not yet imported or seen in Studio**: tomorrow's session does that. Every model can be rebuilt and tweaked from its script.

![Contact sheet](previews/contact-sheet.png)

## Roblox's import rules (read 2026-11-26)

| Rule | What we do | Source |
|---|---|---|
| At most 20,000 triangles per mesh; meshes should be closed and have some thickness | Every model is one mesh, the biggest about 1,400 triangles; nothing is paper thin (fins and lily pads are thin boxes) | https://create.roblox.com/docs/art/modeling/specifications |
| One material per mesh; textures up to 4096 px, one UV set inside 0 to 1 | No textures at all: each part's flat colour is baked into vertex colours, and all parts are joined into one mesh with one material | https://create.roblox.com/docs/art/modeling/texture-specifications |
| The 3D Importer takes .fbx, .obj and .gltf/.glb, with vertex colours | Each model ships as `.glb` and `.fbx`; try `.glb` first (Roblox's Blender page says glTF needs no extra scaling setup) | https://create.roblox.com/docs/studio/importer and https://create.roblox.com/docs/art/blender |
| 1 stud = 28 cm; in Blender set Unit System to None so 1 Blender unit = 1 stud; FBX export with Apply Scalings = FBX Unit Scale; Importer Scale Unit = Stud | Built in studs with Unit System None; FBX uses FBX Unit Scale, Y up, Z forward | https://create.roblox.com/docs/physics/units and https://create.roblox.com/docs/art/blender |
| Parts can be 0.001 to 2048 studs a side | Biggest is the dock, 46 studs long | https://create.roblox.com/docs/reference/engine/classes/BasePart |
| Collision fidelity: Box, Hull, Default, PreciseConvexDecomposition | See "Importing" below | https://create.roblox.com/docs/parts/meshes |

Unconfirmed: whether Studio shows the baked vertex colours exactly as in the previews (the Importer has an "Ignore Vertex Colors" option, so it reads them; check the first import).

## House style: Real-ish (Stewart's pick, 2026-11-26)

Chunky, simple shapes with realistic materials: wood grain on the dock, real grass, sand and stone, clear teal water, natural light. Stewart picked it from the six style options (PR #3, https://github.com/Samizdat-Publications/roblox-fishing-game/pull/3; voting page https://claude.ai/artifact/MJJUZdAHyNqWKE5TdgvX8d). It replaces the flat vertex-colour low-poly look decided earlier the same day. The models already in the game stay until they are re-dressed.

- **Shapes stay simple.** Blender by script (`art/scripts/`) is still the main tool for props, environment, fish, rods and boats. Keep the chunky low-poly shapes: the realism comes from materials and light, not from polygon counts.
- **Desktop first, phones still work.** The game is played mainly on desktop, so the look is aimed at a desktop PC: the best we can get without hitting the PC's performance ceiling. Phones are a second target. They must stay smooth and readable, and they may show a lighter version of the same world. Spend texture memory where the player looks, and save it where they don't.
- **Base layer: Roblox's built-in materials.** Use them for terrain and large repeated surfaces: grass, sand, rock, mud, plank walkways, ground under the islands. They are already physically based and shared by every Roblox game, so they look good and cost almost nothing. The scripts gain a UV step so materials wrap properly on our meshes; check how they map on the first import.
- **Hero layer: custom PBR textures.** A `SurfaceAppearance` (colour, normal, roughness, and metalness where it matters) goes wherever it clearly beats a built-in material: the dock, the stands, the boats, the trophy case, every fish model. Fish are the stars, so they get the best textures. Use shared texture sets per family (one set for all docks, one per fish body type) so quality scales without memory blowing up.
- **Proof corner first, then a budget.** Before the whole world is re-dressed, build one corner of the lake (the dock and the two stands) at full quality, then measure it twice. On Stewart's PC, the target is a steady 60 frames a second at the fixed shots. On phones, the floor is 30 frames a second on Stewart's phone and the smallest phone in the Device Simulator. Those measurements set the texture and draw budget per area.
- **A lighter phone tier.** On touch devices a client script turns down the extras: grass and decoration distance, particle density, some post effects, far props. Roblox also lowers graphics quality on its own on weak devices. When the phone floor fails, cut the phone extras first, then textures the player can't see, and only then the desktop look.
- **Built to grow.** The world will get much bigger: a big lake crossed by vehicles, and fishing islands. Each island is its own streaming area with its own texture set (StreamingEnabled, already on by default), so only nearby islands sit in memory.
- **Readability rules.** The bobber and line glow or carry a bright outline so they read against textures and dark water. Keep the grass in the foreground, and put less fine detail where the player looks for bites.
- **Meshy** for complex organic shapes a script can't make well (and a source of textures for hero props). Decimate it in Blender, and match it to the same materials before import.
- **UI icons** (journal fish, bait, rods, boats) are rendered from the same models, so the UI matches the world.
- **PixelLab and CadQuery are not used** for in-game art, to keep one consistent look.

## Conventions

- **Units:** 1 Blender unit = 1 stud. Blender is Z up; the exports are Y up, so the model's height is Roblox Y.
- **Pivot:** bottom centre of each model's bounding box.
- **Look:** chunky, simple shapes with realistic Roblox materials, made for desktop and still readable on a phone (see House style). `scripts/palette.py` still holds the colours for parts that keep a flat colour, such as awnings, bobbers and UI accents.
- **Fish scale:** 1 stud = 12 cm, the same scale the catch on the line uses (`FishingService.showCatch`: length in studs = cm / 12). Each fish is built at its species' average length; scale it by caught cm / average cm. Heads point along +X.

## Rebuild

```
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b -P "C:\Users\stewa\Documents\Claude\Roblox\art\scripts\build_all.py"
```

(That's Blender's default install folder; adjust if yours differs. Unverified on Stewart's PC.) One model: the same with `art\scripts\dock.py`; one fish: add `-- Walleye` at the end of the line for `fish.py`. In the cloud it ran as plain Python with `pip install bpy==5.1.2` (plus Pillow for the small previews and the contact sheet). `ART_SAMPLES` sets render quality (48 by default). Each run writes `models/<Name>.glb`, `models/<Name>.fbx`, `previews/<Name>.png` (1024 px) and updates `models/manifest.json` (sizes, triangles, what it replaces). `scripts/contact_sheet.py` rebuilds the sheet.

## Importing (all 32 done on 2026-11-26)

What works, learned on the first import:

1. **Convert the colours first:** `python art/scripts/roblox_colors.py <Name>` writes `art/models/roblox/<Name>.glb`. Blender exports vertex colours in linear light and Roblox shows them as display colours, so an unconverted model comes in far too dark (the first bluegill was nearly black). Upload the converted copy, never the one in `art/models/`.
2. **Upload through Open Cloud** (Studio MCP `open_cloud_invoke`, `POST /assets/v1/assets`, assetType Model) from `art/models/roblox/`; the repo folder is an approved upload folder. Record the asset id in the table below. Each upload is a permanent asset, so upload once.
3. **Insert it into `ServerStorage.Art`** (`InsertService:LoadAsset(id)` from `execute_luau` in Edit loads many at once, as plain models with their pivot square). Roblox keeps the size exactly (1 stud = 1 Blender unit) and the pivot at the bottom centre, but gives the model a random turn on insert, and **the head or front points along -X in Roblox** (Blender's +X). `PivotTo` an exact CFrame to place it.
4. **Place it from code:** add an entry to `ART` in `src/ServerScriptService/Server/WorldBuilder.luau` (its CFrame and the gray-box parts it hides), then run `WorldBuilder.dress(workspace.Lake)` in Edit. The gray-box parts stay as invisible collision and cast-check shapes; the models are anchored with `CanCollide`, `CanQuery` and `CanTouch` off, so walking, casting, prompts and zones work exactly as before.
5. **Fish** need no placing: a species with a model in `ServerStorage.Art` (named by its id, like `Bluegill`) hangs on the line when caught, stretched to the catch's length (`FishingService` `artFish`).

| Model | Roblox asset id | In the game |
|---|---|---|
| Dock | 92795692386476 | `Lake.Art`, turned 180 degrees so the lamp end is out in the lake; deck top at y = 1.5 |
| BaitShopStand | 128962467669158 | `Lake.Art` at (18, 1, 96.5), open front to the lake |
| FishBuyerStand | 106188034402949 | `Lake.Art` at (-18, 1, 96.5) |
| PondRim | 85562437402898 | `Lake.Art` round the home pond at (50, 1, 106) |
| Log1 | 89531819976790 | Over gray-box logs 1 and 4 |
| Log2 | 99209213624189 | Over gray-box logs 2 and 5 |
| Log3 | 92896234828500 | Over gray-box log 3 |
| Buoy | 101773810678352 | Floating in the deep hole at (0, -0.6, -25) |
| Reeds | 109116103967365 | 18 clumps over the weed bed (replace the weed sticks) |
| LilyPads | 85183031227808 | 7 on the water round the weed bed |
| PineTall | 101345558596198 | On creek trunks 1, 3, 5, 7 |
| PineShort | 93282291561721 | On creek trunks 2, 4, 6, 8 |
| LeafyTree | 98200740872322 | 7 on the lake shore |
| RockLarge | 91170341972863 | Fitted to creek boulders 1, 2, 4 |
| RockMedium | 140479691148163 | Fitted to creek boulders 3, 5 |
| RockSmall | 110035479332491 | Fitted to the 14 creek pebbles |
| Bobber | 138136046417846 | The bobber on every cast (`FishingService` `makeBobber`) |
| WillowRod | 105973286899843 | In ServerStorage only (rods in hand still the gray box) |
| FiberglassRod | 105439165015959 | In ServerStorage only |
| GraphiteRod | 112794029818185 | In ServerStorage only |
| JonBoat | 73308698165043 | In ServerStorage only, for the boat plan |
| Bluegill | 109571493310355 | On the line when one is landed |
| Pumpkinseed | 94171834310429 | On the line when one is landed |
| YellowPerch | 89203301171747 | On the line when one is landed |
| BlackCrappie | 114088207962110 | On the line when one is landed |
| LargemouthBass | 125320665780187 | On the line when one is landed |
| ChannelCatfish | 86511242177797 | On the line when one is landed |
| CommonCarp | 102551350734293 | On the line when one is landed |
| NorthernPike | 87034965888840 | On the line when one is landed |
| RainbowTrout | 118820630960923 | On the line when one is landed |
| SmallmouthBass | 134271966681380 | On the line when one is landed |
| Walleye | 86662257400132 | On the line when one is landed |
| Bluegill (first try) | 123238298956061 | Not used: uploaded before the colour fix, too dark |

## The models

The table is generated from `models/manifest.json`. Sizes are studs as X x Y (up) x Z.

| Model | Size (studs) | Triangles | Replaces | Notes |
|---|---|---|---|---|
| [Dock](previews/Dock.png) | 16.7 x 18.2 x 46.3 | 1372 | Workspace.Lake.Dock (Deck, EndDeck, Posts) and the two dock-end lamp posts | Deck top is 9 studs above the model base; place the base at y = -7.5 so the deck top sits at y = 1.5. |
| [FishBuyerStand](previews/FishBuyerStand.png) | 12.05 x 12.8 x 6.11 | 772 | Workspace.Lake.SellStand (Counter, PostL, PostR, Roof); keep the SellPrompt and sign on an invisible counter part | Open front faces the lake. Base sits on the ground (y = 1). |
| [BaitShopStand](previews/BaitShopStand.png) | 14.32 x 11.9 x 6.11 | 1100 | Workspace.Lake.ShopStand (Counter, PostL, PostR, Roof); keep the ShopPrompt and sign on an invisible counter part | Open front faces the lake. Base sits on the ground (y = 1). |
| [PondRim](previews/PondRim.png) | 25.0 x 1.81 x 16.73 | 1328 | Workspace.Lake.HomePond RimN, RimS, RimW, RimE | Centre it on the pond (50, 1, 106 in the gray box); base on the ground. |
| [Log1](previews/Log1.png) | 22.16 x 2.81 x 3.49 | 188 | Workspace.Lake.Logs.Log1 to Log5 (mix the variants) | Lies along X. The gray box sinks logs 0.4 to 1.6 studs; keep that. |
| [Log2](previews/Log2.png) | 15.26 x 2.89 x 3.29 | 192 | Workspace.Lake.Logs.Log1 to Log5 (mix the variants) | Lies along X. The gray box sinks logs 0.4 to 1.6 studs; keep that. |
| [Log3](previews/Log3.png) | 18.42 x 4.29 x 5.14 | 292 | Workspace.Lake.Logs.Log1 to Log5 (mix the variants) | Lies along X. The gray box sinks logs 0.4 to 1.6 studs; keep that. |
| [Buoy](previews/Buoy.png) | 1.8 x 3.37 x 1.8 | 230 | Workspace.Lake.DeepHoleBuoy | Base at the water line minus about 0.6 so it floats. |
| [Reeds](previews/Reeds.png) | 3.9 x 7.29 x 3.7 | 428 | Workspace.Lake.WeedBed Weed sticks (scatter clumps over the weed bed) | Base at the water line; about 7 studs tall. |
| [LilyPads](previews/LilyPads.png) | 5.64 x 0.83 x 5.75 | 532 | Nothing yet: new dressing for the weed bed and pond | Sits on the water surface. |
| [PineTall](previews/PineTall.png) | 7.82 x 17.31 x 8.15 | 80 | Cedar Creek Trunk and Crown pairs | About 16 studs, like the gray box. |
| [PineShort](previews/PineShort.png) | 7.96 x 11.73 x 7.64 | 80 | Cedar Creek Trunk and Crown pairs (mix with PineTall) | About 11 studs. |
| [LeafyTree](previews/LeafyTree.png) | 9.49 x 15.67 x 8.88 | 176 | Nothing yet: new dressing for the lake shore | About 15 studs. |
| [RockSmall](previews/RockSmall.png) | 1.79 x 1.13 x 1.64 | 80 | Cedar Creek Boulder1-5 and Pebble1-14 (pick the size that fits) | About 1.6 studs across. |
| [RockMedium](previews/RockMedium.png) | 5.27 x 3.22 x 4.16 | 100 | Cedar Creek Boulder1-5 and Pebble1-14 (pick the size that fits) | About 4 studs across. |
| [RockLarge](previews/RockLarge.png) | 9.07 x 5.73 x 6.62 | 120 | Cedar Creek Boulder1-5 and Pebble1-14 (pick the size that fits) | About 7 studs across. |
| [Bluegill](previews/Bluegill.png) | 1.79 x 1.05 x 0.41 | 924 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 18.5 cm = 1.54 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [Pumpkinseed](previews/Pumpkinseed.png) | 1.55 x 0.87 x 0.34 | 924 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 16.0 cm = 1.33 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [YellowPerch](previews/YellowPerch.png) | 2.27 x 0.74 x 0.3 | 924 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 23.5 cm = 1.96 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [BlackCrappie](previews/BlackCrappie.png) | 2.42 x 1.3 x 0.51 | 924 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 25.0 cm = 2.08 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [LargemouthBass](previews/LargemouthBass.png) | 4.11 x 1.48 x 0.59 | 908 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 42.5 cm = 3.54 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [ChannelCatfish](previews/ChannelCatfish.png) | 6.14 x 1.45 x 1.03 | 964 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 62.5 cm = 5.21 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [CommonCarp](previews/CommonCarp.png) | 5.61 x 2.13 x 0.85 | 932 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 57.5 cm = 4.79 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [NorthernPike](previews/NorthernPike.png) | 8.62 x 1.49 x 0.87 | 908 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 77.5 cm = 6.46 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [RainbowTrout](previews/RainbowTrout.png) | 3.38 x 1.01 x 0.43 | 916 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 35.0 cm = 2.92 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [SmallmouthBass](previews/SmallmouthBass.png) | 3.38 x 1.22 x 0.49 | 908 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 35.0 cm = 2.92 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [Walleye](previews/Walleye.png) | 5.07 x 1.25 x 0.65 | 924 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 52.5 cm = 4.38 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [Bowfin](previews/Bowfin.png) | 6.28 x 1.36 x 0.85 | 908 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 65.0 cm = 5.42 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [LakeSturgeon](previews/LakeSturgeon.png) | 14.74 x 1.84 x 1.99 | 956 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 135.0 cm = 11.25 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [CreekChub](previews/CreekChub.png) | 1.69 x 0.45 x 0.2 | 908 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 17.5 cm = 1.46 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [RockBass](previews/RockBass.png) | 2.17 x 1.14 x 0.45 | 924 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 22.5 cm = 1.88 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [BrookTrout](previews/BrookTrout.png) | 2.8 x 0.81 x 0.36 | 916 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 29.0 cm = 2.42 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [BrownTrout](previews/BrownTrout.png) | 5.56 x 1.6 x 0.75 | 916 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 57.5 cm = 4.79 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [WhiteBass](previews/WhiteBass.png) | 2.9 x 1.19 x 0.47 | 924 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 30.0 cm = 2.50 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [LakeTrout](previews/LakeTrout.png) | 6.28 x 1.51 x 0.8 | 916 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 65.0 cm = 5.42 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [Muskellunge](previews/Muskellunge.png) | 10.77 x 1.83 x 1.07 | 908 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 95.0 cm = 7.92 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [LakeWhitefish](previews/LakeWhitefish.png) | 3.97 x 1.41 x 0.56 | 916 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 45.0 cm = 3.75 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [FreshwaterDrum](previews/FreshwaterDrum.png) | 4.11 x 1.97 x 0.8 | 924 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 42.5 cm = 3.54 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [Burbot](previews/Burbot.png) | 5.61 x 0.84 x 0.66 | 932 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 57.5 cm = 4.79 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [AlbinoCatfish](previews/AlbinoCatfish.png) | 7.37 x 1.74 x 1.24 | 964 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 75.0 cm = 6.25 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [GoldenTrout](previews/GoldenTrout.png) | 4.11 x 1.23 x 0.52 | 916 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 42.5 cm = 3.54 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [TigerMuskie](previews/TigerMuskie.png) | 12.47 x 2.12 x 1.24 | 908 | FishShadows blobs and the catch held on the line (FishingService.showCatch) | Built at the species' average length, 110.0 cm = 9.17 studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X. |
| [WillowRod](previews/WillowRod.png) | 0.67 x 1.06 x 6.0 | 644 | the gray-box rod part from RodService (Willow) | 6.0 studs long along Z, tip toward -Z (as RodService points it). Put the RodTip attachment at the tip. |
| [FiberglassRod](previews/FiberglassRod.png) | 0.67 x 1.06 x 6.6 | 604 | the gray-box rod part from RodService (Fiberglass) | 6.6 studs long along Z, tip toward -Z (as RodService points it). Put the RodTip attachment at the tip. |
| [GraphiteRod](previews/GraphiteRod.png) | 0.67 x 1.06 x 7.2 | 604 | the gray-box rod part from RodService (Graphite) | 7.2 studs long along Z, tip toward -Z (as RodService points it). Put the RodTip attachment at the tip. |
| [Bobber](previews/Bobber.png) | 0.84 x 1.38 x 0.84 | 304 | the ball Bobber and its Top from FishingService.makeBobber | 0.8 studs across like the gray box; the base is the line eye. |
| [JonBoat](previews/JonBoat.png) | 6.05 x 3.6 x 14.8 | 392 | Nothing yet: the boat from the boat plan (gray box in Task 2, this model after) | Hull 14 x 6 studs; floor at about 0.35 studs above the base. Bow toward -Z. |
| [Dinghy](previews/Dinghy.png) | 3.96 x 2.12 x 8.57 | 708 | The gray-box boat BoatService builds (boat plan Task 2) | 8 x 4 stud inflatable; bow toward -Z. Tubes about 1.2 studs high. |
| [DeepV](previews/DeepV.png) | 7.19 x 4.14 x 17.75 | 548 | The gray-box boat BoatService builds (boat plan Task 2) | 16 x 7 stud hull; bow toward -Z. Helm seat behind the console, navigator seat up front. |

Total: 32 models. Every one is a single mesh well under the 20,000 triangle limit; the biggest is the dock at 1372.
