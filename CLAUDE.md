# Fishing Game (Roblox)

Stewart's Roblox fishing game, built by Claude through Roblox Studio's MCP server. His son joins later as creative director. Read these first, in order: `docs/PROGRESS.md` (where things stand), `docs/superpowers/plans/2026-11-26-next-leg.md` (the current leg, L0 to L7), `docs/DIRECTION.md` (wins over DESIGN), `docs/DESIGN.md` (approved design), `docs/ROUTING.md` (who does what), `docs/RESEARCH.md` (context only).

## How we work here

- Stewart is not learning to code. Claude builds; Stewart steers and playtests. Keep explanations to him short and plain; commands he runs are Windows PowerShell 5.1 one-liners with full paths.
- Studio access: the `Roblox_Studio` MCP server (Claude Code local config for this folder). Every tool takes a `studio_id`; get it from `list_roblox_studios`. If the tools are missing, Stewart must open Studio with the place, and the server must be on (Assistant, ..., Manage MCP Servers).
- Source of truth for code: `src/` in this repo, mirroring Studio services (`src/ServerScriptService`, `src/ReplicatedStorage`, `src/StarterPlayer/StarterPlayerScripts`, `src/StarterGui`). Push changes into Studio with the MCP tools; never leave a script edited only in Studio. Save the place (`save_place`, with a note) after each milestone.
- World geometry lives in Studio (the place). Build gray-box geometry from a script in `src/` (or a builder module) where practical so it can be rebuilt.
- Before every commit to main run the gate: `python tools/check.py` (specs, lint, economy run). Look steps use the fixed shots in `tools/shots/` (`shots.py` explains the loop).
- Verify every milestone in a real playtest: `start_stop_play`, `character_navigation`, input tools, `screen_capture`, `get_console_output`. No "done" without that evidence. Log it in `docs/PROGRESS.md`.
- Commit at each milestone with a clear message; push to `origin` (private GitHub repo Samizdat-Publications/roblox-fishing-game). Never commit `.claude/data/` or `.claude/settings.local.json`.
- Notable design calls go in `docs/DECISIONS.md` (date, call, why).
- Things only Stewart can do (Studio toggles, publishing, account settings): list them in `docs/PROGRESS.md` under "Waiting on Stewart" and keep building around them.

## House rules

- No em dashes in anything a person reads (UI text, docs, commit messages). Code comments are fine.
- Server-authoritative economy. No Robux items, no trading, no custom chat. Rating target Minimal or Mild.
- Original names and art only; no copying other games' fish lists, names or UI.
- `planner/game-lab.html` is the source of the "Liam's Game Lab" planner artifact (https://claude.ai/artifact/NmeUgo27TRphk6aFtejiWJ). Its saved answers are in the artifact's db (collection `plan`, doc `main`). Read it before Liam-facing work.
