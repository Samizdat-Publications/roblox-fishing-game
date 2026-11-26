--[[
Frame-time probe. Paste into execute_luau (Studio, Play mode, or Edit mode for a rough number)
after a shot's camera is set: it samples frames for SECONDS and returns average, 95th percentile
and worst frame time in milliseconds, plus frames per second.

Run it at each shot on the PC view and again with the Device Simulator on the smallest phone
(Samsung Galaxy A06). Record results in docs/PERF.md. Studio caps the editor's frame rate, so
these numbers are a budget to compare against, not what a player's device will show.
]]
local SECONDS = 4
local RunService = game:GetService("RunService")
local samples = {}
local signal = RunService.RenderStepped
local ok = pcall(function()
	local c = signal:Connect(function() end)
	c:Disconnect()
end)
if not ok then
	signal = RunService.Heartbeat
end
local conn = signal:Connect(function(dt)
	table.insert(samples, dt * 1000)
end)
task.wait(SECONDS)
conn:Disconnect()
table.sort(samples)
local n = #samples
if n == 0 then
	return "no frames sampled"
end
local sum = 0
for _, v in samples do
	sum += v
end
local avg = sum / n
local p95 = samples[math.max(1, math.floor(n * 0.95))]
local worst = samples[n]
return string.format("frames %d  avg %.1f ms (%.0f fps)  p95 %.1f ms  worst %.1f ms", n, avg, 1000 / avg, p95, worst)
