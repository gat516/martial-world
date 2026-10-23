--!strict
-- The name over every player's head (docs/systems/nameplates.md), the local
-- player's own included. A ReplicatedStorage.Nameplate BillboardGui template
-- (assets/Nameplate.rbxmx: a gold-ruled ink band with the name, a small title
-- line above it) is cloned per character, adorned to its Head and kept
-- in PlayerGui.Nameplates, so it's local only. BillboardGui.MaxDistance hides it
-- beyond MAX_DISTANCE studs. Roblox's own name over the humanoid is turned off.
--
-- What it reads, all player attributes (they replicate):
--   Surname, FirstName  the character screen's names; shown surname first
--                        ("Li Wei"). Until both exist, the Roblox DisplayName.
--   Title               optional string, shown small above the name. Set by a
--                        future titles system; "" or nil hides the line.
--   TitleColor          optional Color3 for the title (default gold).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Surnames = require(ReplicatedStorage.Shared.CharacterCreator.Surnames)

local MAX_DISTANCE = 60 -- studs; beyond this the nameplate disappears
local TITLE_COLOR = Color3.fromRGB(236, 200, 122)
local WATCHED = { "Surname", "FirstName", "Title", "TitleColor" }

local Nameplates = {}

local template: BillboardGui
local folder: Folder
local plates: { [Player]: BillboardGui } = {}

-- "Surname FirstName" once the character screen has set both, else DisplayName.
function Nameplates.nameOf(player: Player): string
	local first = player:GetAttribute("FirstName")
	local key = player:GetAttribute("Surname")
	local surname = if type(key) == "string" and Surnames[key] then Surnames[key].DisplayName else nil
	if type(first) == "string" and first ~= "" and surname then
		return `{surname} {first}`
	end
	return player.DisplayName
end

local function paint(player: Player)
	local plate = plates[player]
	if not plate then
		return
	end
	(plate:FindFirstChild("PlayerName", true) :: TextLabel).Text = Nameplates.nameOf(player)
	local title = plate:FindFirstChild("Title", true) :: TextLabel
	local text = player:GetAttribute("Title")
	local color = player:GetAttribute("TitleColor")
	title.Visible = type(text) == "string" and text ~= ""
	title.Text = if type(text) == "string" then text else ""
	title.TextColor3 = if typeof(color) == "Color3" then color else TITLE_COLOR
end

local function drop(player: Player)
	local plate = plates[player]
	if plate then
		plate:Destroy()
		plates[player] = nil
	end
end

local function attach(player: Player, character: Model)
	drop(player)
	local head = character:WaitForChild("Head", 10)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if not (head and head:IsA("BasePart")) or player.Character ~= character then
		return
	end
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local plate = template:Clone()
	plate.Name = player.Name
	plate.MaxDistance = MAX_DISTANCE
	plate.Adornee = head
	plate.Parent = folder
	plates[player] = plate
	paint(player)
end

local function watch(player: Player)
	for _, name in WATCHED do
		player:GetAttributeChangedSignal(name):Connect(function()
			paint(player)
		end)
	end
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
end

return Nameplates
