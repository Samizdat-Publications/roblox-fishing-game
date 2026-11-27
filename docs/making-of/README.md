# Fishing Game: the making of

A Roblox fishing game where real fishing knowledge matters: the right bait, spot and time of day decide what bites.

Newest first. The live page with before and after sliders is `docs/making-of/index.html` (published as a Claude artifact).

## Polish: A tiny lighthouse on the island

2026-11-27 10:34 · commit `b9b7a0d`

An easter egg from a real lake the family fishes, where a miniature lighthouse about 6 feet tall stands on a little island. Now the Big Lake's island has one too, on its sandy point: red and white bands, a railed gallery and a lantern that glows warm. It is a little taller than a player, so it reads as a toy-sized lighthouse rather than a real one, and the reeds keep back from it so you can spot it from a boat.

![The miniature lighthouse on the island's point, seen from the water](stills/2026-11-27-lighthouse.jpg)
*The miniature lighthouse on the island's point, seen from the water*

## L7: Fishing from the boat seat

2026-11-27 10:29 · commit `41d835c`

Everything about casting works from the dinghy: the landing ring, the bait bench, the lures, the wait and the reel. You can only cast when the boat is nearly stopped, so no trolling at full speed. The first catch on the Big Lake was a Lake Whitefish in the open basin on worms, then a White Bass at dusk on a spinner, the fish the basin is known for. The playtest caught two more problems: a long spinner cast from the Graphite rod lands 65 studs out, past the 60 stud limit where a boat's line came free, so the limit is now the longest possible cast plus 15; and the camera followed the boat's seat instead of the player, so the bobber camera never started. Now it frames the bobber from the boat just as it does from the dock.

![The cast ring from the seat at dusk: The open basin](stills/2026-11-27-boat-cast-ring.jpg)
*The cast ring from the seat at dusk: The open basin*

![The bobber camera, from the boat](stills/2026-11-27-boat-bobber-cam.jpg)
*The bobber camera, from the boat*

![Casting at full speed: Slow the boat down to cast (and the wake behind)](stills/2026-11-27-boat-slow-down.jpg)
*Casting at full speed: Slow the boat down to cast (and the wake behind)*

## L7: An inflatable dinghy you can buy and drive

2026-11-27 10:29 · commit `41d835c`

Bait and Tackle has a new Boats heading. The Inflatable Dinghy costs 1,200 coins, once, and then waits at slip 1 beside the dock every time you play. Walk up and press E to take the helm; W and S drive and A and D steer. In the playtest it reached 12 studs a second and eased to a stop when let go, stopped against the fallen logs instead of driving through them, went through the channel onto the Big Lake, and was turned back at the buoys with a message that it is too small for the blue water. Pressing E by the slip ties it up and stands you on the dock. Jump out on the water and the empty boat sails home by itself a minute later; reset at the helm and it goes home straight away. Two bugs found and fixed on the way: sitting down dragged the boat onto the dock, and tying up left the player in the water. The two-seat Deep-V shows as coming soon.

![Bought: 1,300 coins to 100, and the dinghy is waiting at the slip](stills/2026-11-27-dinghy-shop.jpg)
*Bought: 1,300 coins to 100, and the dinghy is waiting at the slip*

![The dinghy at slip 1, beside the dock](stills/2026-11-27-dinghy-slip.jpg)
*The dinghy at slip 1, beside the dock*

![Out on the Big Lake, with the buoy line ahead](stills/2026-11-27-dinghy-big-lake.jpg)
*Out on the Big Lake, with the buoy line ahead*

![Turned back at the buoys at night](stills/2026-11-27-dinghy-buoy-line.jpg)
*Turned back at the buoys at night*

## L7: The Big Lake, through a channel in the north shore

2026-11-27 10:29 · commit `41d835c`

North of the home lake there is now a second, much bigger lake (about 400 by 300 studs) that you can only reach by boat. A 30 stud channel cuts through the north shore, with a wooden footbridge so the shore path still goes all the way round. The Big Lake follows the same shore rules as the home lake: rounded corners, three wooded headlands, a sandy point, and a round island whose little east tip is the weedy island point where muskie hide. Its water is terrain, written one voxel at a time from those shore numbers, so the sand shallows, the mud bed 7 studs down and the darker bed 14 down past the line of orange buoys all match what the fishing rules think is there. Hills and stands of trees ring its banks, and invisible walls keep swimmers from climbing out into the land beyond.

**Looking north from over the dock: open grass before, the channel, the footbridge and the Big Lake after**

| Before | After |
|---|---|
| ![before](stills/2026-11-27-big-lake-before.jpg) | ![after](stills/2026-11-27-big-lake-after.jpg) |

![A rounded corner of the Big Lake: beach, reeds and the buoy line](stills/2026-11-27-big-lake-shore.jpg)
*A rounded corner of the Big Lake: beach, reeds and the buoy line*

## Play: Braided line, and a dressed creek bank

2026-11-27 04:25 · commit `a38e4b7`

Bait and Tackle now sells braided line: 120 coins once, and every rod's line gets 4 pounds stronger (the Willow goes from 6 to 10, the Graphite from 15 to 19). Since a big fish running on a tight drag can snap the line, it's a cheaper step than saving for the next rod. In the playtest a bass hooked on the Graphite rod fought on the 19 pound braided line. The creek pool's long bare sand bank also got a few reeds, rocks and bushes.

![Bait and Tackle with braided line owned: the rods show their stronger line](stills/2026-11-27-braided-line-shop.jpg)
*Bait and Tackle with braided line owned: the rods show their stronger line*

![The creek pool's bank at golden hour](stills/2026-11-27-pool-bank.jpg)
*The creek pool's bank at golden hour*

## World: Reasons to come back tomorrow

2026-11-27 04:07 · commit `1c09e83`

A chalkboard by the bait shop shows today's forecast, a fish of the day and a rumour about a Legendary. The shopkeeper hands out a small tackle box once a day. When you come back, a card tells you which of your pond fish grew while you were away. And behind your pond, a trophy wall mounts your six best catches, monsters first.

![Today on the Lake](stills/2026-11-27-chalkboard.jpg)
*Today on the Lake*

![While You Were Away](stills/2026-11-27-away-card.jpg)
*While You Were Away*

![The trophy wall behind the home pond](stills/2026-11-27-trophy-wall.jpg)
*The trophy wall behind the home pond*

## Fix: A real rod, and a better catch moment

2026-11-27 03:55 · commit `9502095`

The rods in your hands are the real models now, with a cork grip, a reel and guides. When you land a fish the card pops in with the fish itself turning in a little window, and Rare or better fish get a badge and a sweep of their tier's colour.

![The real rod in hand](stills/2026-11-27-rod-in-hand.jpg)
*The real rod in hand*

![A Rare largemouth bass on the catch card](stills/2026-11-27-rare-card.jpg)
*A Rare largemouth bass on the catch card*

## Art: A lake that looks real

2026-11-27 03:29 · commit `9f8fc8b`

One long night of light and land. The sky and light now change with the clock: a cool misty dawn, a clear day, a warm golden hour, a violet blue hour and a moonlit night. The water is real water, the land rolls out to the horizon with clumps of trees, the shore curves with points you can walk out on, Cedar Creek meanders between soft banks, and the home pond is round and ringed with rocks. Our look critic scored the twelve fixed views 3 out of 10 at the start of the night and 7 out of 10 at the end.

**The same lake, before and after the night**

| Before | After |
|---|---|
| ![before](stills/2026-11-26-all-models-overview.jpg) | ![after](stills/2026-11-27-round-pond-overview.jpg) |

![Golden hour from the dock](stills/2026-11-27-hills-dock-golden.jpg)
*Golden hour from the dock*

![Blue hour](stills/2026-11-27-dusk-blue-hour.jpg)
*Blue hour*

![The riffle at dawn](stills/2026-11-27-riffle-meadow.jpg)
*The riffle at dawn*

![Night, with the deep-hole buoy lit](stills/2026-11-27-buoy-night.jpg)
*Night, with the deep-hole buoy lit*

## Play: Work the lure, mind the line

2026-11-27 02:05 · commit `b7a82ac`

Lures are fished like lures now: no bobber. Reel a spinner back at a steady speed (a little meter shows too slow, just right, too fast) or hop a plastic worm and let it fall; fish strike while it moves. Every rod has a line rating (6, 10 and 15 pounds) and you choose the drag: Tight lands fish faster but a big one running will snap the line unless you ease off.

![Keeping a spinner in the green](stills/2026-11-27-reel-meter.jpg)
*Keeping a spinner in the green*

## World: Weather, feeding frenzies and daily goals

2026-11-27 00:12 · commit `7ababd4`

Each day has weather that changes the light and the fishing: fog in the morning, storms with rain, cold fronts. Now and then a school of fish boils at a spot with gulls overhead and bites come almost at once. Three goals a day pay a few coins; missing a day costs nothing.

![A foggy dawn](stills/2026-11-27-fog-dawn.jpg)
*A foggy dawn*

![A storm rolls in](stills/2026-11-27-storm.jpg)
*A storm rolls in*

![A frenzy at the dock](stills/2026-11-27-frenzy-dock.jpg)
*A frenzy at the dock*

## Play: Bait the hook yourself

2026-11-26 23:29 · commit `b499f9e`

Every bait has its own short rigging minigame, done the real way: thread a worm with three taps, hook a cricket behind the collar, a minnow through both lips, pack stinkbait. Spinners get a clinch knot and plastic worms a Texas rig. Okay, Good or Perfect changes how fast fish bite and how the fight starts, and the hook size has to suit the fish's mouth. Skip it any time and you get Okay, which is the old game.

![The bait bench: hook, bait, three hook sizes and a timing track](stills/2026-11-27-bait-bench.jpg)
*The bait bench: hook, bait, three hook sizes and a timing track*

![Tying a spinner on](stills/2026-11-27-lure-bench.jpg)
*Tying a spinner on*

## Play: The wait, and the fight

2026-11-26 22:34 · commit `52d538f`

When the bobber lands the camera eases onto it, and a fish's shadow swims in, circles and noses the bait before it bites; a quick tap twitches the bait to tempt it. In the fight each kind of fish warns you before its big move: a runner screams the drag, a jumper splashes, a diver bends the rod tip down. The line turns white, orange, then red as it strains.

![The bobber camera while you wait](stills/2026-11-27-bobber-camera.jpg)
*The bobber camera while you wait*

![A fight, with the line showing the strain](stills/2026-11-27-fight.jpg)
*A fight, with the line showing the strain*

## Play: Aim your cast, and a reason to aim

2026-11-26 20:59 · commit `ece97a0`

Hold to cast and a ring rides out across the water to show where the bobber will land, with the spot's name on it; let go when it's where you want it. The water now gives you reasons to aim: land on a fallen log or in the thick of the weeds and you snag (four wiggles to free it), a fish dimpling the surface somewhere means a quick bite if you land close, and cover-loving fish like bass and crappie are likelier near logs, the dock and the weed edge.

![The cast ring, out over the water with the spot's name](stills/2026-11-27-cast-ring.jpg)
*The cast ring, out over the water with the spot's name*

![Amber over a log: a snag warning before you let go](stills/2026-11-27-ring-at-the-logs.jpg)
*Amber over a log: a snag warning before you let go*

## Art: The whole lake in our own models

2026-11-26 16:30 · commit `f883e07`

The rest of the art is in: a Fish Buyer stand, a stone rim for the home pond, mossy logs half sunk in the water, a red and white buoy over the deep hole, reed clumps and lily pads in the weed bed, leafy trees round the lake, pines and rocks along Cedar Creek, a new bobber, and every fish hangs on the line as itself. While checking, the whole lake turned out to have been knocked 55 studs sideways and 10 up in Studio, away from its own water; it is back in place. Walking, casting, selling and the pond all work as before.

![The lake with every model in](stills/2026-11-26-all-models-overview.jpg)
*The lake with every model in*

![Night at the deep hole: a catfish pulls the new bobber under, the new buoy behind](stills/2026-11-26-all-models-bobber-bite.jpg)
*Night at the deep hole: a catfish pulls the new bobber under, the new buoy behind*

![Pines and rocks along Cedar Creek](stills/2026-11-26-all-models-creek.jpg)
*Pines and rocks along Cedar Creek*

![Mossy logs in the east shallows](stills/2026-11-26-all-models-logs.jpg)
*Mossy logs in the east shallows*

## Art: Our first models in the game

2026-11-26 13:30 · commit `c4041a7`

The dock, the Bait and Tackle stand and the bluegill, built by script in Blender, are now in the game. The dock has planks, posts, bollards and two lanterns at the far end; the shop has a striped awning, bait tubs and a rod rack. A landed bluegill now hangs on the line as the real fish. The first import came in nearly black because Blender and Roblox store colours differently, so a small converter now fixes every model before upload. Everything still walks, casts and shops exactly as before, because the old gray blocks stay underneath as invisible floors and walls.

**The dock, gray box and model**

| Before | After |
|---|---|
| ![before](stills/2026-11-26-models-dock-before.jpg) | ![after](stills/2026-11-26-models-dock-after.jpg) |

**Bait and Tackle, gray box and model**

| Before | After |
|---|---|
| ![before](stills/2026-11-26-models-shop-before.jpg) | ![after](stills/2026-11-26-models-shop-after.jpg) |

![Standing at the end of the new dock](stills/2026-11-26-models-dock-end.jpg)
*Standing at the end of the new dock*

![A bluegill as it hangs on the line](stills/2026-11-26-models-bluegill-on-line.jpg)
*A bluegill as it hangs on the line*

## Sound: The lake comes alive with sound

2026-11-26 11:30 · commit `f132de3`

Twenty-seven sounds made with ElevenLabs are now in the game. Birds at dawn, a loon at dusk, frogs at night, and running water that gets louder as you walk to the creek. While you wait, the world goes quiet and the bobber ticks; every kind of bite has its own sound, from a light tap to a deep pull for a catfish. The reel clicks faster when a fish is about to get away, the drag zips when it runs, and a catch ends on a splash sized by the fish and a little tune. A critic model listened to playtest clips and scored it 6 out of 10; after fixing the heavy cast splash, the quiet bites and a late chime it scored 7.

![The quiet wait at dawn, where the bobber ticking does the work](stills/2026-11-26-sound-wait.jpg)
*The quiet wait at dawn, where the bobber ticking does the work*

## Fix: Every fish bites and fights its own way

2026-11-26 10:30 · commit `c0f7a77`

Panfish now nibble the bobber before they take it, perch and trout tap, bass and pike slam it under, and catfish pull it slowly down. On the bar each kind moves differently: bass run back and forth, pike make huge jumps and dive, catfish stay low and steady, trout sit low and then leap. A fish left alone slips the hook, and the bar flashes KEEP REELING! once you stop. Prices were rebalanced so a good spot pays and the Creek Pass now costs 500. The playtest also found that the best rod cast too far to fish the narrow creek; soft casts are short again with any rod.

![Stop reeling and the bar warns you before the fish slips away](stills/2026-11-26-fish-feel-keep-reeling.jpg)
*Stop reeling and the bar warns you before the fish slips away*

![Bait and Tackle with the new prices](stills/2026-11-26-fish-feel-shop.jpg)
*Bait and Tackle with the new prices*

## Art preview: Our own models, first set (Blender previews)

2026-11-26 01:50 · commit `368c415`

An art preview, not yet in the game. Thirty-two low-poly models built by script in Blender overnight: the dock, both market stands, the pond's stone rim, logs, a buoy, reeds, lily pads, pines, a leafy tree, rocks, all eleven fish in their real colours and at true relative size, the three rods with reels, the bobber, and a Jon boat for the boat to come. Each is one mesh with baked colours, sized in studs to drop onto the gray box it replaces. These are renders from Blender; they still need to be imported and checked in Studio.

![All 32 models (Blender renders, not in the game yet)](stills/2026-11-26-art-contact-sheet.jpg)
*All 32 models (Blender renders, not in the game yet)*

![Bluegill, with its dark ear flap and orange belly](stills/2026-11-26-art-bluegill.jpg)
*Bluegill, with its dark ear flap and orange belly*

![The new dock, the same size as the gray-box one](stills/2026-11-26-art-dock.jpg)
*The new dock, the same size as the gray-box one*

## Next: Cedar Creek

2026-11-25 20:20 · commit `cb022b1`

A stream west of the lake behind a tall fence. A 250 coin Creek Pass opens the gate. Its riffle, rocks and deep pool each hold a new fish: rainbow trout at dawn, smallmouth bass by day, walleye after dark. In the playtest the gate blocked the way until the pass was bought, then three trout, three walleye (up to 70 cm and 72 coins) and two smallmouth came out of the creek. The first look found the riffle's water missing; it was too thin for Roblox terrain and now fills properly.

**The west side before and after Cedar Creek**

| Before | After |
|---|---|
| ![before](stills/2026-11-25-creek-before.jpg) | ![after](stills/2026-11-25-creek-after.jpg) |

![The riffle and the rocks, looking upstream](stills/2026-11-25-creek-riffle.jpg)
*The riffle and the rocks, looking upstream*

## Next: Better rods

2026-11-25 19:55 · commit `dc2dd04`

Bait and Tackle now sells rods. Everyone starts with the Willow Rod; the Fiberglass Rod (120 coins) casts 8 studs further and gives a bigger catch zone, and the Graphite Rod (350 coins) casts 16 studs further, has the biggest zone and takes half the pull out of heavy fish. The rod in your hands changes to match. In the playtest a full-power cast went 40 studs with the Willow Rod and 48 with the Fiberglass Rod.

**Bait and Tackle before and after the Rods section**

| Before | After |
|---|---|
| ![before](stills/2026-11-25-rods-before.jpg) | ![after](stills/2026-11-25-rods-after.jpg) |

![The yellow Fiberglass Rod in hand](stills/2026-11-25-rods-in-hand.jpg)
*The yellow Fiberglass Rod in hand*

## Next: Your own pond

2026-11-25 19:25 · commit `2b41b0e`

A stone pond next to the shop where you keep fish from your bag, up to 6 at a time. They grow toward full size while you play and while you're away (up to 8 hours), two grown fish of a kind can have babies, and you sell them later at their bigger size or let them go. Each player sees their own fish swimming in it. In the playtest a bass worth 34 coins when caught sold for 50 after three hours of pond time, and the pond kept all its fish after a restart. Breeding was then slowed down after four babies arrived in three hours.

![Five bass swimming in the pond](stills/2026-11-25-pond-full.jpg)
*Five bass swimming in the pond*

![The pond sign and its Check pond prompt](stills/2026-11-25-pond-stand-close.jpg)
*The pond sign and its Check pond prompt*

![Choosing which fish from the bag to keep](stills/2026-11-25-pond-keep-fish.jpg)
*Choosing which fish from the bag to keep*

![A kept bass swimming in the pond](stills/2026-11-25-pond-stand.jpg)
*A kept bass swimming in the pond*

![Baby bass in the pond panel after three hours of pond time](stills/2026-11-25-pond-babies.jpg)
*Baby bass in the pond panel after three hours of pond time*

## Polish: Fish shadows, the catch on the line, night lamps

2026-11-25 19:11 · commit `34d1104`

Fish shadows now swim where the bite rules say fish should be, a landed fish hangs on the line before it goes in the bag, and lamps on the dock light up the water at night.

**Night at the dock, before and after the lamps**

| Before | After |
|---|---|
| ![before](stills/2026-11-25-m3-night-deep-hole.jpg) | ![after](stills/2026-11-25-polish-night-after.jpg) |

![A bluegill held on the line](stills/2026-11-25-polish-catch-on-line.jpg)
*A bluegill held on the line*

![The Sell Fish sign](stills/2026-11-25-polish-sell-sign.jpg)
*The Sell Fish sign*

![A dock lamp by day](stills/2026-11-25-polish-dock-lamp.jpg)
*A dock lamp by day*

## Fix: The reel always answers

2026-11-25 19:06 · commit `6198609`

The first playtest found that clicking sometimes barely moved the catch zone, and clicks on some parts of the screen lost the fish. Now any click or hold anywhere on screen reels, the player's pull always beats the fish's, buttons step aside during a fight, and a big REELING! prompt shows that it is working.

**The fight: before, and after with the hold-anywhere REELING! prompt**

| Before | After |
|---|---|
| ![before](stills/2026-11-25-reel-before.jpg) | ![after](stills/2026-11-25-reel-after.jpg) |

![The same fight on a phone, with a big REEL button](stills/2026-11-25-reel-phone.jpg)
*The same fight on a phone, with a big REEL button*

## M6: Phone and controller

2026-11-25 18:43 · commit `04d3e64`

On the smallest phone in Studio's simulator, the first pass found a tiny touch button sitting on top of jump, a fight panel over the top bar, and a journal taller than the screen. All fixed: a big Fish button, a moved and shorter fight panel, panels that shrink to fit. Gamepad works too: R2 to cast and reel, Y for the journal. Version 1 complete.

**Phone layout: the tiny touch button, then the big Fish button**

| Before | After |
|---|---|
| ![before](stills/2026-11-25-m6-phone-before.jpg) | ![after](stills/2026-11-25-m6-phone-after.jpg) |

![Fighting a fish on a phone](stills/2026-11-25-m6-phone-fight.jpg)
*Fighting a fish on a phone*

![The journal on a console screen](stills/2026-11-25-m6-console-journal.jpg)
*The journal on a console screen*

## M5: Fish journal and saving

2026-11-25 18:35 · commit `33e0c7f`

Press J for the journal: every species with its count, best weight and length, the bait and spot it was caught on, and a habit tip once you've caught one. Undiscovered fish show as question marks. Coins, bait and the journal save to Roblox and come back after leaving.

![The fish journal, 5 of 8 species found](stills/2026-11-25-m5-journal.jpg)
*The fish journal, 5 of 8 species found*

## M4: Money and the bait shop

2026-11-25 18:35 · commit `33e0c7f`

The Fish Buyer pays coins, worked out on the server so nobody can cheat it. Bait and Tackle sells worms, crickets, minnows, stinkbait and a spinner, and the bait on your hook changes what bites. Six fish sold for 27 coins in the first test.

![The Fish Buyer stand](stills/2026-11-25-m4-sell-stand.jpg)
*The Fish Buyer stand*

![Bait and Tackle: each bait says which fish it suits](stills/2026-11-25-m4-bait-shop.jpg)
*Bait and Tackle: each bait says which fish it suits*

## M3: Real fish habits

2026-11-25 18:35 · commit `33e0c7f`

Eight species, each with its own spots, feeding times, baits, sizes and fight. Tested by fishing them the real way: perch and bluegill at the dock at dawn on worms, largemouth bass at the weed bed at dawn on minnows, channel catfish in the deep hole at 10 PM on stinkbait. The wrong bait at the wrong spot gets a hint instead of a bite.

![10 PM at the end of the dock, stinkbait in the deep hole: catfish time](stills/2026-11-25-m3-night-deep-hole.jpg)
*10 PM at the end of the dock, stinkbait in the deep hole: catfish time*

## M2: Cast and catch

2026-11-25 18:29 · commit `af16abb`

Hold and release to cast, wait for a bite, hook it, then keep the fish in the green zone until the bar fills. A cast onto dry ground is refused with a hint. The first fish landed was a 19.2 cm pumpkinseed worth 6 coins. The hook window went from 1.6 to 2 seconds to be kinder to young players and touch screens.

![Line in the water, waiting for a bite at the dock](stills/2026-11-25-m2-waiting-for-bite.jpg)
*Line in the water, waiting for a bite at the dock*

![First catch: a new species card for a pumpkinseed](stills/2026-11-25-m2-first-catch.jpg)
*First catch: a new species card for a pumpkinseed*

## M1: Gray-box lake

2026-11-25 18:29 · commit `af16abb`

A lake built entirely by script: terrain water, a dock from the south shore, a weed bed, five fallen logs, a deep hole marked by a red buoy, a shore path, and two stands. Players spawn on the dock with a rod. A 16 minute day runs from dawn to night.

![The whole lake from above: dock, weed bed, logs, deep hole buoy, and the two stands](stills/2026-11-25-m1-lake-overview.jpg)
*The whole lake from above: dock, weed bed, logs, deep hole buoy, and the two stands*

![First spawn, rod in hand](stills/2026-11-25-m1-spawn-dock.jpg)
*First spawn, rod in hand*

## M0: Pipeline: code in Git, pushed into Studio

2026-11-25 18:29 · commit `af16abb`

All game code lives as files in the repo and is pushed into Studio script by script, then checked byte for byte. A test script made the full round trip: created, read back, run in a playtest, logged, deleted. 22 scripts and 23 unit tests went in.

## Start: Design approved, empty Baseplate

2026-11-25 18:07 · commit `32f4cd8`

The plan: one lake that plays well before anything else, built from plain gray blocks. Eight real lake fish with real habits, a bar minigame that starts easy, a sell stand, a bait shop, a fish journal, and saving. The research behind it found that the biggest Roblox fishing games reward collecting but never real fishing knowledge, so that became the hook. Built by Claude Opus 5.5 working inside Roblox Studio through Studio's MCP server.
