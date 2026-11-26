# Adding a step to the making-of

Do this at every milestone, fix or feature. Text describes what was built and what playtests found, never anyone's instructions. No em dashes.

1. **Before you change anything visible**, capture a "before" still of the game view (Studio must not be minimized):
   `powershell -ExecutionPolicy Bypass -File tools\capture-studio.ps1 -ViewportOnly -Out docs\making-of\stills\YYYY-MM-DD-<step>-before.jpg`
   Leave out `-ViewportOnly` to keep Studio's panels in the shot.
2. Build and verify the change in a playtest.
3. Capture the "after" from the same camera position and any extra stills worth keeping (`-after.jpg`, `-<what>.jpg`).
4. Add an entry to the END of `docs/making-of/log.json` (entries are oldest first; the page shows newest first): `id`, `tag` (M7, Fix, Polish, Next...), `date`, `time` (24h), `commit` (fill in after committing), `title`, `summary`, `pairs` (before, after, caption), `stills` (src, caption). Set `"inProgress": true` while a step is unfinished. Update `updated` at the top.
5. `node tools/making-of-readme.mjs` to refresh `docs/making-of/README.md`.
6. Commit the stills, log and README with the step, and push.
7. Republish the page (Artifact tool, publish): `url` https://claude.ai/artifact/HNbZAtLhoHCoeMQ6pNVWQd , `file_path` `docs/making-of/index.html`, `root` `docs/making-of`, `files` = `log.json` plus only the new stills (earlier files stay published). From a conversation that hasn't touched the artifact yet, `read` it first.
