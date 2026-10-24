--!strict
-- The character window, opened by the Self tile in the top-right row
-- (Hud.Buttons.SelfButton) or, as a shortcut, by tapping the realm crest over the
-- vitals (Hud.Stack.Vitals.Crest.Open). It grows with the player
-- (docs/character/character-window.md); this is the first stage:
-- one card, Self, with no tabs.
--   Header: realm name and its stage bar (cultivation toward the next stage).
--   Self page (Body.Pages.Self, a ScrollingFrame list by LayoutOrder). Every row
--   has the same shape (user decision, 2026-10-21: the rows were unclear): a seal,
--   then Lines = Kind (what the row is, in small gold capitals), Top (name, with
--   grade or level on the right) and Effects (what it does for the player, one
--   line each, gains in jade; no flavour text). The numbers come from the shared
--   defs (Roots/Pacing.Roots, Methods, Weapons/Pacing.Weapons).
--     3   Foundation, "FOUNDATION": the grade breaking through now would give
--         ("Steady foundation", the grade word in its colour), a bar of this
--         stage's experiences toward Deep ("2 / 4 experiences", marked at the Steady
--         and Solid shares of Pacing.Foundation), the summed bonus of past grades in
--         jade, then the open experiences, one line each with the category in gold
--         ("HUNT  Slay a Stone Boar for the first time"). From PlayerState
--         `foundation` through foundationOf(), the one reader (hidden without it
--         live; sample data in Studio).
--     5   Dantian, "DANTIAN": raw qi in the dantian (RawQi / DantianCap) as a
--         bar, live while the card is open. Standing, this is the only place the
--         dantian shows (the HUD shows it only while seated, SeatBars).
--     8   Race, "RACE": race and variant ("Beast Folk · Wolf", from the Race and
--         RaceVariant attributes), its rarity on the right (lifted rarity colour),
--         the race, variant and innate-trait modifiers summed, one line each.
--     9   Bloodline, "BLOODLINE": not built yet, so "None", muted (seal, Kind and
--         name dimmed, no effect lines). Fill it like Race when bloodlines land.
--     10  Root, "SPIRIT ROOT": the perk at this grade, the element's technique
--         bonus, the cultivation speed from the grade.
--     12-19 free for root actions (a Reroll button, a stored-roots strip).
--     20  Method, "CULTIVATION METHOD" (from Foundation, once a method is
--         active): its cultivation speed (with the root match) and how far it
--         takes you. Read-only: switching methods belongs to the meditation menu.
--     30  Dao, "WEAPON DAO": the equipped class's Dao level, its XP bar and the
--         weapon damage it gives now and at the next level. No weapon or
--         technique names here (they live in the Inventory).
--     Later systems add rows of the same shape; the list scrolls once it is
--     taller than the screen allows (on a phone it always does).
--   Future tabs (Self | Body) go in Body at LayoutOrder 3, between the stage bar
--   and Pages; each tab is a page frame inside Pages.
-- The tile shows (and the crest is tappable) only once the root is tested. After
-- the reveal the tile pops in, swells once and wears a small seal dot until the
-- window is first opened (not saved).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local Methods = require(ReplicatedStorage.Shared.Methods)
local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Rarities = require(ReplicatedStorage.Shared.CharacterCreator.Rarities)
local Registry = require(ReplicatedStorage.Shared.Identity.Registry)
local Roots = require(ReplicatedStorage.Shared.Roots)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local ListWindow = require(script.Parent.ListWindow)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local SlotArt = require(script.Parent.SlotArt)
local State = require(script.Parent.State)

local player = Players.LocalPlayer

-- art/ui/draw_icons.py (icon_Root<Element>.png), art/ui/assets.json
local ROOT_ICONS: { [string]: string } = {
	Fire = "rbxassetid://118526481262580",
	Water = "rbxassetid://123385248218766",
	Wood = "rbxassetid://96802037356491",
	Metal = "rbxassetid://115986167359660",
	Earth = "rbxassetid://106161919828710",
	Lightning = "rbxassetid://92577547227140",
	Wind = "rbxassetid://105323630508720",
	Ice = "rbxassetid://123225211387242",
}

local PULSE = TweenInfo.new(0.32, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 1, true)
local PULSE_SCALE = 1.14

-- effect lines (rich text): gains in jade, losses in a muted red
local GAIN = "#82E6B9"
local LOSS = "#E69A82"
local GOLD = "#E2BA68" -- the Kind labels' gold, for the hint categories
local MUTED = Color3.fromRGB(140, 136, 126) -- an empty row ("None")
local NAME_COLOR = Color3.fromRGB(236, 232, 220)
local MARK_ON_FILL = Color3.fromRGB(14, 18, 20) -- the foundation bar's grade marks
local MARK_ON_TROUGH = Color3.fromRGB(236, 232, 220)
-- foundation grades, lowest first (Pacing.Foundation.GRADES), and their colours
local FOUNDATION_COLORS: { [string]: string } = {
	Cracked = "#E69A82",
	Steady = "#9FC6E0",
	Solid = "#82E6B9",
	Deep = "#F0C860",
}
local LIST_MARGIN = 24 -- px the card keeps from the screen's top and bottom edges

-- Major names for "Reaches: ..." by stage-key prefix (Pacing.Curve keys).
local MAJOR_SHORT: { [string]: string } = {
	QC = "Qi Condensation",
	QR = "Qi Refining",
	FE = "Foundation",
	CF = "Core Formation",
	NS = "Nascent Soul",
}

local SelfCard = {}

local window: Frame
local crest: GuiObject
local openButton: GuiButton -- over the crest
local tile: GuiButton -- Buttons.SelfButton
local newDot: GuiObject -- on the tile
local selfPage: ScrollingFrame
local hud: ScreenGui
local seenOnce = false

function SelfCard.rootIcon(element: string): string
	return ROOT_ICONS[element] or ""
end

-- Each root icon's drawn area in its 128 px image (x, y, w, h; alpha > 40), so a
-- tile can crop the built-in margin and centre the art on its own box.
local ROOT_ICON_RECTS: { [string]: { number } } = {
	Fire = { 19, 1, 89, 121 },
	Water = { 25, 3, 79, 121 },
	Wood = { 13, 5, 104, 119 },
	Metal = { 5, 32, 119, 78 },
	Earth = { 3, 17, 123, 97 },
	Lightning = { 15, 1, 99, 127 },
	Wind = { 0, 24, 109, 99 },
	Ice = { 12, 5, 104, 118 },
}

function SelfCard.rootIconRect(element: string): (Vector2, Vector2)
	local r = ROOT_ICON_RECTS[element]
	if not r then
		return Vector2.zero, Vector2.zero
	end
	return Vector2.new(r[1], r[2]), Vector2.new(r[3], r[4])
end

function SelfCard.gradeColor(grade: string): Color3
	local g = Weapons.Grades[grade]
	return if g then g.color else Color3.new(1, 1, 1)
end

-- The tested root: the state snapshot, else the player's attributes.
local function currentRoot(): Roots.Root?
	local root = State.current.root
	if root and Roots.tested(root) then
		return root
	end
	local element = player:GetAttribute("Root")
	if type(element) == "string" and Roots.Elements[element] then
		local grade = player:GetAttribute("RootGrade")
		return { element = element, grade = if type(grade) == "string" then grade else Pacing.Roots.STARTING_GRADE, pending = "", grades = {} }
	end
	return nil
end

local function percent(share: number): string
	return `{math.floor(share * 100 + 0.5)}%`
end

-- The perk's exact amount at this root's grade, as one line.
local function perkLine(root: Roots.Root): string
	local def = Roots.Elements[root.element]
	local amount = Roots.perk(root, def.perk)
	if def.perk == "technique" then
		return `+{percent(amount)} technique damage`
	elseif def.perk == "regen" then
		return `Heal {percent(amount)} of your health each second out of combat`
	elseif def.perk == "growth" then
		return `Herbs grow +{percent(amount)} faster while you're online`
	elseif def.perk == "strike" then
		return `+{percent(amount)} weapon strike damage`
	elseif def.perk == "health" then
		return `+{percent(amount)} max health`
	elseif def.perk == "walk" then
		return `+{math.floor(amount * 10 + 0.5) / 10} run speed`
	elseif def.perk == "jump" then
		return `+{percent(amount)} jump height`
	end
	return `-{percent(amount)} damage taken`
end

local function gain(text: string): string
	return `<font color="{GAIN}">{text}</font>`
end

local function loss(text: string): string
	return `<font color="{LOSS}">{text}</font>`
end

-- "+12%" / "-8%" for a share change; nil when it rounds to nothing.
local function signed(share: number): string?
	local n = math.floor(share * 100 + 0.5)
	if n == 0 then
		return nil
	end
	return if n > 0 then `+{n}%` else `{n}%`
end

-- A root's effects, one line each (plain text; the card colours them).
local function rootEffects(root: Roots.Root): { string }
	local def = Roots.Elements[root.element]
	local lines = { perkLine(root), `+{percent(Pacing.Roots.MATCH)} {def.name} technique damage` }
	local speed = signed(Roots.speed(root) - 1)
	if speed then
		table.insert(lines, `{speed} cultivation speed`)
	end
	return lines
end

local function detailText(root: Roots.Root): string
	return table.concat(rootEffects(root), "\n")
end

SelfCard.currentRoot = currentRoot
SelfCard.rootDetail = detailText

-- A row's parts: its name and right-hand label (Lines.Top) and its effect lines.
local function rowParts(name: string): (GuiObject, TextLabel, TextLabel, TextLabel)
	local row = selfPage:FindFirstChild(name) :: GuiObject
	local lines = row:FindFirstChild("Lines") :: Instance
	local top = lines:FindFirstChild("Top") :: Instance
	return row, top:FindFirstChild("NameLabel") :: TextLabel, top:FindFirstChild("Grade") :: TextLabel, lines:FindFirstChild("Effects") :: TextLabel
end

local function paintSeal(seal: Instance, element: string)
	local icon = seal:FindFirstChild("Icon") :: ImageLabel
	icon.Image = SelfCard.rootIcon(element)
	icon.Visible = icon.Image ~= "";
	(seal:FindFirstChild("Glyph") :: TextLabel).Visible = icon.Image == ""
end

local function renderRoot(root: Roots.Root)
	local def = Roots.Elements[root.element]
	local row, name, grade, effects = rowParts("Root")
	paintSeal(row:FindFirstChild("Seal") :: Instance, def.id)
	name.Text = `{def.name} Root`
	name.TextColor3 = def.color
	grade.Text = `{root.grade} grade`
	grade.TextColor3 = SelfCard.gradeColor(root.grade)
	local lines = {}
	for _, line in rootEffects(root) do
		table.insert(lines, gain(line))
	end
	effects.Text = table.concat(lines, "\n")
end

-- "+4% weapon damage" (or "Normal weapon damage") at a Dao level.
local function daoDamage(level: number): string
	local text = signed(Weapons.daoMultiplier(level) - 1)
	if not text then
		return "Normal weapon damage"
	end
	local line = `{text} weapon damage`
	return if string.sub(text, 1, 1) == "+" then gain(line) else loss(line)
end

-- The equipped class's Dao: level, XP toward the next, and what it gives.
local function renderDao()
	local id = SlotArt.equipped()
	local classId = Weapons.classOf(if id == "" then nil else id)
	local class = Weapons.Classes[classId]
	local dao = State.current.dao and State.current.dao[classId]
	local level = if dao then dao.level else 0
	local xp = if dao then dao.xp else 0
	local row, name, levelLabel, effects = rowParts("Dao")
	local seal = row:FindFirstChild("Seal") :: Instance
	local icon = seal:FindFirstChild("Icon") :: ImageLabel
	icon.Image = SlotArt.classIcon(classId)
	icon.Visible = icon.Image ~= "";
	(seal:FindFirstChild("Glyph") :: TextLabel).Visible = icon.Image == ""
	name.Text = if class then class.dao else "Weapon Dao"
	levelLabel.Text = `Level {level}`
	local bar = (row:FindFirstChild("Lines") :: Instance):FindFirstChild("Bar") :: Instance
	local fill = (bar:FindFirstChild("Bar") :: Instance):FindFirstChild("Fill") :: Frame
	local value = bar:FindFirstChild("Value") :: TextLabel
	local lines = { daoDamage(level) }
	if level >= Weapons.MAX_LEVEL then
		fill.Size = UDim2.fromScale(1, 1)
		value.Text = "Mastered"
	else
		local need = Weapons.xpToNext(level)
		Motion.ease(fill, { Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1) })
		value.Text = `{math.floor(xp)} / {need} Dao XP`
		table.insert(lines, `Next level: {daoDamage(level + 1)}`)
	end
	fill.Visible = level >= Weapons.MAX_LEVEL or xp > 0
	effects.Text = table.concat(lines, "\n")
end

-- Raw qi in the dantian (refined into cultivation by Circulate).
local function renderDantian()
	local row = selfPage:FindFirstChild("Dantian") :: GuiObject
	local raw = tonumber(player:GetAttribute("RawQi")) or 0
	local room = tonumber(player:GetAttribute("DantianCap")) or 0
	local bar = (row:FindFirstChild("Lines") :: Instance):FindFirstChild("Bar") :: Instance
	local fill = (bar:FindFirstChild("Bar") :: Instance):FindFirstChild("Fill") :: Frame
	Motion.ease(fill, { Size = UDim2.fromScale(if room > 0 then math.clamp(raw / room, 0, 1) else 0, 1) })
	fill.Visible = raw > 0;
	(bar:FindFirstChild("Value") :: TextLabel).Text = if room > 0
		then `{math.floor(raw)} / {math.floor(room)} raw qi`
		else `{math.floor(raw)} raw qi`
end

local function renderRealm()
	local header = (window:FindFirstChild("Body") :: Instance):FindFirstChild("Header") :: Instance;
	(header:FindFirstChild("Realm") :: TextLabel).Text = player:GetAttribute("Realm") or ""
	local stage = (window:FindFirstChild("Body") :: Instance):FindFirstChild("Stage") :: Instance
	local value = player:GetAttribute("Cultivation") or 0
	local max = player:GetAttribute("CultivationMax") or 0
	local fill = (stage:FindFirstChild("Bar") :: Instance):FindFirstChild("Fill") :: Frame
	Motion.ease(fill, { Size = UDim2.fromScale(if max > 0 then math.clamp(value / max, 0, 1) else 0, 1) })
	fill.Visible = value > 0;
	(stage:FindFirstChild("Value") :: TextLabel).Text = if max > 0
		then `{math.floor(value)} / {math.floor(max)} cultivation`
		else `{math.floor(value)} cultivation`
end

-- Methods -------------------------------------------------------------------------

local function activeMethod(): string
	local m = State.current.methods
	if m then
		return m.active
	end
	local attr = player:GetAttribute("Method")
	return if type(attr) == "string" then attr else ""
end

local function rootElement(): string
	local root = currentRoot()
	return if root then root.element else ""
end

-- "+20%" for a 1.2 multiplier
local function qiBonus(def: Methods.Def): number
	return math.floor((Methods.speed(def, rootElement()) - 1) * 100 + 0.5)
end

local function reachesText(key: string): string
	local prefix, minor = string.match(key, "^(%a+)(%d+)$")
	local major = prefix and MAJOR_SHORT[prefix]
	if not major then
		return `Reaches: {key}`
	end
	return if tonumber(minor) == 9 then `Reaches: all of {major}` else `Reaches: {major} {minor}`
end

-- How far a method takes you, for the card ("Takes you up to the end of Foundation").
local function limitText(key: string): string
	local prefix, minor = string.match(key, "^(%a+)(%d+)$")
	local major = prefix and MAJOR_SHORT[prefix]
	if not major then
		return "No limit yet on how far it takes you"
	end
	return if tonumber(minor) == 9 then `Takes you up to the end of {major}` else `Takes you up to {major} {minor}`
end

-- A method's card lines: qi speed (with the root match), whether it matches,
-- and "Reaches: ...".
function SelfCard.methodInfo(def: Methods.Def): (string, boolean, string)
	local match = def.element ~= "" and def.element == rootElement()
	local bonus = qiBonus(def)
	local qi = (if bonus > 0 then `+{bonus}% qi` else "Normal qi speed") .. (if match then " · matches your root!" else "")
	return qi, match, reachesText(def.reaches)
end

function SelfCard.paintSeal(seal: Instance, element: string)
	paintSeal(seal, element)
end

local function renderMethod()
	local row = selfPage:FindFirstChild("Method") :: GuiObject
	local activeId = activeMethod()
	row.Visible = activeId ~= ""
	if activeId == "" then
		return
	end
	local def = Methods.active(activeId)
	local _, name, grade, effects = rowParts("Method")
	paintSeal(row:FindFirstChild("Seal") :: Instance, def.element)
	name.Text = def.name
	name.TextColor3 = SelfCard.gradeColor(def.grade)
	grade.Text = `{def.grade} grade`
	grade.TextColor3 = SelfCard.gradeColor(def.grade)
	local match = def.element ~= "" and def.element == rootElement()
	local speed = signed(Methods.speed(def, rootElement()) - 1)
	local lines = {}
	if speed then
		local line = `{speed} cultivation speed` .. (if match then " (matches your root)" else "")
		table.insert(lines, if string.sub(speed, 1, 1) == "+" then gain(line) else loss(line))
	else
		table.insert(lines, "Normal cultivation speed")
	end
	table.insert(lines, limitText(def.reaches))
	effects.Text = table.concat(lines, "\n")
end

-- Race, bloodline, foundation ------------------------------------------------------

-- One modifier as an effect line, coloured by whether it helps (Registry.MODIFIERS).
local function modifierLine(kind: string, amount: number): string?
	if kind == "walk" then
		local n = math.floor(amount * 10 + 0.5) / 10
		if n == 0 then
			return nil
		end
		local text = (if n > 0 then `+{n}` else tostring(n)) .. " run speed"
		return if n > 0 then gain(text) else loss(text)
	elseif kind == "regen" then
		return if amount > 0 then gain(`Heal {percent(amount)} of your health each second out of combat`) else nil
	end
	local share = signed(if kind == "guard" then -amount else amount)
	if not share then
		return nil
	end
	local what = ({
		health = "max health",
		jump = "jump height",
		strike = "weapon strike damage",
		technique = "technique damage",
		growth = "herb growth",
		guard = "damage taken",
		size = "body size",
	})[kind]
	if not what then
		return nil
	end
	local text = `{share} {what}`
	if kind == "size" then
		return text -- neither a gain nor a loss
	end
	return if amount > 0 then gain(text) else loss(text)
end

local MODIFIER_ORDER = { "health", "strike", "technique", "guard", "regen", "walk", "jump", "growth", "size" }

-- Race, variant and their innate traits' modifiers, summed (as Registry.stat does
-- on the server for those; traits earned later aren't the race's).
local function raceEffects(raceId: string, variantId: string): { string }
	local totals: { [string]: number } = {}
	local function add(mods: { [string]: number }?)
		for kind, amount in mods or {} do
			totals[kind] = (totals[kind] or 0) + amount
		end
	end
	local race = Registry.race(raceId)
	add(race and race.Modifiers)
	local variant = Registry.variant(raceId, variantId)
	add(variant and variant.Modifiers)
	local active = player:GetAttribute("Traits")
	for _, id in Registry.innate(raceId, variantId) do
		local def = Registry.trait(id)
		local on = type(active) ~= "string" or table.find(string.split(active, ","), id) ~= nil
		if def and on then
			add(def.Modifiers)
		end
	end
	local lines = {}
	for _, kind in MODIFIER_ORDER do
		local line = modifierLine(kind, totals[kind] or 0)
		if line then
			table.insert(lines, line)
		end
	end
	return lines
end

-- "RACE": the race and its variant ("Beast Folk · Wolf"), the rarity on the right.
local function renderRace()
	local row, name, rarityLabel, effects = rowParts("Race")
	local raceId = player:GetAttribute("Race")
	local race = Registry.race(raceId)
	row.Visible = race ~= nil
	if not race then
		return
	end
	local variantId = player:GetAttribute("RaceVariant")
	variantId = if type(variantId) == "string" then variantId else ""
	local variant = Registry.variant(raceId, variantId)
	name.Text = if variant then `{race.DisplayName} · {variant.DisplayName}` else race.DisplayName
	name.TextColor3 = NAME_COLOR
	local rarity = Rarities[(variant and variant.Rarity) or race.Rarity]
	rarityLabel.Text = if rarity then rarity.DisplayName else ""
	-- the rarity hue, lifted so it reads on the dark card at phone size
	rarityLabel.TextColor3 = if rarity then rarity.Color:Lerp(Color3.new(1, 1, 1), 0.35) else NAME_COLOR
	local lines = raceEffects(raceId, variantId)
	effects.Text = table.concat(lines, "\n")
	effects.Visible = #lines > 0
end

-- "BLOODLINE": not built yet (docs/character/bloodline.md), so always "None",
-- muted. When it lands, read data.bloodline.id here and fill the row like Race.
local function renderBloodline()
	local _, name, right, effects = rowParts("Bloodline")
	name.Text = "None"
	name.TextColor3 = MUTED
	right.Text = ""
	effects.Visible = false
end

export type Foundation = {
	count: number, -- weighted experiences this stage (a boss counts double)
	target: number, -- this stage's count for a Deep grade
	grade: string, -- what breaking through now would give: Cracked | Steady | Solid | Deep
	bonus: number, -- every graded stage's bonus summed, as a share of health and power
	hints: { { category: string, text: string } }, -- open experiences, up to ~5
}

-- Sample data for Studio playtests while the server doesn't push `foundation` yet
-- (never in a live server, where the row hides instead).
local PREVIEW_FOUNDATION: Foundation = {
	count = 2,
	target = 4,
	grade = "Steady",
	bonus = 0.04,
	hints = {
		{ category = "Hunt", text = "Slay a Stone Boar for the first time" },
		{ category = "Home", text = "Harvest a tier II herb" },
		{ category = "Boss", text = "The fast road: defeat the Elder Wolf King" },
	},
}

-- The one reader of the foundation snapshot (server Foundation.state, PlayerState
-- `foundation`; docs/systems/remotes.md). nil hides the row.
local function foundationOf(state: any): Foundation?
	local f = state and state.foundation
	if type(f) ~= "table" then
		return if RunService:IsStudio() then PREVIEW_FOUNDATION else nil
	end
	return {
		count = tonumber(f.count) or 0,
		target = tonumber(f.target) or 0,
		grade = if type(f.grade) == "string" then f.grade else "Cracked",
		bonus = tonumber(f.bonus) or 0,
		hints = if type(f.hints) == "table" then f.hints else {},
	}
end

-- Where the bar's grade marks sit: the shares of the target that reach Steady and
-- Solid (the grades between the lowest and the highest in Pacing.Foundation).
local function gradeShares(): { number }
	local grades = Pacing.Foundation.GRADES
	local shares = {}
	for i = 2, #grades - 1 do
		table.insert(shares, grades[i].share)
	end
	return shares
end

-- "FOUNDATION": the grade this stage would get now, experiences toward Deep on a
-- bar marked at Steady and Solid, the bonus so far, and what's still open.
local function renderFoundation()
	local row, name, right, effects = rowParts("Foundation")
	local f = foundationOf(State.current)
	row.Visible = f ~= nil
	if not f then
		return
	end
	name.Text = `<font color="{FOUNDATION_COLORS[f.grade] or "#ECE8DC"}">{f.grade}</font> foundation`
	right.Text = ""
	local bar = (row:FindFirstChild("Lines") :: Instance):FindFirstChild("Bar") :: Instance
	local trough = bar:FindFirstChild("Bar") :: Instance
	local fill = trough:FindFirstChild("Fill") :: Frame
	local share = if f.target > 0 then math.clamp(f.count / f.target, 0, 1) else 1
	Motion.ease(fill, { Size = UDim2.fromScale(share, 1) })
	fill.Visible = share > 0
	for i, at in gradeShares() do
		local mark = trough:FindFirstChild(`Mark{i}`) :: GuiObject?
		if mark then
			-- dark where the fill covers it, pale on the empty trough
			mark.Position = UDim2.fromScale(at, 0)
			mark.BackgroundColor3 = if at <= share then MARK_ON_FILL else MARK_ON_TROUGH
		end
	end
	(bar:FindFirstChild("Value") :: TextLabel).Text = `{math.floor(f.count)} / {math.floor(f.target)} experiences`
	local lines = {}
	local bonus = signed(f.bonus)
	if bonus and f.bonus > 0 then
		table.insert(lines, gain(`{bonus} max health and power from your foundations`))
	end
	if f.grade == "Deep" then
		table.insert(lines, gain("Deep: nothing more to gain at this stage"))
	else
		for _, hint in f.hints do
			table.insert(lines, `<font color="{GOLD}" size="11">{string.upper(hint.category)}</font>  {hint.text}`)
		end
	end
	effects.Text = table.concat(lines, "\n")
	effects.Visible = #lines > 0
end

local function renderRows(root: Roots.Root)
	renderRoot(root)
	renderDao()
	renderRealm()
	renderMethod()
	renderDantian()
	renderRace()
	renderBloodline()
	renderFoundation()
end

-- The list grows with its rows up to what fits on screen, then scrolls. The
-- canvas comes from the layout: AutomaticCanvasSize doesn't count rows that
-- size themselves. Sizes are in the card's own units (its pop scale divided out).
local function fitList()
	local layout = selfPage:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	local motion = window:FindFirstChild("Motion") :: UIScale?
	local scale = if motion and motion.Scale > 0 then motion.Scale else 1
	local content = layout.AbsoluteContentSize.Y / scale
	local chrome = window.AbsoluteSize.Y / scale - selfPage.Size.Y.Offset
	local room = math.max(120, hud.AbsoluteSize.Y - 2 * LIST_MARGIN - chrome)
	selfPage.Size = UDim2.new(1, 0, 0, math.min(content, room))
	selfPage.CanvasSize = UDim2.fromOffset(0, content)
end

local function render()
	local root = currentRoot()
	openButton.Visible = root ~= nil
	tile.Visible = root ~= nil
	if not root then
		newDot.Visible = false
		if window.Visible then
			Menus.close(window)
		end
		return
	end
	if window.Visible then
		renderRows(root)
	end
end

function SelfCard.open()
	if not currentRoot() then
		return
	end
	-- fill before showing so it never opens with stale text
	renderRows(currentRoot() :: Roots.Root)
	selfPage.CanvasPosition = Vector2.zero
	seenOnce = true
	newDot.Visible = false
	Menus.open(window)
end

function SelfCard.toggle()
	if window.Visible then
		Menus.close(window)
	else
		SelfCard.open()
	end
end

-- After the root reveal: the tile pops in and swells once, with the dot until
-- it's opened.
function SelfCard.announce()
	if seenOnce or not currentRoot() then
		return
	end
	openButton.Visible = true
	newDot.Visible = true
	local scale = tile:FindFirstChild("Motion") :: UIScale?
	tile.Visible = true
	if scale then
		scale.Scale = 0.8
		Motion.tween(scale, { Scale = 1 }).Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				Motion.tween(scale, { Scale = PULSE_SCALE }, PULSE)
			end
		end)
	end
end

function SelfCard.init(gui: ScreenGui)
	hud = gui
	window = gui:FindFirstChild("SelfCard") :: Frame
	selfPage = ((window:FindFirstChild("Body") :: Instance):FindFirstChild("Pages") :: Instance):FindFirstChild("Self") :: ScrollingFrame
	crest = gui:FindFirstChild("Crest", true) :: GuiObject
	openButton = crest:FindFirstChild("Open") :: GuiButton
	tile = (gui:FindFirstChild("Buttons") :: Instance):FindFirstChild("SelfButton") :: GuiButton
	newDot = tile:FindFirstChild("NewDot") :: GuiObject

	Menus.register(window)
	ListWindow.bindClose(window)

	-- the crest itself gives the press feedback (the button over it is invisible)
	local scale = crest:FindFirstChild("Motion") :: UIScale?
	openButton.MouseEnter:Connect(function()
		if scale then
			Motion.tween(scale, { Scale = 1.04 })
		end
	end)
	openButton.MouseLeave:Connect(function()
		if scale then
			Motion.tween(scale, { Scale = 1 })
		end
	end)
	openButton.Activated:Connect(function()
		Motion.tap(crest)
		SelfCard.toggle()
	end)
	-- the tile gets its press feedback from Motion.buttons, like the other tiles
	tile.Activated:Connect(SelfCard.toggle)

	local layout = selfPage:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitList)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitList)

	State.onChanged(function()
		render()
	end)
	for _, attr in { "Root", "RootGrade", "Realm", "Cultivation", "CultivationMax", "Weapon", "Method", "RawQi", "DantianCap", "Race", "RaceVariant", "Traits" } do
		player:GetAttributeChangedSignal(attr):Connect(render)
	end
	render()
end

return SelfCard
