--!strict
-- The phone tier's foliage (leg 3, N1 round 2). Server/BankDress tags every copy of the bank kit
-- it places: "FoliageUnder" (undergrowth, the bank lip, the lawn corners' bushes and ferns),
-- "FoliageReed", "FoliageStone" and "FoliageTree", each with a FoliageAlt attribute (0 or 1).
-- While the player attribute LookTierActive is "phone" (ClientModules/LookDirector), on this
-- screen only:
--   * no foliage casts a shadow: every tagged copy, and (N1 close-out) every untagged model named
--     in FoliageTier.SHADOW_NAMES (driftwood, the old trees and reeds, the Big Lake's dressing);
--   * undergrowth past 40 studs from the camera is hidden (LocalTransparencyModifier 1);
--   * every second reed clump and stone group (FoliageAlt 1) past NEAR (60) studs is hidden;
--   * every second far tree (FoliageFar, FoliageAlt 1) past 40 studs is hidden;
--   * every second kit tree (FoliageAlt 1) past FAR (100) studs is hidden;
--   * (N3 review 3) every kit tree past GONE (220) studs is hidden: Cedar Creek's 63 cedars
--     alone are about 80k triangles.
-- (N3 review 3, final, 11/28/2026: NEAR 60 and FAR 100, were 80 and 150; GONE is new.)
-- (N1 round 4, the advisor: from shot 01's view that drops every second far pine and all the
-- undergrowth, for about 300 draw calls on a phone. The overview, shot 07, is no player's view.)
-- On the desktop tier it does nothing (and puts everything back when the tier changes to it).
--
-- Cheap by design: copies sit in 24 stud buckets; twice a second it works out, per bucket, which
-- distance band (past UNDER, NEAR, FAR and GONE) its centre is in, and touches only the copies in
-- buckets whose band changed. Copies that stream in or out are added and dropped as they go.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local FoliageTier = {}

FoliageTier.TAGS = { "FoliageUnder", "FoliageReed", "FoliageStone", "FoliageTree" }
FoliageTier.UNDER = 40 -- undergrowth, and every second far tree, hide past this
FoliageTier.NEAR = 60 -- every second reed and stone group hides past this (N3 review 3: was 80)
FoliageTier.FAR = 100 -- every second kit tree hides past this (N3 review 3: was 150)
FoliageTier.GONE = 220 -- every kit tree hides past this (N3 review 3)
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

-- (N1 close-out, the advisor's review 3) Foliage nobody tagged (driftwood, the old Scenery and
-- WorldBuilder trees and reeds still standing, the Big Lake's dressing) loses its shadows on the
-- phone tier too: any model with one of these names. Shadows only; nothing is hidden.
FoliageTier.SHADOW_NAMES = {
	PineTall = true,
	PineShort = true,
	LeafyTree = true,
	Reeds = true,
	DriftwoodBranch = true,
	DriftwoodLog = true,
	DriftwoodStump = true,
	ReedClump1 = true,
	ReedClump2 = true,
	ShorePine1 = true,
	ShorePine2 = true,
	BirchLean1 = true,
	BirchLean2 = true,
	FarPine1 = true,
	FarPine2 = true,
	FarLeafy1 = true,
	FarLeafy2 = true,
	Fern1 = true,
	Fern2 = true,
	Bush1 = true,
	Bush2 = true,
} :: { [string]: boolean }

type ShadowEntry = { parts: { BasePart }, shadows: { boolean } }

local entries: { [Model]: Entry } = {}
local shadowOnly: { [Model]: ShadowEntry } = {}
local buckets: { [number]: Bucket } = {}
local phone = false
local started = false

local function key(ix: number, iz: number): number
	return (ix + 4096) * 8192 + (iz + 4096)
end

-- Which copies hide in a band (0: within UNDER, 1: UNDER to NEAR, 2: NEAR to FAR, 3: FAR to
-- GONE, 4: past GONE).
function FoliageTier.hides(tag: string, alt: number, band: number, far: boolean?): boolean
	if band == 0 then
		return false
	elseif tag == "FoliageUnder" then
		return true
	elseif tag == "FoliageReed" or tag == "FoliageStone" then
		return band >= 2 and alt == 1
	elseif tag == "FoliageTree" then
		return band >= 4 or (alt == 1 and (band >= 3 or far == true))
	end
	return false
end

function FoliageTier.band(d: number): number
	return if d > FoliageTier.GONE then 4 elseif d > FoliageTier.FAR then 3 elseif d > FoliageTier.NEAR then 2 elseif d > FoliageTier.UNDER then 1 else 0
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

local function dropShadowOnly(model: Model)
	local se = shadowOnly[model]
	if not se then
		return
	end
	shadowOnly[model] = nil
	if phone then
		for i, p in se.parts do
			p.CastShadow = se.shadows[i]
		end
	end
end

local function add(model: Instance, tag: string)
	if not model:IsA("Model") or entries[model] then
		return
	end
	dropShadowOnly(model) -- tagged after all: the tagged entry takes over
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

-- An untagged model named in SHADOW_NAMES: its shadows go off on the phone tier.
local function addShadowOnly(inst: Instance)
	if not inst:IsA("Model") or not FoliageTier.SHADOW_NAMES[inst.Name] then
		return
	end
	local m = inst :: Model
	if entries[m] or shadowOnly[m] then
		return
	end
	for _, tag in FoliageTier.TAGS do
		if CollectionService:HasTag(m, tag) then
			return
		end
	end
	local parts: { BasePart } = {}
	local shadows: { boolean } = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(shadows, d.CastShadow)
		end
	end
	shadowOnly[m] = { parts = parts, shadows = shadows }
	if phone then
		for _, p in parts do
			p.CastShadow = false
		end
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
	for _, se in shadowOnly do
		for i, p in se.parts do
			p.CastShadow = if on then false else se.shadows[i]
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
	-- Untagged foliage, by name (shadows only).
	for _, d in workspace:GetDescendants() do
		addShadowOnly(d)
	end
	workspace.DescendantAdded:Connect(addShadowOnly)
	workspace.DescendantRemoving:Connect(function(d: Instance)
		if shadowOnly[d :: Model] then
			shadowOnly[d :: Model] = nil
		end
	end)
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
