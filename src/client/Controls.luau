--!strict
-- A shared lock on the character's movement controls. Anything that needs the
-- player still (circulating, meditating) locks by name, and movement comes back
-- only once every lock is released, so one ending can't free the other.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local Controls = {}

local locks: { [string]: boolean } = {}

local function controls(): any?
	local ok, module = pcall(function()
		return require((player:WaitForChild("PlayerScripts") :: any).PlayerModule)
	end)
	return if ok then (module :: any):GetControls() else nil
end

local function apply()
	local ctl = controls()
	if ctl then
		if next(locks) then
			ctl:Disable()
		else
			ctl:Enable()
		end
	end
end

function Controls.lock(reason: string)
	locks[reason] = true
	apply()
end

function Controls.unlock(reason: string)
	locks[reason] = nil
	apply()
end

return Controls
