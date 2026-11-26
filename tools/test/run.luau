--[[
Runs the Edit-mode unit tests (src/ServerScriptService/Tests/*.spec.luau) outside Studio
with Lune (https://lune-org.github.io/docs). Same specs, same `t` helpers as TestRunner.

    lune run tools/test/run.luau

It fakes just enough of Roblox for the pure shared modules: `script.Parent` and
`require(Shared.X)` load files from src/ReplicatedStorage/Shared, Vector3, Color3 and
CFrame come from Lune's Roblox library, and `Random` is a small stand-in (see below).
Results match Studio's in pass or fail, not in exact random draws.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local SHARED_DIR = "src/ReplicatedStorage/Shared/"
local TESTS_DIR = "src/ServerScriptService/Tests/"

-- Random: Roblox uses PCG32; this uses a 32-bit xorshift. Same interface, different numbers.
local Random = {}
Random.__index = Random
function Random.new(seed: number?)
	local s = math.floor(math.abs(seed or os.clock() * 1e6)) % 4294967296
	if s == 0 then
		s = 2463534242
	end
	return setmetatable({ s = s }, Random)
end
function Random:_next(): number
	local x = self.s
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.s = x
	return x / 4294967296
end
function Random:NextNumber(lo: number?, hi: number?): number
	local u = self:_next()
	if lo and hi then
		return lo + (hi - lo) * u
	end
	return u
end
function Random:NextInteger(lo: number, hi: number): number
	return lo + math.floor(self:_next() * (hi - lo + 1))
end

local function baseEnv(): { [string]: any }
	local env = {
		Vector3 = roblox.Vector3,
		Color3 = roblox.Color3,
		CFrame = roblox.CFrame,
		Random = Random,
	}
	return setmetatable(env, { __index = getfenv(1) :: any })
end

-- Read every Shared module up front (file reads can't happen inside a metamethod).
local SOURCES: { [string]: string } = {}
for _, f in fs.readDir(SHARED_DIR) do
	local name = f:match("^(.+)%.luau$")
	if name then
		SOURCES[name] = fs.readFile(SHARED_DIR .. f)
	end
end

-- A fresh module cache per spec file, like TestRunner's clone of Shared.
local function makeShared()
	local cache = {}
	local folder = {}
	local loadModule

	local function moduleRef(name: string)
		return { __module = name }
	end
	setmetatable(folder, {
		__index = function(_, name)
			if SOURCES[name] then
				return moduleRef(name)
			end
			error("Shared has no module " .. tostring(name), 2)
		end,
	})

	local function req(ref: any)
		if type(ref) ~= "table" or not ref.__module then
			error("require expects a Shared module, got " .. tostring(ref), 2)
		end
		return loadModule(ref.__module)
	end

	function loadModule(name: string)
		if cache[name] == nil then
			local src = SOURCES[name]
			local env = baseEnv()
			env.script = { Parent = folder, Name = name }
			env.require = req
			local fn = luau.load(src, { debugName = name, environment = env })
			cache[name] = fn()
		end
		return cache[name]
	end

	return folder, req
end

-- Tests whose result hangs on Roblox's exact random draws for one fixed seed. They pass
-- in Studio; here they're reported as skipped instead of failed.
local NEEDS_ROBLOX_RANDOM = {
}
local skipped = {}

local filter = process.args[1]
local passed, failed = 0, {}
local files = fs.readDir(TESTS_DIR)
table.sort(files)
for _, file in files do
	if file:match("%.spec%.luau$") and (not filter or file:find(filter, 1, true)) then
		local folder, req = makeShared()
		local env = baseEnv()
		env.require = req
		local ok, specFn = pcall(luau.load, fs.readFile(TESTS_DIR .. file), { debugName = file, environment = env })
		local t = {}
		function t.test(name: string, body: () -> ())
			local ok2, err = pcall(body)
			if not ok2 and NEEDS_ROBLOX_RANDOM[file .. " > " .. name] then
				table.insert(skipped, file .. " > " .. name)
			elseif ok2 then
				passed += 1
			else
				table.insert(failed, file .. " > " .. name .. ": " .. tostring(err))
			end
		end
		function t.ok(cond: any, msg: string?)
			if not cond then
				error(msg or "expected true", 2)
			end
		end
		function t.eq(a: any, b: any, msg: string?)
			if a ~= b then
				error(string.format("%s: expected %s, got %s", msg or "eq", tostring(b), tostring(a)), 2)
			end
		end
		if not ok then
			table.insert(failed, file .. " did not load: " .. tostring(specFn))
		else
			local ok3, err = pcall(function()
				specFn()(t, folder)
			end)
			if not ok3 then
				table.insert(failed, file .. " crashed: " .. tostring(err))
			end
		end
	end
end

print(string.format("TESTS: %d passed, %d failed, %d skipped (need Roblox's Random)", passed, #failed, #skipped))
for _, f in skipped do
	print("  SKIP " .. f)
end
for _, f in failed do
	print("  FAIL " .. f)
end
process.exit(if #failed == 0 then 0 else 1)
