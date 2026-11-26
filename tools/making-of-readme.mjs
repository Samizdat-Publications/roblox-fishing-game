// Writes docs/making-of/README.md from docs/making-of/log.json, so GitHub (and Claude Duet) show the
// making-of with images inline. Run: node tools/making-of-readme.mjs
import { readFileSync, writeFileSync } from "node:fs";

const dir = new URL("../docs/making-of/", import.meta.url);
const log = JSON.parse(readFileSync(new URL("log.json", dir), "utf8"));
const L = [];
L.push(`# ${log.project}: the making of`, "", log.pitch || "", "");
L.push("Newest first. The live page with before and after sliders is `docs/making-of/index.html` (published as a Claude artifact).", "");
for (const e of [...log.entries].reverse()) {
  L.push(`## ${e.tag}: ${e.title}`, "", `${e.date} ${e.time || ""}${e.commit ? ` · commit \`${e.commit}\`` : ""}${e.inProgress ? " · in progress" : ""}`, "", e.summary || "", "");
  for (const p of e.pairs || []) {
    L.push(`**${p.caption || "Before and after"}**`, "", "| Before | After |", "|---|---|", `| ![before](${p.before}) | ![after](${p.after}) |`, "");
  }
  for (const s of e.stills || []) L.push(`![${s.caption || ""}](${s.src})`, `*${s.caption || ""}*`, "");
}
writeFileSync(new URL("README.md", dir), L.join("\n"));
console.log("Wrote docs/making-of/README.md with", log.entries.length, "entries");
