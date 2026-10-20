--!strict
-- A small card floating over one plant (Hud.PlantTag, a BillboardGui template):
-- its title ("Huge Dewy Spirit Grass"), rarity and size ("×2.4"), its mutations as
-- chips in their colours, and a growth bar with the time left, or "Ready to
-- harvest". One card at a time; GardenView decides which plant it follows.
-- Always on top, and it fades out past MaxDistance (authored on the template).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local Motion = require(script.Parent.Motion)

export type Mutation = { name: string, color: Color3 }
export type Info = {
	title: string,
	color: Color3,
	rarity: string,
	sizeLabel: string?,
	size: number,
	mutations: { Mutation },
	progress: number,
	ready: boolean,
	secondsLeft: number,
	regrows: boolean,
}

local PlantTag = {}

local tag: BillboardGui? = nil
local shownFor: BasePart? = nil
local chipKey = "" -- the mutations the chips were last built for

-- The template lives in Hud; the card itself is parented straight to PlayerGui
-- (a BillboardGui doesn't draw from inside a ScreenGui).
local function ensure(): BillboardGui?
	if tag then
		return tag
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local hud = playerGui and playerGui:FindFirstChild("Hud")
	local template = hud and hud:FindFirstChild("PlantTag") :: BillboardGui?
	if not (playerGui and template) then
		return nil
	end
	local made = template:Clone()
	made.Name = "PlantTagCard"
	made.Enabled = false
	made.Parent = playerGui
	tag = made
	return made
end

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function sizeText(size: number): string
	return "×" .. string.format("%.1f", size)
end

function PlantTag.show(part: BasePart, info: Info)
	local t = ensure()
	if not t then
		return
	end
	local card = t:FindFirstChild("Card") :: Frame
	local rarity = Items.Rarities[info.rarity]
	local rarityColor = if rarity then rarity.color else info.color;
	(card:FindFirstChild("Title") :: TextLabel).Text = info.title;
	(card:FindFirstChild("Meta") :: TextLabel).Text = `<font color="{hex(rarityColor)}">{info.rarity}</font>  ·  {sizeText(info.size)}`

	-- mutation chips (rebuilt only when they change)
	local chips = card:FindFirstChild("Chips") :: Frame
	local parts = {}
	for _, m in info.mutations do
		table.insert(parts, m.name)
	end
	local key = table.concat(parts, ",")
	if key ~= chipKey then
		chipKey = key
		local template = chips:FindFirstChild("ChipTemplate") :: ImageLabel
		for _, child in chips:GetChildren() do
			if child.Name == "Chip" then
				child:Destroy()
			end
		end
		for i, m in info.mutations do
			local chip = template:Clone()
			chip.Name = "Chip"
			chip.LayoutOrder = i
			chip.ImageColor3 = m.color
			local label = chip:FindFirstChild("Label") :: TextLabel
			label.Text = m.name
			label.TextColor3 = m.color
			chip.Visible = true
			chip.Parent = chips
		end
	end
	chips.Visible = #info.mutations > 0

	-- growth, or ready
	local growth = card:FindFirstChild("Growth") :: Frame
	local ready = card:FindFirstChild("Ready") :: TextLabel
	growth.Visible = not info.ready
	ready.Visible = info.ready
	ready.Text = if info.regrows then "Ready to pick" else "Ready to harvest"
	if not info.ready then
		local track = growth:FindFirstChild("Track") :: Frame
		local fill = track:FindFirstChild("Fill") :: Frame
		fill.BackgroundColor3 = info.color
		local target = UDim2.fromScale(math.clamp(info.progress, 0, 1), 1)
		if shownFor == part then
			Motion.ease(fill, { Size = target })
		else
			fill.Size = target
		end
		(growth:FindFirstChild("TimeLabel") :: TextLabel).Text = clock(info.secondsLeft)
	end

	t.Adornee = part
	if shownFor ~= part or not t.Enabled then
		t.Enabled = true
		local scale = card:FindFirstChild("Motion") :: UIScale?
		if scale then
			scale.Scale = 0.85
			Motion.tween(scale, { Scale = 1 })
		end
	end
	shownFor = part
end

function PlantTag.hide()
	if tag then
		tag.Enabled = false
		tag.Adornee = nil
	end
	shownFor = nil
end

return PlantTag
