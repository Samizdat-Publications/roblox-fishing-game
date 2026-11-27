--!strict
-- The bobber camera's numbers (L4). While the line is in, the view eases toward a framing
-- that keeps the bobber big and centred: the camera's focus rises a little and slides out
-- along the line toward the bobber, the view turns to centre it, and the field of view
-- narrows just enough that the bobber is at least TARGET_PX tall on this screen. Any camera
-- or movement input hands control straight back (ClientModules/BobberCamView).
-- Pure math, no Roblox services. UNVERIFIED in Studio (written 2026-11-26).
local BobberCam = {}

BobberCam.BOBBER_SCALE = 1.6 -- the bobber model is scaled up this much (FishingService.makeBobber)
BobberCam.MODEL_HEIGHT = 1.38 -- the bobber model's height in studs before scaling (art/README.md)
BobberCam.BOBBER_HEIGHT = BobberCam.MODEL_HEIGHT * BobberCam.BOBBER_SCALE

BobberCam.RAISE = 1.5 -- studs the camera's focus rises
BobberCam.PULL_SHARE = 0.2 -- the focus slides this share of the way out toward the bobber...
BobberCam.PULL_MAX = 8 -- ...up to this many studs
BobberCam.TARGET_PX = 28 -- aim for the bobber this many pixels tall (the floor is 24)
BobberCam.MIN_PX = 24
BobberCam.MIN_FOV = 24 -- never narrower than this (degrees)
BobberCam.EASE_IN = 1.0 -- seconds to ease into the framing
BobberCam.EASE_OUT = 0.25 -- seconds for the zoom and offset to let go after a hand-back
BobberCam.STEER_RATE = 3 -- how quickly the view turns toward the bobber (per second)
BobberCam.DEFAULT_ZOOM = 12.5 -- Roblox's default camera distance (for the phone check)

-- How far the focus slides out toward a bobber this far away (flat studs).
function BobberCam.pull(flatDistance: number): number
	return math.clamp(flatDistance * BobberCam.PULL_SHARE, 0, BobberCam.PULL_MAX)
end

-- How tall (pixels) something `height` studs tall looks `distance` studs away on a screen
-- `viewportHeight` pixels tall at this vertical field of view (degrees).
function BobberCam.pixels(height: number, distance: number, viewportHeight: number, fov: number): number
	local span = 2 * math.tan(math.rad(fov) / 2) * math.max(distance, 0.01)
	return height / span * viewportHeight
end

-- The field of view that makes the bobber TARGET_PX tall, never wider than the player's own
-- and never narrower than MIN_FOV.
function BobberCam.fovFor(height: number, distance: number, viewportHeight: number, defaultFov: number): number
	local want = 2 * math.deg(math.atan(height * viewportHeight / (2 * BobberCam.TARGET_PX * math.max(distance, 0.01))))
	return math.clamp(want, math.min(BobberCam.MIN_FOV, defaultFov), defaultFov)
end

-- 0..1 smooth ease.
function BobberCam.ease(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

return BobberCam
