--!strict
-- The phone tier's foliage (leg 3, N1 round 2). Server/BankDress tags every copy of the bank kit
-- it places: "FoliageUnder" (undergrowth, the bank lip, the lawn corners' bushes and ferns),
-- "FoliageReed", "FoliageStone" and "FoliageTree", each with a FoliageAlt attribute (0 or 1).
-- While the player attribute LookTierActive is "phone" (ClientModules/LookDirector), on this
-- screen only:
--   * no tagged foliage casts a shadow;
--   * undergrowth past 40 studs from the camera is hidden (LocalTransparencyModifier 1);
--   * every second reed clump and stone group (FoliageAlt 1) past 80 studs is hidden;
--   * every second far tree (FoliageFar, FoliageAlt 1) past 40 studs is hidden;
--   * every second kit tree (FoliageAlt 1) past 150 studs is hidden.
-- (N1 round 4, the advisor: from shot 01's view that drops every second far pine and all the
-- undergrowth, for about 300 draw calls on a phone. The overview, shot 07, is no player's view.)
-- On the desktop tier it does nothing (and puts everything back when the tier changes to it).
--
-- Cheap by design: copies sit in 24 stud buckets; twice a second it works out, per bucket, which
-- distance band (past 40, past 80, past 150) its centre is in, and touches only the copies in
-- buckets whose band changed. Copies that stream in or out are added and dropped as they go.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local FoliageTier = {}

FoliageTier.TAGS = { "FoliageUnder", "FoliageReed", "FoliageStone", "FoliageTree" }
FoliageTier.UNDER = 40 -- undergrowth, and every second far tree, hide past this
FoliageTier.NEAR = 80 -- every second reed and stone group hides past this
FoliageTier.FAR = 150 -- every second kit tree hides past this
FoliageTier.EVERY = 0.5 -- seconds between checks
local BUCKET = 24

type Entry = {
	model: Model,
	tag: string,
	alt: number,
	far: boolean, -- a far model (FoliageFar)
	parts: { BasePart },
	shadows: { boolean }, -- each part's CastShadow before this tier touched it
	hidden: boolean,
	bucket: number,
}
type Bucket = { cx: number, cz: number, band: number, entries: { [Model]: Entry } }

local entries: { [Model]: Entry } = {}
local buckets: { [number]: Bucket } = {}
local phone = false
local started = false

local function key(ix: number, iz: number): number
	return (ix + 4096) * 8192 + (iz + 4096)
end

-- Which copies hide in a band (0: within UNDER, 1: UNDER to NEAR, 2: NEAR to FAR, 3: past FAR).
function FoliageTier.hides(tag: string, alt: number, band: number, far: boolean?): boolean
	if band == 0 then
		return false
	elseif tag == "FoliageUnder" then
		return true
	elseif tag == "FoliageReed" or tag == "FoliageStone" then
		return band >= 2 and alt == 1
	elseif tag == "FoliageTree" then
		return alt == 1 and (band >= 3 or far == true)
	end
	return false
end

function FoliageTier.band(d: number): number
	return if d > FoliageTier.FAR then 3 elseif d > FoliageTier.NEAR then 2 elseif d > FoliageTier.UNDER then 1 else 0
end

local function setHidden(e: Entry, hide: boolean)
	if e.hidden == hide then
		return
	end
	e.hidden = hide
	local v = if hide then 1 else 0
	for _, p in e.parts do
		p.LocalTransparencyModifier = v
	end
end

local function setShadows(e: Entry, off: boolean)
	for i, p in e.parts do
		p.CastShadow = if off then false else e.shadows[i]
	end
end

local function add(model: Instance, tag: string)
	if not model:IsA("Model") or entries[model] then
		return
	end
	local parts: { BasePart } = {}
	local shadows: { boolean } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(shadows, d.CastShadow)
		end
	end
	local pos = model:GetPivot().Position
	local ix, iz = math.floor(pos.X / BUCKET), math.floor(pos.Z / BUCKET)
	local k = key(ix, iz)
	local b = buckets[k]
	if not b then
		b = { cx = (ix + 0.5) * BUCKET, cz = (iz + 0.5) * BUCKET, band = 0, entries = {} }
		buckets[k] = b
	end
	local alt = model:GetAttribute("FoliageAlt")
	local e: Entry = {
		model = model,
		tag = tag,
		alt = if type(alt) == "number" then alt else (ix + iz) % 2,
		far = model:GetAttribute("FoliageFar") == true,
		parts = parts,
		shadows = shadows,
		hidden = false,
		bucket = k,
	}
	entries[model] = e
	b.entries[model] = e
	if phone then
		setShadows(e, true)
		setHidden(e, FoliageTier.hides(e.tag, e.alt, b.band, e.far))
	end
end

local function remove(model: Instance)
	local e = entries[model :: Model]
	if not e then
		return
	end
	entries[model :: Model] = nil
	local b = buckets[e.bucket]
	if b then
		b.entries[model :: Model] = nil
	end
end

-- Re-bands every bucket from the camera (phone tier only); touches only the buckets whose band
-- changed, or every bucket with `all`.
local function tick(all: boolean?)
	local cam = workspace.CurrentCamera
	if not (cam and phone) then
		return
	end
	local c = cam.CFrame.Position
	for _, b in buckets do
		local band = FoliageTier.band(math.sqrt((b.cx - c.X) ^ 2 + (b.cz - c.Z) ^ 2))
		if all or band ~= b.band then
			b.band = band
			for _, e in b.entries do
				setHidden(e, FoliageTier.hides(e.tag, e.alt, band, e.far))
			end
		end
	end
end

local function setPhone(on: boolean)
	if on == phone then
		return
	end
	phone = on
	for _, e in entries do
		setShadows(e, on)
		if not on then
			setHidden(e, false)
		end
	end
	if on then
		tick(true)
	end
end

function FoliageTier.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	for _, tag in FoliageTier.TAGS do
		for _, m in CollectionService:GetTagged(tag) do
			add(m, tag)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(m)
			add(m, tag)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
	end
	local function readTier()
		setPhone(player:GetAttribute("LookTierActive") == "phone")
	end
	player:GetAttributeChangedSignal("LookTierActive"):Connect(readTier)
	readTier()
	task.spawn(function()
		while true do
			task.wait(FoliageTier.EVERY)
			tick()
		end
	end)
end

return FoliageTier
