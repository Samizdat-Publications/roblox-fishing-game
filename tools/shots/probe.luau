--[[
Frame-time probe. Paste into execute_luau on the Client data model during Play, after a shot's
camera is pinned. It samples for SECONDS and returns the render CPU and GPU time per frame from
the Stats service, plus the raw frame time, triangles and draw calls in view, and texture and
terrain graphics memory.

Studio holds a window that is not in front to about 15 fps, so the raw frame time (66.7 ms) says
nothing about the game. Render CPU and GPU time are what the frame actually costs; compare those
against docs/PERF.md. A real phone check is still Stewart's (docs/PROGRESS.md, Waiting on Stewart).

Graphics quality: Studio's Automatic level drops low when its window is not in front, so the probe
pins it: Level21 on the desktop tier, Level3 with PHONE = true. PHONE = true also sets the
LocalPlayer attribute LookTier = "phone" (read by the LookDirector client module) and waits for
the look to settle. Both are put back afterwards.
]]
-- N3 review 3 (11/28/2026): the numbers depend on the viewport's size (a 1701 wide run read very
-- differently from PERF.md's 1237 x 787 baseline). The line ends with the viewport, and starts
-- "NOT COMPARABLE" when it is not BASELINE_WIDTH wide; Lua cannot resize Studio's viewport, so
-- size the Studio window until the pin reports viewport 1237 wide before probing. Record the line
-- with: python tools/shots/shots.py perf <run> <id> "<line>".
local BASELINE_WIDTH = 1237
local SECONDS = 4
local PHONE = false
local SETTLE = 1.5 -- seconds after a tier or quality change before sampling

local RS = game:GetService("RunService")
local S = game:GetService("Stats")
local player = game:GetService("Players").LocalPlayer

local function try(f: () -> any): any
	local ok, v = pcall(f)
	return if ok then v else nil
end

-- Pin the tier and the quality level; remember what was there to put it back.
local oldTier = try(function()
	return player:GetAttribute("LookTier")
end)
local oldQuality = try(function()
	return settings().Rendering.QualityLevel
end)
if PHONE then
	pcall(function()
		player:SetAttribute("LookTier", "phone")
	end)
end
pcall(function()
	settings().Rendering.QualityLevel = if PHONE then Enum.QualityLevel.Level03 else Enum.QualityLevel.Level21
end)
task.wait(SETTLE)

local frame, cpu, gpu, tris, draws = {}, {}, {}, {}, {}
local conn = RS.RenderStepped:Connect(function(dt)
	table.insert(frame, dt * 1000)
	table.insert(cpu, S.RenderCPUFrameTime * 1000)
	table.insert(gpu, S.RenderGPUFrameTime * 1000)
	local t = try(function()
		return S.SceneTriangleCount
	end)
	if type(t) == "number" then
		table.insert(tris, t)
	end
	local d = try(function()
		return S.SceneDrawcallCount
	end)
	if type(d) == "number" then
		table.insert(draws, d)
	end
end)
task.wait(SECONDS)
conn:Disconnect()

local function memTag(name: string): number?
	return try(function()
		return S:GetMemoryUsageMbForTag((Enum.DeveloperMemoryTag :: any)[name])
	end)
end
local texMb = memTag("GraphicsTexture")
local terrainMb = memTag("GraphicsTerrain")
local meshMb = memTag("GraphicsMeshParts")
local partsMb = memTag("GraphicsParts")
local qualityNow = try(function()
	return settings().Rendering.QualityLevel.Name
end)

-- Put the tier and quality back.
if PHONE then
	pcall(function()
		player:SetAttribute("LookTier", oldTier)
	end)
end
if oldQuality then
	pcall(function()
		settings().Rendering.QualityLevel = oldQuality
	end)
end

if #frame == 0 then
	return "no frames sampled (run this on the Client during Play)"
end
local function stat(t: { number }): (number, number, number)
	table.sort(t)
	local sum = 0
	for _, x in t do
		sum += x
	end
	return sum / #t, t[math.max(1, math.floor(#t * 0.95))], t[#t]
end
local function fmt(x: number?, pattern: string): string
	return if type(x) == "number" then string.format(pattern, x) else "n/a"
end
local fa = stat(frame)
local ca, cp, cw = stat(cpu)
local ga, gp, gw = stat(gpu)
local ta, tw
if #tris > 0 then
	local a, _, w = stat(tris)
	ta, tw = a, w
end
local da, dw
if #draws > 0 then
	local a, _, w = stat(draws)
	da, dw = a, w
end
local line = string.format(
	"render CPU avg %.2f p95 %.2f worst %.2f ms | GPU avg %.2f p95 %.2f worst %.2f ms | raw frame %.1f ms | memory %.0f MB | instances %d",
	ca, cp, cw, ga, gp, gw, fa, S:GetTotalMemoryUsageMb(), S.InstanceCount
)
line ..= string.format(
	" | tier %s quality %s | triangles avg %s max %s | draw calls avg %s max %s | texture %s MB | terrain %s MB | mesh parts %s MB | parts %s MB",
	if PHONE then "phone" else "desktop",
	qualityNow or "n/a",
	fmt(ta, "%.0f"), fmt(tw, "%.0f"), fmt(da, "%.0f"), fmt(dw, "%.0f"),
	fmt(texMb, "%.0f"), fmt(terrainMb, "%.0f"), fmt(meshMb, "%.0f"), fmt(partsMb, "%.0f")
)
local vp = workspace.CurrentCamera.ViewportSize
local vw, vh = math.round(vp.X), math.round(vp.Y)
line ..= string.format(" | viewport %dx%d", vw, vh)
if vw ~= BASELINE_WIDTH then
	line = string.format("NOT COMPARABLE (viewport %d wide, docs/PERF.md budgets are at %d wide) | ", vw, BASELINE_WIDTH) .. line
end
return line
