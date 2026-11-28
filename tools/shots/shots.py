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
  python tools/shots/shots.py snippet weather          Luau for the SERVER (execute_luau, Server, not Client):
                                                       sets workspace DebugWeather to Clear, waits 25 s for
                                                       the look to settle, returns the Weather attribute
  Weather: every scored shot must be taken under Clear. The client cannot force it: DebugWeather
  is a server attribute (Studio only; WeatherService then holds that kind through every refresh,
  the UTC date roll and game midnight included, until it is cleared). Run "snippet weather" on
  the Server once per Play session, after pin. Each shot snippet returns the Weather it sees,
  like "shot 03-dockend-noon set Clear"; record it right after the capture:
  python tools/shots/shots.py weather <run> <id> <kind>  writes run.json "weather": {"<id>": "<kind>"}
                                                       (<id> may be "all" for every shot of the run)
  (per shot: execute the snippet, then
   powershell -ExecutionPolicy Bypass -File tools/capture-studio.ps1 -ViewportOnly -Out <run>/<id>.jpg
   capture-studio.ps1 picks the window titled "Fishing Game" when several Studios are open)
  Screens (set U, kind "screen"): run pin first, then each screen's snippet; it turns the HUD back
  on over the dock-end noon view and puts the UI in that state, and returns the viewport and the
  weather it sees, like "screen u02-shop set viewport 1600x900 weather Clear". Two sizes per screen
  (N2 review 1, 11/27/2026), the file names kept from shots.json "screen_sizes":
    desktop <run>/<id>-1280.jpg: NO Device Simulator. The Studio viewport as it is, at least 1280 by
      720 (make the Studio window big), captured unscaled: capture-studio.ps1 ... -Width 4000.
    phone <run>/<id>-667-raw.jpg: the Device Simulator at 667 by 375, the whole letterboxed viewport,
      also with -Width 4000. Then "phonecrop" cuts the device out to exactly 667 by 375 and saves
      it at 2x (Lanczos) as <run>/<id>-667.jpg, the file the sheet and the critic use.
  The capture loop for set U, per screen and per size (all desktop files first, then the phone):
    1. execute_luau (Client) "snippet <id> --set U"; it returns "... viewport WxH weather K"
    2. execute_luau (Client) "snippet uicheck"; save the JSON line it returns as
       <run>/<stem>-uicheck.json (<stem> is <id>-1280 or <id>-667)
    3. python tools/shots/shots.py uicheck <run> <stem> <run>/<stem>-uicheck.json
       records it in run.json "uicheck" and its viewport in "viewport". If anything is outside the
       viewport it says so: fix the UI or move on; score leaves that file out either way.
    4. run the screen snippet again, then capture-studio.ps1 -ViewportOnly -Width 4000
       -Out <run>/<id>-1280.jpg (desktop) or -Out <run>/<id>-667-raw.jpg (phone)
    5. python tools/shots/shots.py weather <run> <id> <kind>  (once per screen, from step 1)
  Then: python tools/shots/shots.py phonecrop <run>   (every *-667-raw.jpg to its 2x *-667.jpg;
        --rect x,y,w,h for one raw if the automatic find fails, --only <stem> to redo one)
  python tools/shots/shots.py viewport <run> <stem> <w> <h>   records a ViewportSize by hand
                                                       (<stem> may be a bare screen id: the desktop file)
  python tools/shots/shots.py snippet uicheck          Luau (Client): JSON of every visible GuiObject of
                                                       our ScreenGuis partly outside the viewport, any
                                                       visible text under 14 px and button under 44 px
  Runs that newrun makes for set U now carry "protocol": 2; score then needs, for every screen
  file, a recorded viewport (desktop at least 1280x720, phone exactly 667x375) and a uicheck, and
  leaves out any file whose uicheck found something outside the viewport. --skip-ui-checks scores
  without them. Older runs (no protocol) score as before.
  Frame cost at a shot: run tools/shots/probe.luau the same way; budget in docs/PERF.md.
  Default-look counts: run tools/shots/audit.luau the same way and save its JSON line as
  <run>/audit.json; score stores it beside the scores.
  python tools/shots/shots.py sheet <run> [--before <run>]   contact sheet (and before/after pairs)
  python tools/shots/shots.py score <run> --step <slug> [--runs 3] [--note "..."] [--also identity]
                                                       [--any-weather]
                                                       Refuses a run whose run.json "weather" is not
                                                       Clear for every scored shot, unless --any-weather
                                                       (old runs, before the weather was recorded).
                                                       Neon review, median of runs, appended to
                                                       docs/critic/score_history.json. Rubric by set:
                                                       look for A, B, C, D and ui for U (--rubric
                                                       overrides); --also adds more rubrics in the
                                                       same call, one history entry each.
                                                       [--skip-ui-checks]  (set U, see above)
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
-- The Roblox top bar (menu and chat buttons) is not covered by CoreGuiType.All.
pcall(function() SG:SetCore("TopbarEnabled", false) end)
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
-- What every screen snippet returns at the end: the viewport size (record it) and the weather.
local function tag(): string
\tlocal v = workspace.CurrentCamera.ViewportSize
\treturn string.format(" viewport %dx%d weather %s", math.round(v.X), math.round(v.Y), tostring(workspace:GetAttribute("Weather")))
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


# Run on the SERVER (execute_luau, Server data model) once per Play session: DebugWeather is a
# server attribute, so the client cannot set it. WeatherService holds the kind in Studio.
WEATHER = """-- Server, during Play: hold Clear for the look shots (Studio only; see WeatherService).
workspace:SetAttribute("DebugWeather", "Clear")
task.wait(25) -- let the weather look blend in before any capture
return "weather " .. tostring(workspace:GetAttribute("Weather"))
"""

SCORED_WEATHER = "Clear"

# Run on the Client right after a screen's snippet (set U preflight): returns one JSON line.
UICHECK = """-- Client, during Play, after a screen snippet: what of our UI would not show or read well.
-- outside: visible GuiObjects that draw something and lie partly outside their ScreenGui's area
-- (after clipping by ancestors with ClipsDescendants); small_text: visible TextLabel/TextButton
-- under 14 px (TextSize times UIScale, or estimated from TextBounds when TextScaled);
-- small_buttons: visible GuiButtons under 44 px on their short side.
local HS = game:GetService("HttpService")
local TS = game:GetService("TextService")
local PG = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local vp = workspace.CurrentCamera.ViewportSize
local function r(x: number): number return math.round(x * 10) / 10 end
local out = { viewport = { math.round(vp.X), math.round(vp.Y) }, guis = {}, outside = {}, small_text = {}, small_buttons = {} }
local function name(o: Instance): string return (o:GetFullName():gsub("^.-PlayerGui%.", "")) end
local function shown(o: Instance, sg: Instance): boolean
\tlocal x = o
\twhile x and x ~= sg do
\t\tif x:IsA("GuiObject") and not x.Visible then return false end
\t\tx = x.Parent
\tend
\treturn true
end
local function uiScale(o: Instance, sg: Instance): number
\tlocal s, x = 1, o
\twhile x and x ~= sg.Parent do
\t\tfor _, c in x:GetChildren() do
\t\t\tif c:IsA("UIScale") then s *= c.Scale end
\t\tend
\t\tx = x.Parent
\tend
\treturn s
end
local function isText(o: Instance): boolean
\treturn (o:IsA("TextLabel") or o:IsA("TextButton")) and o.Text ~= "" and o.TextTransparency < 1
end
local function draws(o: GuiObject): boolean
\tif o.BackgroundTransparency < 1 or isText(o) then return true end
\treturn (o:IsA("ImageLabel") or o:IsA("ImageButton")) and o.Image ~= "" and o.ImageTransparency < 1
end
local function textPx(o: any, sg: Instance): (number, string)
\tif not o.TextScaled then return o.TextSize * uiScale(o, sg), "TextSize" end
\tlocal lines = 1
\tfor _ in string.gmatch(o.ContentText, "\\n") do lines += 1 end
\tlocal est = o.TextBounds.Y / lines
\tif o.TextWrapped and o.Font ~= Enum.Font.Unknown then
\t\t-- the largest size whose wrapped height still fits the rendered height
\t\tlocal ok = pcall(function()
\t\t\tlocal lo, hi = 1, 100
\t\t\twhile lo < hi do
\t\t\t\tlocal mid = math.ceil((lo + hi) / 2)
\t\t\t\tlocal h = TS:GetTextSize(o.ContentText, mid, o.Font, Vector2.new(o.AbsoluteSize.X, 1e5)).Y
\t\t\t\tif h <= o.TextBounds.Y + 1 then lo = mid else hi = mid - 1 end
\t\t\tend
\t\t\test = lo
\t\tend)
\t\tif ok then return est, "TextBounds wrapped (estimate)" end
\tend
\treturn est, "TextBounds"
end
for _, sg in PG:GetChildren() do
\tif sg:IsA("ScreenGui") and sg.Enabled then
\t\tlocal p0, sz = sg.AbsolutePosition, sg.AbsoluteSize
\t\ttable.insert(out.guis, { name = sg.Name, area = { r(p0.X), r(p0.Y), r(sz.X), r(sz.Y) } })
\t\tfor _, o in sg:GetDescendants() do
\t\t\tif o:IsA("GuiObject") and shown(o, sg) and o.AbsoluteSize.X > 0 and o.AbsoluteSize.Y > 0 then
\t\t\t\tlocal a, s = o.AbsolutePosition, o.AbsoluteSize
\t\t\t\tlocal x0, y0, x1, y1 = a.X, a.Y, a.X + s.X, a.Y + s.Y
\t\t\t\tlocal anc = o.Parent
\t\t\t\twhile anc and anc ~= sg do
\t\t\t\t\tif anc:IsA("GuiObject") and anc.ClipsDescendants then
\t\t\t\t\t\tlocal ca, cs = anc.AbsolutePosition, anc.AbsoluteSize
\t\t\t\t\t\tx0, y0 = math.max(x0, ca.X), math.max(y0, ca.Y)
\t\t\t\t\t\tx1, y1 = math.min(x1, ca.X + cs.X), math.min(y1, ca.Y + cs.Y)
\t\t\t\t\tend
\t\t\t\t\tanc = anc.Parent
\t\t\t\tend
\t\t\t\tlocal seen = x1 > x0 and y1 > y0
\t\t\t\tif seen and draws(o) and (x0 < p0.X - 1 or y0 < p0.Y - 1 or x1 > p0.X + sz.X + 1 or y1 > p0.Y + sz.Y + 1) then
\t\t\t\t\ttable.insert(out.outside, { path = name(o), rect = { r(x0 - p0.X), r(y0 - p0.Y), r(x1 - x0), r(y1 - y0) } })
\t\t\t\tend
\t\t\t\tif seen and isText(o) then
\t\t\t\t\tlocal px, how = textPx(o, sg)
\t\t\t\t\tif px < 14 then
\t\t\t\t\t\ttable.insert(out.small_text, { path = name(o), px = r(px), from = how, text = string.sub(o.ContentText, 1, 40) })
\t\t\t\t\tend
\t\t\t\tend
\t\t\t\tif seen and o:IsA("GuiButton") and math.min(s.X, s.Y) < 44 then
\t\t\t\t\ttable.insert(out.small_buttons, { path = name(o), size = { r(s.X), r(s.Y) } })
\t\t\t\tend
\t\t\tend
\t\tend
\tend
end
return HS:JSONEncode(out)
"""

DESKTOP_MIN = (1280, 720)
PHONE = (667, 375)
UI_CONTEXT = ("Files ending -1280 are the desktop: the Studio viewport as it is, at least 1280 by 720, "
              "no Device Simulator (recorded viewport sizes: {sizes}). Files ending -667 are a 667 by 375 "
              "phone screen cut out of the Device Simulator and shown at 2x (1334 by 750), so halve what you "
              "measure on them. The round buttons at the top left (Roblox logo, menu, chat) are Roblox's own "
              "top bar, not ours: do not judge their look, but our layout must clear them.")


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
            + f"task.wait(1.5)\nreturn \"shot {s['id']} set \" .. tostring(workspace:GetAttribute(\"Weather\"))\n")


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
    elif a.id == "uicheck":
        print(UICHECK)
    elif a.id == "weather":
        print(WEATHER)
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
        meta["protocol"] = 2  # desktop viewport as is, phone cut to 667x375 at 2x, a uicheck per file
    (run / "run.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(run)


def read_meta(run: Path) -> dict:
    meta = run / "run.json"
    return json.loads(meta.read_text(encoding="utf-8")) if meta.exists() else {}


def cmd_weather(a):
    run = Path(a.run)
    meta_path = run / "run.json"
    if not meta_path.exists():
        sys.exit(f"No run.json in {run}. Make the run with: python tools/shots/shots.py newrun")
    meta = read_meta(run)
    ids = meta.get("shots") or [s["id"] for s in need_set(meta.get("set", "A"))]
    if a.id == "all":
        targets = list(ids)
    elif a.id in ids:
        targets = [a.id]
    else:
        sys.exit(f"{a.id} is not a shot of {run.name}. Its shots: {', '.join(ids)}")
    weather = meta.setdefault("weather", {})
    for sid in targets:
        weather[sid] = a.kind
    meta_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    note = "" if a.kind == SCORED_WEATHER else f"  (not {SCORED_WEATHER}: score will refuse it without --any-weather)"
    print(f"{run.name}: " + ", ".join(f"{sid} {a.kind}" for sid in targets) + note)


def weather_problems(run: Path, shots: list[dict]) -> list[str]:
    """Scored shots whose recorded weather is missing or not Clear."""
    recorded = read_meta(run).get("weather", {}) or {}
    bad = []
    for s in shots:
        w = recorded.get(s["id"])
        if w != SCORED_WEATHER:
            bad.append(f"{s['id']} ({w if w else 'not recorded'})")
    return bad


DESKTOP_TAG = f"-{SCREEN_SIZES[0][0]}"
PHONE_TAG = f"-{PHONE[0]}"


def screen_stem(meta: dict, arg: str, size: str | None) -> str:
    """The file stem a record is for: <id>-1280 or <id>-667. A bare screen id means the desktop file
    unless --size says otherwise."""
    ids = meta.get("shots") or [s["id"] for s in need_set(meta.get("set", "U"))]
    tags = [f"-{w}" for w, _ in SCREEN_SIZES]
    if any(arg.endswith(tg) for tg in tags) and arg.rsplit("-", 1)[0] in ids:
        return arg
    if arg in ids:
        return f"{arg}-{size}" if size else arg + DESKTOP_TAG
    sys.exit(f"{arg} is not a screen of this run. Its screens: {', '.join(ids)} (add -1280 or -667 for one size)")


def write_meta(run: Path, meta: dict) -> None:
    (run / "run.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")


def need_meta(run: Path) -> dict:
    if not (run / "run.json").exists():
        sys.exit(f"No run.json in {run}. Make the run with: python tools/shots/shots.py newrun --set U")
    return read_meta(run)


def viewport_problem(stem: str, size) -> str | None:
    """Why a recorded viewport is wrong for its file, or None when it is fine."""
    if not size:
        return "no viewport recorded"
    w, h = int(size[0]), int(size[1])
    if stem.endswith(PHONE_TAG) and (w, h) != PHONE:
        return f"phone viewport {w}x{h}, not {PHONE[0]}x{PHONE[1]} (set the Device Simulator)"
    if stem.endswith(DESKTOP_TAG) and (w < DESKTOP_MIN[0] or h < DESKTOP_MIN[1]):
        return f"desktop viewport {w}x{h}, under {DESKTOP_MIN[0]}x{DESKTOP_MIN[1]} (make the Studio window bigger)"
    return None


def cmd_viewport(a):
    run = Path(a.run)
    meta = need_meta(run)
    stem = screen_stem(meta, a.id, a.size)
    meta.setdefault("viewport", {})[stem] = [a.w, a.h]
    write_meta(run, meta)
    bad = viewport_problem(stem, [a.w, a.h])
    print(f"{run.name}: {stem} viewport {a.w}x{a.h}" + (f"  (WRONG: {bad}; score will refuse it)" if bad else ""))


def load_json_arg(arg: str) -> dict:
    """A JSON object from a file path, "-" (stdin) or the literal text; text before the first { is skipped."""
    if arg == "-":
        text = sys.stdin.read()
    elif Path(arg).exists():
        text = Path(arg).read_text(encoding="utf-8")
    else:
        text = arg
    text = text.strip()
    if "{" not in text:
        sys.exit("No JSON object in the uicheck input. Paste what snippet uicheck returned, or a file holding it.")
    try:
        return json.loads(text[text.index("{"):text.rindex("}") + 1])
    except ValueError as e:
        sys.exit(f"The uicheck input is not valid JSON: {e}")


def cmd_uicheck(a):
    run = Path(a.run)
    meta = need_meta(run)
    stem = screen_stem(meta, a.id, a.size)
    data = load_json_arg(a.result)
    for k in ("outside", "small_text", "small_buttons"):
        data[k] = data.get(k) or []  # JSONEncode turns an empty table into {} or []
    meta.setdefault("uicheck", {})[stem] = data
    if data.get("viewport"):
        meta.setdefault("viewport", {})[stem] = data["viewport"]
    write_meta(run, meta)
    vp = data.get("viewport")
    print(f"{run.name}: {stem} uicheck recorded" + (f", viewport {vp[0]}x{vp[1]}" if vp else ", no viewport in it"))
    bad = viewport_problem(stem, vp)
    if bad:
        print(f"  viewport: {bad}")
    for x in data["small_text"]:
        print(f"  small text {x.get('px')} px ({x.get('from', '')}): {x.get('path')}  \"{x.get('text', '')}\"")
    for x in data["small_buttons"]:
        print(f"  small button {x.get('size')}: {x.get('path')}")
    if data["outside"]:
        for x in data["outside"]:
            print(f"  OUTSIDE the viewport {x.get('rect')}: {x.get('path')}")
        print(f"ABORT {stem}: {len(data['outside'])} visible element(s) lie partly outside the viewport. "
              "score leaves this file out; fix the layout and capture it again.")
        sys.exit(1)


def find_device_rect(im, tol: int = 12) -> tuple[int, int, int, int] | None:
    """The phone screen inside a Device Simulator capture: the largest block that is not the flat
    letterbox colour (the most common exact colour on the image border; tol is kept low because the
    dark lake water is close to it). Returns (x, y, w, h) or None."""
    from collections import Counter
    from PIL import Image, ImageChops

    rgb = im.convert("RGB")
    W, H = rgb.size
    px = rgb.load()
    border = [px[x, y] for x in range(0, W, 2) for y in (1, H - 2)] + [px[W - 2, y] for y in range(0, H, 2)]
    bg = Counter(border).most_common(1)[0][0]
    diff = ImageChops.difference(rgb, Image.new("RGB", rgb.size, bg)).split()
    mask = ImageChops.lighter(ImageChops.lighter(diff[0], diff[1]), diff[2]).point(lambda v: 255 if v > tol else 0)

    def longest_run(values: list[float], thresh: float) -> tuple[int, int] | None:
        best, start = None, None
        for i, v in enumerate(values + [0.0]):
            if v >= thresh and start is None:
                start = i
            elif v < thresh and start is not None:
                if best is None or i - start > best[1] - best[0]:
                    best = (start, i)
                start = None
        return best

    rows = list(mask.resize((1, H), Image.BOX).tobytes())
    ry = longest_run([v / 255 for v in rows], 0.5 * max(rows) / 255) if max(rows) else None
    if not ry:
        return None
    band = mask.crop((0, ry[0], W, ry[1]))
    cols = list(band.resize((W, 1), Image.BOX).tobytes())
    rx = longest_run([v / 255 for v in cols], 0.5)
    if not rx:
        return None
    return rx[0], ry[0], rx[1] - rx[0], ry[1] - ry[0]  # JPEG blur may add a pixel a side


def cmd_phonecrop(a):
    from PIL import Image

    run = Path(a.run)
    meta = read_meta(run)
    raws = sorted(list(run.glob(f"*{PHONE_TAG}-raw.jpg")) + list(run.glob(f"*{PHONE_TAG}-raw.png")))
    if a.only:
        raws = [r for r in raws if r.stem[: -len("-raw")] == a.only]
    if not raws:
        sys.exit(f"No *{PHONE_TAG}-raw.jpg in {run}" + (f" for {a.only}" if a.only else ""))
    if a.rect and len(raws) != 1:
        sys.exit("--rect is for one raw at a time: add --only <stem>")
    want = PHONE[0] / PHONE[1]
    failed = []
    for raw in raws:
        stem = raw.stem[: -len("-raw")]
        im = Image.open(raw).convert("RGB")
        rect = tuple(int(v) for v in a.rect.split(",")) if a.rect else find_device_rect(im)
        if not rect:
            print(f"{raw.name}: no device found (all letterbox?); pass --only {stem} --rect x,y,w,h")
            failed.append(stem)
            continue
        x, y, w, h = rect
        aspect = w / h
        if abs(aspect / want - 1) > a.tolerance:
            print(f"{raw.name}: found {w}x{h} at ({x}, {y}), aspect {aspect:.3f}, not {want:.3f}. The device is "
                  "cut off or the find failed: capture the whole viewport (-Width 4000) or pass --rect x,y,w,h")
            failed.append(stem)
            continue
        if x == 0 or y == 0 or x + w == im.width or y + h == im.height:
            print(f"{raw.name}: warning, the device touches the image edge; check it is not cut off")
        phone = im.crop((x, y, x + w, y + h)).resize(PHONE, Image.LANCZOS)
        out = phone.resize((PHONE[0] * 2, PHONE[1] * 2), Image.LANCZOS)
        dest = run / f"{stem}.jpg"
        out.save(dest, quality=92)
        meta.setdefault("phonecrop", {})[stem] = {"raw": raw.name, "rect": [x, y, w, h], "scale": round(h / PHONE[1], 3)}
        print(f"{raw.name}: device {w}x{h} at ({x}, {y}), scale {h / PHONE[1]:.3f} -> {dest.name} {out.width}x{out.height}")
    if meta:
        write_meta(run, meta)
    if failed:
        sys.exit(f"Not cropped: {', '.join(failed)}")


def ui_gate(run: Path, found: list[tuple[str, Path | None]]) -> tuple[list[str], list[str], dict]:
    """Set U, protocol 2: (problems that refuse the score, files left out, viewports by file)."""
    meta = read_meta(run)
    vps, checks = meta.get("viewport", {}) or {}, meta.get("uicheck", {}) or {}
    problems, left_out = [], []
    for stem, p in found:
        if not p:
            raw = run / f"{stem}-raw.jpg"
            if raw.exists():
                problems.append(f"{stem}: only the raw capture is there; run: python tools/shots/shots.py phonecrop {run}")
            continue
        bad = viewport_problem(stem, vps.get(stem))
        if bad:
            problems.append(f"{stem}: {bad}")
        if stem not in checks:
            problems.append(f"{stem}: no uicheck recorded")
        elif checks[stem].get("outside"):
            left_out.append(stem)
        if stem.endswith(PHONE_TAG):
            from PIL import Image
            with Image.open(p) as im:
                if im.size != (PHONE[0] * 2, PHONE[1] * 2):
                    problems.append(f"{stem}: {im.width}x{im.height}, not the 2x phone crop; run phonecrop")
    return problems, left_out, {s: vps.get(s) for s, p in found if p}


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


def score_one(a, run: Path, set_name: str, files: list[str], rubric: str, audit: dict | None, context: str = "") -> dict:
    verdicts = []
    step = a.step if rubric == "look" else f"{a.step}-{rubric}"
    for i in range(a.runs):
        out = run / (f"critic-{a.step}-{i + 1}.json" if rubric == "look" else f"critic-{a.step}-{rubric}-{i + 1}.json")
        cmd = [sys.executable, str(ROOT / "tools" / "critic" / "critic.py"), "review", *files,
               "--step", step, "--rubric", rubric, "--json-out", str(out)]
        if a.note:
            cmd += ["--note", a.note]
        if context:
            cmd += ["--context", context]
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
    if a.group:
        # Score one group of a set (set A holds the home lake and the creek; N1 is judged on the lake).
        shots = [s for s in shots if s.get("group", s.get("place")) == a.group]
    found = images(run, shots)
    ui_meta = {}
    context = ""
    if set_name == "U" and read_meta(run).get("protocol", 0) >= 2:
        if a.skip_ui_checks:
            print("Warning (--skip-ui-checks): viewports and uichecks not checked")
        else:
            problems, left_out, vps = ui_gate(run, found)
            if problems:
                sys.exit(f"Refusing to score {run.name}:\n  " + "\n  ".join(problems)
                         + "\n(see the set U capture loop in tools/shots/shots.py, or pass --skip-ui-checks)")
            if left_out:
                print("Left out, something lies outside the viewport (run.json uicheck): " + ", ".join(left_out))
                found = [(stem, p) for stem, p in found if stem not in left_out]
            ui_meta = {"viewport": vps, "left_out": left_out}
            sizes = ", ".join(f"{s} {v[0]}x{v[1]}" for s, v in vps.items() if v and s.endswith(DESKTOP_TAG) and s not in left_out)
            context = UI_CONTEXT.format(sizes=sizes or "none")
    files = [str(p) for _, p in found if p]
    if not files:
        sys.exit(f"No images for set {set_name} in {run}")
    scored = [s for s in shots if any(p for stem, p in found if stem in file_stems(s))]
    bad = weather_problems(run, scored)
    if bad and not a.any_weather:
        sys.exit(f"Refusing to score {run.name}: these shots were not recorded under {SCORED_WEATHER}: "
                 + ", ".join(bad) + ". Record each with: python tools/shots/shots.py weather <run> <id> <kind>"
                 " (or pass --any-weather for an old run).")
    if bad:
        print(f"Warning (--any-weather): not recorded under {SCORED_WEATHER}: " + ", ".join(bad))
    recorded = read_meta(run).get("weather", {}) or {}
    weather = {s["id"]: recorded.get(s["id"]) for s in scored}
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
        entry = score_one(a, run, set_name, files, rubric, audit, context)
        entry["weather"] = weather
        entry.update(ui_meta)
        if bad:
            entry["any_weather"] = True
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
    p = sub.add_parser("weather", help="record the weather a shot was taken under in run.json")
    p.add_argument("run"); p.add_argument("id", help='a shot id of the run, or "all"')
    p.add_argument("kind", help="the Weather attribute the shot snippet returned, like Clear")
    p.set_defaults(fn=cmd_weather)
    p = sub.add_parser("viewport", help="record a screen file's ViewportSize in run.json (set U)")
    p.add_argument("run"); p.add_argument("id", help="<id>-1280 or <id>-667, or a bare screen id for the desktop file")
    p.add_argument("w", type=int); p.add_argument("h", type=int)
    p.add_argument("--size", default=None, help="1280 or 667 when id is a bare screen id")
    p.set_defaults(fn=cmd_viewport)
    p = sub.add_parser("uicheck", help="record what snippet uicheck returned for a screen file (set U)")
    p.add_argument("run"); p.add_argument("id", help="<id>-1280 or <id>-667, or a bare screen id for the desktop file")
    p.add_argument("result", help="a file holding the JSON, - for stdin, or the JSON itself")
    p.add_argument("--size", default=None, help="1280 or 667 when id is a bare screen id")
    p.set_defaults(fn=cmd_uicheck)
    p = sub.add_parser("phonecrop", help="cut the 667x375 phone out of every *-667-raw.jpg and save it at 2x as *-667.jpg")
    p.add_argument("run"); p.add_argument("--only", default=None, help="one stem, like u02-shop-667")
    p.add_argument("--rect", default=None, help="x,y,w,h of the device in the raw, when the automatic find fails")
    p.add_argument("--tolerance", type=float, default=0.025, help="allowed aspect error (default 0.025)")
    p.set_defaults(fn=cmd_phonecrop)
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
    p.add_argument("--group", default=None, help="score only this group of the set, like lake or creek")
    p.add_argument("--any-weather", action="store_true", help="score even if a shot's recorded weather is not Clear (old runs)")
    p.add_argument("--skip-ui-checks", action="store_true", help="set U: score without the recorded viewports and uichecks")
    p.set_defaults(fn=cmd_score)
    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
