--!strict
-- The region entry banner: crossing into a new named region (Shared.Regions)
-- shows its name on a ribbon across the top of the screen (Rewards' banner tier,
-- StarterGui.Rewards.Canvas.Banner), a calm travel beat beside the breakthrough
-- card. The ribbon and the realm under it are coloured by danger:
--   jade ribbon "Safe ground" (no realm), the navy-and-gold ribbon when you're at
--   or past its realm, a crimson ribbon and "Beyond your cultivation" when it's
--   above yours.
-- It never takes input, skips the first region you spawn into (and respawns),
-- waits until you've stayed in the new region a moment, and stays quiet while a
-- menu or minigame is open. Regions sharing a name (the sect's two) count as one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Realms = require(ReplicatedStorage.Shared.Realms)
local Regions = require(ReplicatedStorage.Shared.Regions)
local Menus = require(script.Parent.Menus)
local Rewards = require(script.Parent.Rewards)

local POLL = 0.3 -- seconds between position checks
local SETTLE = 1.0 -- seconds you must stay in a new region before it's announced
local HOLD = 2.6 -- seconds the banner stays up (a breakthrough holds 2.6-4)
local HOLD_DANGER = 3.4

local MOODS = {
	safe = { style = "jade", kicker = Color3.fromRGB(150, 225, 190), tag = Color3.fromRGB(190, 240, 215) },
	normal = { style = "gold", kicker = Color3.fromRGB(232, 190, 92), tag = Color3.fromRGB(240, 214, 160) },
	danger = { style = "crimson", kicker = Color3.fromRGB(255, 120, 100), tag = Color3.fromRGB(255, 200, 185) },
}

local player = Players.LocalPlayer

local RegionBanner = {}

-- The player's own stage index on the Realms ladder, from the Realm attribute (its name).
local function myIndex(): number
	local name = player:GetAttribute("Realm")
	for i, stage in Realms.Stages do
		if stage.name == name then
			return i
		end
	end
	return 1
end

local function show(region: Regions.Region)
	local mood, tagText
	if region.realm == nil then
		mood, tagText = MOODS.safe, "Safe ground"
	else
		local major, minor = region.realm[1] :: string, region.realm[2] :: number
		local name = Realms.get(major, minor).name
		if Realms.index(major, minor) > myIndex() then
			mood = MOODS.danger
			tagText = `{name}  <font color="#ff7a64">·  Beyond your cultivation</font>`
		else
			mood, tagText = MOODS.normal, name
		end
	end
	Rewards.show({
		tier = "banner",
		style = mood.style,
		kicker = "YOU HAVE ENTERED",
		kickerColor = mood.kicker,
		title = region.name,
		tag = tagText,
		tagColor = mood.tag,
		subtitle = region.subtitle,
		hold = if mood == MOODS.danger then HOLD_DANGER else HOLD,
	})
end

function RegionBanner.init()
	local current: string? = nil -- the name announced (or spawned into) last
	local pending: string? = nil
	local pendingSince = 0
	-- for a few seconds after (re)spawning, regions are just noted: that's where the
	-- server put you, not somewhere you travelled
	local quietUntil = os.clock() + 3

	player.CharacterAdded:Connect(function()
		quietUntil = os.clock() + 3
	end)

	task.spawn(function()
		while true do
			task.wait(POLL)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local region = root and Regions.at(root.Position)
			if not region then
				pending = nil
				continue
			end
			if os.clock() < quietUntil then
				current, pending = region.name, nil
				continue
			end
			if region.name == current then
				pending = nil
				continue
			end
			local now = os.clock()
			if pending ~= region.name then
				pending, pendingSince = region.name, now
			elseif now - pendingSince >= SETTLE then
				current, pending = region.name, nil
				if not Menus.isOpen() then
					show(region)
				end
			end
		end
	end)
end

return RegionBanner
