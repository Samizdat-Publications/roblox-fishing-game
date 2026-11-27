# Sound upload plan

Written 11/26/2026, when Stewart's account hit Roblox's audio upload cap. Code: `src/ReplicatedStorage/Shared/SoundSheets.luau` (sheets and stand-ins, tested in `SoundSheets.spec`), `tools/audio/build_sheet.py` (packs a sheet).

## Update, 11/27/2026: the cap is lifted

Stewart completed Roblox age verification on the uploading account on 11/27/2026. The account had already used all 100 uploads for the month, and that evening six more went through (two sheets, two motor loops, the frenzy loop and the frenzy music), so the verification counts. The exact new monthly number isn't shown anywhere we can read; leg 3 still budgets uploads and keeps the sheets. Rain comes from Roblox's licensed library (Pro Sound Effects, no upload).

## The cap (checked in Roblox's docs, 11/26/2026)

- From Roblox's audio guide (https://create.roblox.com/docs/audio/assets.md): unverified accounts can import **100** free audio assets per 30 days; **ID-verified accounts can import 2,000** per 30 days. A daily limit, if any, is replaced by the monthly one.
- The count is per account, so the Fishing Game and Dont Wave Back (Dead Calm) share it while one account uploads for both. Today's 100 were 27 for this game and 73 for Dead Calm. The window resets about 12/26/2026.
- **The fix is ID verification** (Stewart completed age verification on the uploading account on 11/27/2026; the next upload will show whether the cap is now 2,000), which lifts the cap to 2,000. Only the account that uploads needs it: the one Studio is signed in as when Claude uploads. Until it's done, the rules below apply.
- Models and images have their own limits and are not affected.

## Split between the two games (until verification)

The next 100 uploads: **60 for the Fishing Game, 40 for Dont Wave Back.** Both sessions log each upload against their share in their own audio README. After ID verification the split no longer matters.

## Every sound the game needs

Status: **up** = uploaded and playing; **stand-in** = plays a borrowed uploaded sound with another speed, region or volume until its own upload; **sheet** = will ship inside a sound sheet (one upload covers many); **later** = only needed when its feature is switched on.

| Sound | Status now | Ships as | Priority |
|---|---|---|---|
| amb-lake-dawn, -day, -dusk, -night, amb-creek | up | own file (loops) | done |
| wait-bobber-tick | up | own file | done |
| bite-nibble, bite-tap, bite-slam, bite-deep-pull | up | own file | done |
| reel-click, drag-zip, line-strain, thrash-splash | up | own file | done |
| splash-small, splash-big | up | own file | done |
| sting-common to sting-godlike (7), sting-new-species | up | own file | done |
| theme-lake, theme-creek, tension-fight | up | own file | done |
| bobber-plop | up (sheet-water, 11/27) | sheet-water | done |
| cast-whoosh | up (sheet-water, 11/27) | sheet-water | done |
| line-snap | up (sheet-water, 11/27) | sheet-water | done |
| pond-splash | up (sheet-water, 11/27) | sheet-water | done |
| sting-trophy | stand-in (sting-rare, slower) | own file | 2 |
| sting-monster | stand-in (sting-mythic, slower) | own file | 2 |
| server-horn | stand-in (sting-legendary, slowed slice) | own file | 2 |
| sell-coins | up (sheet-ui, 11/27) | sheet-ui | done |
| journal-page, ui-click, ui-open | up (sheet-ui, 11/27) | sheet-ui | done |
| goal-complete | up (sheet-ui, 11/27) | sheet-ui | done |
| bait bench: worm wriggle, hook click, knot pull, minnow flick, squish, cricket chirp | none (L3) | sheet-bait | 1 when L3 starts |
| L4 the wait: a low swell as a fish shadow comes for the bait, a twitch flick | none | sheet-water or own | 1 when L4 starts |
| frenzy-boil | up (own loop, 11/27) | own file (loop) | done |
| frenzy-burst | up (own file, 11/27) | own file | done |
| rain-on-water, thunder-far, wind-gust | up: rain from the licensed library, thunder and wind in sheet-water (11/27) | library / sheet | done |
| amb-biglake, amb-bluewater, theme-biglake, tension-bluewater | none | own files | later (Big Lake) |
| motor-dinghy-idle, motor-dinghy-run, boat-bump, buoy-bell | up (motors own loops, the rest in sheet-water, 11/27); motor-deepv-run waits for the Deep-V | own / sheet | done |
| breach-huge | stand-in (splash-big, slower) | own file | later (Godlike events) |
| winter: ice crack, auger, wind over ice | none | own / sheet | later (seasons) |

## Order for the next uploads

1. **Suspense and bite cues** (the wait and the bite are the heart of it): sheet-water (cast whoosh, bobber plop, line snap, pond splash, boat bump, buoy bell) as one upload, then the L4 wait cues.
2. **Rarity stingers:** sting-trophy, sting-monster, server-horn (own files, they're long and loud).
3. **Place ambience** as places switch on: Big Lake and blue water, rain, wind, thunder.
4. **The rest:** sheet-ui, sheet-bait (with L3), frenzy, motors, music for the Big Lake.

Roughly: 2 sheets plus 3 stingers is 5 uploads for this leg's needs, against 60 in our share. The cap only bites if every later feature lands before 12/26.

## How it works

- **Sound sheets:** short one-shots share a file. `SoundSheets.sheets` lists each sheet's cues (start and length in seconds). `python tools/audio/build_sheet.py sheet-water` packs `audio/final/<cue>.mp3` files into `audio/sheets/sheet-water.mp3` at those starts, trimmed and faded so cues never bleed. Upload the sheet once and paste its id into the sheet's `id`; every cue then plays as a region (`Sound.PlaybackRegion`).
- **Stand-ins:** `SoundSheets.standIns` borrows an uploaded sound (a speed, a slice, a volume). `SoundSheets.resolve` picks, in order: the sound's own id in `SoundIds`, its sheet's region, its stand-in, or nothing (SoundFX skips it).
- **Swapping in a real upload** is one line: paste the id into `SoundIds` (own file) or the sheet's `id`. The stand-in stops being used by itself.
- **Free library:** Roblox's licensed Creator Store sounds (for example creator ProSoundEffects) can be used by id with no upload. Use them for anything generic we don't need to own (rain, wind, thunder, motors) before spending uploads on them.
