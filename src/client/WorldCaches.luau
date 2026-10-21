--!strict
-- Hides the prompts of manual caches and weapon racks this player has already
-- claimed (the server's prompt carries a `Cache` attribute; State.caches lists
-- the claimed ones). This module owns those prompts' Enabled on the client.

local CollectionService = game:GetService("CollectionService")

local State = require(script.Parent.State)

local WorldCaches = {}

local function refresh(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local id = prompt:GetAttribute("Cache")
	if type(id) ~= "string" then
		return
	end
	local claimed = State.current.caches
	prompt.Enabled = not (claimed and claimed[id])
end

local function watch(anchor: Instance)
	for _, child in anchor:GetChildren() do
		refresh(child)
	end
	anchor.ChildAdded:Connect(function(child)
		-- the server sets Cache before parenting, but replication may lag a frame
		task.defer(refresh, child)
	end)
end

function WorldCaches.init()
	for _, tag in { "ManualCache", "WeaponRack" } do
		for _, anchor in CollectionService:GetTagged(tag) do
			watch(anchor)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(watch)
	end
	State.onChanged(function()
		for _, tag in { "ManualCache", "WeaponRack" } do
			for _, anchor in CollectionService:GetTagged(tag) do
				for _, child in anchor:GetChildren() do
					refresh(child)
				end
			end
		end
	end)
end

return WorldCaches
