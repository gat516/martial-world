--!strict
-- Server side of the character screen (docs/systems/character-creator.md): the
-- free first roll of race and last name, paid rerolls, hair-id validation and
-- loading, and Enter World. Everything persistent or random is decided here; the
-- client only previews.
--
-- State lives on the player as attributes (they replicate, so the screen just
-- reads them): Race, RaceVariant, Surname, FirstName, CharacterConfirmed. Race,
-- variant and last name are saved in the profile (`identity`, owned by
-- Traits.luau, which also rolls and checks races and variants against
-- Shared.Identity); the first name and look aren't saved yet.
--
-- CharacterAction (RemoteFunction) actions, each returning (ok, payload|message):
--   "state"              -> { products = { RerollRace = {price, live}, ... }, mock }
--   "templates"          -> { [catalogId]: templateImage } for every Clothing option
--   "hair", id           -> validates the catalog id is hair and hands the client a
--                           copy of the accessory (parented in its PlayerGui) to preview
--   "defaults"           -> once: { skin, hairs = { {id, accessory} } } from the
--                           player's own avatar, the screen's starting look
--   "choices"            -> { races = {ids}, variants = {ids} } the player may pick
--                           right now (Availability Select, or Unlock with Requires met)
--   "choose", kind, id   -> kind "Race" | "Variant": picks one of those (Traits.choose)
--   "reroll", kind       -> kind "Race" | "Surname". Live product: returns
--                           { productId } and the client prompts the purchase; the
--                           reroll happens in the receipt handler. Mock (id 0): rerolls
--                           at once, Studio and testbed only.
--   "confirm", look      -> checks and applies the look; fires onConfirmed. Where
--                           Players.CharacterAutoLoads is off (the test place) the
--                           first confirm spawns the character, and the dead respawn
--                           from here.

local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local CC = ReplicatedStorage.Shared.CharacterCreator
local Clothing = require(CC.Clothing)
local HairColors = require(CC.HairColors)
local Products = require(CC.Products)
local Registry = require(ReplicatedStorage.Shared.Identity.Registry)
local SkinColors = require(CC.SkinColors)
local Rules = require(CC.Rules)
local Surnames = require(CC.Surnames)
local Receipts = require(script.Parent.Receipts)
local PlayerData = require(script.Parent.PlayerData)
local Traits = require(script.Parent.Traits)

export type Look = {
	Shirt: string, -- Clothing option Id
	Pants: string,
	HairIds: { number }, -- catalog ids of hair accessories, up to Rules.MAX_HAIRS (empty for none)
	HairColor: string, -- HairColors Id
	SkinColor: string, -- SkinColors Id ("Avatar" keeps the avatar's skin)
	FirstName: string,
}

local CLASSIC_FACE = "rbxasset://textures/face.png" -- Roblox's default smile
local HAIR_COOLDOWN = 1.5 -- seconds between hair loads per player
local PREVIEW_FOLDER = "CharacterPreview" -- in PlayerGui: only that player sees it

local random = Random.new()
local looks: { [Player]: Look } = {}
local lastHair: { [Player]: number } = {}
local defaultsSent: { [Player]: boolean } = {}
local hairCache: { [number]: Accessory | false } = {} -- false = not a hair we can load
local templates: { [number]: string }? = nil

local CharacterIdentity = {}
-- Integration hooks: append functions.
CharacterIdentity.onConfirmed = {} :: { (Player, Look) -> () }
CharacterIdentity.onRerolled = {} :: { (Player, string, string) -> () } -- player, kind, new key

local KINDS = {
	Race = { product = Products.RerollRace },
	Surname = { product = Products.RerollSurname },
}

local function mockAllowed(): boolean
	return RunService:IsStudio() or Config.TESTBED
end

-- A fresh roll of "Race" (with its variant, through Traits) or "Surname", saved
-- in the profile. Returns the new key, or nil while the profile isn't loaded.
local function roll(player: Player, kind: string): string?
	local data = PlayerData.get(player)
	if not data then
		return nil
	end
	local key: string?
	if kind == "Race" then
		key = Traits.rollRace(player, data)
	else
		key = Rules.roll(Surnames :: any, random)
		data.identity.surname = key :: string
		player:SetAttribute("Surname", key)
	end
	if key then
		for _, hook in CharacterIdentity.onRerolled do
			task.spawn(hook, player, kind, key)
		end
	end
	return key
end

-- Gives a player their race, variant and last name from the saved profile; a
-- new player, or one whose race or variant the config dropped, rolls for free.
function CharacterIdentity.load(player: Player, data: PlayerData.Data)
	Traits.load(player, data)
	local surname = data.identity.surname
	if not (Surnames :: any)[surname] then
		surname = Rules.roll(Surnames :: any, random)
		data.identity.surname = surname
	end
	player:SetAttribute("Surname", surname)
end

local function optionById(list: { Clothing.Option }, id: string): Clothing.Option?
	for _, option in list do
		if option.Id == id then
			return option
		end
	end
	return nil
end

local function colorById(id: string): Color3?
	for _, entry in HairColors do
		if entry.Id == id then
			return entry.Color
		end
	end
	return nil
end

local function skinById(id: any): SkinColors.SkinColor?
	for _, entry in SkinColors do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

-- Catalog Shirt/Pants id -> the template image the Shirt/Pants instance needs.
local function templateOf(assetId: number): string?
	local ok, model = pcall(InsertService.LoadAsset, InsertService, assetId)
	if not ok or not model then
		warn(`CharacterIdentity: couldn't load clothing {assetId}`)
		return nil
	end
	local clothing = model:FindFirstChildWhichIsA("Clothing", true)
	local template = if clothing and clothing:IsA("Shirt")
		then clothing.ShirtTemplate
		elseif clothing and clothing:IsA("Pants") then clothing.PantsTemplate
		else nil
	model:Destroy()
	return template
end

local function allTemplates(): { [number]: string }
	if not templates then
		local found = {}
		for _, list in { Clothing.Shirt, Clothing.Pants } do
			for _, option in list do
				if option.AssetId > 0 and not found[option.AssetId] then
					found[option.AssetId] = templateOf(option.AssetId)
				end
			end
		end
		templates = found
	end
	return templates :: { [number]: string }
end

-- Loads a hair accessory by catalog id, after checking the catalog says it's hair.
local function loadHair(id: number): Accessory?
	local cached = hairCache[id]
	if cached ~= nil then
		return if cached then cached else nil
	end
	local okInfo, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, Enum.InfoType.Asset)
	if not okInfo or type(info) ~= "table" or not Rules.HAIR_ASSET_TYPES[info.AssetTypeId] then
		hairCache[id] = false
		return nil
	end
	local okLoad, model = pcall(InsertService.LoadAsset, InsertService, id)
	local accessory = okLoad and model and model:FindFirstChildWhichIsA("Accessory")
	if accessory then
		accessory.Parent = nil
		model:Destroy()
		hairCache[id] = accessory
		return accessory
	end
	if okLoad and model then
		model:Destroy()
	end
	hairCache[id] = false
	return nil
end

local function filterName(player: Player, name: string): string?
	local ok, result = pcall(TextService.FilterStringAsync, TextService, name, player.UserId)
	if not ok then
		return nil
	end
	local okText, text = pcall((result :: TextFilterResult).GetNonChatStringForBroadcastAsync, result)
	if not okText or text ~= name then
		return nil -- filtered (tags) or the filter is down: refuse rather than guess
	end
	return text
end

-- Brings the player into the world. Only needed where Players.CharacterAutoLoads
-- is off (the test place), so nobody stands in the world behind the screen.
local function spawnCharacter(player: Player)
	if player.Parent then
		local ok, err = pcall(player.LoadCharacter, player)
		if not ok then
			warn("CharacterIdentity: couldn't spawn", player.Name, err)
		end
	end
end

-- Puts a copy of a hair in the player's PlayerGui (only they see it) and returns
-- it, for the screen to preview. One copy per id; other hairs stay.
local function previewCopy(player: Player, id: number, hair: Accessory): Accessory?
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return nil
	end
	local folder = gui:FindFirstChild(PREVIEW_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = PREVIEW_FOLDER
		folder.Parent = gui
	end
	local old = (folder :: Instance):FindFirstChild(tostring(id))
	if old then
		old:Destroy()
	end
	local copy = hair:Clone()
	copy.Name = tostring(id)
	copy.Parent = folder
	return copy
end

-- The player's own Roblox avatar, for the screen's starting look: skin colour and
-- up to Rules.MAX_HAIRS of their hairs. Empty when the avatar can't be read
-- (Studio test players have no avatar).
local function avatarDefaults(player: Player): { skin: Color3?, hairIds: { number } }
	local result = { skin = nil :: Color3?, hairIds = {} :: { number } }
	if player.UserId <= 0 then
		return result -- a Studio test player
	end
	local ok, description = pcall(Players.GetHumanoidDescriptionFromUserId, Players, player.UserId)
	if not ok or not description then
		return result
	end
	result.skin = description.HeadColor
	local function add(id: number?)
		if id and id > 0 and #result.hairIds < Rules.MAX_HAIRS and not table.find(result.hairIds, id) then
			table.insert(result.hairIds, id)
		end
	end
	-- Newer avatars list their hair only in the accessory list, not HairAccessory.
	local okList, accessories = pcall(description.GetAccessories, description, true)
	if okList then
		for _, entry in accessories do
			if entry.AccessoryType == Enum.AccessoryType.Hair then
				add(entry.AssetId)
			end
		end
	end
	for raw in string.gmatch(description.HairAccessory, "%d+") do
		add(tonumber(raw))
	end
	return result
end

local function dress(player: Player, look: Look)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and humanoid) then
		return
	end
	-- dress at scale 1 (ApplyDescription and new accessories assume it); the size
	-- comes back at the end (Traits.applySize skips while Dressing is set)
	character:SetAttribute("Dressing", true)
	Traits.scaleCharacter(character, 1)
	local shirt = optionById(Clothing.Shirt, look.Shirt)
	local pants = optionById(Clothing.Pants, look.Pants)
	-- A clean body (user, 2026-10-23): the avatar's skin colours and nothing else
	-- of theirs but the chosen hairs; the default head and the classic face (Head
	-- and Face 0), no other accessories, and only the chosen shirt and pants.
	-- A picked skin colour (SkinColors) replaces the avatar's on every part.
	local okDesc, applied = pcall(humanoid.GetAppliedDescription, humanoid)
	local description = Instance.new("HumanoidDescription")
	local skin = skinById(look.SkinColor)
	for _, part in { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
		if skin and skin.Color then
			(description :: any)[part .. "Color"] = skin.Color
		elseif okDesc and applied then
			(description :: any)[part .. "Color"] = (applied :: any)[part .. "Color"]
		end
	end
	description.Shirt = if shirt then shirt.AssetId else 0
	description.Pants = if pants then pants.AssetId else 0
	local ok, err = pcall(humanoid.ApplyDescription, humanoid, description)
	description:Destroy()
	if not ok then
		warn("CharacterIdentity: couldn't dress", player.Name, err)
	end
	-- Face 0 should leave the classic smile; make sure of it.
	local head = character:FindFirstChild("Head")
	local face = head and head:FindFirstChildOfClass("Decal")
	if face then
		face.Texture = CLASSIC_FACE
	end
	-- Options with a Template image are worn as is (no catalog item to apply).
	for kind, option in { Shirt = shirt, Pants = pants } do
		local template = option and option.Template
		if template then
			local clothing = character:FindFirstChildOfClass(kind :: any)
			if not clothing then
				clothing = Instance.new(kind :: any)
				clothing.Parent = character
			end
			if clothing:IsA("Shirt") then
				clothing.ShirtTemplate = template
			elseif clothing:IsA("Pants") then
				clothing.PantsTemplate = template
			end
		end
	end
	-- Hair goes on as the same accessories the preview showed (loaded through
	-- InsertService). HumanoidDescription.HairAccessory left newer hair off.
	local color = colorById(look.HairColor)
	for _, id in look.HairIds do
		local hair = loadHair(id)
		if hair then
			local copy = hair:Clone()
			if color then
				Rules.tintHair(copy, color)
			end
			humanoid:AddAccessory(copy)
		end
	end
	-- back to the body size the profile calls for (Titan Frame), now that
	-- everything is on and can grow with it
	character:SetAttribute("Dressing", nil)
	Traits.applySize(player)
end

local function confirm(player: Player, raw: any): (boolean, any)
	if type(raw) ~= "table" then
		return false, "Bad request"
	end
	if not optionById(Clothing.Shirt, raw.Shirt) or not optionById(Clothing.Pants, raw.Pants) then
		return false, "Pick a shirt and pants"
	end
	if not colorById(raw.HairColor) then
		return false, "Pick a hair colour"
	end
	if not skinById(raw.SkinColor) then
		return false, "Pick a skin colour"
	end
	local hairIds: { number } = {}
	if type(raw.HairIds) ~= "table" then
		return false, "Bad request"
	end
	for _, id in raw.HairIds do
		if #hairIds >= Rules.MAX_HAIRS then
			return false, `At most {Rules.MAX_HAIRS} hairs`
		end
		if type(id) ~= "number" or table.find(hairIds, id) or not loadHair(id) then
			return false, "That hair can't be used"
		end
		table.insert(hairIds, id)
	end
	local name, why = Rules.checkFirstName(if type(raw.FirstName) == "string" then raw.FirstName else "")
	if not name then
		return false, why
	end
	if not filterName(player, name :: string) then
		return false, "Choose a different name"
	end
	local look: Look = {
		Shirt = raw.Shirt,
		Pants = raw.Pants,
		HairIds = hairIds,
		HairColor = raw.HairColor,
		SkinColor = raw.SkinColor,
		FirstName = name :: string,
	}
	looks[player] = look
	player:SetAttribute("FirstName", look.FirstName)
	player:SetAttribute("CharacterConfirmed", true)
	if not player.Character then
		-- First Enter World: the player comes into the world now (CharacterAdded dresses them).
		task.spawn(spawnCharacter, player)
	elseif Rules.APPLY_TO_CHARACTER then
		task.spawn(dress, player, look)
	end
	for _, hook in CharacterIdentity.onConfirmed do
		task.spawn(hook, player, look)
	end
	return true, look
end

function CharacterIdentity.handle(player: Player, action: any, arg: any, ...: any): (boolean, any)
	if action == "state" then
		local products = {}
		for kind, entry in KINDS do
			products[kind] = { price = entry.product.RobuxPrice, live = entry.product.ProductId ~= 0 }
		end
		return true, { products = products, mock = mockAllowed() }
	elseif action == "templates" then
		return true, allTemplates()
	elseif action == "hair" then
		if type(arg) ~= "number" or arg ~= math.floor(arg) or arg <= 0 then
			return false, "That isn't a valid asset ID"
		end
		local now = os.clock()
		if now - (lastHair[player] or 0) < HAIR_COOLDOWN then
			return false, "Slow down"
		end
		lastHair[player] = now
		local hair = loadHair(arg)
		if not hair then
			return false, "That ID isn't a hair accessory"
		end
		local copy = previewCopy(player, arg, hair)
		if not copy then
			return false, "Try again"
		end
		return true, copy
	elseif action == "defaults" then
		-- Once per player: the avatar's skin and hairs, each hair with a preview copy.
		if defaultsSent[player] then
			return false, "Already sent"
		end
		defaultsSent[player] = true
		local avatar = avatarDefaults(player)
		local hairs = {}
		for _, id in avatar.hairIds do
			local hair = loadHair(id)
			local copy = hair and previewCopy(player, id, hair)
			if copy then
				table.insert(hairs, { id = id, accessory = copy })
			end
		end
		return true, { skin = avatar.skin, hairs = hairs }
	elseif action == "reroll" then
		local entry = KINDS[arg]
		if not entry then
			return false, "Bad request"
		end
		if entry.product.ProductId ~= 0 then
			return true, { productId = entry.product.ProductId }
		elseif mockAllowed() then
			return true, { rolled = roll(player, arg) }
		end
		return false, "Not available yet"
	elseif action == "choices" then
		local data = PlayerData.get(player)
		if not data then
			return false, "Try again"
		end
		local races, variants = {}, {}
		for id in Registry.choosableRaces(data) do
			table.insert(races, id)
		end
		for id in Registry.choosableVariants(data.identity.race, data) do
			table.insert(variants, id)
		end
		table.sort(races)
		table.sort(variants)
		return true, { races = races, variants = variants }
	elseif action == "choose" then
		return Traits.choose(player, arg, ...)
	elseif action == "confirm" then
		return confirm(player, arg)
	end
	return false, "Bad request"
end

function CharacterIdentity.look(player: Player): Look?
	return looks[player]
end

function CharacterIdentity.forget(player: Player)
	looks[player] = nil
	lastHair[player] = nil
	defaultsSent[player] = nil
end

function CharacterIdentity.start()
	-- Paid rerolls: only through Roblox's receipt, never on the client's word.
	for kind, entry in KINDS do
		if entry.product.ProductId ~= 0 then
			Receipts.register(entry.product.ProductId, function(player)
				roll(player, kind)
				return true
			end)
		end
	end
	local function watch(player: Player)
		-- race, variant and last name load from the profile in Main (CharacterIdentity.load)
		player.CharacterAdded:Connect(function(character)
			local look = looks[player]
			if look and Rules.APPLY_TO_CHARACTER then
				task.defer(dress, player, look)
			end
			-- Without auto loading Roblox doesn't respawn the dead, so do it here.
			if not Players.CharacterAutoLoads then
				local humanoid = character:WaitForChild("Humanoid") :: Humanoid
				humanoid.Died:Once(function()
					task.wait(Players.RespawnTime)
					if player.Character == character then
						spawnCharacter(player)
					end
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		task.spawn(watch, player)
	end
end

return CharacterIdentity
