--[[
Frame-time probe. Paste into execute_luau on the Client data model during Play, after a shot's
camera is pinned. It samples for SECONDS and returns the render CPU and GPU time per frame from
the Stats service, plus the raw frame time.

Studio holds a window that is not in front to about 15 fps, so the raw frame time (66.7 ms) says
nothing about the game. Render CPU and GPU time are what the frame actually costs; compare those
against docs/PERF.md. A real phone check is still Stewart's (docs/PROGRESS.md, Waiting on Stewart).
]]
local SECONDS = 4
local RS = game:GetService("RunService")
local S = game:GetService("Stats")
local frame, cpu, gpu = {}, {}, {}
local conn = RS.RenderStepped:Connect(function(dt)
	table.insert(frame, dt * 1000)
	table.insert(cpu, S.RenderCPUFrameTime * 1000)
	table.insert(gpu, S.RenderGPUFrameTime * 1000)
end)
task.wait(SECONDS)
conn:Disconnect()
if #frame == 0 then
	return "no frames sampled (run this on the Client during Play)"
end
local function stat(t)
	table.sort(t)
	local sum = 0
	for _, x in t do
		sum += x
	end
	return sum / #t, t[math.max(1, math.floor(#t * 0.95))], t[#t]
end
local fa = stat(frame)
local ca, cp, cw = stat(cpu)
local ga, gp, gw = stat(gpu)
return string.format(
	"render CPU avg %.2f p95 %.2f worst %.2f ms | GPU avg %.2f p95 %.2f worst %.2f ms | raw frame %.1f ms | memory %.0f MB | instances %d",
	ca, cp, cw, ga, gp, gw, fa, S:GetTotalMemoryUsageMb(), S.InstanceCount
)
