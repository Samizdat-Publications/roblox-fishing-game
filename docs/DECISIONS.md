# Decisions

Notable design and build calls, newest last.

## 2026-11-25

- **Rules live in pure shared modules.** Fish habits, bite odds, sizes, prices, the fight and the inventory are plain Luau modules in `ReplicatedStorage.Shared` with no Roblox service calls, so they can be unit tested in Edit mode. Server services are thin wrappers around them.
- **The fight runs on the client, the server checks it.** The bar minigame needs instant response, so the client simulates it with the same `FightModel` and a server-given seed. The server picks the species, rolls the size and price only after a win, and refuses wins that arrive faster than the fastest possible fight (`FightModel.minSeconds`). The client can never pick a fish, a size or a coin amount.
- **One button for everything.** Hold and release to cast, press on a bite to hook, hold to reel, press while waiting to reel in. Mouse button 1 (or F), gamepad R2, and an on-screen Fish button on touch. Journal is J or gamepad Y; bait cycles with B or D-pad right; panels close with gamepad B or Backspace. Stand prompts use E or gamepad X.
- **Cast aims where the camera looks**, flattened to the ground, 8 to 40 studs depending on charge. Works the same on every device.
- **Live bait is used when a fish takes it, lures are kept.** Spinner and plastic worm are bought once. A missed hook does not cost bait, and another bite can come.
- **Nobody gets stuck.** With no bait, no lure and less than the cheapest pack, the shopkeeper gives 5 free worms.
- **Bite speed rewards knowledge.** A spot, time and bait that suit a fish make it bite in about 3 to 5 seconds; a weak match takes up to 14; a combo nothing wants gets a hint after 12 seconds instead of silence.
- **Water is terrain water** (swimmable, so a player who falls in can get out), with an invisible part marking the lake bounds for cast checks. Zones are invisible boxes named by spot.
- **Day length is 16 real minutes**, starting at 7 AM (dawn), so dawn and dusk each last about 2 minutes.
- **Reel assist starts on** (bigger catch zone, slower loss). It can be turned off in the journal.
- **Species reveal on catch.** The fight shows only a hint ("Heavy, keeps pulling down"); the name and journal habit appear when the fish is landed. The journal shows a species' habits only after the first catch, so players learn by fishing.
- **Sync path:** `tools/sync/build_manifest.py` writes `build/manifest.json`; a local `python -m http.server 8765` serves it and `tools/sync/sync.luau`, run through `execute_luau`, creates or updates the scripts. Fallback is `multi_edit`.
- **Studio-only test hook:** the client hooks and reels by itself (through the same input handler) when the player has a `DebugAutoFish` attribute and the game runs in Studio, so automated playtests can land fish. It does nothing in a live game.
- **Own touch button instead of the ContextActionService one.** The built-in touch button came out 45 px and on top of Roblox's jump button on small phones. A 110 px Fish button left of jump, driven by the same handler, is easier for kids' thumbs.
- **Fight bar sits left of center** so a thumb on the Fish button never covers it, and panels shrink to fit short phone screens.
- **Landscape only.** The game sets the screen to landscape; fishing reads better sideways.
- **Pushing code without localhost.** After a Studio update the Assistant blocks localhost HTTP unless the user allow-lists it, so changes go in with `multi_edit` and `tools/sync/verify.py` checks Studio against `src/` by checksum.
- **Pike made a little gentler** (zone 0.24, speed 1.5, loss 0.20) after the unit test showed a perfect player could still lose one.

## 2026-11-25 (evening)

- **Input wins the fight.** The catch zone now aims for a steady climb speed while held (1.25 bar heights a second) and falls at 0.85 when released, reaching those speeds in about a tenth of a second; each fresh click or tap sets an immediate climb. Clicking and holding both work. Species differ by how the fish moves, how long it takes to land, and a small slowdown for heavy fish (up to 12 percent).
- **During a bite or fight, the whole screen is the button.** Input comes from UserInputService, ignoring whether the UI handled it, so no panel or button can steal a reel. Panels are locked and the character stands still for the duration.
- **No accidental recast.** After a fight the button must be released and 0.8 s pass before the next cast.
- **Data version 2** turns reel assist back on for older saves (a test had switched it off on Stewart's save).
- **Pushing code:** `tools/sync/push_snippet.py` builds a paste-ready Luau snippet for whole files when the localhost sync is blocked; `multi_edit` for small edits; `tools/sync/verify.py` confirms the result.
- **Stewart's direction (2026-11-25 evening):** Liam fills in the planner later; until then Claude makes the design calls for looks and fun and logs them here.
- **Home pond rules:** 6 fish, only from your own catches (no buying fish); growth closes 30 percent of the gap to full size per hour; two grown fish of a kind (60 percent of the way to full size) have a 25 percent chance of a baby every 30 minutes; time away counts up to 8 hours. Pond fish sell at their grown size, which makes the pond a slow, steady money-maker without beating active fishing.
- **Pond fish are per player:** the pond is shared scenery, but each player sees only their own fish in it (drawn on their own screen).
- **Rods include the reel** (one item, not two) to keep the shop simple for kids. Three tiers: Willow (free), Fiberglass (120), Graphite (350). Bonuses are cast distance, catch zone size and, for Graphite, less pull from heavy fish; they never change which fish bite, so knowledge still beats gear.
- **Cedar Creek is a stream, not a second lake,** so it plays differently: three short stretches (riffle, rocks, pool) each with one signature fish, all real stream species (rainbow trout, smallmouth bass, walleye). The Creek Pass costs 250 coins once, bought with a one second hold at the gate. The gate opens on the owner's screen only; the server also refuses creek casts without a pass, so it can't be skipped by casting over the fence.

## 2026-11-26 (overnight, cloud, unverified in Studio)

- **Big Lake fish sit in their own data file until the Big Lake exists.** The boat plan asked for new species in `FishData.luau`, but the journal lists every species in it, so three fish nobody can catch yet would show as "???" the moment this merged. They live in `BigLakeFishData.luau` with the same shape; boat plan Task 5 appends them to `FishData` with the zones.
- **The boat starts server-owned.** Roblox's own example hands a driven vehicle to the driver, but it also says the server can't check physics a client owns. A fishing boat is slow, so the server keeps it and checks every move; switch to driver ownership plus checks only if the playtest feels laggy.
- **No deprecated body movers.** The boat uses `LinearVelocity`, `AngularVelocity`, `AlignOrientation` and `AlignPosition`; the `VehicleSeat` is read for input only.
- **Tests also run outside Studio** with Lune (`lune run tools/test/run.luau`), using a small `Random` stand-in. One existing test depends on Roblox's exact random draws for its seed and is reported as skipped there.
- **Models are one mesh with vertex colours.** Roblox allows one material per mesh, so each model's flat-coloured parts are baked into vertex colours and joined. One MeshPart per model, no textures to upload.

## 2026-11-26 (Stewart approved the economy changes; still unverified in Studio)

- **All six economy changes applied** (`docs/ECONOMY.md`): bite time = 3 s / total weight, 3 to 40 s, weaker combos give the "nothing here" hint; panfish prices up and big-fish prices down; Fiberglass Rod 150, Creek Pass 500, Graphite Rod 900; Spinner and Plastic Worm 100; pond, bait and bag left alone; the slack-line rule.
- **Slack line is 2.5 seconds, not 1.** Stewart approved "pressed in the last second", but a 1 second rule punishes the right play against a fish that sits at the bottom of the bar (let go and rest the zone there). Nothing fills until the first press; after 2.5 s without one the line goes slack and progress drains slowly. A tap fixes it; the UI should say "Keep reeling!" (`FightModel.slack`).
- **Players who already bought the Creek Pass at 250 keep it.** Prices only affect new purchases.
- **Fish fight in six styles, chosen from how the real fish fight.** Trout and smallmouth jump, largemouth make runs, catfish and carp bulldog to the bottom, pike and muskie shake their heads, panfish dart, perch and walleye wander. A style only changes how the fish moves on the bar; zone size, gain and loss stay per species, so the economy numbers hold. The test bot that tracks the fish still beats every species, so no style is unfair.
- **Bites have four shapes, and none shortens the hook window below 1.8 s.** Nibble, tap, slam, pull. A pull (catfish, carp) gives a longer window because the real thing is slow. The window floor keeps it fair for younger players.

## 2026-11-26

- **Boat prices stay for now** (Stewart): Inflatable Dinghy 1,200 coins, Deep-V 4,000. Retune after playtests.
- **StyLua:** reformat once, after PR #1 is merged and nothing else is in flight, in a commit of its own ("Format with StyLua, no behavior changes"), pushed into Studio with checksums and tests confirmed. Then the format check in `.github/workflows/checks.yml` becomes enforcing instead of report-only, and Selene's error (and its warnings, if cheap) get fixed.
- **Art house style:** Duet's chunky low-poly, flat-colour, vertex-coloured look. Blender by script (`art/scripts/`) for all props, environment, fish, rods and boats; Meshy only for one-off organic shapes, decimated and recoloured to the palette in Blender; UI icons rendered from the same models; no PixelLab or CadQuery for in-game art. The palette lives in `art/scripts/palette.py`. Details in `art/README.md`.
- **Critic tooling** (`tools/critic/`): standard library Python only (no SDK to install), Files API for clips and audio, small images sent inline, uploaded files deleted after each review. Verdicts are JSON (score, per-point scores, top 3 fixes, strengths, broken) written as Markdown to `docs/critic/`, each with an "Action taken" line. The model ids were checked against the API's model list (gemini-4-hydrogen, -neon, -carbon all exist).
- **The beauty bar:** Neon scored the gray box 3/10 on the first review; a beauty pass is done at 7/10 or better on stills plus a golden-hour clip, with no agreed "broken" items left.

## 2026-11-26 (PR #1 in Studio)

- **A rod's extra reach scales with cast power.** The flat bonus made the Graphite Rod's shortest cast 24 studs, longer than the creek is wide, so the best rod couldn't fish the riffle. Now cast length = 8 + power x (32 + rod bonus): full power reaches exactly as far as before, a soft cast is 8 studs with any rod.
- **The "Keep reeling!" warning waits for the first press.** It showed the instant a fish was hooked, which reads as "you already messed up". Before the first press the bar says "HOLD TO REEL"; the fish still slips away if the player never reels.

## 2026-11-26 (second overnight run, cloud, all unverified in Studio)

- **Size class is rolled at the hook, on the server.** As the rarity plan says: trophies and monsters fight harder, so the fight has to know first. Studio-only test hook: set the player attribute `DebugSizeClass` to `trophy` or `monster`.
- **New Legendary fish were tuned down before landing.** At first try the Lake Sturgeon and Brown Trout put an expert at 104 coins a minute (+32 percent). Rarity and price were cut until the expert sat at +15 percent, the plan's limit, with the dock kid unchanged.
- **Mythics are tied to weather and don't count toward a place's 6 to 10 species.** One per place: Albino Catfish (deep hole, storm nights), Golden Trout (riffle, foggy dawns), Tiger Muskie (island point, the pre-storm rush). A species with a `weather` table only bites in those weathers.
- **Legendary and rarer fish never breed in the home pond,** and a trophy or monster in the pond keeps its size. Otherwise two sturgeon would become a farm.
- **Daily goals are the same for everyone on the same UTC day** (friends can chase them together), never ask for water you can't reach yet, and pay as soon as they're done. Rewards 25, 60 and 120 coins: about 2 minutes of an expert's fishing and 7 of a new player's, so they help the slower player most.
- **Weather is planned per server per game day** (at midnight on the game clock), seeded when the server starts. Servers don't share weather. The look (Atmosphere density, haze, brightness) is a first guess for the critic loop.
- **Frenzies are only for real schooling fish,** Common and Uncommon (bluegill and pumpkinseed at the dock, perch in open water, crappie at the logs, chubs in the riffle, white bass and whitefish on the Big Lake), about 1.2 a game day, a minute each.
- **Boats: one boat per owner waits at the slip, the one chosen in the shop.** Four slips cover a small server; a fifth owner waits for a free slip. Buying a boat makes it the one at the slip.
- **Big Lake fish are now in `FishData.list`** (the journal shows all 26 species), because the Big Lake exists in code (`BoatWorld`). Its fish shadows aren't drawn yet.
- **Team catches split coins evenly with the odd coin to whoever landed it,** and the fish finder shows each mark's tier colour and size, never its name.
- **Sounds play from `Shared/SoundIds.luau` once uploaded;** until an id is pasted in, the game keeps its built-in sounds.
