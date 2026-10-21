--!strict
-- What the player just gained, in StarterGui.Rewards.
--   Feed: a compact entry per thing gained (Spirit Stones, items, insight,
--   manuals, weapons). Gaining the same thing again while its entry is up adds to it and
--   pops the count ("Spirit Stones x23" -> "x24"), so fast farming reads as one
--   climbing number. Entries fade a few seconds after their last gain; the oldest
--   go first when the feed is full.
--   Victory card: a boss kill opens a centre card ("Victory", "<boss> defeated")
--   and every reward arriving in the next moment lands on it as a tile, as well
--   as in the feed. Click or tap closes it (after a short beat), or it closes by
--   itself.
-- Fed by the server's Effect events: "stones", "loot", "insight", "manual",
-- "weapon", "boss".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Items = require(ReplicatedStorage.Shared.Items)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)
local SlotArt = require(script.Parent.SlotArt)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local STONE_ICON = "rbxassetid://112328127073930"
local INSIGHT_ICON = "rbxassetid://92675446701433"
local GOLD = Color3.fromRGB(214, 172, 92)
local STONE_COLOR = Color3.fromRGB(200, 235, 255)

local ENTRY_LIFE = 3.5 -- seconds an entry stays after its last gain
local ENTRY_STEP = 36 -- entry height plus padding, for the visible cap
local CARD_COLLECT = 1.5 -- seconds after a boss kill that rewards join the card
local CARD_MIN = 1.0 -- seconds before a click can close the card
local CARD_LIFE = 7 -- it closes by itself after this
local RAY_SPEED = 12 -- degrees per second

type Look = { name: string, icon: string?, glyph: string?, color: Color3 }
type Entry = { frame: GuiObject, count: number, last: number }

local Rewards = {}

local feed: Frame
local entryTemplate: GuiObject
local card: Frame
local list: Frame
local rewardTemplate: GuiObject
local entries: { [string]: Entry } = {}
local order = 0

local tiles: { [string]: { frame: GuiObject, count: number } } = {}
local cardOpenedAt = 0
local collectUntil = 0
local rayConn: RBXScriptConnection? = nil

local function lookOf(key: string): Look?
	if key == "stones" then
		return { name = "Spirit Stones", icon = STONE_ICON, color = STONE_COLOR }
	elseif key == "insight" then
		return { name = "Insight", icon = INSIGHT_ICON, color = GOLD }
	elseif key == "qi" then
		return { name = "Raw Qi", glyph = "氣", color = Color3.fromRGB(120, 235, 180) }
	elseif key:sub(1, 7) == "manual:" then
		local def = Techniques.Defs[key:sub(8)]
		return def and { name = `{def.name} manual`, glyph = "卷", color = GOLD }
	elseif key:sub(1, 7) == "weapon:" then
		local id = key:sub(8)
		return Weapons.Defs[id] and { name = SlotArt.weaponName(id), icon = SlotArt.weaponIcon(id), color = SlotArt.weaponColor(id) }
	end
	local item = Items.Defs[key]
	return item and { name = item.name, icon = item.icon, glyph = item.glyph, color = Items.rarityColor(item) }
end

-- Icon or glyph, name and count on a template clone (feed entry or card tile).
local function paint(frame: GuiObject, look: Look, count: number)
	local icon = frame:FindFirstChild("Icon") :: ImageLabel
	local glyph = frame:FindFirstChild("Glyph") :: TextLabel
	icon.Image = look.icon or ""
	icon.Visible = look.icon ~= nil
	glyph.Text = look.glyph or ""
	glyph.TextColor3 = look.color
	glyph.Visible = look.icon == nil;
	(frame:FindFirstChild("NameLabel") :: TextLabel).Text = look.name;
	(frame:FindFirstChild("CountLabel") :: TextLabel).Text = `x{count}`
end

local function pop(frame: GuiObject)
	local scale = frame:FindFirstChild("Motion") :: UIScale?
	if scale then
		scale.Scale = 1.18
		Motion.tween(scale, { Scale = 1 }, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
	end
end

-- Fade a feed entry and everything drawn on it, then remove it.
local function fadeOut(frame: GuiObject)
	local info = TweenInfo.new(0.35)
	for _, obj in { frame, table.unpack(frame:GetDescendants()) } do
		if obj:IsA("ImageLabel") then
			Motion.tween(obj, { ImageTransparency = 1 }, info)
		elseif obj:IsA("TextLabel") then
			Motion.tween(obj, { TextTransparency = 1, TextStrokeTransparency = 1 }, info)
		end
	end
	task.delay(0.4, function()
		frame:Destroy()
	end)
end

local function capacity(): number
	return math.max(1, math.floor((feed.AbsoluteSize.Y + 4) / ENTRY_STEP))
end

local function dropOldest()
	local oldestKey, oldest = nil, math.huge
	for key, e in entries do
		if e.last < oldest then
			oldestKey, oldest = key, e.last
		end
	end
	if oldestKey then
		fadeOut(entries[oldestKey].frame)
		entries[oldestKey] = nil
	end
end

local function feedGain(key: string, amount: number)
	local look = lookOf(key)
	if not look then
		return
	end
	local now = os.clock()
	local e = entries[key]
	if e then
		e.count += amount
		e.last = now
		paint(e.frame, look, e.count)
		pop(e.frame)
		return
	end
	local count = 0
	for _ in entries do
		count += 1
	end
	if count >= capacity() then
		dropOldest()
	end
	order += 1
	local frame = entryTemplate:Clone()
	frame.Name = "Entry"
	frame.LayoutOrder = order
	paint(frame, look, amount)
	local accent = frame:FindFirstChild("Accent") :: ImageLabel?
	if accent then
		accent.ImageColor3 = look.color
	end
	frame.Visible = true
	frame.Parent = feed
	pop(frame)
	entries[key] = { frame = frame, count = amount, last = now }
end

-- Victory card ---------------------------------------------------------------------

local function closeCard()
	if not card.Visible then
		return
	end
	Motion.close(card)
	if rayConn then
		rayConn:Disconnect()
		rayConn = nil
	end
end

local function cardGain(key: string, amount: number)
	if os.clock() > collectUntil then
		return
	end
	local look = lookOf(key)
	if not look then
		return
	end
	local tile = tiles[key]
	if tile then
		tile.count += amount
		paint(tile.frame, look, tile.count)
		pop(tile.frame)
		return
	end
	local frame = rewardTemplate:Clone()
	frame.Name = "Reward"
	order += 1
	frame.LayoutOrder = order
	paint(frame, look, amount)
	frame.Visible = true
	frame.Parent = list
	pop(frame)
	tiles[key] = { frame = frame, count = amount }
end

local function openCard(bossName: string, qi: number)
	for _, t in tiles do
		t.frame:Destroy()
	end
	table.clear(tiles);
	(card:FindFirstChild("Title") :: TextLabel).Text = "Victory";
	(card:FindFirstChild("Subtitle") :: TextLabel).Text = `{bossName} defeated`;
	(card:FindFirstChild("Hint") :: TextLabel).Text = if Platform.isTouch() then "Tap to continue" else "Click to continue"
	cardOpenedAt = os.clock()
	collectUntil = cardOpenedAt + CARD_COLLECT
	Menus.open(card)
	if qi > 0 then
		cardGain("qi", qi)
	end
	local rays = card:FindFirstChild("Rays") :: ImageLabel
	if not rayConn then
		rayConn = RunService.RenderStepped:Connect(function(dt)
			rays.Rotation = (rays.Rotation + RAY_SPEED * dt) % 360
		end)
	end
	local opened = cardOpenedAt
	task.delay(CARD_LIFE, function()
		if cardOpenedAt == opened then
			closeCard()
		end
	end)
end

local function gain(key: string, amount: number)
	feedGain(key, amount)
	cardGain(key, amount)
end

function Rewards.init()
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Rewards") :: ScreenGui
	feed = gui:FindFirstChild("Feed") :: Frame
	entryTemplate = feed:FindFirstChild("EntryTemplate") :: GuiObject
	card = gui:FindFirstChild("BossReward") :: Frame
	list = card:FindFirstChild("List") :: Frame
	rewardTemplate = list:FindFirstChild("RewardTemplate") :: GuiObject
	Menus.register(card, { close = closeCard });

	(ReplicatedStorage.Remotes.Effect :: RemoteEvent).OnClientEvent:Connect(function(kind: string, ...)
		local args = { ... }
		if kind == "stones" then
			gain("stones", args[2])
		elseif kind == "loot" then
			gain(args[1], args[2])
		elseif kind == "insight" then
			gain("insight", args[1])
		elseif kind == "manual" then
			gain(`manual:{args[1]}`, 1)
		elseif kind == "weapon" then
			gain(`weapon:{args[1]}`, 1)
		elseif kind == "boss" then
			openCard(args[1], args[2])
		end
	end)

	UserInputService.InputBegan:Connect(function(input)
		local click = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
		if click and card.Visible and os.clock() - cardOpenedAt >= CARD_MIN then
			closeCard()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for key, e in entries do
				if now - e.last > ENTRY_LIFE then
					fadeOut(e.frame)
					entries[key] = nil
				end
			end
		end
	end)
end

return Rewards
