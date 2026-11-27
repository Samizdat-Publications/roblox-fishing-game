# Ideas backlog

Raw ideas to plan later. Not approved designs: the Fable 5.2 planning session (set for 2026-11-26) turns the good ones into plans. Newest at the bottom; add a date to each.

## From Stewart's playtests

- 2026-11-26 **See the bait on the hook.** The worm, cricket, minnow, stinkbait or lure on the line, visible in your hand and on the cast, so you can tell what's on without reading the HUD.
- 2026-11-26 **Lures change the cast.** A spinner casts farther than live bait (heavier, more aerodynamic). That gives a real reason to pick lures for far spots, alongside what each fish wants.
- 2026-11-26 **A better cast.** More physical: a back swing and release, the line arcing out, a lure whose weight changes the arc, a splash where it lands. Clearer power and aim feedback, with matching graphics such as a power meter, an aim marker on the water and a landing ripple.
- 2026-11-26 **Variety, rarity and huge hauls.** Captured in `DIRECTION.md`, section 3: seven tiers up to Godlike, trophy and monster fish, feeding frenzies.
- 2026-11-26 **Beauty and suspense.** Captured in `DIRECTION.md`, sections 1 and 2.
- 2026-11-26 **Pond breeding you can steer** (from Gemini Hydrogen's review): feed pond fish to trigger breeding, and a journal badge for raising a bred fish to trophy size. Needs Stewart's OK.
- 2026-11-26 **An ocean dock.** A second dock on the ocean (or a Great Lake), where the boats matter and how far out you can go depends on the boat. Every boat works with one person and better with two (for example throttle and steering at different ends of the boat).
- 2026-11-26 **Seasons and a frozen lake.** One Real-ish lake that changes with the time of day (dawn mist, bright day, golden afternoon, moonlit night) and with the seasons (autumn colours, then winter). In winter the lake freezes over, which opens a winter fishing minigame: cut a hole in the ice and fish through it. Later work, after the current leg; the beauty pass (L5) builds the day cycle first.

## Found while testing

- 2026-11-26 Automated playtests wasted most of their time facing land. Fix in progress: a test shortcut to stand at each spot facing the water, plus a player cast assist that turns a near-miss toward the water.

## From the overnight build (11/27/2026)

- 2026-11-27 **The real rod in your hands.** Done the same night: the rod models are welded along the invisible logical rod, and hide while RodFeel draws the bend.
- 2026-11-27 **Look critic's remaining asks.** Done the same night (now 7/10): trees in clumps, signs on top, a round stone-edged home pond, short grass by the creek, the noon light. Still open: night water and the bobber at night, signs hiding sooner than 140 studs, the creek pool's straight sand bank, the even lake path, Lighting.Technology to Future (a Studio setting, check on a phone first).
- 2026-11-27 **Buy line, not just rods.** Done the same night: braided line, 120 coins once, 4 lb more on any rod (save v10).

## From Gemini's Leg 3 Review (2026-11-27)

- 2026-11-27 **Buddy Tackle Loan & Cedar Creek Guest Pass (Co-op).** When a player boards another player's boat (or joins their crew at the Boathouse), let the guest temporarily fish using the boat owner's unlocked rod line rating and shared boat tackle box for that trip (still earning their own coins and journal catches, with zero player trading). Also let a player walking within 20 studs of a Creek Pass holder pass through the Cedar Creek gate as a guest.
- 2026-11-27 **Double Hookup! (Co-op).** When two players within 15 studs hook and fight fish at the same time, show a brass "DOUBLE HOOKUP!" banner, raise tension music, and award a +25% coin bonus and a Double Haul journal stamp if both land their fish.
- 2026-11-27 **Bow Chumming (Co-op).** Give a seated boat passenger a 90-second cooldown "Toss Chum" action that spawns a 25-second mini-boil ripple ahead of the bow, pulling fish shadows closer and cutting bite wait time by 25% for everyone aboard.
- 2026-11-27 **"The One That Got Away" Rematch Swirl.** When a Rare+, Trophy, or Monster fish snaps the line or spits a mismatched hook, leave a private dark swirl at that spot for 2 minutes with a toast telling the player what to fix (hook size or drag). Casting back into the swirl with corrected gear grants a rematch strike.
- 2026-11-27 **Quick-Rig (`Auto-Good`) on the Bait Bench.** Keep the full Bait Bench as the only path to `Perfect` (`0.8x` wait, `50%` bait survival, weedless Texas rig), and unlock an optional Quick-Rig button (`Auto-Good`) during an active Feeding Frenzy or after mastering 10 `Perfect` rigs on that bait.
- 2026-11-27 **Interactive Home Pond ("Feed & Watch" + Simple Color Morphs).** Render actual scaled `FishModels` inside the Home Pond, add a once-per-game-day `E: Toss Feed` prompt for a 2-hour `1.5x` growth/breeding buff, and give pond-born fish a `1 in 12` chance of a natural color morph (Golden, Albino, Piebald, Midnight) tinted over `FishSkin`.
- 2026-11-27 **Topwater Frog & Vertical Deep Jig lures.** Two new retrieve modes in `Retrieve`: a surface Popper/Frog hopped and paused over `WeedBed` and `LilyCove`, and a Deep Leadhead Jig dropped straight under a boat at `DropOff` while watching the Deep-V Fish Finder marks rise toward it.
- 2026-11-27 **Wildlife Tells & World Discovery Secrets.** One Great Blue Heron that flies to whichever shore spot currently holds the best bite weight; 2 to 3 flip-stones/logs in Cedar Creek and the N6 island yielding rare non-shop Wild Crayfish/Hellgrammite bait once a day; and 3 washed-up Myth Clues around the Big Lake and island that unlock a "Myths of the Deep" journal page revealing the Godlike ritual.
- 2026-11-27 **Two-Phase Co-op Godlike Boss Blueprint.** Build Liam's Godlike encounter around the Deep-V and Net: Phase 1 requires the driver to steer with the monster's runs to bleed line strain while the navigator tracks sonar; Phase 2 brings a surface breach where the crewmate uses a timed Team Net/Gaff prompt to secure the catch.
