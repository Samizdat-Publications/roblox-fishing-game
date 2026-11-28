-- The creek kit's placement (Neon Pass 2, Shared/CreekPlan): the arch sits on the gate with its
-- front to the lake, the sign board on the slab's face, the post blocks clear of the leaf; eight
-- fence sections alternate and join, hand over to the old fence with no gap and keep the gate
-- open; the lantern arm points where it is told; the kit fits the creek's triangle budget and
-- stays out of the fixed shots.
return function(t, Shared)
	local CreekPlan = require(Shared.CreekPlan)
	local Scatter = require(Shared.Scatter)

	local GX, GZ, GROUND = -162, 0, 1
	local function near(a: number, b: number, eps: number?): boolean
		return math.abs(a - b) <= (eps or 1e-3)
	end

	t.test("the arch: on the gate, front to the lake, sign on the slab, posts clear of the leaf", function()
		local cf = CreekPlan.archCFrame(GX, GZ, GROUND)
		-- The modeler's placing CFrame.
		local want = CFrame.new(-162, 0.6, 0) * CFrame.Angles(0, -math.pi / 2, 0)
		t.ok((cf.Position - want.Position).Magnitude < 1e-4, "pivot")
		t.ok(cf.LookVector:Dot(want.LookVector) > 0.9999, "turn")
		t.ok(cf.LookVector.X > 0.999, "front faces the lake (+X)")
		t.ok(cf.RightVector.Z > 0.999, "its +X runs south")

		local sign, w, h, d = CreekPlan.archSign(cf)
		t.ok(near(w, 6.97) and near(h, 1.24), "board sized to the slab's flat face")
		t.ok(sign.LookVector.X > 0.999, "painted front to the lake")
		t.ok(near(sign.Position.X, -162 + 1.02) and near(sign.Position.Y, 0.6 + 8.17) and near(sign.Position.Z, 0), "board centre on the slab")
		-- Its faces sit just proud of the slab's two faces (z -1.18 and -0.86 from the pivot).
		t.ok(d / 2 > 0.16 and d / 2 < 0.2, "faces a hair proud of the slab")
		-- The sign clears the gate leaf (1 thick on the fence line, x -162.5..-161.5).
		t.ok(sign.Position.X - d / 2 > -161.5, "the board stands in front of the leaf")

		local blocks = CreekPlan.archColliders(cf)
		t.eq(#blocks, 2, "two post blocks")
		for _, b in blocks do
			local p, s = b.cframe.Position, b.size
			local inner = math.abs(p.Z - GZ) - s.X / 2 -- local x runs along world z here
			t.ok(inner >= 4.05, string.format("block inner face %.2f clears the 8 stud leaf", inner))
			t.ok(near(p.X, GX) and near(p.Y - s.Y / 2, GROUND), "stands on the fence line, on the ground")
			t.ok(p.Y + s.Y / 2 >= 10.2, "reaches the beam")
		end
		local gap = math.abs(blocks[1].cframe.Position.Z - blocks[2].cframe.Position.Z) - blocks[1].size.X
		t.ok(gap >= 8, string.format("opening %.2f passable with the gate open", gap))
	end)

	t.test("the hero fence: eight sections, alternating, joined, handing over to the old fence", function()
		local F = CreekPlan.HERO_FENCE
		local fence = CreekPlan.heroFence(CreekPlan.SEED, GX, GZ, GROUND)
		t.eq(#fence, 8, "eight sections")
		local again = CreekPlan.heroFence(CreekPlan.SEED, GX, GZ, GROUND)
		for i, s in fence do
			t.ok(again[i].yaw == s.yaw and again[i].lift == s.lift and again[i].model == s.model, "same seed, same fence " .. i)
		end
		local other = CreekPlan.heroFence(CreekPlan.SEED + 1, GX, GZ, GROUND)
		t.ok(other[1].yaw ~= fence[1].yaw, "another seed jitters differently")

		local step = CreekPlan.heroStep()
		t.ok(step >= 10 and step <= 10.95, string.format("step %.2f: a stretch the rails still bridge", step))
		-- The next section's open end reaches the last one's far post (rails poke 0.5 past a post).
		t.ok(step - F.openEnd <= F.post + 0.5, "rails meet the next post")
		t.ok(step - F.openEnd >= F.post - 0.5, "no overlap past a post's own rails")
		-- The first section's rails end inside the arch's post block.
		local P = CreekPlan.ARCH.post
		t.ok(F.first - F.openEnd >= P.inner and F.first - F.openEnd <= P.outer, "first rails end in the arch post")

		local sides = { [1] = {}, [-1] = {} }
		local jittered = false
		for _, s in fence do
			table.insert(sides[s.side], s)
			t.ok(math.abs(s.yaw - (if s.side == 1 then -math.pi / 2 else math.pi / 2)) <= F.yawJitter + 1e-9, "yaw jitter small")
			t.ok(math.abs(s.lift) <= F.liftJitter + 1e-9, "height jitter small")
			jittered = jittered or math.abs(s.lift) > 1e-3
			local cf = s.cframe
			-- The open end (local -X) points back toward the gate.
			local openEnd = (cf * CFrame.new(-F.openEnd, 0, 0)).Position
			local farPost = (cf * CFrame.new(F.post, 0, 0)).Position
			t.ok(math.abs(openEnd.Z - GZ) < math.abs(farPost.Z - GZ), "open end toward the arch")
			t.ok(math.abs(openEnd.Z - GZ) > 4.05, "keeps out of the gate opening")
			t.ok(math.abs(farPost.X - GX) < 0.3, "on the fence line")
			t.ok(math.abs(farPost.Z - GZ) <= F.endAt + 0.3, "inside the hero span")
			t.ok(near(cf.Position.Y, GROUND - F.sink + s.lift), "pivot at the ground line less 0.4")
		end
		t.ok(jittered, "the line is not a ruler")
		for _, side in { 1, -1 } do
			local run = sides[side]
			t.eq(#run, 4, "four a side")
			for i = 2, #run do
				t.ok(run[i].model ~= run[i - 1].model, "variants alternate")
			end
			local last = run[#run]
			local endPost = (CFrame.new(GX, 0, last.z) * CFrame.Angles(0, if side == 1 then -math.pi / 2 else math.pi / 2, 0) * CFrame.new(F.post, 0, 0)).Position
			t.ok(near(math.abs(endPost.Z - GZ), F.endAt, 1e-3), "the run ends on the old fence's post")
		end
		t.ok(sides[1][1].model ~= sides[-1][1].model, "the two sides start on different variants")
	end)

	t.test("the hero fence hides the old posts and rails it replaces, and no others", function()
		local E = CreekPlan.HERO_FENCE.endAt
		-- Scenery's old fence: posts every 76/12 from the leaf's edges (4 and -4) out to 80.
		local step = 76 / 12
		local shown = 0
		for k = 0, 12 do
			for _, side in { 1, -1 } do
				local z = side * (4 + k * step)
				local hidden = CreekPlan.heroHides("Post", z, GZ)
				t.eq(hidden, 4 + k * step <= E + 1e-6, string.format("post at z %.2f", z))
				if k < 12 then
					local mid = side * (4 + (k + 0.5) * step)
					local railHidden = CreekPlan.heroHides("Rail", mid, GZ)
					t.eq(railHidden, 4 + (k + 1) * step <= E + 1e-6, string.format("rail at z %.2f", mid))
					if not railHidden then
						shown += 1
					end
				end
			end
		end
		t.ok(shown > 0, "the rest of the fence stays")
	end)

	t.test("the lantern post: arm where it is told, core at scale, foot sunk", function()
		local foot = Vector3.new(-158, 1, -5.5)
		for _, arm in { { 0, 1 }, { -1, 0 }, { 1, 0 }, { 0, -1 } } do
			local cf = CreekPlan.lanternCFrame(foot, arm[1], arm[2])
			local dir = cf:VectorToWorldSpace(Vector3.new(0, 0, -1))
			t.ok(near(dir.X, arm[1]) and near(dir.Z, arm[2]) and near(dir.Y, 0), string.format("arm along (%d, %d)", arm[1], arm[2]))
			t.ok(near(cf.Position.Y, foot.Y - 0.1), "sunk 0.1")
			local core = CreekPlan.lanternCore(cf)
			t.ok(near(core.Y - cf.Position.Y, 6.43, 0.01), string.format("core %.2f up", core.Y - cf.Position.Y))
			local reach = Vector3.new(core.X - cf.Position.X, 0, core.Z - cf.Position.Z)
			t.ok(near(reach.Magnitude, 1.38, 0.01), "core 1.38 out along the arm")
			t.ok(reach.Unit:Dot(Vector3.new(arm[1], 0, arm[2])) > 0.999, "core over the arm's end")
		end
	end)

	t.test("the kit fits the creek's triangle budget and stays out of the fixed shots", function()
		local kit = CreekPlan.kitTriangles()
		t.eq(kit, 1100 + 4 * 212 + 4 * 212 + 2 * 351, "arch, eight sections, two lanterns")
		local plan = CreekPlan.plan(CreekPlan.SEED, { boughsPer = CreekPlan.BOUGHS_ON })
		t.ok(plan.triangles + kit <= CreekPlan.BUDGET, string.format("%d + %d = %d triangles", plan.triangles, kit, plan.triangles + kit))
		print(string.format("  [CreekKit] plan %d + kit %d = %d triangles (budget %d)", plan.triangles, kit, plan.triangles + kit, CreekPlan.BUDGET))

		-- No section, arch post or lantern stands at a shot camera's eye (props' clearance).
		local spots = {}
		for _, s in CreekPlan.heroFence(CreekPlan.SEED, GX, GZ, GROUND) do
			for _, lx in { -5.5, 0, 5 } do
				table.insert(spots, (s.cframe * CFrame.new(lx, 0, 0)).Position)
			end
		end
		for _, b in CreekPlan.archColliders(CreekPlan.archCFrame(GX, GZ, GROUND)) do
			table.insert(spots, b.cframe.Position)
		end
		table.insert(spots, CreekPlan.lanternCore(CreekPlan.lanternCFrame(Vector3.new(-158, 1, -5.5), 0, 1)))
		for _, p in spots do
			t.ok(Scatter.shotClear(p.X, p.Z, false), string.format("clear of the shots at (%.1f, %.1f)", p.X, p.Z))
		end
		-- Shot 11 looks at the gate through the opening, not into a post.
		local c = CreekPlan.shotCam("11")
		t.ok(c ~= nil, "shot 11")
		if c then
			local ex, ez, lx, lz = c.eye[1], c.eye[3], c.look[1], c.look[3]
			local f = (GX - ex) / (lx - ex)
			local z = ez + (lz - ez) * f
			t.ok(math.abs(z - GZ) < CreekPlan.ARCH.post.inner, string.format("shot 11 crosses the fence line at z %.2f, in the opening", z))
		end
	end)
end
