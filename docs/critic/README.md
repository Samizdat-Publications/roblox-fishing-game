# Critic verdicts

Written by `tools/critic/critic.py`: Gemini 4 models watching our stills and playtest clips (with audio) and scoring them against a rubric in `tools/critic/rubrics/`. One file per review: `<date>-<step>-<model>.md`. Each ends with "Action taken": what we changed because of it, or why we didn't. The critics inform; the playtest and Stewart decide.

- **Neon** (`gemini-4-neon`): everyday critic, every look or sound step. `python tools/critic/critic.py review --step <slug> --rubric look|sound|playtest <files>`
- **Hydrogen** (`gemini-4-hydrogen`): cheap screener for many variants. `python tools/critic/critic.py rank --step <slug> --criteria "<what best means>" <files>`
- **Carbon** (`gemini-4-carbon`): milestone design consultant, shown DESIGN, DIRECTION, PROGRESS plus stills and clips. `python tools/critic/critic.py consult --step <slug> --question "<question>" <files>`

Needs `GEMINI_API_KEY` in the repo's `.env` (never committed). Standard library Python only.

## The bar

The first Neon review (`2026-11-25-baseline-look-neon.md`) scored the gray-box look 3/10. A beauty pass is done when Neon scores the place at least 7/10 on stills and a golden-hour clip, with no "broken or ugly" item left that we agree with.
