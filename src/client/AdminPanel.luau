--!strict
-- The admin dashboard (Hud.AdminPanel): a compact side panel for testing, only for
-- players the server marks Admin. F2 toggles it on any device with a keyboard. On
-- touch (phones, tablets, Studio's device emulator) an admin-only tile with the 管
-- seal (`Buttons.AdminButton`, first in the row, never shown to other players)
-- toggles it too, and the panel shows a close seal in place of the F2 hint; on a
-- phone it fills the right side under the tiles and scrolls, and a UI preview chip
-- closes it so the previewed screen can be seen whole (reopen it from the tile
-- once that screen closes: open windows hide the tiles). It doesn't register with
-- Menus, so the world and the HUD stay visible while you trigger things.
--
-- Two tabs in the header: Tools (Sections) and Traits (AdminTraits.luau: a
-- player's race, variant and traits). Tools sections are cloned from
-- SectionTemplate (a title, an optional count box and a grid of chips). Every
-- chip calls AdminAction:InvokeServer(action, ...), which returns (ok, message);
-- the message is toasted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Items = require(ReplicatedStorage.Shared.Items)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Weather = require(ReplicatedStorage.Shared.Weather)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Roots = require(ReplicatedStorage.Shared.Roots)
local Methods = require(ReplicatedStorage.Shared.Methods)
local AdminTraits = require(script.Parent.AdminTraits)
local Hud = require(script.Parent.Hud)
local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)

local player = Players.LocalPlayer

local TAB_ON = "rbxassetid://124847805310931" -- button_gold
local TAB_OFF = "rbxassetid://88447362782150" -- button_lacquer
local TOUCH_CHIP_HEIGHT = 36
-- touch on a phone: the panel's box, right-aligned under the tile row
local PHONE_TOP = 64
local PHONE_BOTTOM_GAP = 10
local WEATHER_ORDER = { "Clear", "Rain", "Storm", "Windy", "AuspiciousMist", "RainbowAurora", "HeavenSplit" }

local AdminPanel = {}

local panel: Frame
local list: ScrollingFrame
local sectionTemplate: Frame
local order = 0
local spawnTier = "adult" -- the "Beast tier" chip last pressed

-- "AuspiciousMist" -> "Auspicious Mist"
local function spaced(id: string): string
	return (string.gsub(id, "(%l)(%u)", "%1 %2"))
end

local function remoteOf(): RemoteFunction?
	return ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("AdminAction") :: RemoteFunction?
end

-- Waits for the answer: (ok, message | payload). Never throws.
local function call(...: any): (boolean, any)
	local remote = remoteOf()
	if not remote then
		return false, "AdminAction remote is missing"
	end
	local args = table.pack(...)
	local ok, success, payload = pcall(function()
		return remote:InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok then
		return false, "Admin action failed"
	end
	return success == true, payload
end

local function invoke(...: any)
	local remote = remoteOf()
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
	local cells = (s:FindFirstChild("Grid") :: Frame):FindFirstChildWhichIsA("UIGridLayout")
	if cells and Platform.isTouch() then
		cells.CellSize = UDim2.new(cells.CellSize.X, UDim.new(0, TOUCH_CHIP_HEIGHT)) -- thumb-sized
	end
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
	-- Open screens in this client: the Studio command bar loads its own fresh copy of a
	-- module (never init'd), so its require(...).open() can't reach the real UI
	local function preview(label: string, path: { string }, fn: string, ...: any): Chip
		local args = table.pack(...)
		return { label = label, press = function()
			local node: Instance = script.Parent
			for _, name in path do
				node = node:FindFirstChild(name) :: Instance
			end
			if Platform.isTouch() and panel.Visible then
				Motion.close(panel) -- see the previewed screen whole
			end
			local ok, err = pcall(function()
				(require(node :: ModuleScript) :: any)[fn](table.unpack(args, 1, args.n))
			end)
			if not ok then
				Hud.toast(`{label} failed: {err}`)
			end
		end }
	end
	section("UI previews", nil, {
		preview("Build mode", { "BuildMode" }, "open"),
		preview("Build catalog", { "BuildCatalog" }, "open", "build"),
		preview("Spirit Market", { "BuildCatalog" }, "open", "shop"),
		preview("Death screen", { "DeathScreen" }, "preview", "boss"),
		preview("Boss card", { "Rewards" }, "preview", "card", "boss"),
		preview("Milestone card", { "Rewards" }, "preview", "card", "milestone"),
		preview("Rank-up card", { "Sect", "SectRank" }, "preview"),
		preview("Dialogue", { "Dialogue" }, "preview"),
		preview("Herbarium", { "Herbarium" }, "preview"),
		preview("Sect board", { "Sect", "SectBoard" }, "preview"),
		preview("World event", { "Events", "WorldEventView" }, "preview"),
		preview("Tribulation", { "Events", "TribulationView" }, "preview"),
		preview("Leaderboard", { "Events", "Leaderboards" }, "preview"),
		preview("Death-save", { "DeathSave" }, "preview"),
	})
	section("Spirit Stones", 1000, {
		{ label = "Give stones", press = function(n)
			invoke("stones", n)
		end },
	})

	-- the count box is the level to set (1 to Techniques.MAX_LEVEL)
	local techniques: { Chip } = {}
	for _, id in Techniques.Order do
		local def = Techniques.Defs[id]
		table.insert(techniques, { label = def and def.name or spaced(id), color = def and def.color, press = function(n)
			invoke("techniqueLevel", id, n)
		end })
	end
	section("Technique level", Techniques.MAX_LEVEL, techniques)

	local weapons: { Chip } = {
		{ label = "All weapons", press = function()
			invoke("allWeapons")
		end },
	}
	for _, id in Weapons.Order do
		local def = Weapons.Defs[id]
		local grade = Weapons.Grades[def.grade]
		table.insert(weapons, { label = def.name, color = grade and grade.color, press = function()
			invoke("weapon", id)
		end })
	end
	section("Give weapon", nil, weapons)

	-- the first method given becomes active; Reset goes back to Sect Breathing
	local methods: { Chip } = {
		{ label = "Reset methods", color = Color3.fromRGB(240, 150, 130), press = function()
			invoke("method", "")
		end },
	}
	for _, id in Methods.Order do
		local def = Methods.Defs[id]
		if id ~= Methods.BASIC then
			local grade = Weapons.Grades[def.grade]
			table.insert(methods, { label = def.name, color = grade and grade.color, press = function()
				invoke("method", id)
			end })
		end
	end
	section("Give method", nil, methods)

	-- the count box is the Dao level to set (1 to Weapons.MAX_LEVEL)
	local daos: { Chip } = {}
	for _, class in Weapons.ClassOrder do
		table.insert(daos, { label = Weapons.Classes[class].dao, press = function(n)
			invoke("daoLevel", class, n)
		end })
	end
	section("Dao level", Weapons.MAX_LEVEL, daos)

	local roots: { Chip } = {
		{ label = "Reroll root", press = function()
			invoke("root")
		end },
		{ label = "Raise grade", press = function()
			invoke("rootGrade")
		end },
		{ label = "Untest root", press = function()
			invoke("root", "")
		end },
	}
	for _, id in Roots.Order do
		local def = Roots.Elements[id]
		table.insert(roots, { label = def.name, color = def.color, press = function()
			invoke("root", id)
		end })
	end
	section("Spirit root", nil, roots)

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

	-- realm variants: the tier the beast chips below spawn at (Pacing.Variants; bosses ignore it)
	local tiers: { Chip } = {}
	for _, tier in Pacing.Variants.ORDER do
		local label = string.upper(string.sub(tier, 1, 1)) .. string.sub(tier, 2)
		table.insert(tiers, { label = label, press = function()
			spawnTier = tier
			Hud.toast(`Beasts spawn as {label}`)
		end })
	end
	section("Beast tier", nil, tiers)

	local beasts: { Chip } = {}
	local enemyIds = {}
	for id in Enemies.Defs do
		table.insert(enemyIds, id)
	end
	table.sort(enemyIds)
	for _, id in enemyIds do
		local def = (Enemies.Defs :: any)[id]
		table.insert(beasts, { label = def and def.name or spaced(id), press = function(n)
			invoke("spawn", id, n, spawnTier)
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
	return player:GetAttribute("Admin") == true
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

-- Tools (the Sections list) or Traits; the picked tab's art turns gold.
local function selectTab(name: string)
	local traitsPage = panel:FindFirstChild("Traits") :: ScrollingFrame?
	local tabs = panel:FindFirstChild("Tabs")
	if not (traitsPage and tabs) then
		return
	end
	list.Visible = name == "Tools"
	traitsPage.Visible = name == "Traits"
	for _, tab in tabs:GetChildren() do
		if tab:IsA("ImageButton") then
			tab.Image = if tab.Name == name .. "Tab" then TAB_ON else TAB_OFF
		end
	end
	if name == "Traits" then
		AdminTraits.show()
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
	local touch = Platform.isTouch()
	local tile = (gui:FindFirstChild("Buttons") :: Instance):FindFirstChild("AdminButton") :: GuiButton?
	local close = panel:FindFirstChild("Close") :: GuiButton?
	local keyHint = panel:FindFirstChild("KeyHint") :: GuiObject?
	if keyHint then
		keyHint.Visible = not touch
	end
	if close then
		close.Visible = touch
		close.Activated:Connect(function()
			AdminPanel.toggle()
		end)
	end
	if touch and Platform.isSmall() then
		panel.Position = UDim2.new(1, -12, 0, PHONE_TOP)
		panel.Size = UDim2.new(0, 380, 1, -(PHONE_TOP + PHONE_BOTTOM_GAP))
	end
	if tile then
		tile.Activated:Connect(function()
			AdminPanel.toggle()
		end)
	end
	local function showTile()
		if tile then
			tile.Visible = touch and allowed()
		end
	end
	showTile()
	player:GetAttributeChangedSignal("Admin"):Connect(showTile)
	local traitsPage = panel:FindFirstChild("Traits") :: ScrollingFrame?
	local tabs = panel:FindFirstChild("Tabs")
	if traitsPage and tabs then
		AdminTraits.init(traitsPage, call, Hud.toast)
		for _, name in { "Tools", "Traits" } do
			local tab = tabs:FindFirstChild(name .. "Tab") :: GuiButton?
			if tab then
				tab.Activated:Connect(function()
					-- only for admins: the Traits tab asks the server on first open
					if allowed() then
						selectTab(name)
					end
				end)
			end
		end
		selectTab("Tools")
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
