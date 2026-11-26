-- Compile every Luau file under src/ to catch syntax errors outside Studio, including
-- server and client scripts the unit tests can't load. Run: lune run tools/test/syntax.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local bad = 0
local count = 0
local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif name:match("%.luau$") then
			count += 1
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				bad += 1
				print("SYNTAX " .. path .. ": " .. tostring(err))
			end
		end
	end
end
walk("src")
print(string.format("SYNTAX: %d files, %d with errors", count, bad))
if bad > 0 then
	process.exit(1)
end
