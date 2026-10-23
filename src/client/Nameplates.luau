--!strict
-- The name over every player's head (docs/systems/nameplates.md), the local
-- player's own included. A ReplicatedStorage.Nameplate BillboardGui template
-- (assets/Nameplate.rbxmx: a gold-ruled ink band with the name, a small title
-- line above it) is cloned per character, adorned to its Head and kept
-- in PlayerGui.Nameplates, so it's local only. BillboardGui.MaxDistance (from
-- the camera) hides it beyond MAX_DISTANCE studs; your own plate goes sooner,
-- at OWN_MAX_DISTANCE, so it disappears as you zoom out. Roblox's own name over
-- the humanoid is turned off.
--
-- Non-player characters tagged NAMEPLATE_TAG (the testbed's stand-in player,
-- TestbedDummy) get one too, reading the same attributes from the model.
--
-- What it reads, all attributes on the Player (or the tagged model):
--   Surname, FirstName  the character screen's names; shown surname first
--                        ("Li Wei"). Until both exist, the Roblox DisplayName
--                        (a tagged model's Name).
--   Title               optional string, shown small above the name. Set by a
--                        future titles system; "" or nil hides the line.
--   TitleColor          optional Color3 for the title (default gold).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Surnames = require(ReplicatedStorage.Shared.CharacterCreator.Surnames)

local MAX_DISTANCE = 60 -- studs from the camera; beyond this a nameplate disappears
local OWN_MAX_DISTANCE = 18 -- your own: zooming the camera out past this hides it
local TITLE_COLOR = Color3.fromRGB(236, 200, 122)
local WATCHED = { "Surname", "FirstName", "Title", "TitleColor" }
local NAMEPLATE_TAG = "NameplateTarget"

local Nameplates = {}

-- Whose plate: a Player, or a tagged model that carries the attributes itself.
type Source = Player | Model

local template: BillboardGui
local folder: Folder
local plates: { [Source]: BillboardGui } = {}

-- "Surname FirstName" once both are set, else the DisplayName (or model Name).
function Nameplates.nameOf(source: Source): string
	local first = source:GetAttribute("FirstName")
	local key = source:GetAttribute("Surname")
	local surname = if type(key) == "string" and Surnames[key] then Surnames[key].DisplayName else nil
	if type(first) == "string" and first ~= "" and surname then
		return `{surname} {first}`
	end
	return if source:IsA("Player") then source.DisplayName else source.Name
end

local function paint(source: Source)
	local plate = plates[source]
	if not plate then
		return
	end
	(plate:FindFirstChild("PlayerName", true) :: TextLabel).Text = Nameplates.nameOf(source)
	local title = plate:FindFirstChild("Title", true) :: TextLabel
	local text = source:GetAttribute("Title")
	local color = source:GetAttribute("TitleColor")
	title.Visible = type(text) == "string" and text ~= ""
	title.Text = if type(text) == "string" then text else ""
	title.TextColor3 = if typeof(color) == "Color3" then color else TITLE_COLOR
end

local function drop(source: Source)
	local plate = plates[source]
	if plate then
		plate:Destroy()
		plates[source] = nil
	end
end

local function attach(source: Source, character: Model)
	drop(source)
	local head = character:WaitForChild("Head", 10)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	local current = if source:IsA("Player") then source.Character == character else character.Parent ~= nil
	if not (head and head:IsA("BasePart")) or not current then
		return
	end
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local plate = template:Clone()
	plate.Name = source.Name
	plate.MaxDistance = if source == Players.LocalPlayer then OWN_MAX_DISTANCE else MAX_DISTANCE
	plate.Adornee = head
	plate.Parent = folder
	plates[source] = plate
	paint(source)
end

local function listen(source: Source)
	for _, name in WATCHED do
		source:GetAttributeChangedSignal(name):Connect(function()
			paint(source)
		end)
	end
end

local function watch(player: Player)
	listen(player)
	player.CharacterAdded:Connect(function(character)
		attach(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		drop(player)
	end)
	if player.Character then
		task.spawn(attach, player, player.Character)
	end
end

local function watchModel(instance: Instance)
	if instance:IsA("Model") and not plates[instance] then
		listen(instance)
		task.spawn(attach, instance, instance)
	end
end

function Nameplates.init()
	template = ReplicatedStorage:WaitForChild("Nameplate") :: BillboardGui
	folder = Instance.new("Folder")
	folder.Name = "Nameplates"
	folder.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(drop)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	CollectionService:GetInstanceAddedSignal(NAMEPLATE_TAG):Connect(watchModel)
	CollectionService:GetInstanceRemovedSignal(NAMEPLATE_TAG):Connect(function(instance)
		if instance:IsA("Model") then
			drop(instance)
		end
	end)
	for _, instance in CollectionService:GetTagged(NAMEPLATE_TAG) do
		watchModel(instance)
	end
end

return Nameplates
