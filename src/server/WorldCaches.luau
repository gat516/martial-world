--!strict
-- Manual caches and sect weapon racks: world anchors the map places.
--   ManualCache  a BasePart tagged "ManualCache" with attributes `Cache` (unique
--                id), `Manual` (technique id) and/or `Weapon` (weapon id), and
--                optionally `Realm` (a stage key like "QC5": needed to claim it).
--                Or `Method` (a cultivation method id, Shared.Methods).
--                A ManualScroll (ServerStorage.WeaponModels.ManualScroll) rests on it.
--   WeaponRack   a BasePart tagged "WeaponRack" with `Weapon` (a weapon id) and
--                optionally `Cache` (defaults to "rack:<Weapon>").
-- Each shows a prompt (ServerStorage.ItemTemplates.CachePrompt / RackPrompt);
-- a player claims each anchor once (data.caches). Zero anchors is fine.
-- The client hides prompts the player has already claimed (WorldCaches client).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local WeaponPacing = require(ReplicatedStorage.Shared.Pacing).Weapons
local Realms = require(ReplicatedStorage.Shared.Realms)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local WeaponDefs = require(ReplicatedStorage.Shared.Weapons)
local Cultivation = require(script.Parent.Cultivation)
local PlayerData = require(script.Parent.PlayerData)
local Progression = require(script.Parent.Progression)
local Weapons = require(script.Parent.Weapons)
local Methods = require(script.Parent.Methods)
local MethodDefs = require(ReplicatedStorage.Shared.Methods)

local templates = ServerStorage:WaitForChild("ItemTemplates") :: Folder

local WorldCaches = {}

local function cacheId(anchor: BasePart, tag: string): string?
	local id = anchor:GetAttribute("Cache")
	if type(id) == "string" and id ~= "" then
		return id
	end
	local weapon = anchor:GetAttribute("Weapon")
	if tag == "WeaponRack" and type(weapon) == "string" then
		return `rack:{weapon}`
	end
	return nil
end

local function realmMet(data: PlayerData.Data, anchor: BasePart): (boolean, string?)
	local key = anchor:GetAttribute("Realm")
	local need = type(key) == "string" and Realms.ByKey[key]
	if not need then
		return true, nil
	end
	local have = Realms.index(data.realm.major, data.realm.minor)
	if have < Realms.index(need.major, need.minor) then
		return false, `Its secrets are beyond you. Reach {need.name} first.`
	end
	return true, nil
end

local function claim(player: Player, anchor: BasePart, tag: string)
	local data = PlayerData.get(player)
	local id = cacheId(anchor, tag)
	if not (data and id) then
		return
	end
	if data.caches[id] then
		Cultivation.notify(player, "You've already taken what this holds.")
		return
	end
	local ok, why = realmMet(data, anchor)
	if not ok then
		Cultivation.notify(player, why :: string)
		return
	end
	local manual = anchor:GetAttribute("Manual")
	local weapon = anchor:GetAttribute("Weapon")
	local method = anchor:GetAttribute("Method")
	local manualDef = type(manual) == "string" and Techniques.Defs[manual] or nil
	local weaponDef = type(weapon) == "string" and WeaponDefs.Defs[weapon] or nil
	local methodDef = type(method) == "string" and MethodDefs.Defs[method] or nil
	if not manualDef and not weaponDef and not methodDef then
		warn(`WorldCaches: {anchor:GetFullName()} names no valid Manual, Weapon or Method`)
		return
	end
	data.caches[id] = true
	if manualDef then
		if data.techniques.owned[manualDef.id] then
			-- already known: the study still deepens its Dao
			if manualDef.weapon ~= "Any" then
				Weapons.addXp(player, manualDef.weapon, WeaponPacing.XP_MANUAL)
			end
			Cultivation.notify(player, `You already know {manualDef.name}; studying it again deepens your understanding.`)
		else
			Progression.grantManual(player, manualDef.id)
		end
	end
	if weaponDef then
		Weapons.grant(player, weaponDef.id)
	end
	if methodDef and not Methods.grant(player, methodDef.id) then
		Cultivation.notify(player, `You already know the {methodDef.name}.`)
	end
	Cultivation.pushState(player)
end

local function setUp(anchor: Instance, tag: string)
	if not (anchor:IsA("BasePart") and anchor:IsDescendantOf(workspace)) then
		return
	end
	local promptName = if tag == "ManualCache" then "CachePrompt" else "RackPrompt"
	local template = templates:FindFirstChild(promptName)
	if not (template and template:IsA("ProximityPrompt")) then
		warn(`WorldCaches: ServerStorage.ItemTemplates.{promptName} is missing`)
		return
	end
	if anchor:FindFirstChild(promptName) then
		return
	end
	local prompt = template:Clone()
	local weapon = anchor:GetAttribute("Weapon")
	local manual = anchor:GetAttribute("Manual")
	local weaponDef = type(weapon) == "string" and WeaponDefs.Defs[weapon] or nil
	local manualDef = type(manual) == "string" and Techniques.Defs[manual] or nil
	if tag == "WeaponRack" and weaponDef then
		prompt.ObjectText = weaponDef.name
	elseif manualDef then
		prompt.ObjectText = `{manualDef.name} manual`
	elseif type(anchor:GetAttribute("Method")) == "string" and MethodDefs.Defs[anchor:GetAttribute("Method") :: string] then
		prompt.ObjectText = MethodDefs.Defs[anchor:GetAttribute("Method") :: string].name
	end
	-- the client reads this to hide prompts already claimed
	prompt:SetAttribute("Cache", cacheId(anchor, tag))
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		claim(player, anchor, tag)
	end)
	if tag == "ManualCache" then
		local models = ServerStorage:FindFirstChild("WeaponModels")
		local scroll = models and models:FindFirstChild("ManualScroll")
		if scroll and scroll:IsA("Model") then
			local copy = scroll:Clone()
			for _, d in copy:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			copy:PivotTo(anchor.CFrame * CFrame.new(0, anchor.Size.Y / 2 + copy:GetExtentsSize().Y / 2, 0))
			copy.Parent = anchor
		end
	end
end

function WorldCaches.start()
	for _, tag in { "ManualCache", "WeaponRack" } do
		for _, anchor in CollectionService:GetTagged(tag) do
			task.spawn(setUp, anchor, tag)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(anchor)
			setUp(anchor, tag)
		end)
	end
end

return WorldCaches
