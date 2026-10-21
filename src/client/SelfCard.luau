--!strict
-- The character window, opened by tapping the realm crest over the vitals
-- (Hud.Stack.Vitals.Crest.Open). It grows with the player
-- (docs/systems/character.md, "Character window"); this is the first stage:
-- one card, Self, with no tabs.
--   Header: realm name and its stage bar (cultivation toward the next stage).
--   Self page (Body.Pages.Self, a vertical list by LayoutOrder):
--     10  Root: element seal, "<Element> Root", grade in its colour, the one-line
--         perk. Tapping it shows RootDetail (11), the exact numbers.
--     12-19 free for root actions (a Reroll button, a stored-roots strip).
--     20  free for the cultivation method row (FE).
--     30  Weapon: the equipped weapon's badge, name in its grade colour and its
--         class's Dao level (weapons themselves live in the Inventory).
--   Future tabs (Self | Body) go in Body at LayoutOrder 3, between the stage bar
--   and Pages; each tab is a page frame inside Pages.
-- The crest is only tappable once the root is tested. After the reveal it pulses
-- once and wears a small seal dot until the window is first opened (not saved).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Roots = require(ReplicatedStorage.Shared.Roots)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
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

local SelfCard = {}

local window: Frame
local crest: GuiObject
local openButton: GuiButton
local newDot: GuiObject
local selfPage: Frame
local seenOnce = false

function SelfCard.rootIcon(element: string): string
	return ROOT_ICONS[element] or ""
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
		return { element = element, grade = if type(grade) == "string" then grade else Pacing.Roots.STARTING_GRADE }
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

local function matchingTechniques(element: string): { string }
	local names = {}
	for _, id in Techniques.Order do
		local def = Techniques.Defs[id] :: any
		if def and def.element == element then
			table.insert(names, def.name)
		end
	end
	return names
end

local function detailText(root: Roots.Root): string
	local def = Roots.Elements[root.element]
	local lines = { perkLine(root) }
	local names = matchingTechniques(def.id)
	local match = `+{percent(Pacing.Roots.MATCH)}`
	table.insert(lines, if #names > 0 then `{def.name} techniques {match} damage: {table.concat(names, ", ")}` else `{def.name} techniques {match} damage`)
	local speed = string.format("%.2f", Roots.speed(root)):gsub("0+$", ""):gsub("%.$", "")
	table.insert(lines, `Cultivation speed x{speed}`)
	return table.concat(lines, "\n")
end

local function renderRoot(root: Roots.Root)
	local def = Roots.Elements[root.element]
	local row = selfPage:FindFirstChild("Root") :: GuiObject
	local seal = row:FindFirstChild("Seal") :: GuiObject;
	(seal:FindFirstChild("Icon") :: ImageLabel).Image = SelfCard.rootIcon(def.id)
	local name = row:FindFirstChild("NameLabel") :: TextLabel
	name.Text = `{def.name} Root`
	name.TextColor3 = def.color
	local grade = row:FindFirstChild("Grade") :: TextLabel
	grade.Text = `{root.grade} grade`
	grade.TextColor3 = SelfCard.gradeColor(root.grade);
	(row:FindFirstChild("Blurb") :: TextLabel).Text = def.blurb;
	(selfPage:FindFirstChild("RootDetail") :: TextLabel).Text = detailText(root)
end

local function renderWeapon()
	local row = selfPage:FindFirstChild("Weapon") :: GuiObject
	local id = SlotArt.equipped()
	local weaponId = if id == "" then Weapons.FIST else id
	local badge = row:FindFirstChild("Badge") :: GuiObject;
	(badge:FindFirstChild("Icon") :: ImageLabel).Image = SlotArt.weaponIcon(weaponId)
	local name = row:FindFirstChild("NameLabel") :: TextLabel
	name.Text = SlotArt.weaponName(weaponId)
	name.TextColor3 = SlotArt.weaponColor(weaponId)
	local classId = Weapons.classOf(if id == "" then nil else id)
	local class = Weapons.Classes[classId]
	local dao = State.current.dao and State.current.dao[classId]
	local level = if dao then dao.level else 0;
	(row:FindFirstChild("Dao") :: TextLabel).Text = if class then `{class.name} Dao {level}` else ""
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

local function render()
	local root = currentRoot()
	openButton.Visible = root ~= nil
	if not root then
		newDot.Visible = false
		if window.Visible then
			Menus.close(window)
		end
		return
	end
	if window.Visible then
		renderRoot(root)
		renderWeapon()
		renderRealm()
	end
end

function SelfCard.open()
	if not currentRoot() then
		return
	end
	-- fill before showing so it never opens with stale text
	local root = currentRoot() :: Roots.Root
	renderRoot(root)
	renderWeapon()
	renderRealm();
	(selfPage:FindFirstChild("RootDetail") :: GuiObject).Visible = false;
	((selfPage:FindFirstChild("Root") :: Instance):FindFirstChild("More") :: TextLabel).Text = "+"
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

-- After the root reveal: one swell of the crest, and the dot until it's opened.
function SelfCard.announce()
	if seenOnce or not currentRoot() then
		return
	end
	openButton.Visible = true
	newDot.Visible = true
	local scale = crest:FindFirstChild("Motion") :: UIScale?
	if scale then
		scale.Scale = 1
		Motion.tween(scale, { Scale = PULSE_SCALE }, PULSE)
	end
end

function SelfCard.init(gui: ScreenGui)
	window = gui:FindFirstChild("SelfCard") :: Frame
	selfPage = ((window:FindFirstChild("Body") :: Instance):FindFirstChild("Pages") :: Instance):FindFirstChild("Self") :: Frame
	crest = gui:FindFirstChild("Crest", true) :: GuiObject
	openButton = crest:FindFirstChild("Open") :: GuiButton
	newDot = crest:FindFirstChild("NewDot") :: GuiObject

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

	local rootRow = selfPage:FindFirstChild("Root") :: GuiButton
	local detail = selfPage:FindFirstChild("RootDetail") :: GuiObject
	local more = rootRow:FindFirstChild("More") :: TextLabel
	rootRow.Activated:Connect(function()
		detail.Visible = not detail.Visible
		more.Text = if detail.Visible then "-" else "+"
	end)

	State.onChanged(function()
		render()
	end)
	for _, attr in { "Root", "RootGrade", "Realm", "Cultivation", "CultivationMax", "Weapon" } do
		player:GetAttributeChangedSignal(attr):Connect(render)
	end
	render()
end

return SelfCard
