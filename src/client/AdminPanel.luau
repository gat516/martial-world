--!strict
-- The admin dashboard (Hud.AdminPanel): a compact side panel for testing, only for
-- players the server marks Admin, and only on mouse and keyboard. F2 toggles it;
-- there is no on-screen button. It doesn't register with Menus, so the world and
-- the HUD stay visible while you trigger things.
--
-- Sections are cloned from SectionTemplate (a title, an optional count box and a
-- grid of chips). Every chip calls AdminAction:InvokeServer(action, ...), which
-- returns (ok, message); the message is toasted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Items = require(ReplicatedStorage.Shared.Items)
local Weather = require(ReplicatedStorage.Shared.Weather)
local Hud = require(script.Parent.Hud)
local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)

local player = Players.LocalPlayer

local WEATHER_ORDER = { "Clear", "Rain", "Storm", "Windy", "AuspiciousMist", "RainbowAurora", "HeavenSplit" }

local AdminPanel = {}

local panel: Frame
local list: ScrollingFrame
local sectionTemplate: Frame
local order = 0

-- "AuspiciousMist" -> "Auspicious Mist"
local function spaced(id: string): string
	return (string.gsub(id, "(%l)(%u)", "%1 %2"))
end

local function invoke(...: any)
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("AdminAction") :: RemoteFunction?
	if not remote then
		Hud.toast("AdminAction remote is missing")
		return
	end
	local args = table.pack(...)
	task.spawn(function()
		local ok, _, message = pcall(function()
			return remote:InvokeServer(table.unpack(args, 1, args.n))
		end)
		if not ok then
			Hud.toast("Admin action failed")
		elseif message then
			Hud.toast(tostring(message))
		end
	end)
end

type Chip = { label: string, color: Color3?, press: (count: number) -> () }

-- A section: title, an optional count box (its default), and chips.
local function section(title: string, count: number?, chips: { Chip })
	order += 1
	local s = sectionTemplate:Clone()
	s.Name = title
	s.LayoutOrder = order
	local head = s:FindFirstChild("Head") :: Frame;
	(head:FindFirstChild("Title") :: TextLabel).Text = title
	local field = head:FindFirstChild("CountField") :: GuiObject
	local box = field:FindFirstChild("CountBox") :: TextBox
	field.Visible = count ~= nil
	box.Text = tostring(count or 1)
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		box.Text = tostring(if n then math.max(1, math.floor(n)) else count or 1)
	end)
	local grid = s:FindFirstChild("Grid") :: Frame
	local chipTemplate = grid:FindFirstChild("ChipTemplate") :: GuiButton
	for i, c in chips do
		local chip = chipTemplate:Clone()
		chip.Name = "Chip"
		chip.LayoutOrder = i
		local label = chip:FindFirstChild("Label") :: TextLabel
		label.Text = c.label
		if c.color then
			label.TextColor3 = c.color
		end
		chip.Activated:Connect(function()
			c.press(math.max(1, math.floor(tonumber(box.Text) or count or 1)))
		end)
		chip.Visible = true
		chip.Parent = grid
	end
	s.Visible = true
	s.Parent = list
end

local function build()
	-- Weather and events
	local weather: { Chip } = {}
	for _, id in WEATHER_ORDER do
		if Weather.Defs[id] then
			table.insert(weather, { label = spaced(id), press = function()
				invoke("weather", id)
			end })
		end
	end
	section("Weather", nil, weather)

	local okEvents, WorldEvents = pcall(function()
		return require(ReplicatedStorage.Shared:FindFirstChild("WorldEvents") :: ModuleScript) :: any
	end)
	if okEvents and WorldEvents and WorldEvents.Defs then
		local events: { Chip } = {}
		local ids = {}
		for id in WorldEvents.Defs do
			table.insert(ids, id)
		end
		table.sort(ids)
		for _, id in ids do
			table.insert(events, { label = WorldEvents.Defs[id].name or spaced(id), press = function()
				invoke("event", id)
			end })
		end
		table.insert(events, { label = "Stop all events", color = Color3.fromRGB(240, 150, 130), press = function()
			invoke("stopEvents")
		end })
		section("World events", nil, events)
	end

	section("Player", nil, {
		{ label = "Fill dantian", press = function()
			invoke("fillQi")
		end },
		{ label = "All build ×5", press = function()
			invoke("buildItems", 5)
		end },
	})
	section("Spirit Stones", 1000, {
		{ label = "Give stones", press = function(n)
			invoke("stones", n)
		end },
	})

	local items: { Chip } = {}
	for _, id in Items.Order do
		local def = Items.Defs[id]
		table.insert(items, { label = def and def.name or id, press = function(n)
			invoke("give", id, n)
		end })
	end
	section("Give items", 1, items)

	local seeds: { Chip } = {}
	for _, id in Herbs.Order do
		local herb = Herbs.Defs[id]
		table.insert(seeds, { label = herb and herb.name or id, color = herb and herb.color, press = function(n)
			invoke("seeds", id, n)
		end })
	end
	section("Seeds", 5, seeds)

	local beasts: { Chip } = {}
	local enemyIds = {}
	for id in Enemies.Defs do
		table.insert(enemyIds, id)
	end
	table.sort(enemyIds)
	for _, id in enemyIds do
		local def = (Enemies.Defs :: any)[id]
		table.insert(beasts, { label = def and def.name or spaced(id), press = function(n)
			invoke("spawn", id, n)
		end })
	end
	section("Spawn beasts", 1, beasts)

	section("Garden", nil, {
		{ label = "Grow all now", press = function()
			invoke("growAll")
		end },
	})
	local mutations: { Chip } = {}
	for _, id in Herbs.MutationOrder do
		local m = Herbs.Mutations[id]
		table.insert(mutations, { label = m and m.name or id, color = m and m.color, press = function()
			invoke("mutateAll", id)
		end })
	end
	section("Mutate all plants", nil, mutations)
	local wild: { Chip } = {}
	for _, id in Herbs.Order do
		local herb = Herbs.Defs[id]
		if herb and herb.wild then
			table.insert(wild, { label = herb.name, color = herb.color, press = function()
				invoke("wild", id)
			end })
		end
	end
	if #wild > 0 then
		section("Sprout wild herbs", nil, wild)
	end
end

local function allowed(): boolean
	return player:GetAttribute("Admin") == true and not Platform.isTouch()
end

function AdminPanel.toggle()
	if not allowed() then
		return
	end
	if panel.Visible then
		Motion.close(panel)
	else
		Motion.open(panel)
	end
end

function AdminPanel.init(gui: ScreenGui)
	panel = gui:FindFirstChild("AdminPanel") :: Frame
	if not panel then
		return
	end
	list = panel:FindFirstChild("Sections") :: ScrollingFrame
	sectionTemplate = list:FindFirstChild("SectionTemplate") :: Frame
	panel.Visible = false
	if Platform.isTouch() then
		return -- PC only
	end
	local built = false
	local function ensureBuilt()
		if not built and allowed() then
			built = true
			build()
		end
	end
	ensureBuilt()
	player:GetAttributeChangedSignal("Admin"):Connect(function()
		ensureBuilt()
		if not allowed() then
			panel.Visible = false
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F2 then
			ensureBuilt()
			AdminPanel.toggle()
		end
	end)
end

return AdminPanel
