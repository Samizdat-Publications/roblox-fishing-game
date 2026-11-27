"""Fixed shots, contact sheets and critic score history for the look of the game.

Studio cannot run headless, so a session drives Studio and this script does the rest. Every
command takes --set A|B|U|C|D (default A, the home lake and the creek, so old commands still work):
A home lake and creek, B the Big Lake, C the boats (N4), D the island (N6), U the UI screens.

  python tools/shots/shots.py list [--set B]
  Shots are taken during Play on the Client data model: Edit mode does not have the whole world
  (the builder adds most of it at run time).
  python tools/shots/shots.py snippet pin              run once per Play session (execute_luau, Client):
                                                       hides the HUD, pins clock and camera each frame
  python tools/shots/shots.py snippet 01-dock-dawn      Luau for one shot or screen (execute_luau, Client)
  python tools/shots/shots.py snippet all [--set U]    every shot of a set, for reference
  python tools/shots/shots.py newrun [--set B]         makes artifacts/shots/<stamp>[-<set>]/ and prints it
  (per shot: execute the snippet, then
   powershell -ExecutionPolicy Bypass -File tools/capture-studio.ps1 -ViewportOnly -Out <run>/<id>.jpg
   capture-studio.ps1 picks the window titled "Fishing Game" when several Studios are open)
  Screens (set U, kind "screen"): run pin first, then each screen's snippet; it turns the HUD back
  on over the dock-end noon view and puts the UI in that state. Capture each screen at every size
  in shots.json "screen_sizes" (1280x720 and 667x375; set the viewport with the Device Simulator)
  as <run>/<id>-1280.jpg and <run>/<id>-667.jpg. Run the snippet again right before each capture.
  Frame cost at a shot: run tools/shots/probe.luau the same way; budget in docs/PERF.md.
  Default-look counts: run tools/shots/audit.luau the same way and save its JSON line as
  <run>/audit.json; score stores it beside the scores.
  python tools/shots/shots.py sheet <run> [--before <run>]   contact sheet (and before/after pairs)
  python tools/shots/shots.py score <run> --step <slug> [--runs 3] [--note "..."] [--also identity]
                                                       Neon review, median of runs, appended to
                                                       docs/critic/score_history.json. Rubric by set:
                                                       look for A, B, C, D and ui for U (--rubric
                                                       overrides); --also adds more rubrics in the
                                                       same call, one history entry each.
  sheet and score read the set from the run's run.json when --set is not given.

The UI screens ask a small Studio-only hook in the Controller first and fall back to posing the
interface by hand without it. The hook: in Controller.start, when RunService:IsStudio(), set the
LocalPlayer attribute DebugScreenHook = true, and on a change of the attribute DebugScreen (a
string; ignore nil) first reset (goIdle(), UI.closePanels()), then: "hud" nothing more; "shop"
UI.openShop(); "journal" UI.toggleJournal(); "card" UI.catchCard(a Rare payload: fish
{ id = "LargemouthBass", name = "Largemouth Bass", cm = 46, kg = 1.5, price = 38, spot = "WeedBed",
bait = "PlasticWorm" }, tier "Rare", best true) and then set the CatchCard's "Token" attribute to
-1 so it does not close itself; "fight" UI.setLocked(true), UI.showFight({ zoneSize = 0.3,
zonePos = 0.55, fishPos = 0.6, progress = 0.45, strain = 0.1 }, "Big runs, then rests.", true),
UI.showDrag("Medium", 8); "bench" openBench().

Runs live under artifacts/ (not committed). Copy a sheet worth keeping into docs/critic/ or the making-of.
Standard library plus Pillow.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import statistics
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHOTS = json.loads((Path(__file__).parent / "shots.json").read_text(encoding="utf-8"))
HISTORY = ROOT / "docs" / "critic" / "score_history.json"
RUNS = ROOT / "artifacts" / "shots"
SETS = ("A", "B", "U", "C", "D")
SET_NAMES = {"A": "home lake and creek", "B": "the Big Lake", "U": "UI screens", "C": "boats (added in N4)", "D": "the island (added in N6)"}
DEFAULT_RUBRIC = {"A": "look", "B": "look", "C": "look", "D": "look", "U": "ui"}
SCREEN_SIZES = [tuple(x) for x in SHOTS.get("screen_sizes", [[1280, 720], [667, 375]])]


def set_of(s: dict) -> str:
    return s.get("set", "A")


def in_set(name: str) -> list[dict]:
    return [s for s in SHOTS["shots"] if set_of(s) == name]


def need_set(name: str) -> list[dict]:
    shots = in_set(name)
    if not shots:
        sys.exit(f"Set {name} ({SET_NAMES.get(name, name)}) has no shots yet. Add them to tools/shots/shots.json.")
    return shots


def shot(sid: str) -> dict:
    for s in SHOTS["shots"]:
        if s["id"] == sid:
            return s
    sys.exit(f"No shot named {sid}. Try: python tools/shots/shots.py list --set A|B|U")


def is_screen(s: dict) -> bool:
    return s.get("kind") == "screen"


def file_stems(s: dict) -> list[str]:
    """The image names a shot is captured as (without extension): one per screen size for screens."""
    if is_screen(s):
        return [f"{s['id']}-{w}" for w, _ in SCREEN_SIZES]
    return [s["id"]]


PIN = """-- One-time setup on the Client during Play: hide the HUD and pin clock and camera every frame
-- to _G.__shot, so the game's own camera and day cycle cannot move them.
local RS = game:GetService("RunService")
local L = game:GetService("Lighting")
local SG = game:GetService("StarterGui")
for _, g in game.Players.LocalPlayer.PlayerGui:GetChildren() do
\tif g:IsA("ScreenGui") then g.Enabled = false end
end
pcall(function() SG:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
-- Studio's Automatic quality drops low when its window is not in front (no lantern light, no
-- Soft vs Realistic difference), so pin the desktop tier's top level for every shot.
pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level21 end)
local shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
local looks = shared and shared:FindFirstChild("LookPresets")
local lookMod = looks and select(2, pcall(require, looks))
if _G.__shotHB then _G.__shotHB:Disconnect() end
_G.__shotHB = RS.Heartbeat:Connect(function()
\tlocal s = _G.__shot
\tif not s then return end
\tL.ClockTime = s.clock
\t-- If a look module exists (beauty pass), let it set the light for this hour the same way the game does.
\tif type(lookMod) == "table" and lookMod.apply then lookMod.apply(s.clock) end
\tlocal cam = workspace.CurrentCamera
\tcam.CameraType = Enum.CameraType.Scriptable
\tcam.FieldOfView = s.fov
\tcam.CFrame = CFrame.lookAt(s.eye, s.look)
end)
return "pin ready"
"""

# Runs before every screen's own luau (set U): the background view, the HUD back on, and the
# interface reset to the plain HUD so screens never stack.
SCREEN_PRELUDE = """local P = game:GetService("Players").LocalPlayer
local PG = P:WaitForChild("PlayerGui")
pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level21 end)
if _G.__benchStep then _G.__benchStep:Disconnect(); _G.__benchStep = nil end
local ui = PG:FindFirstChild("FishingUI")
if not ui then return "FishingUI not found: run this on the Client during Play" end
for _, g in PG:GetChildren() do
\tif g:IsA("ScreenGui") then g.Enabled = (g == ui) end
end
for _, n in { "Shop", "Journal", "Pond", "Tackle", "CatchCard", "Fight", "ReelPrompt", "DragBox", "Goals", "Power", "Bite" } do
\tlocal f = ui:FindFirstChild(n)
\tif f and f:IsA("GuiObject") then f.Visible = false end
end
for _, n in { "BaitButton", "JournalButton" } do
\tlocal b = ui:FindFirstChild(n)
\tif b and b:IsA("GuiObject") then b.Visible = true end
end
-- Ask the Studio-only DebugScreen hook in the Controller (see shots.py) when it is there.
local function viaHook(name: string): boolean
\tif P:GetAttribute("DebugScreenHook") ~= true then return false end
\tP:SetAttribute("DebugScreen", nil)
\tP:SetAttribute("DebugScreen", name)
\ttask.wait(0.8)
\treturn true
end
task.wait(0.5)
"""


def shot_line(s: dict) -> str:
    e, l = s["eye"], s["look"]
    return (f"_G.__shot = {{clock = {s['clock']}, fov = {SHOTS['fov']}, "
            f"eye = Vector3.new({e[0]}, {e[1]}, {e[2]}), look = Vector3.new({l[0]}, {l[1]}, {l[2]})}}\n")


def luau_for(s: dict) -> str:
    if is_screen(s):
        sizes = " and ".join(f"{w}x{h}" for w, h in SCREEN_SIZES)
        return (f"-- screen {s['id']}: {s['what']} (capture at {sizes}; run pin first)\n"
                + shot_line(s) + SCREEN_PRELUDE + "\n".join(s["luau"]) + "\n")
    return (f"-- shot {s['id']}: {s['what']}\n" + shot_line(s)
            + f"task.wait(1.5)\nreturn \"shot {s['id']} set\"\n")


def git_commit() -> str:
    try:
        return subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True).strip()
    except Exception:
        return "unknown"


def run_set(run: Path, given: str | None) -> str:
    """The set a run was made for: --set if given, else run.json's, else A."""
    if given:
        return given
    meta = run / "run.json"
    if meta.exists():
        return json.loads(meta.read_text(encoding="utf-8")).get("set", "A")
    return "A"


def cmd_list(a):
    shots = in_set(a.set)
    if not shots:
        print(f"Set {a.set} ({SET_NAMES[a.set]}) has no shots yet.")
        return
    for s in shots:
        files = ", ".join(f + ".jpg" for f in file_stems(s)) if is_screen(s) else ""
        print(f"{s['id']:<22} {s.get('group', s['place']):<8} {s['clock']:>5}  {s['what']}" + (f"  [{files}]" if files else ""))


def cmd_snippet(a):
    if a.id == "pin":
        print(PIN)
    elif a.id == "all":
        for s in need_set(a.set):
            print(luau_for(s))
    else:
        print(luau_for(shot(a.id)))


def cmd_newrun(a):
    shots = need_set(a.set)
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
    run = RUNS / (stamp if a.set == "A" else f"{stamp}-{a.set}")
    run.mkdir(parents=True, exist_ok=True)
    meta = {"stamp": stamp, "set": a.set, "commit": git_commit(), "shots": [s["id"] for s in shots],
            "files": [f + ".jpg" for s in shots for f in file_stems(s)], "fov": SHOTS["fov"]}
    if a.set == "U":
        meta["screen_sizes"] = [list(x) for x in SCREEN_SIZES]
    (run / "run.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(run)


def images(run: Path, shots: list[dict]) -> list[tuple[str, Path | None]]:
    """(label, image or None) for every file the set's shots are captured as, in order."""
    out = []
    for s in shots:
        for stem in file_stems(s):
            p = next((run / f"{stem}{ext}" for ext in (".jpg", ".png") if (run / f"{stem}{ext}").exists()), None)
            out.append((stem, p))
    return out


def cmd_sheet(a):
    from PIL import Image, ImageDraw, ImageFont

    run = Path(a.run)
    shots = need_set(run_set(run, a.set))
    before = Path(a.before) if a.before else None
    cell_w, cell_h, label_h, pad = 480, 300, 26, 8
    try:
        font = ImageFont.truetype("arial.ttf", 16)
    except OSError:
        font = ImageFont.load_default()
    cols = 2 if before else 3
    rows_items = []
    before_imgs = dict(images(before, shots)) if before else {}
    for label, p in images(run, shots):
        if before:
            rows_items += [(f"{label} before", before_imgs.get(label)), (f"{label} after", p)]
        else:
            rows_items.append((label, p))
    rows = (len(rows_items) + cols - 1) // cols
    W = cols * (cell_w + pad) + pad
    H = rows * (cell_h + label_h + pad) + pad
    sheet = Image.new("RGB", (W, H), (24, 30, 34))
    d = ImageDraw.Draw(sheet)
    for i, (label, p) in enumerate(rows_items):
        x = pad + (i % cols) * (cell_w + pad)
        y = pad + (i // cols) * (cell_h + label_h + pad)
        d.text((x + 4, y + 4), label, fill=(230, 236, 234), font=font)
        if p and p.exists():
            im = Image.open(p).convert("RGB")
            im.thumbnail((cell_w, cell_h))
            sheet.paste(im, (x + (cell_w - im.width) // 2, y + label_h + (cell_h - im.height) // 2))
        else:
            d.rectangle([x, y + label_h, x + cell_w, y + label_h + cell_h], outline=(200, 80, 70), width=2)
            d.text((x + 12, y + label_h + 12), "missing", fill=(220, 120, 110), font=font)
    out = Path(a.out) if a.out else run / ("sheet-vs-" + before.name + ".jpg" if before else "sheet.jpg")
    sheet.save(out, quality=88)
    missing = [label for label, p in rows_items if not (p and p.exists())]
    print(out)
    if missing:
        print("Missing:", ", ".join(missing))


def merge_stock_items(verdicts: list[dict]) -> list[dict]:
    """Stock-Roblox items named across runs (identity rubric), most often named first."""
    seen: dict[str, dict] = {}
    for v in verdicts:
        for it in v.get("stock_items", []) or []:
            name = str(it.get("item", "")).strip()
            if not name:
                continue
            key = name.lower()
            if key not in seen:
                seen[key] = {"item": name, "reason": it.get("reason", ""), "runs": 0}
            seen[key]["runs"] += 1
    return sorted(seen.values(), key=lambda x: -x["runs"])


def score_one(a, run: Path, set_name: str, files: list[str], rubric: str, audit: dict | None) -> dict:
    verdicts = []
    step = a.step if rubric == "look" else f"{a.step}-{rubric}"
    for i in range(a.runs):
        out = run / (f"critic-{a.step}-{i + 1}.json" if rubric == "look" else f"critic-{a.step}-{rubric}-{i + 1}.json")
        cmd = [sys.executable, str(ROOT / "tools" / "critic" / "critic.py"), "review", *files,
               "--step", step, "--rubric", rubric, "--json-out", str(out)]
        if a.note:
            cmd += ["--note", a.note]
        subprocess.run(cmd, cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
        verdicts.append(json.loads(out.read_text(encoding="utf-8")))
        print(f"{rubric} run {i + 1}: {verdicts[-1]['score']}/10  ({verdicts[-1]['report']})")
    points: dict[str, list[float]] = {}
    for v in verdicts:
        for x in v.get("scores", []):
            points.setdefault(x["point"], []).append(x["score"])
    entry = {
        "date": dt.date.today().isoformat(),
        "step": a.step,
        "set": set_name,
        "rubric": rubric,
        "run": run.name,
        "commit": json.loads((run / "run.json").read_text())["commit"] if (run / "run.json").exists() else git_commit(),
        "shots": len(files),
        "median": statistics.median(v["score"] for v in verdicts),
        "scores": [v["score"] for v in verdicts],
        "points": {k: statistics.median(v) for k, v in points.items()},
        "reports": [v["report"] for v in verdicts],
    }
    stock = merge_stock_items(verdicts)
    if stock or rubric == "identity":
        entry["stock_items"] = stock
    if audit is not None:
        entry["audit"] = audit
    return entry


def cmd_score(a):
    run = Path(a.run)
    set_name = run_set(run, a.set)
    shots = need_set(set_name)
    found = images(run, shots)
    files = [str(p) for _, p in found if p]
    if not files:
        sys.exit(f"No images for set {set_name} in {run}")
    if len(files) < len(found):
        print(f"Warning: only {len(files)} of {len(found)} images found in {run}")
    audit = None
    audit_path = Path(a.audit) if a.audit else run / "audit.json"
    if audit_path.exists():
        text = audit_path.read_text(encoding="utf-8").strip()
        try:
            audit = json.loads(text[text.index("{"):]) if "{" in text else {"line": text}
        except ValueError:
            audit = {"line": text}
    rubrics = [a.rubric or DEFAULT_RUBRIC[set_name]] + [r for r in (a.also or []) if r != (a.rubric or DEFAULT_RUBRIC[set_name])]
    hist = json.loads(HISTORY.read_text(encoding="utf-8")) if HISTORY.exists() else []
    for rubric in rubrics:
        entry = score_one(a, run, set_name, files, rubric, audit)
        hist.append(entry)
        HISTORY.write_text(json.dumps(hist, indent=2) + "\n", encoding="utf-8")
        print(f"set {set_name}, {rubric}: median {entry['median']}/10 over {a.runs} runs, appended to {HISTORY.relative_to(ROOT)}")
        if entry.get("stock_items"):
            print("  stock Roblox items named: " + "; ".join(f"{x['item']} ({x['runs']}/{a.runs})" for x in entry["stock_items"]))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("list"); p.add_argument("--set", choices=SETS, default="A"); p.set_defaults(fn=cmd_list)
    p = sub.add_parser("snippet"); p.add_argument("id"); p.add_argument("--set", choices=SETS, default="A"); p.set_defaults(fn=cmd_snippet)
    p = sub.add_parser("newrun"); p.add_argument("--set", choices=SETS, default="A"); p.set_defaults(fn=cmd_newrun)
    p = sub.add_parser("sheet"); p.add_argument("run"); p.add_argument("--before"); p.add_argument("--out")
    p.add_argument("--set", choices=SETS, default=None, help="default: the run's own set (run.json), else A")
    p.set_defaults(fn=cmd_sheet)
    p = sub.add_parser("score"); p.add_argument("run"); p.add_argument("--step", required=True)
    p.add_argument("--set", choices=SETS, default=None, help="default: the run's own set (run.json), else A")
    p.add_argument("--runs", type=int, default=3)
    p.add_argument("--rubric", default=None, help="default by set: look for A, B, C, D; ui for U")
    p.add_argument("--also", action="append", help="another rubric scored in the same call, like identity (repeatable)")
    p.add_argument("--audit", default=None, help="audit.luau output saved as JSON (default: <run>/audit.json if present)")
    p.add_argument("--note", default="")
    p.set_defaults(fn=cmd_score)
    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
