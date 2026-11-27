-- The field guide and tackle box look (leg 3, N2): readable colours, the phone text and touch
-- minimums, and the locked sizes of the tuned minigames (the overlay check depends on them).
return function(t, Shared)
	local UIStyle = require(Shared.UIStyle)
	local Rarity = require(Shared.Rarity)
	local Config = require(Shared.Config)
	local C = UIStyle.COLORS
	local MIN = 4.5

	local function atLeast(a: Color3, b: Color3, what: string)
		local r = UIStyle.contrast(a, b)
		t.ok(r >= MIN, string.format("%s: contrast %.2f is under %.1f", what, r, MIN))
	end

	t.test("the restyle lands switched off", function()
		t.eq(Config.UI_STYLE_ON, false, "UI_STYLE_ON")
	end)

	t.test("ink and every text ink read on paper and on the older paper", function()
		for _, key in { "ink", "inkSoft", "greenInk", "redInk", "waterInk", "brassInk" } do
			atLeast(C[key], C.paper, key .. " on paper")
			atLeast(C[key], C.paperDeep, key .. " on paperDeep")
		end
	end)

	t.test("button and frame text reads: ink on brass and sage, paper on leather and wood", function()
		atLeast(C.ink, C.brass, "ink on brass")
		atLeast(C.ink, C.brassLight, "ink on brassLight")
		atLeast(C.ink, C.sage, "ink on sage")
		atLeast(C.ink, C.canvas, "ink on canvas")
		for _, key in { "leather", "leatherDark", "wood", "woodDark" } do
			atLeast(C.paper, C[key], "paper on " .. key)
		end
	end)

	t.test("the rarity colours are exactly Rarity's", function()
		for _, tier in Rarity.list do
			t.ok(UIStyle.RARITY[tier.id] == tier.color, tier.id .. " differs from Rarity")
			t.ok(UIStyle.RARITY_INK[tier.id] ~= nil, tier.id .. " has no ink")
		end
	end)

	t.test("every rarity reads on paper as ink (the stamp text and journal names)", function()
		for _, tier in Rarity.list do
			atLeast(UIStyle.rarityInk(tier.id, 0), C.paper, tier.id .. " ink on paper")
			atLeast(UIStyle.rarityInk(tier.id, 0), C.paperDeep, tier.id .. " ink on paperDeep")
		end
		-- Godlike's ink shifts hue: every step of the cycle reads.
		for i = 0, 19 do
			atLeast(UIStyle.rarityInk("Godlike", i * 0.1), C.paper, "Godlike ink at hue step " .. i)
		end
		-- The stamp: its ink over a light tint of the exact colour on paper.
		for _, tier in Rarity.list do
			local tinted = UIStyle.mix(tier.color, C.paper, UIStyle.STAMP_TINT)
			atLeast(UIStyle.rarityInk(tier.id, 0), tinted, tier.id .. " stamp")
		end
		-- The exact colours never carry text (ribbons and stamp fills only), because some of
		-- them (Epic) read under 4.5 to 1 with both ink and paper.
	end)

	t.test("the scale rule is unchanged: 1.15 at 1280 by 720, 0.72 at 667 by 375", function()
		t.ok(math.abs(UIStyle.uiScale(1280, 720) - 1.15) < 1e-9, "desktop scale")
		t.ok(math.abs(UIStyle.uiScale(667, 375) - 0.72) < 1e-9, "phone scale")
	end)

	t.test("no text under 14 px on the smallest phone, for every role", function()
		local s = UIStyle.uiScale(667, 375)
		for role in UIStyle.TEXT do
			t.ok(UIStyle.textSize(role, s) * s >= UIStyle.PHONE_MIN_PX, role .. " under 14 px at 667 by 375")
			t.ok(UIStyle.textSize(role, 1.15) >= UIStyle.TEXT[role], role .. " shrank on the desktop")
		end
		for size = 8, 30 do
			t.ok(UIStyle.textSize(size, UIStyle.SCALE.min) * UIStyle.SCALE.min >= 14, "size " .. size .. " at the smallest scale")
		end
	end)

	t.test("touch targets are 44 px at the smallest scale", function()
		local s = UIStyle.SCALE.min
		t.ok(UIStyle.touchSize(s) * s >= UIStyle.TOUCH_MIN_PX, "touch size")
	end)

	t.test("the tuned minigames keep their sizes and places", function()
		local function same(got: { number }, want: { number }, what: string)
			t.eq(#got, #want, what .. " length")
			for i, v in want do
				t.eq(got[i], v, what .. " [" .. i .. "]")
			end
		end
		local L = UIStyle.LOCKED
		same(L.fight.size, { 150, 320 }, "fight size")
		same(L.fight.pos, { 0.5, -260, 0.5, -140 }, "fight position")
		same(L.fight.track, { 56, 236, 20, 46 }, "fight track")
		same(L.fight.progress, { 22, 236, 100, 46 }, "fight progress")
		same(L.fight.reelPrompt, { 360, 80, 0.5, 70, 0.5, -40 }, "reel prompt")
		same(L.fight.dragBox, { 150, 58, 0.5, -100, 0.5, 60 }, "drag box")
		same(L.power, { 300, 22, 0.5, -150, 1, -100 }, "power meter")
		same(L.bench.size, { 600, 340 }, "bench size")
		same(L.bench.pos, { 0.5, -100, 0, 56 }, "bench position")
		same(L.bench.closeUp, { 320, 196, 16, 46 }, "bench close-up")
		same(L.bench.track, { 320, 22, 16, 250 }, "bench track")
		t.eq(L.castRing.radius, 2, "ring radius")
		t.eq(L.castRing.inner, 1.3, "ring inner radius")
		t.eq(L.castRing.beads, 10, "ring beads")
		t.eq(L.castRing.beadSize, 0.4, "ring bead size")
		same(L.castRing.label, { 190, 34 }, "ring label")
	end)

	t.test("every panel image has a fallback colour and a sane slice", function()
		for name, img in UIStyle.IMAGES do
			t.ok(C[img.fill] ~= nil, name .. " fill is not a colour")
			t.ok(img.stroke == nil or C[img.stroke] ~= nil, name .. " stroke is not a colour")
			t.ok(img.id == nil or (type(img.id) == "string" and img.id:match("^rbxassetid://%d+$") ~= nil), name .. " id")
			t.eq(#img.size, 2, name .. " size")
			if img.slice then
				local s = img.slice
				t.ok(s[1] >= 0 and s[2] >= 0 and s[3] <= img.size[1] and s[4] <= img.size[2] and s[1] < s[3] and s[2] < s[4], name .. " slice outside the image")
			end
		end
		for _, key in { "paper", "canvas", "leather", "brassButton", "brassButtonPressed", "tackleTab", "fightFrame", "waterTrack", "fishMarker", "raritySeal", "rarityRibbon", "weightTag", "coin", "creel", "dial", "dialHand", "journal", "goals", "bait", "ruler", "stitch" } do
			t.ok(UIStyle.IMAGES[key] ~= nil, "missing image " .. key)
		end
	end)

	t.test("every font role names a family and a weight", function()
		for _, role in { "title", "body", "bodyBold", "hand" } do
			local f = UIStyle.FONTS[role]
			t.ok(f ~= nil and type(f.family) == "string" and type(f.weight) == "string", role)
		end
	end)
end
