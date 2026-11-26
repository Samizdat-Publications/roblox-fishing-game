# Direction: beauty, sound, fish variety and rarity

Set 2026-11-26. This sits alongside `DESIGN.md` and wins where they differ. Three things now lead the game:
1. **The beauty of the fishing places.**
2. **Sound that builds suspense.**
3. **Lots of fish, with clear rarity tiers and the occasional huge haul.**

## 1. Beauty of the fishing places comes first

Every fishing spot should look like a postcard you'd want to sit at, at every time of day. Players should take screenshots.

- **Light does the heavy lifting:**
  - Future lighting, a tuned Atmosphere (haze, glare, decay), ColorCorrection and SunRays;
  - a soft Bloom on water glints;
  - Lighting presets that blend through dawn, day, golden hour, dusk and night.
  
  Golden hour and blue hour should be the most beautiful moments and should line up with the best bites.
- **Water is the star.** Tune terrain water colour, transparency, reflectance, wave size and speed per place:
  - the lake is calm and mirror-like at dawn;
  - the creek is clear and quick over stones;
  - the deep hole is dark;
  - add mist at dawn, lily pads and reeds at the edges, insects over the water at dusk, and moon glitter at night.
- **Each place gets its own mood and palette, drawn from real lakes** (no real place names): pine-dark lake water, a sunlit stream, later a misty big lake and a frozen lake.
- **Models** follow the house style in `art/README.md`: Real-ish, Stewart's pick on 2026-11-26. That means chunky, simple shapes made by script in Blender, with realistic materials (Roblox's built-in materials first, custom textures only on hero props). Materials and light make the models beautiful, not polygon counts.
- **Phones count.** The look has to hold up on the smallest phone in the Device Simulator, without heavy effects that tank the frame rate.
- **Judged by a critic, not by us.** Every look pass is checked by the Gemini critic (section 5) on stills and a short video. Iterate until it scores well, and log the before and after stills in the making-of.

## 2. Sound design builds suspense

Sound turns waiting for a bite into tension, and a bite into a jolt. Use ElevenLabs liberally.

- **Ambience per place and time:**
  - **Lake:** birds at dawn, distant loons at dusk, crickets and frogs at night, wind in the pines, lapping at the dock.
  - **Creek:** running water that gets louder as you walk closer.
  
  Loop the ambience seamlessly and crossfade it with the clock.
- **The wait is the suspense.** While the line is in, the music drops away, and small sounds tell the story:
  - the bobber ticking in the ripples;
  - a faint tap as a fish noses the bait;
  - a held breath of near silence before a strike.
  
  Bigger and rarer fish get a lower, heavier pre-bite cue: a deep pull in the water, a low swell. A sharp listener learns to hear what's coming.
- **The fight:**
  - reel clicks and the drag zip follow line tension, and the pitch rises as it nears breaking;
  - the line creaks and strains when it's about to snap;
  - heavy thrashing comes in when the fish runs;
  - splashes are sized by the fish's weight.
- **The reveal:** a catch stinger that scales with rarity, from a soft pluck for a Common up to a full choir swell for a Godlike. The music swells briefly, then settles back to the place's theme.
- **Music:**
  - one calm theme per place, played sparingly;
  - a tension layer that fades in during fights with rare fish;
  - short stingers for new species, records and huge hauls.
- **Tools:**
  - ElevenLabs **SFX v3** (`eleven_text_to_sound_v3`) for effects and ambience; generate several variants of each and keep the best.
  - ElevenLabs **Eleven Music v2.5** (`music_v2_5`) for themes and stingers.
  
  Key: `ELEVENLABS_API_KEY` in the local `.env` (never committed). Every sound must pass Roblox's audio upload rules and moderation. Keep a list of each sound, its prompt and its asset id in `audio/README.md`.

## 3. Fish variety and rarity tiers

Seven tiers, each with a colour used everywhere it appears: catch card, journal, shadows, stingers.

| Tier | Colour | Feel |
|---|---|---|
| Common | gray | every cast |
| Uncommon | green | most sessions |
| Rare | blue | a good find |
| Epic | purple | the right spot, bait and time |
| Legendary | orange-gold | the story you tell later |
| Mythic | pink-red | a once-in-a-while legend; special conditions, often weather |
| Godlike | shifting rainbow | one or two in the whole game; a myth players hunt for |

**Rarity comes from real behaviour.** The right spot, time, bait and (later) weather is what makes a rare fish possible. Nothing is ever sold to raise luck. This builds on the overnight bite rule: rare fish only bite in narrow conditions.

**Variety target:**
- each place has 6 to 10 species, including at least one Legendary;
- Mythics are tied to places and weather;
- Godlike fish are hidden across the game;
- aim for about 30 species by public launch, each with real habits, its own fight and bite style, its own model, and a journal entry with a tip.

**Huge hauls,** two kinds:
- **Trophy and monster fish:**
  - every catch already has a size;
  - a small chance, around 2 percent, of a Trophy: top-end length, much heavier, a bigger payout and a bigger fight;
  - a much smaller chance, around 0.2 percent, of a Monster: record-breaking, far bigger than normal.
  
  Each gets a celebration: a slow-motion leap, a camera push-in, a stinger, a journal record, and a server-wide message for Monsters.
- **Feeding frenzies:** a short burst where a school boils at the surface and bites come back to back, for a big bag in a minute. A weather or time-of-day event, announced by sound and sight (birds diving, water boiling).

Keep the overnight economy check honest: trophies, monsters and frenzies are exciting but rare, and their payouts should not undo the money curve. Re-run `tools/econ/sim.py` after adding them.

## 4. Order of work (after the overnight merge)

1. **Rarity tiers:** tiers on every species, tier colours in the UI, trophy and monster sizes with their celebrations, then re-run the economy simulation.
2. **Sound pass on the lake and creek:** ambience, waiting and bite cues, fight sounds, reveal stingers, place themes.
3. **Beauty pass on the lake, then the creek:** lighting presets, water, mist, particles, the new models, with a critic loop on stills and video.
4. **More species,** up to 8 to 10 per place, each with a model from the house style.
5. **Feeding frenzies,** alongside the weather work in `WEATHER.md`.

Each step: playtest in Studio, before and after stills in the making-of, commit and push.

## 5. Critics and review

All three Gemini 4 models take video, images and audio natively, so the critic watches real playtest footage, not just stills. Set it up as `tools/critic/` (a script that sends files to the Gemini API with a rubric and writes the verdict to `docs/critic/<date>-<step>.md`).

- **Recording:** record playtest clips from Studio, 10 to 30 seconds each:
  - a cast and bite;
  - a fight;
  - a catch reveal;
  - a slow walk along the shore at golden hour;
  - the same spot at night.
  
  Use the MCP server's video capture where it works, or a screen recording of the Studio window. Keep the audio in, so the critic hears the sound design. Stills come from `tools/capture-studio.ps1`.
- **Gemini 4 Neon** (`gemini-4-neon`) is the everyday critic, run on every look or sound step. Rubric:
  - composition, light, water and mood;
  - whether it looks like a place you'd want to fish;
  - readability on a phone;
  - whether the waiting builds suspense and the bite lands;
  - whether the catch reveal feels earned for its rarity;
  - anything broken or ugly.
  
  It gives a score and its top 3 fixes. Iterate until the score clears the bar set in the first review.
- **Gemini 4 Hydrogen** (`gemini-4-hydrogen`) is the cheap screener: rank many ElevenLabs variants or model previews quickly and pass only the best to Neon or a human.
- **Gemini 4 Carbon** (`gemini-4-carbon`), the most capable and the slowest, is the occasional design consultant at milestones. Give it the project itself: `DESIGN.md`, `DIRECTION.md`, `PROGRESS.md`, the latest stills and 2 or 3 clips. Ask it open questions: what would make this more fun, more beautiful or more tense; what is missing compared with the best fishing games; what looks broken. Its answers are suggestions for the next plan, never orders.
- Key: `GEMINI_API_KEY` in the local `.env`. The critics inform; the playtest and Stewart decide. Log every verdict, including the ones not acted on.
- Antigravity is installed if a second set of agent hands is ever useful; nothing here depends on it.

Sources checked 2026-11-26:
- [ElevenLabs models](https://elevenlabs.io/docs/overview/models)
- [ElevenLabs SFX v3 changelog](https://elevenlabs.io/docs/changelog/2026/11/2)
- [Gemini API models](https://ai.google.dev/gemini-api/docs/models)
