--!strict
-- The bobber camera (L4). When the bobber lands, the view eases (about a second) toward a
-- framing that keeps it big and centred: the camera's focus rises a little and slides out
-- along the line (Humanoid.CameraOffset), the view turns gently toward the bobber, and the
-- field of view narrows just enough that the bobber is at least 24 pixels tall on this
-- screen (Shared/BobberCam). It runs right after Roblox's own camera each frame, so the
-- player's camera stays in charge of zoom and collisions.
--
-- Any camera drag, mouse wheel, right stick, screen touch, shift-lock look or movement hands
-- control straight back: the turning stops that frame, the zoom and offset let go over a
-- quarter second, and it stays off until the next cast lands. It never fights the player.
-- Local to this player. UNVERIFIED in Studio (written 2026-11-26).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BobberCam = require(Shared.BobberCam)

local BobberCamView = {}

local STICK_DEADZONE = 0.2
local MOVE_DEADZONE = 0.05
-- Controller states while the line is in: the framing holds through the bite and the strike.
local LINE_STATES = { Waiting = true, Bite = true, Hooking = true }
local CAMERA_KEYS = {
	[Enum.KeyCode.Left] = true,
	[Enum.KeyCode.Right] = true,
	[Enum.KeyCode.I] = true,
	[Enum.KeyCode.O] = true,
	[Enum.KeyCode.PageUp] = true,
	[Enum.KeyCode.PageDown] = true,
	[Enum.KeyCode.ButtonR3] = true,
	[Enum.KeyCode.ButtonL3] = true,
}

local getState: () -> string = function()
	return "Idle"
end
local wanted = false -- this wait wants the framing (set when the bobber lands)
local handedBack = false -- the player took the camera back during this wait
local weight = 0 -- 0..1, how far into the framing (eased)
local bobberAt: Vector3? = nil
local baseFov: number? = nil -- the player's own field of view, restored when we let go
local ownsOffset = false

local function bobberPart(): BasePart?
	local b = workspace:FindFirstChild("Bobber_" .. Players.LocalPlayer.Name)
	return if b and b:IsA("BasePart") then b else nil
end

-- The player moved the camera or the character: give it straight back.
function BobberCamView.handBack()
	if wanted and not handedBack then
		handedBack = true
	end
end

-- The bobber landed at `pos`: ease into the framing for this wait.
function BobberCamView.engage(pos: Vector3)
	wanted = true
	handedBack = false
	bobberAt = pos
end

function BobberCamView.isActive(): boolean
	return wanted and not handedBack and weight > 0
end

-- The framing brings the camera close behind the head, so fade the character (only for this
-- player) while it's on; 0 puts it back.
local faded = 0
local function fadeCharacter(amount: number)
	if math.abs(amount - faded) < 0.02 then
		return
	end
	faded = amount
	local char = Players.LocalPlayer.Character
	if not char then
		return
	end
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = amount
		end
	end
end

local function letGo(hum: Humanoid?)
	local cam = workspace.CurrentCamera
	fadeCharacter(0)
	if baseFov then
		cam.FieldOfView = baseFov
		baseFov = nil
	end
	if ownsOffset and hum then
		hum.CameraOffset = Vector3.zero
	end
	ownsOffset = false
end

local function step(dt: number)
	local cam = workspace.CurrentCamera
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local state = getState()
	if wanted and not LINE_STATES[state] then
		wanted = false -- the line came in (or a fish is on): this wait is over
	end
	if hum and hum.MoveDirection.Magnitude > MOVE_DEADZONE then
		BobberCamView.handBack()
	end
	if wanted and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		-- Shift lock: the mouse turns the camera directly, so leave it alone.
		BobberCamView.handBack()
	end
	local on = wanted
		and not handedBack
		and hum ~= nil
		and root ~= nil
		and cam.CameraType == Enum.CameraType.Custom
		and cam.CameraSubject == hum
	if on then
		weight = math.min(1, weight + dt / BobberCam.EASE_IN)
	else
		weight = math.max(0, weight - dt / BobberCam.EASE_OUT)
	end
	if weight <= 0 or not hum or not root then
		letGo(hum)
		return
	end
	local w = BobberCam.ease(weight)
	fadeCharacter(0.7 * w)
	local part = bobberPart()
	local bobber = if part then part.Position else bobberAt
	if not bobber then
		letGo(hum)
		return
	end
	if not baseFov then
		baseFov = cam.FieldOfView
	end

	-- The focus rises and slides out along the line (in the root part's own space).
	local flat = Vector3.new(bobber.X - root.Position.X, 0, bobber.Z - root.Position.Z)
	local out = if flat.Magnitude > 0.01 then flat.Unit * BobberCam.pull(flat.Magnitude) else Vector3.zero
	local worldOffset = (Vector3.new(0, BobberCam.RAISE, 0) + out) * w
	hum.CameraOffset = root.CFrame:VectorToObjectSpace(worldOffset)
	ownsOffset = true

	-- Narrow the view just enough for the bobber to read on this screen.
	local height = if part then part.Size.Y else BobberCam.BOBBER_HEIGHT
	local dist = (bobber - cam.CFrame.Position).Magnitude
	local fov = BobberCam.fovFor(height, dist, cam.ViewportSize.Y, baseFov :: number)
	cam.FieldOfView = (baseFov :: number) + (fov - (baseFov :: number)) * w

	-- Turn gently toward the bobber, only while the framing is wanted (stops on hand-back).
	if on then
		local focus = cam.Focus.Position
		local toBobber = bobber - focus
		if toBobber.Magnitude > 0.5 then
			local zoom = (cam.CFrame.Position - focus).Magnitude
			local a = (1 - math.exp(-BobberCam.STEER_RATE * dt)) * w
			local look = cam.CFrame.LookVector:Lerp(toBobber.Unit, a)
			if look.Magnitude > 0.01 then
				look = look.Unit
				cam.CFrame = CFrame.lookAt(focus - look * zoom, focus)
			end
		end
	end
end

local function onInput(input: InputObject, processed: boolean)
	if not wanted or handedBack then
		return
	end
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseWheel then
		BobberCamView.handBack()
	elseif t == Enum.UserInputType.MouseMovement then
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			BobberCamView.handBack() -- dragging the camera
		end
	elseif t == Enum.UserInputType.MouseButton2 then
		BobberCamView.handBack()
	elseif t == Enum.UserInputType.Touch then
		-- A touch on the 3D view (not on a button) is the start of a camera drag: on touch
		-- screens the camera is always the player's.
		if not processed then
			BobberCamView.handBack()
		end
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 or input.KeyCode == Enum.KeyCode.Thumbstick1 then
		if input.Position.Magnitude > STICK_DEADZONE then
			BobberCamView.handBack()
		end
	elseif CAMERA_KEYS[input.KeyCode] then
		BobberCamView.handBack()
	end
end

-- `stateFn` returns the Controller's fishing state.
function BobberCamView.start(stateFn: () -> string)
	getState = stateFn
	RunService:BindToRenderStep("BobberCam", Enum.RenderPriority.Camera.Value + 1, step)
	UserInputService.InputBegan:Connect(onInput)
	UserInputService.InputChanged:Connect(onInput)
	UserInputService.TouchPinch:Connect(function()
		BobberCamView.handBack()
	end)
end

return BobberCamView
