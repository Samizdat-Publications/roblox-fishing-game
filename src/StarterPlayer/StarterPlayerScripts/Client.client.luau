-- Client boot.
local modules = script.Parent:WaitForChild("ClientModules")
local Controller = require(modules:WaitForChild("Controller"))
Controller.start()
task.spawn(function()
	require(modules:WaitForChild("FishShadows")).start()
end)
print("[Client] fishing controller started")
