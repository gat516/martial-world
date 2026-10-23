--!strict
-- The admin panel's Traits tab (Hud.AdminPanel.Traits; docs/systems/identity.md):
-- pick a player, see their race, variant and traits, set their race or variant,
-- and give, force or remove any trait to test it without earning it. Everything
-- goes through the AdminAction remote's trait* actions, so the server's rules
-- (Traits.luau) decide; this only shows and asks. The catalogue comes from the
-- shared Registry, the target's state from "traitInfo", re-read after each action
-- and whenever the target's Race/Traits attributes change.
--
-- Layout lives in the GUI (PlayerRow, PlayerGrid, TargetRow, Race/Variant grids,
-- HeldList, CatalogHead + FilterGrid + CatalogList, and hidden Templates: Chip,
-- Tag, TraitRow); this fills it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = require(ReplicatedStorage.Shared.Identity.Registry)
local Requirements = require(ReplicatedStorage.Shared.Identity.Requirements)
local Rarities = require(ReplicatedStorage.Shared.CharacterCreator.Rarities)

local AdminTraits = {}

-- art (art/ui/assets.json)
local ART = {
	lacquer = "rbxassetid://88447362782150",
	gold = "rbxassetid://124847805310931",
	jade = "rbxassetid://124219422183170",
	red = "rbxassetid://75982847120268",
}
local COLOR = {
	cream = Color3.fromRGB(250, 240, 220),
	muted = Color3.fromRGB(176, 192, 186),
	dim = Color3.fromRGB(128, 132, 130),
	hidden = Color3.fromRGB(140, 196, 214), -- Hidden: admins only
	disabled = Color3.fromRGB(226, 112, 98), -- Disabled: off for everyone
	forced = Color3.fromRGB(240, 200, 110),
	exclusive = Color3.fromRGB(214, 170, 120),
	inactive = Color3.fromRGB(150, 150, 150),
	gold = Color3.fromRGB(255, 226, 160),
}
local MODIFIER_TEXT = {
	health = "max health", walk = "walk speed", jump = "jump", strike = "strike damage",
	guard = "damage taken", technique = "technique damage", growth = "herb growth", regen = "regen/s",
}
local MAX_PLAYERS = 6

export type Call = (...any) -> (boolean, any)

local page: ScrollingFrame
local call: Call
local toast: (string) -> ()
local templates: Folder

local who: number? = nil -- target UserId; nil = yourself
local info: { [string]: any }? = nil
local busy = false
local filter = "All"
local query = ""
local selected: string? = nil -- the trait row opened for details (one at a time)
local rows: { { id: string, row: ImageButton } } = {} -- every trait row on screen
local watching: { RBXScriptConnection } = {}
local refreshQueued = false

local function clone(name: string): any
	return (templates:FindFirstChild(name) :: Instance):Clone()
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local kept = {}
	for _, entry in rows do
		if entry.row.Parent then
			table.insert(kept, entry)
		end
	end
	rows = kept
end

local function sortedKeys(map: { [string]: any }, byName: boolean?): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		if byName and map[a].DisplayName ~= map[b].DisplayName then
			return map[a].DisplayName < map[b].DisplayName
		end
		return a < b
	end)
	return keys
end

local function percent(n: number): string
	return `{math.floor(n * 1000 + 0.5) / 10}%`
end

-- "+3% technique damage, +1 walk speed"
local function modifiersText(mods: { [string]: number }?): string
	local parts = {}
	for _, kind in sortedKeys(mods or {}) do
		local value = (mods :: any)[kind]
		local amount = if kind == "walk" then `{value}` else percent(value)
		local sign = if value >= 0 then "+" else ""
		if kind == "guard" then
			sign, amount = "-", percent(math.abs(value))
		end
		table.insert(parts, `{sign}{amount} {MODIFIER_TEXT[kind] or kind}`)
	end
	return table.concat(parts, ", ")
end

-- A chip (lacquer button art) with its label, art and press.
local function chip(parent: Instance, label: string, order: number, opts: { art: string?, color: Color3?, faded: boolean?, press: () -> () })
	local c = clone("Chip") :: ImageButton
	c.Name = "Chip"
	c.LayoutOrder = order
	c.Image = opts.art or ART.lacquer
	c.ImageTransparency = if opts.faded then 0.45 else 0
	local text = c:FindFirstChild("Label") :: TextLabel
	text.RichText = true
	text.Text = label
	text.TextColor3 = opts.color or COLOR.cream
	c.Activated:Connect(opts.press)
	c.Visible = true
	c.Parent = parent
	return c
end

local function tag(parent: Instance, text: string, color: Color3, order: number)
	local t = clone("Tag") :: ImageLabel
	t.ImageColor3 = color
	t.LayoutOrder = order
	t.Visible = true
	local label = t:FindFirstChild("Label") :: TextLabel
	label.Text = text
	label.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35)
	t.Parent = parent
end

-- Status of an availability entry as (text, colour), or nil when Released.
local function statusTag(entry: any): (string?, Color3?)
	if entry.Status == "Disabled" then
		return "Disabled", COLOR.disabled
	elseif entry.Status == "Hidden" then
		return "Hidden", COLOR.hidden
	end
	return nil, nil
end

--[[ Server ]]

local refresh: () -> ()
local paintSelection: () -> ()

-- Runs a trait action for the target, toasts its message and refreshes.
local function act(action: string, ...: any)
	if busy then
		return
	end
	busy = true
	local args = table.pack(...)
	task.spawn(function()
		local ok, message = call(action, who, table.unpack(args, 1, args.n))
		busy = false
		toast(if type(message) == "string" then message elseif ok then "Done" else "Failed")
		refresh()
	end)
end

--[[ Painting ]]

local function identity(): any
	return { race = info and info.race or "", variant = info and info.variant or "", traits = {} }
end

local function owned(): { [string]: any }
	local map = {}
	for _, t in (info and info.traits) or {} do
		map[t.id] = t
	end
	return map
end

local function paintTarget()
	local label = (page:FindFirstChild("TargetRow") :: Frame):FindFirstChild("TargetLabel") :: TextLabel
	if not info then
		label.Text = "Nobody loaded"
		return
	end
	local me = Players.LocalPlayer
	local you = me ~= nil and info.userId == me.UserId
	label.Text = `{info.name}{if you then " (you)" else ""}  <font color="#b0c0ba">·</font>  <font color="#ffe2a0">{if info.race == "" then "No race" else info.label}</font>`
end

local function paintRaces()
	local raceGrid = page:FindFirstChild("RaceGrid") :: Frame
	local variantGrid = page:FindFirstChild("VariantGrid") :: Frame
	local variantHead = page:FindFirstChild("VariantHead") :: Frame
	clear(raceGrid)
	clear(variantGrid)
	local race = info and info.race or ""
	local variant = info and info.variant or ""
	for order, id in sortedKeys(Registry.Races, true) do
		local def = Registry.Races[id]
		local status, color = statusTag(Registry.raceEntry(id))
		local current = id == race
		local text = def.DisplayName
		if status == "Disabled" then
			text = `<s>{text}</s>`
		elseif status then
			text ..= ` <font size="10">{string.lower(status)}</font>`
		end
		chip(raceGrid, text, order, {
			art = if current then ART.gold else nil,
			color = color,
			faded = status == "Disabled",
			press = function()
				if status == "Disabled" then
					toast(`{def.DisplayName} is disabled`)
				elseif current then
					toast(`Already {def.DisplayName}`)
				else
					act("traitSetRace", id, "")
				end
			end,
		})
	end
	local variants = Registry.Variants[race]
	variantHead.Visible = variants ~= nil
	variantGrid.Visible = variants ~= nil
	if variants then
		((variantHead :: any).Title :: TextLabel).Text = `{Registry.Races[race].DisplayName} variant`
		for order, id in sortedKeys(variants, true) do
			local def = variants[id]
			local entry = Registry.variantEntry(race, id)
			local status, color = statusTag(entry)
			local current = id == variant
			local text = def.DisplayName
			if status == "Disabled" then
				text = `<s>{text}</s>`
			elseif status then
				text ..= ` <font size="10">{string.lower(status)}</font>`
			end
			chip(variantGrid, text, order, {
				art = if current then ART.gold else nil,
				color = color,
				faded = status == "Disabled",
				press = function()
					if status == "Disabled" then
						toast(`{def.DisplayName} is disabled`)
					elseif current then
						toast(`Already {def.DisplayName}`)
					else
						act("traitSetRace", race, id)
					end
				end,
			})
		end
	end
end

local ROW_IDLE = Color3.fromRGB(205, 205, 205)
local ROW_HOVER = Color3.fromRGB(235, 235, 235)
local ROW_SELECTED = Color3.fromRGB(255, 236, 190)

-- The selected row: details open, name gold, rim lit; the rest closed.
paintSelection = function()
	for _, entry in rows do
		local row = entry.row
		if row.Parent then
			local on = entry.id == selected
			row.ImageColor3 = if on then ROW_SELECTED else ROW_IDLE
			local details = row:FindFirstChild("Details") :: TextLabel
			details.Visible = on
			local name = (row:FindFirstChild("Top") :: any).Line.TraitName :: TextLabel
			name.TextColor3 = if on then COLOR.gold else (name:GetAttribute("Base") :: Color3?) or COLOR.cream
		end
	end
end

-- One trait row: name and tags, an info line, an action (Give, Force or
-- Remove); clicking the row selects it and opens its details.
-- `held` is the owned record when the target has it.
local function traitRow(parent: Instance, id: string, order: number, held: any, inHeldList: boolean)
	local def = Registry.Traits[id]
	local row = clone("TraitRow") :: ImageButton
	row.Name = id
	row.LayoutOrder = order
	row.Visible = true
	local top = row:FindFirstChild("Top") :: Frame
	local line = top:FindFirstChild("Line") :: Frame
	local name = line:FindFirstChild("TraitName") :: TextLabel
	local action = top:FindFirstChild("Action") :: ImageButton
	local infoLabel = row:FindFirstChild("Info") :: TextLabel
	local details = row:FindFirstChild("Details") :: TextLabel

	local entry = Registry.traitEntry(id)
	local status, statusColor = statusTag(entry)
	local access = def and Registry.accessLabel(id) or "Unknown trait"
	local open = def ~= nil and Registry.accessible(id, identity(), nil)
	name.Text = if def then def.DisplayName else id
	name.TextColor3 = if held and not held.active then COLOR.inactive else COLOR.cream
	name:SetAttribute("Base", name.TextColor3)
	row.ImageColor3 = ROW_IDLE

	-- tags: rarity, status, (held) forced / inactive, then who it's for (last:
	local rarity = def and Rarities[def.Rarity]
	if rarity then
		tag(line, rarity.DisplayName, rarity.Color, 1)
	end
	if status then
		tag(line, status, statusColor :: Color3, 2)
	end
	if def and def.Access ~= "Everyone" then
		tag(line, access, COLOR.exclusive, 5)
	end
	if held and held.force then
		tag(line, "Forced", COLOR.forced, 3)
	end
	if held and not held.active then
		tag(line, "Inactive", COLOR.inactive, 4)
	end

	-- info line: category, how it's obtained, and (held) where it came from
	local bits = { if def then def.Category else "?" }
	if def then
		table.insert(bits, def.Obtain)
		if def.Requires then
			table.insert(bits, `needs {Requirements.describe(def.Requires)}`)
		end
	end
	if held then
		table.insert(bits, `from {held.src}`)
	elseif def and not open then
		table.insert(bits, "not open to them")
	end
	infoLabel.Text = table.concat(bits, " · ")

	local lines = {}
	if def then
		table.insert(lines, def.Description)
		local mods = modifiersText(def.Modifiers)
		if mods ~= "" then
			table.insert(lines, `<font color="#ffe2a0">{mods}</font>`)
		end
		table.insert(lines, `For: {access}`)
		if def.Excludes then
			local names = {}
			for _, other in def.Excludes do
				local o = Registry.Traits[other]
				table.insert(names, if o then o.DisplayName else other)
			end
			table.insert(lines, `Can't be held with {table.concat(names, ", ")}`)
		end
		if def.Mechanics then
			table.insert(lines, `Mechanics: {table.concat(def.Mechanics, ", ")}`)
		end
		table.insert(lines, `<font color="#808482">id {id}</font>`)
	end
	-- what it means for the loaded player, next to the button that acts on it
	if info and def then
		local whoName = info.name
		local line = if held
			then `{whoName} holds it (from {held.src}{if held.force then ", forced" else ""}{if held.active then "" else ", inactive: no effect now"}). Remove takes it away.`
			elseif status == "Disabled" then "Disabled: nobody can be given it."
			elseif open then `Open to {whoName}. Give adds it now.`
			else `Not open to {whoName} ({Registry.label(info.race, info.variant)}). Force gives it anyway, for testing.`
		table.insert(lines, `<font color="#ffe2a0">{line}</font>`)
	end
	details.Text = table.concat(lines, "\n")
	table.insert(rows, { id = id, row = row })
	row.Activated:Connect(function()
		selected = if selected == id then nil else id
		paintSelection()
	end)
	row.MouseEnter:Connect(function()
		if selected ~= id then
			row.ImageColor3 = ROW_HOVER
		end
	end)
	row.MouseLeave:Connect(function()
		if selected ~= id then
			row.ImageColor3 = ROW_IDLE
		end
	end)

	-- the action: Remove what they hold, Give what's open, Force what isn't;
	-- nothing on a disabled trait they don't hold
	local actionLabel = action:FindFirstChild("Label") :: TextLabel
	if held then
		action.Image = ART.red
		actionLabel.Text = "Remove"
		action.Activated:Connect(function()
			act("traitRemove", id)
		end)
	elseif status == "Disabled" or not def or not info then
		action.Visible = false
	elseif open then
		action.Image = ART.jade
		actionLabel.Text = "Give"
		action.Activated:Connect(function()
			act("traitGrant", id, false)
		end)
	else
		action.Image = ART.gold
		actionLabel.Text = "Force"
		action.Activated:Connect(function()
			act("traitGrant", id, true)
		end)
	end
	row.Parent = parent
	return row
end

local function paintHeld()
	local head = page:FindFirstChild("HeldHead") :: Frame
	local list = page:FindFirstChild("HeldList") :: Frame
	clear(list)
	local traits = (info and info.traits) or {}
	((head :: any).Title :: TextLabel).Text = if info then `Held traits ({#traits})` else "Held traits"
	for order, t in traits do
		traitRow(list, t.id, order, t, true)
	end
	paintSelection()
end

local function matches(id: string, def: any): boolean
	if filter == "Their pool" then
		if not info or not table.find(Registry.traitPool(info.race, info.variant), id) then
			return false
		end
	elseif filter ~= "All" and def.Category ~= filter then
		return false
	end
	if query == "" then
		return true
	end
	local haystack = string.lower(`{id} {def.DisplayName} {def.Category} {def.Obtain} {def.Rarity} {Registry.accessLabel(id)} {Registry.traitEntry(id).Status}`)
	return string.find(haystack, query, 1, true) ~= nil
end

local function paintCatalog()
	local list = page:FindFirstChild("CatalogList") :: Frame
	local head = page:FindFirstChild("CatalogHead") :: Frame
	clear(list)
	local have = owned()
	local shown = 0
	local ids = sortedKeys(Registry.Traits, true)
	for _, id in ids do
		local def = Registry.Traits[id]
		if matches(id, def) then
			shown += 1
			traitRow(list, id, shown, have[id], false)
		end
	end
	((head :: any).Title :: TextLabel).Text = `All traits ({shown}/{#ids})`
	paintSelection()
end

local function paintFilters()
	local grid = page:FindFirstChild("FilterGrid") :: Frame
	clear(grid)
	local names = { "All" }
	for _, category in Registry.Categories do
		table.insert(names, category)
	end
	table.insert(names, "Their pool")
	for order, name in names do
		chip(grid, name, order, {
			art = if name == filter then ART.gold else nil,
			press = function()
				filter = name
				paintFilters()
				paintCatalog()
			end,
		})
	end
end

local function paintPlayers()
	local grid = page:FindFirstChild("PlayerGrid") :: Frame
	clear(grid)
	local box = ((page:FindFirstChild("PlayerRow") :: any).PlayerField.PlayerBox) :: TextBox
	local q = string.lower(box.Text)
	local list = Players:GetPlayers()
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	local shown = 0
	for _, p in list do
		local hit = q == "" or string.find(string.lower(p.Name), q, 1, true) or string.find(string.lower(p.DisplayName), q, 1, true)
		if hit and shown < MAX_PLAYERS then
			shown += 1
			local current = info ~= nil and info.userId == p.UserId
			chip(grid, p.Name, shown, {
				art = if current then ART.gold else nil,
				press = function()
					who = p.UserId
					refresh()
				end,
			})
		end
	end
	-- alone on the server there's nobody to pick but yourself (Me)
	grid.Visible = #list > 1 or q ~= ""
end

local function paint()
	paintTarget()
	paintPlayers()
	paintRaces()
	paintHeld()
	paintCatalog()
end

-- Follow the target's own changes (a sync, a kill unlocking a trait).
local function watch(userId: number?)
	for _, c in watching do
		c:Disconnect()
	end
	watching = {}
	local target = if userId then Players:GetPlayerByUserId(userId) else nil
	if not target then
		return
	end
	for _, attribute in { "Race", "RaceVariant", "Traits", "TraitsInactive" } do
		table.insert(watching, target:GetAttributeChangedSignal(attribute):Connect(function()
			if not refreshQueued and not busy then
				refreshQueued = true
				task.delay(0.2, function()
					refreshQueued = false
					refresh()
				end)
			end
		end))
	end
end

function refresh()
	task.spawn(function()
		local ok, payload = call("traitInfo", who)
		if ok and type(payload) == "table" then
			local changed = not info or info.userId ~= payload.userId
			info = payload
			who = payload.userId
			if changed then
				watch(payload.userId)
			end
		else
			toast(if type(payload) == "string" then payload else "Couldn't load that player")
			who = if info then info.userId else nil -- stay on the last good target
		end
		paint()
	end)
end

local built = false

-- First open: wire the controls and load yourself.
function AdminTraits.show()
	if built then
		refresh()
		return
	end
	built = true
	local row = page:FindFirstChild("PlayerRow") :: any
	local box = row.PlayerField.PlayerBox :: TextBox
	box.FocusLost:Connect(function(enter)
		if enter and box.Text ~= "" then
			-- traitInfo answers with the UserId, which later actions use
			who = (tonumber(box.Text) or box.Text) :: any
			box.Text = ""
			refresh()
		end
	end)
	box:GetPropertyChangedSignal("Text"):Connect(paintPlayers)
	local me = row.MeButton :: GuiButton
	me.Activated:Connect(function()
		who = nil
		refresh()
	end)
	local sync = (page:FindFirstChild("TargetRow") :: any).SyncButton :: GuiButton
	sync.Activated:Connect(function()
		act("traitSync")
	end)
	local search = (page:FindFirstChild("CatalogHead") :: any).SearchField.SearchBox :: TextBox
	search:GetPropertyChangedSignal("Text"):Connect(function()
		query = string.lower(search.Text)
		paintCatalog()
	end)
	Players.PlayerAdded:Connect(paintPlayers)
	Players.PlayerRemoving:Connect(function()
		task.defer(paintPlayers)
	end)
	paintFilters()
	paint()
	refresh()
end

function AdminTraits.init(traitsPage: ScrollingFrame, invokeFn: Call, toastFn: (string) -> ())
	page = traitsPage
	call = invokeFn
	toast = toastFn
	templates = page:FindFirstChild("Templates") :: Folder

	-- AutomaticCanvasSize doesn't count rows that size themselves (docs/systems/ui.md),
	-- which left the page unscrollable with most traits below the fold. Size the
	-- canvas from the list instead, undoing any UIScale above the page.
	local layout = page:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	local padding = page:FindFirstChildOfClass("UIPadding")
	page.AutomaticCanvasSize = Enum.AutomaticSize.None
	local function scale(): number
		local s = 1
		local node: Instance? = page.Parent
		while node do
			local ui = node:FindFirstChildOfClass("UIScale")
			if ui then
				s *= ui.Scale
			end
			node = node.Parent
		end
		return math.max(s, 0.01)
	end
	local function resize()
		local extra = if padding then padding.PaddingTop.Offset + padding.PaddingBottom.Offset else 0
		page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y / scale() + extra)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)
	resize()
end

return AdminTraits
