--!strict
-- "Hold up your catch" (L4b): for a trophy or a monster, the camera swings round in front of
-- the player and frames them with the fish hanging from the rod tip (the server hangs it
-- there, FishingService.showCatch) for about HOLD seconds while the catch card's TROPHY! or
-- MONSTER! banner shows, then hands the camera straight back. Moving, casting or another fish
-- ends it early. This player's screen only. UNVERIFIED in Studio (written 2026-11-26).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Approach = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Approach"))

local CatchMoment = {}

local HOLD = 2 -- seconds the camera holds the shot
local EASE = 0.35 -- seconds to swing in
local FRONT = 7 -- studs in front of the player
local SIDE = 2.5 -- studs off to the rod side
local UP = 1.2 -- studs above the focus
local MOVE_DEADZONE = 0.1

local playing = false
local conn: RBXScriptConnection? = nil

local function finish()
	if not playing then
		return
	end
	playing = false
	if conn then
		conn:Disconnect()
		conn = nil
	end
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
end

-- A catch came in: play the moment if it's a trophy or a monster.
function CatchMoment.play(payload: any)
	local fish = payload and payload.fish
	local class = payload and payload.sizeClass
	if not fish or (class ~= "trophy" and class ~= "monster") then
		return
	end
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not root or not hum or not head then
		return
	end
	finish()
	local cam = workspace.CurrentCamera
	local startCf = cam.CFrame
	local len = Approach.shadowLength(type(fish.cm) == "number" and fish.cm or 50)
	playing = true
	cam.CameraType = Enum.CameraType.Scriptable
	local t0 = os.clock()
	conn = RunService.RenderStepped:Connect(function()
		if not playing then
			return
		end
		local elapsed = os.clock() - t0
		if elapsed >= EASE + HOLD or hum.MoveDirection.Magnitude > MOVE_DEADZONE or not root.Parent then
			finish()
			return
		end
		-- The fish hangs about a stud under the rod tip (FishingService.showCatch).
		local rod = char and char:FindFirstChild("Rod")
		local tip = rod and rod:FindFirstChild("RodTip")
		local fishAt = if tip and tip:IsA("Attachment") then tip.WorldPosition - Vector3.new(0, 1 + len / 2, 0) else head.Position
		local focus = head.Position:Lerp(fishAt, 0.5)
		local forward = root.CFrame.LookVector
		local right = root.CFrame.RightVector
		local eye = focus + forward * (FRONT + len * 0.4) + right * SIDE + Vector3.new(0, UP, 0)
		local goal = CFrame.lookAt(eye, focus)
		local k = math.clamp(elapsed / EASE, 0, 1)
		k = k * k * (3 - 2 * k)
		cam.CFrame = startCf:Lerp(goal, k)
	end)
end

-- Something else wants the camera (a new cast, a fish on).
function CatchMoment.cancel()
	finish()
end

function CatchMoment.isPlaying(): boolean
	return playing
end

return CatchMoment
