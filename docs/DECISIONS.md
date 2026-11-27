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

## 2026-11-26 (sound pass)

- **Sound ids live in code, not in the place.** `Shared/SoundIds.luau` maps each sound name to its asset id and the client builds the Sound objects at start, so the sound setup is in `src/` and survives a world rebuild. An empty id is skipped, so a sound can be swapped or removed without breaking anything.
- **The music is sparing.** A place's theme plays at most once every 4 minutes, only after 10 s with no line in, and fades out the moment you cast. The waiting is meant to be quiet; the bobber and the bites carry it.
- **The tension layer follows the fish's weight, not its species.** The species stays secret until it's landed, so the client uses the fight's heaviness (catfish, carp, pike, walleye) to bring in the low music.
- **Stingers read the species' rarity tier and fall back to Common.** Main has no tiers yet; when PR #2's tiers merge, the right stinger plays without a code change.
- **Uploads go through Open Cloud** from `C:\Users\stewa\Documents\Claude\Roblox` (approved by Stewart in Studio's MCP Permissions). Each sound was uploaded once; ids are recorded right away so nothing is uploaded twice.

## 2026-11-26 (first models)

- **Models sit over the gray box instead of replacing it.** The gray-box parts stay as invisible collision and cast-check shapes and the models never collide or block a raycast. Walking, casting, zones and prompts don't change at all, and a model can be swapped or removed without touching gameplay.
- **Placement lives in code** (`WorldBuilder.dress` and its `ART` list), the models live in `ServerStorage.Art`. Rebuilding the lake keeps the art.
- **Colours are converted outside Blender** (`art/scripts/roblox_colors.py`) so the Blender scripts and previews stay true to glTF; only the uploaded copy is changed.
- **Only the bluegill hangs as a model so far.** Every other species keeps the old shape until its model is uploaded; adding one is an upload plus an insert into `ServerStorage.Art`, no code.

## 2026-11-26 (leg plan, Fable 5.2 review)

- **The leg plan for 11/27 to 12/17/2026 is `docs/superpowers/plans/2026-11-26-next-leg.md`** (L0 to L7). It sits under `DIRECTION.md` and adds Stewart's priority: the cast (control over where and how far) and a bait-the-hook minigame come before the beauty pass. Readable page: https://claude.ai/artifact/3F2bNUEujyw3c92QDYqWox (source `planner/next-leg.html`).
- **Stewart's rulings for this leg** (asked directly): Liam plays along the way and steers each milestone, no reveal date; only Stewart and Liam play, no publishing work; no Robux, and ElevenLabs, Gemini and Meshy keep running at today's pace without asking per batch; voice chat off and aim for a Minimal or Mild rating (Stewart does those clicks).
- **Fable 5.2 is the orchestrator; routing per `docs/ROUTING.md`.** The agent files the routing names (builder, grunt, scout, verifier, modeler) are in `.claude/agents/` so it works from any machine. Stewart set the main session for L0 onward to Opus 5.5 at high effort; hard calls go to Fable through `fable-advisor`, and looks are still judged by the main session, never handed to a subagent.
- **PR #2 lands behind switches.** Weather, frenzies, goals, boats and the Big Lake each get an on and off switch in `Config` when PR #2 is merged (start of L1), so each is proven by itself.
- **The harness:** `tools/shots/shots.json` is the fixed list of 12 views (8 lake, 4 creek; dawn, noon, golden hour, night). `tools/shots/shots.py` makes the Studio snippet for each shot, the contact sheet (with before and after pairs) and the critic score (median of 3 Neon runs, appended to `docs/critic/score_history.json`). `tools/shots/probe.luau` measures frame time. `tools/lint.py` fails on em dashes in docs and in Luau strings. `tools/check.py` is the gate before every commit to main (Lune specs, compile check when present, lint, quick economy run); the lint also runs on GitHub.

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
- **The 25 new sound prompts slot into the sound pass's `Shared/SoundIds.luau` with empty ids,** so `SoundFX` skips them until they're generated and uploaded; a trophy or monster plays its own stinger once uploaded and the tier stinger until then.
- **A boat's heading is held by one AlignOrientation that the server turns each frame,** not an AngularVelocity next to it. Two constraints on the same axis fight each other; one target also rights the hull after a bump.
- **Goals never send anyone to blue water,** because it needs a full crew; boat owners can get Big Lake basin and island goals. A frenzy goal counts catches made while the server's frenzy is on at that spot, decided on the server.
- **Journal rumours sharpen with play:** ten catches after a tier's first rumour, the rumour also names the best bait. Knowledge stays earned, not bought.
- **Gulls over a frenzy are client-only visuals,** placed at the server's boil (`workspace` attribute `FrenzyAt`), so every player sees them in the same place without the server moving parts.
- **The driver's client sends the helm's controls (`BoatInput`), and the server still drives the boat.** A VehicleSeat only copies Throttle and Steer to the server when the driver owns the physics, and these boats stay server-owned so nobody can fly one. Inputs are clamped and go stale after half a second.
- **A save that couldn't be read is never written over.** The player plays on fresh data that session with a message to rejoin; before, three failed reads gave fresh data that autosave then wrote over the real save.
- **The switches are plain booleans in `Config`, all off,** and a switched-off feature leaves no trace a player can find: no Goals button, no boats in the shop (the server still answers the shop so it never waits), clear skies. Boats count as on only when the Big Lake is on, since the slips and channel are part of the Big Lake build.

## 2026-11-26 (all models)

- **The lake was moved back to its coordinates.** After a Studio restart the whole `Workspace.Lake` model sat 6 studs west, 10 up and 55 north of where `WorldBuilder` builds it, while the terrain water, the fishing zones and the cast checks stayed put. Nothing in the game wants that offset, so it was moved back exactly (ground top at y = 1) and the art re-dressed. If you ever drag the lake on purpose, tell Claude: the zone and water boxes in `WorldBuilder` would need to move with it.
- **Placement stays in code, with three kinds of place:** an exact spot, a seeded scatter (reeds, lily pads) that comes out the same on every rebuild, or fitted over a gray-box part (logs, pines, rocks). The gray-box parts stay as invisible collision, so the creek boulders still block wading.
- **Rods in hand stay gray-box for now.** The rod models are uploaded, but swapping the held rod touches the weld, the tip attachment the line hangs from, and every device's camera view; it gets its own step with a playtest.
- **Fish shadows stay as soft blobs.** They are shadows under the water; real fish models there would read as fish floating in plain sight and give away the species.


## 2026-11-26 (house style: Real-ish)

- **The house style is now Real-ish** (Stewart's pick from the six style options in PR #3, https://github.com/Samizdat-Publications/roblox-fishing-game/pull/3). It means chunky, simple shapes with realistic materials. It replaces the flat vertex-colour low-poly look from earlier the same day. Rules are in `art/README.md`.
- **Why, over the critic's ranking:** Gemini 4 Neon ranked it last (7.3 against 8.2 for the top two), but the gap is small, and it came from one model scoring AI concept art. Its main knocks apply to any style and have known fixes: busy textures hiding the bobber (a glowing bobber and line) and dark night shots. Stewart judged the lake concept the best-looking of all, and that's his call.
- **Quality first, within a measured phone budget.** Stewart wants it to look as good as we can get it without hitting a performance ceiling. That means two layers. Roblox's built-in materials go on terrain and large surfaces, where they look good for free. Custom PBR textures go wherever they clearly look better, with fish first. A full-quality test corner of the lake, measured on the smallest phone and Stewart's phone, sets the per-area budget before the rest is re-dressed.
- **Where the game is going (Stewart, 2026-11-26), so the style has to scale to it:** a much bigger lake that needs vehicles to cross; fishing islands, each with its own exotic fish found only there; a trophy case for your fish; and a breeding genetics system, growing from the home pond's breeding. Each island becomes its own streaming area with its own texture set. These are direction, not scheduled work; they get planned after the current leg.
- **Liam can still vote** on the style page (https://claude.ai/artifact/MJJUZdAHyNqWKE5TdgvX8d). A different pick from him is a conversation, not a rebuild.

- **Desktop is the main platform; mobile is second** (Stewart, 2026-11-26). The look is aimed at a desktop PC: a steady 60 frames a second on Stewart's PC at the fixed shots. Phones must stay smooth and readable, at least 30 frames a second on Stewart's phone and the smallest simulated phone, with a lighter tier of extras on touch devices. Updated in `art/README.md`, `DIRECTION.md`, the L5 checks in the leg plan, and the critic's context and rubrics. The critic keeps the `phone_readability` name so score history stays comparable.
- **When Fable plans next:** two sessions. First, a short one before L5 (by about 12/08). L5 was planned for the old low-poly look and now has to build Real-ish. The world map has to be set before L5 shapes the shoreline and hills and L7 builds the Big Lake: lake size for vehicles, island spots, and streaming areas. Second, the full next-leg plan when L7 wraps (about 12/16 to 12/17), for the islands and their own fish, the bigger lake and vehicles, the trophy case (L6's trophy wall is a start) and breeding genetics (growing from the pond).

- **Art fallback: Cozy Diorama** (Stewart, 2026-11-26). If the Real-ish proof corner cannot hit the frame budgets (60 frames a second on Stewart's PC, 30 on his phone and the smallest simulated phone) after reasonable tuning, the house style falls back to Cozy Diorama (`docs/styles/diorama/` in PR #3, https://github.com/Samizdat-Publications/roblox-fishing-game/pull/3), which needs far less texture memory. Stewart sees the measurements before the switch. Rule added to `art/README.md`.
- **Rarity and Godlike direction** (Stewart, 2026-11-26): tier odds like a normal collecting game (Legendary about once every session or two when fishing well, Mythic tied to conditions, Godlike rarest and event-only), value matches rarity (a fish pays about what normal fishing earns in the time it takes to find one, plus a premium; this replaces the idea of Legendaries paying less), and Godlike fish are original giant myth-level creatures run as boss-style events. Full text in `docs/RARITY-DIRECTION.md`.
- **The lake's look changes over time instead of being one fixed look** (Stewart, 2026-11-26). The five look mockups (https://claude.ai/artifact/DjMRLNSn6t91zKmR93sGr6) are hours and seasons of the same Real-ish lake, not rivals: the beauty pass (L5) builds the day cycle (misty dawn, bright day, golden afternoon, moonlit night). Seasons come later: autumn colours, then a winter where the lake freezes for an ice-fishing minigame (`docs/IDEAS.md`).

## 2026-11-26 (night, L1 and Stewart's go-aheads)

- **The six Real-ish looks are approved as a set** (Stewart: "These look great"). No single pick: the beauty pass (L5) builds the day cycle (misty dawn, bright day, golden afternoon, moonlit night), starting with golden afternoon, Summer Day's water (light in the shallows, dark over the deep hole) and Night's glowing bobber. Autumn and the frozen winter with ice fishing come later as seasons.
- **Rarity retune (my calls on RARITY-DIRECTION.md, numbers in `docs/ECONOMY.md`):** odds follow the tier, Epic and Legendary capped at their best spot, value about the inverse of how often a tier lands, small fish take lures now and then, rock bass and carp feed at night. Where the direction's two columns disagree, the feel wins for Legendary (about one every two sessions); the share column guides the lower tiers. A lure expert landing mostly Rare predators is accepted as the reward for lures. Tier labels are unchanged.
- **Ocean dock and boats (Stewart, 2026-11-26):** later there is a second dock on an ocean (or a Great Lake if the ocean can't be made to work), where vehicles come into play and how far out you can go depends on the boat. **Every boat can be run by one person but works better with two**, for example throttle and steering at different ends of the boat that one player can still manage alone. This changes the boat plan's Deep-V rule (it needed two aboard to move): in L7 the Deep-V moves with one person, and a second player makes it better, not possible. Recorded for L7 and the next-leg planning.
- **Sound uploads:** Stewart's account hit Roblox's audio cap (100 uploads per 30 days, shared by both games, resets about 12/26/2026). Plan in `audio/UPLOAD-PLAN.md` (stand-ins until then).
- **Sound under the upload cap (my calls, plan in `audio/UPLOAD-PLAN.md`):** Roblox's docs say the cap is 100 per 30 days unverified and 2,000 when ID verified, so verification is the real fix (Stewart plans it 11/27/2026; it's the account Studio uploads with). Meanwhile: stand-ins borrow uploaded sounds (`SoundSheets.standIns`), short one-shots ship in sound sheets played as regions (one upload, many sounds), uploads go in priority order (suspense and bite cues, rarity stingers, place ambience, the rest), and the next 100 split 60 Fishing Game, 40 Dont Wave Back. Generic sounds (rain, wind, motors) try Roblox's free licensed library first.
- **Moving the game to another account:** Roblox transfers games only into a group (Creator Dashboard, Publish settings, Initiate ownership transfer); the game keeps its id and link. Assets stay owned by the account that uploaded them, so check permissions for sounds and models before a transfer.
- **Full sim, kid-beatable (Stewart, 2026-11-26):** the more detailed the actual fishing the better: the cast, choosing and putting the bait on the hook, and reeling in. Aim for a full fishing sim, but easy enough that a 13-year-old who knows a little about fishing can beat it. This sets the bar for L2 (the cast), L3 (the bait bench) and L4 (the wait and the reel): real technique that pays off, clear feedback, and nothing that needs adult reflexes or reading.
- **StyLua reformat waits for the localhost sync** (my call): reformatting touches every script, so Studio would need every script re-pushed by hand (about 400 KB through the tool). Once Stewart allows `localhost:8765` in Studio's MCP permissions the sync tool pushes everything in one call; do the reformat then, in its own commit, and make the format check enforcing.

## 2026-11-26 (night): Gemini Hydrogen code review (`docs/reviews/2026-11-26-gemini-hydrogen-review.md`), what I took

- **Taken, L2b (next):** the "nothing wants this" hint names a better choice right there (the best bait for this spot now, or the best spot for this bait now) instead of the generic advice, so a kid doesn't read it as a broken timer. A save-migration test that loads a save from every older version (v2 to v6) and checks coins, journal and pond survive. Snags (already L2) make live-bait spend matter.
- **Taken, L4 (the wait and the reel, full sim):** reel assist turns itself off after the first 3 catches and stays a journal toggle; try `FIGHT_IDLE_GRACE` near 1.2 s (now 2.5) against the sim and a playtest; each of the six fight styles gets a visible and audible tell (drag scream on runners, a breach splash on jumpers, and so on); juice: a line that shifts colour with tension, ripple rings on cast and bite, a rod tip that bends, and a short "hold up your catch" moment for trophies and monsters. A lower fight start for rarer fish is folded into the same tuning.
- **Taken, L5 (beauty pass), added to its list:** four lighting presets blended by the clock (already the plan, now Real-ish), a shoreline with coves and a peninsula instead of the rectangle, deeper water darkening toward the deep hole, and a clear landmark at every fishing spot.
- **Taken, L6 (weather):** cap fog density about 0.45 so the bobber stays visible at the Graphite Rod's full reach; wind and cold fronts drive wave size and cloud cover.
- **Checked and partly stale:** "a smart player caps all upgrades in about 10 minutes". Today's sim has the Graphite Rod at 20 minutes for a smart player without a pond and 24 with one, 53 for the dock kid (after the rarity retune). A mid-tier lure around 350 to 400 coins is a good idea for the shop curve; it waits for the L3 bait bench, where lures get their own rigging.
- **Logged as an idea, not built (needs Stewart):** feeding pond fish to trigger breeding, and a journal badge for raising a bred fish to trophy size (`docs/IDEAS.md`).
- **Skipped:** Rojo `default.project.json`. Studio blocks localhost, so Rojo's sync can't run either; the MCP push with checksums works. Revisit if Stewart allows `localhost:8765`.
