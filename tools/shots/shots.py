"""Fixed shots, contact sheets and critic score history for the look of the game.

Studio cannot run headless, so a session drives Studio and this script does the rest:

  python tools/shots/shots.py list
  Shots are taken during Play on the Client data model: Edit mode does not have the whole world
  (the builder adds most of it at run time).
  python tools/shots/shots.py snippet pin              run once per Play session (execute_luau, Client):
                                                       hides the HUD, pins clock and camera each frame
  python tools/shots/shots.py snippet 01-dock-dawn      Luau for one shot (execute_luau, Client)
  python tools/shots/shots.py snippet all              every shot, for reference
  python tools/shots/shots.py newrun                   makes artifacts/shots/<stamp>/ and prints it
  (per shot: execute the snippet, then
   powershell -ExecutionPolicy Bypass -File tools/capture-studio.ps1 -ViewportOnly -Out <run>/<id>.jpg
   capture-studio.ps1 picks the window titled "Fishing Game" when several Studios are open)
  Frame cost at a shot: run tools/shots/probe.luau the same way; budget in docs/PERF.md.
  python tools/shots/shots.py sheet <run> [--before <run>]   contact sheet (and before/after pairs)
  python tools/shots/shots.py score <run> --step <slug> [--runs 3] [--note "..."]
                                                       Neon look review, median of runs, appended to
                                                       docs/critic/score_history.json

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


def shot(sid: str) -> dict:
    for s in SHOTS["shots"]:
        if s["id"] == sid:
            return s
    sys.exit(f"No shot named {sid}. Try: python tools/shots/shots.py list")


PIN = """-- One-time setup on the Client during Play: hide the HUD and pin clock and camera every frame
-- to _G.__shot, so the game's own camera and day cycle cannot move them.
local RS = game:GetService("RunService")
local L = game:GetService("Lighting")
local SG = game:GetService("StarterGui")
for _, g in game.Players.LocalPlayer.PlayerGui:GetChildren() do
\tif g:IsA("ScreenGui") then g.Enabled = false end
end
pcall(function() SG:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
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


def luau_for(s: dict) -> str:
    e, l = s["eye"], s["look"]
    return (f"-- shot {s['id']}: {s['what']}\n"
            f"_G.__shot = {{clock = {s['clock']}, fov = {SHOTS['fov']}, "
            f"eye = Vector3.new({e[0]}, {e[1]}, {e[2]}), look = Vector3.new({l[0]}, {l[1]}, {l[2]})}}\n"
            f"task.wait(1.5)\nreturn \"shot {s['id']} set\"\n")


def git_commit() -> str:
    try:
        return subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True).strip()
    except Exception:
        return "unknown"


def cmd_list(_):
    for s in SHOTS["shots"]:
        print(f"{s['id']:<20} {s['place']:<6} {s['clock']:>5}  {s['what']}")


def cmd_snippet(a):
    if a.id == "pin":
        print(PIN)
    elif a.id == "all":
        for s in SHOTS["shots"]:
            print(luau_for(s))
    else:
        print(luau_for(shot(a.id)))


def cmd_newrun(_):
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
    run = RUNS / stamp
    run.mkdir(parents=True, exist_ok=True)
    meta = {"stamp": stamp, "commit": git_commit(), "shots": [s["id"] for s in SHOTS["shots"]], "fov": SHOTS["fov"]}
    (run / "run.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(run)


def images(run: Path) -> list[tuple[dict, Path | None]]:
    out = []
    for s in SHOTS["shots"]:
        p = next((run / f"{s['id']}{ext}" for ext in (".jpg", ".png") if (run / f"{s['id']}{ext}").exists()), None)
        out.append((s, p))
    return out


def cmd_sheet(a):
    from PIL import Image, ImageDraw, ImageFont

    run = Path(a.run)
    before = Path(a.before) if a.before else None
    cell_w, cell_h, label_h, pad = 480, 300, 26, 8
    try:
        font = ImageFont.truetype("arial.ttf", 16)
    except OSError:
        font = ImageFont.load_default()
    cols = 2 if before else 3
    rows_items = []
    for s, p in images(run):
        if before:
            bp = images(before)[[x["id"] for x in SHOTS["shots"]].index(s["id"])][1]
            rows_items += [(f"{s['id']} before", bp), (f"{s['id']} after", p)]
        else:
            rows_items.append((s["id"], p))
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


def cmd_score(a):
    run = Path(a.run)
    files = [str(p) for _, p in images(run) if p]
    if len(files) < len(SHOTS["shots"]):
        print(f"Warning: only {len(files)} of {len(SHOTS['shots'])} shots found in {run}")
    verdicts = []
    for i in range(a.runs):
        out = run / f"critic-{a.step}-{i + 1}.json"
        cmd = [sys.executable, str(ROOT / "tools" / "critic" / "critic.py"), "review", *files,
               "--step", a.step, "--rubric", a.rubric, "--json-out", str(out)]
        if a.note:
            cmd += ["--note", a.note]
        subprocess.run(cmd, cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
        verdicts.append(json.loads(out.read_text(encoding="utf-8")))
        print(f"run {i + 1}: {verdicts[-1]['score']}/10  ({verdicts[-1]['report']})")
    points: dict[str, list[float]] = {}
    for v in verdicts:
        for x in v.get("scores", []):
            points.setdefault(x["point"], []).append(x["score"])
    entry = {
        "date": dt.date.today().isoformat(),
        "step": a.step,
        "rubric": a.rubric,
        "run": run.name,
        "commit": json.loads((run / "run.json").read_text())["commit"] if (run / "run.json").exists() else git_commit(),
        "shots": len(files),
        "median": statistics.median(v["score"] for v in verdicts),
        "scores": [v["score"] for v in verdicts],
        "points": {k: statistics.median(v) for k, v in points.items()},
        "reports": [v["report"] for v in verdicts],
    }
    hist = json.loads(HISTORY.read_text(encoding="utf-8")) if HISTORY.exists() else []
    hist.append(entry)
    HISTORY.write_text(json.dumps(hist, indent=2) + "\n", encoding="utf-8")
    print(f"median {entry['median']}/10 over {a.runs} runs, appended to {HISTORY.relative_to(ROOT)}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list").set_defaults(fn=cmd_list)
    p = sub.add_parser("snippet"); p.add_argument("id"); p.set_defaults(fn=cmd_snippet)
    sub.add_parser("newrun").set_defaults(fn=cmd_newrun)
    p = sub.add_parser("sheet"); p.add_argument("run"); p.add_argument("--before"); p.add_argument("--out"); p.set_defaults(fn=cmd_sheet)
    p = sub.add_parser("score"); p.add_argument("run"); p.add_argument("--step", required=True)
    p.add_argument("--runs", type=int, default=3); p.add_argument("--rubric", default="look"); p.add_argument("--note", default="")
    p.set_defaults(fn=cmd_score)
    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
