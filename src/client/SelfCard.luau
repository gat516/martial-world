--!strict
-- The character window, opened by the Self tile in the top-right row
-- (Hud.Buttons.SelfButton) or, as a shortcut, by tapping the realm crest over the
-- vitals (Hud.Stack.Vitals.Crest.Open): who you are as a cultivator, and what
-- would solidify your next breakthrough (docs/character/character-window.md).
-- Inventory-sized (760x500 at most, centred; Menus moves it under Roblox's top bar
-- on short screens). Built by tools/build_self_card.luau; this fills it.
--   Desktop: three columns at once.
--     Self         the avatar (a live copy of your character in Avatar.View), your
--                  name, Race (race · variant, rarity), Bloodline ("None", muted;
--                  deferred), Strength (max health, power with the foundation bonus)
--     Cultivation  Realm (stage bar, % right, what's next), Foundation ("Foundation
--                  86%", percent only; bar marked at 50% and 100%, the next open
--                  experiences), Dantian (raw qi), Heart (heart-demon notes,
--                  once a trial is done)
--     Path         Spirit Root (grade, perk, Marrow Washing progress), Cultivation
--                  Method (from Foundation; hidden on Sect Breathing), Weapon Dao (a
--                  plain row per class trained, the one in hand first)
--   Phone (UiScale.isPhone): the same sections on three tabs, Self | Cultivation |
--     Path, each page in two columns; the title plaque is hidden.
-- Every section has one shape: Kind (gold capitals), Top (NameLabel, Right), an
-- optional Bar, Summary (a few lines at a glance) and Detail (the exact numbers,
-- hidden). Tapping a section with detail ("+" by its Kind) expands it in place; so
-- does tapping a Dao row. Effects are gains in jade and losses in a muted red, the
-- numbers from the shared defs. No flavour text, no technique or weapon names.
-- The tile shows (and the crest is tappable) only once the root is tested. After
-- the reveal the tile pops in, swells once and wears a small seal dot until the
-- window is first opened (not saved).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Methods = require(ReplicatedStorage.Shared.Methods)
local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Rarities = require(ReplicatedStorage.Shared.CharacterCreator.Rarities)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Registry = require(ReplicatedStorage.Shared.Identity.Registry)
local Roots = require(ReplicatedStorage.Shared.Roots)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local ListWindow = require(script.Parent.ListWindow)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Nameplates = require(script.Parent.Nameplates)
local SlotArt = require(script.Parent.SlotArt)
local State = require(script.Parent.State)
local UiScale = require(script.Parent.UiScale)

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
local MUTED = Color3.fromRGB(140, 136, 126) -- an empty section ("None")
local NAME_COLOR = Color3.fromRGB(236, 232, 220)
local DAO_EQUIPPED = Color3.fromRGB(255, 226, 160) -- the class in hand (as the Inventory)
local MARK_ON_FILL = Color3.fromRGB(14, 18, 20) -- the foundation bar's 50% and 100% marks
local MARK_ON_TROUGH = Color3.fromRGB(236, 232, 220)
local HOVER = 0.94 -- a section's background on hover (1 = none)
local TAB_ON = { image = "rbxassetid://89951515494594", text = Color3.fromRGB(255, 244, 214) }
local TAB_OFF = { image = "rbxassetid://70679462267599", text = Color3.fromRGB(170, 190, 184) }
local PAGES = { "Self", "Cultivation", "Path" }
local AVATAR_FOV = 30
local AVATAR_YAW = math.rad(-14) -- a slight three-quarter turn, like the creator's preview

-- Major names for "Reaches: ..." by stage-key prefix (Pacing.Curve keys).
local MAJOR_SHORT: { [string]: string } = {
	QC = "Qi Condensation",
	QR = "Qi Refining",
	FE = "Foundation",
	CF = "Core Formation",
	NS = "Nascent Soul",
}
-- heart-demon trials are keyed by major (Pacing.Curve `major`)
local MAJOR_NAMES: { [string]: string } = {
	QiCondensation = "Qi Condensation",
	QiRefining = "Qi Refining",
	Foundation = "Foundation Establishment",
}

local SelfCard = {}

local window: Frame
local crest: GuiObject
local openButton: GuiButton -- over the crest
local tile: GuiButton -- Buttons.SelfButton
local newDot: GuiObject -- on the tile
local body: GuiObject -- the layout in use: window.Desktop or window.Phone
local seenOnce = false
local page = "Self" -- the phone tab shown

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
	return if g then g.color else Roots.GradeColors[grade] or Color3.new(1, 1, 1)
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

-- One perk's exact amount at this root's grade, as one line.
local function perkLine(root: Roots.Root, kind: Roots.Perk): string
	local amount = Roots.perk(root, kind)
	if kind == "technique" then
		return `+{percent(amount)} technique damage`
	elseif kind == "regen" then
		return `Heal {percent(amount)} of your health each second out of combat`
	elseif kind == "growth" then
		return `Herbs grow +{percent(amount)} faster while you're online`
	elseif kind == "strike" then
		return `+{percent(amount)} weapon strike damage`
	elseif kind == "health" then
		return `+{percent(amount)} max health`
	elseif kind == "walk" then
		return `+{math.floor(amount * 10 + 0.5) / 10} run speed`
	elseif kind == "jump" then
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
	local lines = {}
	for _, p in Roots.perks(def.id) do
		table.insert(lines, perkLine(root, p.kind))
	end
	table.insert(lines, `+{percent(Pacing.Roots.MATCH)} {def.name} technique damage`)
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


local function paintSeal(seal: Instance, element: string)
	local icon = seal:FindFirstChild("Icon") :: ImageLabel
	icon.Image = SelfCard.rootIcon(element)
	icon.Visible = icon.Image ~= "";
	(seal:FindFirstChild("Glyph") :: TextLabel).Visible = icon.Image == ""
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

export type Foundation = {
	percent: number, -- the stage's foundation as a percentage of its target; may pass 100 (up to max)
	max: number, -- the most a stage can hold (Pacing.Foundation.MAX_PERCENT)
	bonus: number, -- every graded stage's bonus summed, as a share of health and power
	hints: { { category: string, text: string } }, -- open experiences, up to ~5
}

-- Sample data for Studio playtests while the server doesn't push `foundation` yet
-- (never in a live server, where the row hides instead).
local PREVIEW_FOUNDATION: Foundation = {
	percent = 86,
	max = 150,
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
	if f.hidden then
		return nil -- a hook stage (QC1-3) has no foundation yet
	end
	return {
		percent = tonumber(f.percent) or 0,
		max = tonumber(f.max) or 150,
		bonus = tonumber(f.bonus) or 0,
		hints = if type(f.hints) == "table" then f.hints else {},
	}
end

-- The foundation bar spans 0-150 %: the fill runs to the 100 % mark, then on in a
-- brighter tone (Over) past it; the marks sit at 50 % (below it the stage is
-- unsteady) and 100 % (full). Past 150 % the bar stays full and the label keeps
-- counting up to the stage's max.
local FOUNDATION_SPAN = 150
local FOUNDATION_FULL = 100
local FOUNDATION_MARKS = { 50, 100 }

local function sectionOf(name: string): GuiButton
	return body:FindFirstChild(name, true) :: GuiButton
end

local function number(n: number): string
	local s = tostring(math.floor(n))
	local formatted = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	return (string.gsub(formatted, "^,", ""))
end

-- The name takes what the right-hand label leaves.
local function fitTop(top: Instance)
	local name = top:FindFirstChild("NameLabel") :: TextLabel
	local right = top:FindFirstChild("Right") :: TextLabel
	local width = 0
	if right.Text ~= "" then
		width = TextService:GetTextSize(right.Text, right.TextSize, Enum.Font.BuilderSansBold, Vector2.new(1000, 100)).X + 8
	end
	name.Size = UDim2.new(1, -width, 1, 0)
end

local function setLines(label: TextLabel, lines: { string }?)
	local text = if lines then table.concat(lines, "\n") else ""
	label.Text = text
	return text ~= ""
end

-- Fill one section; a section whose detail went away folds back up.
local function fill(name: string, f: Fill)
	local section = sectionOf(name)
	local top = section:FindFirstChild("Top") :: Instance
	local nameLabel = top:FindFirstChild("NameLabel") :: TextLabel
	local right = top:FindFirstChild("Right") :: TextLabel
	nameLabel.Text = f.name
	nameLabel.TextColor3 = f.nameColor or NAME_COLOR
	right.Text = f.right or ""
	right.TextColor3 = f.rightColor or NAME_COLOR
	fitTop(top)
	local bar = section:FindFirstChild("Bar")
	if bar and f.share then
		local fillFrame = (bar:FindFirstChild("Trough") :: Instance):FindFirstChild("Fill") :: Frame
		Motion.ease(fillFrame, { Size = UDim2.fromScale(math.clamp(f.share, 0, 1), 1) })
		fillFrame.Visible = f.share > 0
	end
	local summary = section:FindFirstChild("Summary") :: TextLabel
	summary.Visible = setLines(summary, f.summary)
	local detail = section:FindFirstChild("Detail") :: TextLabel
	local hasDetail = setLines(detail, f.detail)
	local more = (section:FindFirstChild("Kind") :: Instance):FindFirstChild("More") :: TextLabel
	more.Visible = hasDetail
	section.Active = hasDetail
	if not hasDetail then
		detail.Visible = false
	end
	more.Text = if detail.Visible then "–" else "+"
end

-- Self ----------------------------------------------------------------------------

-- "RACE": the race and its variant ("Beast Folk · Wolf"), the rarity on the right,
-- the modifiers in the detail.
local function renderRace()
	local section = sectionOf("Race")
	local raceId = player:GetAttribute("Race")
	local race = Registry.race(raceId)
	section.Visible = race ~= nil
	if not race then
		return
	end
	local variantId = player:GetAttribute("RaceVariant")
	variantId = if type(variantId) == "string" then variantId else ""
	local variant = Registry.variant(raceId, variantId)
	local rarity = Rarities[(variant and variant.Rarity) or race.Rarity]
	local lines = raceEffects(raceId, variantId)
	fill("Race", {
		name = if variant then `{race.DisplayName} · {variant.DisplayName}` else race.DisplayName,
		right = if rarity then rarity.DisplayName else "",
		-- the rarity hue, lifted so it reads on the dark card at phone size
		rightColor = if rarity then rarity.Color:Lerp(Color3.new(1, 1, 1), 0.35) else nil,
		detail = if #lines > 0 then lines else { "No traits that change your strength" },
	})
end

-- "BLOODLINE": not built yet (docs/character/bloodline.md), so always "None",
-- muted. When it lands, read data.bloodline.id here and fill it like Race.
local function renderBloodline()
	fill("Bloodline", { name = "None", nameColor = MUTED })
end

-- The stage the Realm attribute names (Realms.Stages), for its power.
local function currentStage(): Realms.Stage?
	local name = player:GetAttribute("Realm")
	for _, stage in Realms.Stages do
		if stage.name == name then
			return stage
		end
	end
	return nil
end

-- "STRENGTH": max health and power (the realm's, times the foundation bonus, as
-- the server's Combat.power; a qi surge's boost isn't counted).
local function renderStats()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local stage = currentStage()
	local f = foundationOf(State.current)
	local bonus = if f then f.bonus else 0
	local base = if stage then stage.power else 1
	local power = base * (1 + bonus)
	local health = if humanoid then humanoid.MaxHealth elseif stage then stage.health * (1 + bonus) else 0
	local detail = { `Max health {number(health)}`, `Power x{string.format("%.2f", base)} from your realm` }
	local share = signed(bonus)
	if share and bonus > 0 then
		table.insert(detail, gain(`{share} max health and power from your foundations`))
	end
	fill("Stats", {
		name = `{number(health)} health`,
		right = `Power x{string.format("%.2f", power)}`,
		detail = detail,
	})
end

-- The avatar: a still copy of your character in the well's ViewportFrame,
-- turned a little toward three-quarters and lit from the upper left. Rebuilt on
-- each open (and when the character respawns while it's open).
local function renderAvatar()
	local view = body:FindFirstChild("View", true) :: ViewportFrame?
	if not view then
		return
	end
	local world = view:FindFirstChildOfClass("WorldModel")
	if not world then
		world = Instance.new("WorldModel")
		world.Parent = view
	end
	local camera = view:FindFirstChildOfClass("Camera")
	if not camera then
		-- built here: a Camera inside a ViewportFrame doesn't survive the Rojo sync
		camera = Instance.new("Camera")
		camera.FieldOfView = AVATAR_FOV
		camera.Parent = view
	end
	view.CurrentCamera = camera
	world:ClearAllChildren()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not rootPart then
		return
	end
	local archivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = archivable
	if not copy then
		return
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ForceField") or d:IsA("LayerCollector") or d:IsA("ParticleEmitter") or d:IsA("Tool") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	copy:PivotTo(CFrame.new()) -- upright at the origin, facing -Z
	copy.Parent = world
	local cf, size = copy:GetBoundingBox()
	local height = size.Y * 1.12
	local distance = (height / 2) / math.tan(math.rad(AVATAR_FOV / 2))
	local facing = CFrame.Angles(0, AVATAR_YAW, 0) * Vector3.new(0, 0, -1)
	camera.CFrame = CFrame.lookAt(cf.Position + facing * distance, cf.Position)
end

local function renderSelf()
	(body:FindFirstChild("PlayerName", true) :: TextLabel).Text = Nameplates.nameOf(player)
	renderRace()
	renderBloodline()
	renderStats()
end

-- Cultivation -----------------------------------------------------------------------

-- "REALM": the stage, its bar (share on the right), and what's next; the exact
-- cultivation in the detail.
local function renderRealm()
	local value = tonumber(player:GetAttribute("Cultivation")) or 0
	local max = tonumber(player:GetAttribute("CultivationMax")) or 0
	local share = if max > 0 then math.clamp(value / max, 0, 1) else 0
	local stage = currentStage()
	local nextStage = nil
	if stage then
		local i = table.find(Realms.Stages, stage)
		nextStage = if i then Realms.Stages[i + 1] else nil
	end
	local summary = {}
	if player:GetAttribute("BreakthroughReady") == true then
		table.insert(summary, gain("Ready to break through"))
	elseif nextStage then
		table.insert(summary, `Next: {nextStage.name}`)
	end
	fill("Realm", {
		name = player:GetAttribute("Realm") or "",
		nameColor = Color3.fromRGB(226, 186, 104),
		right = `{math.floor(share * 100)}%`,
		share = share,
		summary = summary,
		detail = { if max > 0 then `{number(value)} / {number(max)} cultivation` else `{number(value)} cultivation` },
	})
end

-- "FOUNDATION": the percent this stage would get now ("Foundation 86%", never a
-- grade word or count; owner, 2026-10-24) on a bar marked at 50% and 100%, the next
-- two open experiences; the rest and the bonus so far in the detail.
local function hintLine(hint: { category: string, text: string }): string
	local size = if UiScale.isPhone() then 12 else 11
	return `<font color="{GOLD}" size="{size}">{string.upper(hint.category)}</font>  {hint.text}`
end

local function renderFoundation()
	local section = sectionOf("Foundation")
	local f = foundationOf(State.current)
	section.Visible = f ~= nil
	if not f then
		return
	end
	local percent = math.max(0, f.percent)
	local trough = (section:FindFirstChild("Bar") :: Instance):FindFirstChild("Trough") :: Instance
	local full = FOUNDATION_FULL / FOUNDATION_SPAN
	local over = trough:FindFirstChild("Over") :: Frame
	local past = math.clamp((percent - FOUNDATION_FULL) / FOUNDATION_SPAN, 0, 1 - full)
	over.Position = UDim2.fromScale(full, 0)
	Motion.ease(over, { Size = UDim2.fromScale(past, 1) })
	over.Visible = past > 0
	local share = math.clamp(percent / FOUNDATION_SPAN, 0, 1)
	for i, at in FOUNDATION_MARKS do
		local mark = trough:FindFirstChild(`Mark{i}`) :: GuiObject?
		if mark then
			-- dark where the fill covers it, pale on the empty trough
			local x = at / FOUNDATION_SPAN
			mark.Position = UDim2.fromScale(x, 0)
			mark.BackgroundColor3 = if x <= share then MARK_ON_FILL else MARK_ON_TROUGH
		end
	end
	local summary, detail = {}, {}
	local capped = percent >= f.max
	if capped then
		table.insert(summary, gain(`{f.max}%: the most this stage can hold`))
	end
	for i, hint in f.hints do
		table.insert(if i <= 2 and not capped then summary else detail, hintLine(hint))
	end
	local bonus = signed(f.bonus)
	if bonus and f.bonus > 0 then
		table.insert(detail, gain(`{bonus} max health and power from your foundations`))
	end
	fill("Foundation", {
		name = `Foundation {math.floor(percent + 0.5)}%`,
		share = math.min(percent, FOUNDATION_FULL) / FOUNDATION_SPAN,
		summary = summary,
		detail = detail,
	})
end

-- "DANTIAN": raw qi (refined into cultivation by Circulate), live while open.
local function renderDantian()
	local raw = tonumber(player:GetAttribute("RawQi")) or 0
	local room = tonumber(player:GetAttribute("DantianCap")) or 0
	fill("Dantian", {
		name = "Raw qi",
		right = if room > 0 then `{number(raw)} / {number(room)}` else number(raw),
		share = if room > 0 then raw / room else 0,
		detail = { "Circulate while meditating to refine raw qi into cultivation" },
	})
end

-- "HEART DEMON": once a trial is done, the latest heart note; every trial's note
-- in the detail (State.current.heartDemon.trials[major].note).
local function renderHeart()
	local section = sectionOf("Heart")
	local trials = State.current.heartDemon and State.current.heartDemon.trials
	local done = {}
	for major, trial in trials or {} do
		if type(trial) == "table" and type(trial.note) == "string" and trial.note ~= "" then
			table.insert(done, { major = major, trial = trial })
		end
	end
	section.Visible = #done > 0
	if #done == 0 then
		return
	end
	table.sort(done, function(a, b)
		return (tonumber(a.trial.at) or 0) > (tonumber(b.trial.at) or 0)
	end)
	local latest = done[1]
	local detail = {}
	if #done > 1 then
		for _, d in done do
			table.insert(detail, `{MAJOR_NAMES[d.major] or d.major}: {d.trial.note}`)
		end
	end
	if (tonumber(latest.trial.tempered) or 0) > 0 then
		table.insert(detail, gain(`Tempered {latest.trial.tempered} of your foundations`))
	end
	fill("Heart", {
		name = if latest.trial.calm then "Calmed" else "Still whispers",
		nameColor = if latest.trial.calm then Color3.fromRGB(130, 230, 185) else Color3.fromRGB(230, 154, 130),
		right = MAJOR_NAMES[latest.major] or "",
		rightColor = Color3.fromRGB(200, 196, 184),
		summary = { latest.trial.note },
		detail = detail,
	})
end

local function renderCultivation()
	renderRealm()
	renderFoundation()
	renderDantian()
	renderHeart()
end

-- Path -------------------------------------------------------------------------------

-- "SPIRIT ROOT": the perk at a glance, with the Marrow Washing progress once a pill
-- is in; the element bonus, speed and the washing count in the detail.
local function renderRoot(root: Roots.Root)
	local def = Roots.Elements[root.element]
	local effects = rootEffects(root)
	local mains = #Roots.perks(def.id) -- every perk at a glance (a rare root has two)
	local summary, detail = {}, {}
	for i, line in effects do
		table.insert(if i <= mains then summary else detail, gain(line))
	end
	local washed, need = Roots.washed(root)
	local nextGrade = Roots.nextGrade(root.grade)
	if need and nextGrade then
		local line = `Washed {washed} / {need} toward {nextGrade} grade`
		table.insert(if washed > 0 then summary else detail, line)
	end
	for _, pill in Pacing.Roots.FRAGMENTS.PILLS do
		local have, per = Roots.fragments(root, pill)
		if have > 0 then
			table.insert(detail, `{Roots.FragmentNames[pill]}s: {have} / {per}`)
		end
	end
	fill("Root", {
		name = `{def.name} Root`,
		nameColor = def.color,
		right = `{root.grade} grade`,
		rightColor = SelfCard.gradeColor(root.grade),
		summary = summary,
		detail = detail,
	})
end

-- "CULTIVATION METHOD" (from Foundation, once one is active): its cultivation
-- speed at a glance; the root match and how far it takes you in the detail.
local function renderMethod()
	local section = sectionOf("Method")
	local activeId = activeMethod()
	section.Visible = activeId ~= ""
	if activeId == "" then
		return
	end
	local def = Methods.active(activeId)
	local match = def.element ~= "" and def.element == rootElement()
	local speed = signed(Methods.speed(def, rootElement()) - 1)
	local line = "Normal cultivation speed"
	if speed then
		line = `{speed} cultivation speed`
		line = if string.sub(speed, 1, 1) == "+" then gain(line) else loss(line)
	end
	local detail = { limitText(def.reaches) }
	if match then
		table.insert(detail, 1, "Matches your root")
	end
	fill("Method", {
		name = def.name,
		nameColor = SelfCard.gradeColor(def.grade),
		right = `{def.grade} grade`,
		rightColor = SelfCard.gradeColor(def.grade),
		summary = { line },
		detail = detail,
	})
end

-- "WEAPON DAO": a plain row per class trained (any level or XP), the class in
-- hand first and always listed, then Weapons.ClassOrder. Tap a row for its XP and
-- the weapon damage now and at the next level.
local function renderDao()
	local section = sectionOf("Dao")
	local rows = section:FindFirstChild("Rows") :: Instance
	local template = rows:FindFirstChild("RowTemplate") :: GuiButton
	local id = SlotArt.equipped()
	local held = Weapons.classOf(if id == "" then nil else id)
	local dao = State.current.dao or {}
	local classes = { held }
	for _, classId in Weapons.ClassOrder do
		local d = dao[classId]
		if classId ~= held and d and (d.level > 0 or d.xp > 0) then
			table.insert(classes, classId)
		end
	end
	local keep: { [Instance]: boolean } = {}
	for i, classId in classes do
		local class = Weapons.Classes[classId]
		local d = dao[classId]
		local level = if d then d.level else 0
		local xp = if d then d.xp else 0
		local name = `Row_{classId}`
		local row = rows:FindFirstChild(name) :: GuiButton?
		if not row then
			local made = template:Clone()
			made.Name = name
			made.Visible = true
			made.Parent = rows
			made.Activated:Connect(function()
				local detail = made:FindFirstChild("Detail") :: TextLabel
				detail.Visible = not detail.Visible
			end)
			made.MouseEnter:Connect(function()
				Motion.tween(made, { BackgroundTransparency = HOVER })
			end)
			made.MouseLeave:Connect(function()
				Motion.tween(made, { BackgroundTransparency = 1 })
			end)
			row = made
		end
		local r = row :: GuiButton
		keep[r] = true
		r.LayoutOrder = i
		local top = r:FindFirstChild("Top") :: Instance
		local icon = top:FindFirstChild("Icon") :: ImageLabel
		-- the class glyph in its colour, as the Inventory's Dao sections
		SlotArt.setIcon(icon, SlotArt.classGlyph(classId))
		icon.ImageColor3 = SlotArt.classColor(classId)
		local nameLabel = top:FindFirstChild("NameLabel") :: TextLabel
		nameLabel.Text = if class then class.dao else `{classId} Dao`
		nameLabel.TextColor3 = if classId == held then DAO_EQUIPPED else NAME_COLOR;
		local progress = if level >= Weapons.MAX_LEVEL then 1 else math.clamp(xp / Weapons.xpToNext(level), 0, 1);
		(top:FindFirstChild("Right") :: TextLabel).Text = if level >= Weapons.MAX_LEVEL
			then `Lv {level}`
			else `Lv {level} · {math.floor(progress * 100)}%`
		local rightLabel = top:FindFirstChild("Right") :: TextLabel
		local rightWidth = TextService:GetTextSize(rightLabel.Text, rightLabel.TextSize, Enum.Font.BuilderSansBold, Vector2.new(1000, 100)).X + 8
		nameLabel.Size = UDim2.new(1, -24 - rightWidth, 1, 0) -- past the glyph, short of the level
		local fillFrame = ((r:FindFirstChild("Bar") :: Instance):FindFirstChild("Trough") :: Instance):FindFirstChild("Fill") :: Frame
		local lines = {}
		if level >= Weapons.MAX_LEVEL then
			fillFrame.Size = UDim2.fromScale(1, 1)
			fillFrame.Visible = true
			table.insert(lines, "Mastered")
			table.insert(lines, daoDamage(level))
		else
			local need = Weapons.xpToNext(level)
			Motion.ease(fillFrame, { Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1) })
			fillFrame.Visible = xp > 0
			table.insert(lines, `{math.floor(xp)} / {need} Dao XP`)
			table.insert(lines, daoDamage(level))
			table.insert(lines, `Next level: {daoDamage(level + 1)}`)
		end
		(r:FindFirstChild("Detail") :: TextLabel).Text = table.concat(lines, "\n")
	end
	for _, child in rows:GetChildren() do
		if child:IsA("GuiButton") and child ~= template and not keep[child] then
			child:Destroy()
		end
	end
end

local function renderPath(root: Roots.Root)
	renderRoot(root)
	renderMethod()
	renderDao()
end

local function renderAll(root: Roots.Root)
	renderSelf()
	renderCultivation()
	renderPath(root)
end

-- Layout -------------------------------------------------------------------------------

-- Phone tabs: one page at a time, the chosen tab in gold.
local function showPage(name: string)
	page = name
	local phone = window:FindFirstChild("Phone") :: Instance
	local pages = phone:FindFirstChild("Pages") :: Instance
	local tabs = phone:FindFirstChild("Tabs") :: Instance
	for _, id in PAGES do
		(pages:FindFirstChild(id) :: GuiObject).Visible = id == name
		local tab = tabs:FindFirstChild(id .. "Tab") :: ImageButton
		local style = if id == name then TAB_ON else TAB_OFF
		tab.Image = style.image;
		(tab:FindFirstChild("Label") :: TextLabel).TextColor3 = style.text
	end
end

-- The layout for this session's screen (decided once by UiScale.isPhone).
local function chooseLayout()
	local phone = UiScale.isPhone()
	local desktop = window:FindFirstChild("Desktop") :: GuiObject
	local phoneRoot = window:FindFirstChild("Phone") :: GuiObject
	desktop.Visible = not phone
	phoneRoot.Visible = phone;
	(window:FindFirstChild("TitlePlaque") :: GuiObject).Visible = not phone
	body = if phone then phoneRoot else desktop
	if phone then
		showPage(page)
	end
end

-- Tap to expand: every section with detail, in both layouts.
local function bindSections(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") and d:FindFirstChild("Kind") and d:FindFirstChild("Detail") then
			local section = d
			section.Activated:Connect(function()
				if not section.Active then
					return
				end
				local detail = section:FindFirstChild("Detail") :: TextLabel
				detail.Visible = not detail.Visible;
				((section:FindFirstChild("Kind") :: Instance):FindFirstChild("More") :: TextLabel).Text = if detail.Visible then "–" else "+"
			end)
			section.MouseEnter:Connect(function()
				if section.Active then
					Motion.tween(section, { BackgroundTransparency = HOVER })
				end
			end)
			section.MouseLeave:Connect(function()
				Motion.tween(section, { BackgroundTransparency = 1 })
			end)
		end
	end
end

-- Open fresh: details folded, every list at its top.
local function foldAll()
	for _, d in body:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == "Detail" then
			d.Visible = false
		elseif d:IsA("TextLabel") and d.Name == "More" then
			d.Text = "+"
		elseif d:IsA("ScrollingFrame") then
			d.CanvasPosition = Vector2.zero
		end
	end
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
		renderAll(root)
	end
end

function SelfCard.open()
	local root = currentRoot()
	if not root then
		return
	end
	chooseLayout()
	foldAll()
	-- fill before showing so it never opens with stale text
	renderAll(root)
	renderAvatar()
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
	window = gui:FindFirstChild("SelfCard") :: Frame
	body = window:FindFirstChild("Desktop") :: GuiObject
	crest = gui:FindFirstChild("Crest", true) :: GuiObject
	openButton = crest:FindFirstChild("Open") :: GuiButton
	tile = (gui:FindFirstChild("Buttons") :: Instance):FindFirstChild("SelfButton") :: GuiButton
	newDot = tile:FindFirstChild("NewDot") :: GuiObject

	Menus.register(window)
	ListWindow.bindClose(window)
	bindSections(window)
	local tabs = (window:FindFirstChild("Phone") :: Instance):FindFirstChild("Tabs") :: Instance
	for _, id in PAGES do
		(tabs:FindFirstChild(id .. "Tab") :: GuiButton).Activated:Connect(function()
			showPage(id)
		end)
	end

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

	State.onChanged(function()
		render()
	end)
	for _, attr in { "Root", "RootGrade", "Realm", "Cultivation", "CultivationMax", "BreakthroughReady", "Weapon", "Method", "RawQi", "DantianCap", "Race", "RaceVariant", "Traits", "Surname", "FirstName" } do
		player:GetAttributeChangedSignal(attr):Connect(render)
	end
	player.CharacterAppearanceLoaded:Connect(function()
		if window.Visible then
			renderAvatar()
			render()
		end
	end)
	render()
end

return SelfCard
