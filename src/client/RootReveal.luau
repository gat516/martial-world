--!strict
-- The spirit root reveal card (Hud.RootReveal): a small centre card the first
-- time the local player's root is tested at the Testing Stone. It shows the
-- element's seal over rays in its colour, "Spirit Root", the element's name, the
-- grade in its colour and the one-line perk. Rare roots (Lightning, Wind, Ice)
-- add a gold ring round the seal and a "RARE!" tag. A tap or click closes it
-- (after a short beat), or it closes by itself; then the Self tile appears in the
-- top-right row with a pulse to show where the root now lives (SelfCard).
-- Fed by Effect "root" (player, element, grade, first), sent to everyone; only
-- the local player's first test opens the card (a repeat test gets a toast from
-- the server). The pillar of light from the same event is world vfx, not here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Roots = require(ReplicatedStorage.Shared.Roots)
local Motion = require(script.Parent.Motion)
local SelfCard = require(script.Parent.SelfCard)

local CARD_DELAY = 0.6 -- let the pillar rise first
local CARD_MIN = 1.0 -- seconds before a tap can close it
local CARD_LIFE = 6 -- it closes by itself after this
local RAY_SPEED = 14 -- degrees per second

local player = Players.LocalPlayer

local RootReveal = {}

local card: Frame
local openedAt = 0
local rayConn: RBXScriptConnection? = nil
local closing = false

local function close()
	if not card.Visible or closing then
		return
	end
	closing = true
	Motion.fadeOut(card, function()
		card.Visible = false
		closing = false
		if rayConn then
			rayConn:Disconnect()
			rayConn = nil
		end
		SelfCard.announce()
	end)
end

function RootReveal.show(element: string, grade: string)
	local def = Roots.Elements[element]
	if not def then
		return
	end
	local seal = card:FindFirstChild("Seal") :: GuiObject;
	(seal:FindFirstChild("Icon") :: ImageLabel).Image = SelfCard.rootIcon(element);
	(seal:FindFirstChild("Trim") :: GuiObject).Visible = def.rare;
	(card:FindFirstChild("Rare") :: GuiObject).Visible = def.rare
	local rays = card:FindFirstChild("Rays") :: ImageLabel
	rays.ImageColor3 = def.color
	local name = card:FindFirstChild("NameLabel") :: TextLabel
	name.Text = def.name
	name.TextColor3 = def.color
	local gradeLabel = card:FindFirstChild("Grade") :: TextLabel
	gradeLabel.Text = `{grade} grade`
	gradeLabel.TextColor3 = SelfCard.gradeColor(grade);
	(card:FindFirstChild("Blurb") :: TextLabel).Text = def.blurb

	closing = false
	openedAt = os.clock()
	card.Visible = true
	Motion.fadeIn(card)
	if not rayConn then
		rayConn = RunService.RenderStepped:Connect(function(dt)
			rays.Rotation = (rays.Rotation + RAY_SPEED * dt) % 360
		end)
	end
	local opened = openedAt
	task.delay(CARD_LIFE, function()
		if openedAt == opened then
			close()
		end
	end)
end

function RootReveal.init(gui: ScreenGui)
	card = gui:FindFirstChild("RootReveal") :: Frame
	card.Visible = false;

	(ReplicatedStorage.Remotes.Effect :: RemoteEvent).OnClientEvent:Connect(function(kind: string, who: Player?, element: string?, grade: string?, first: boolean?)
		if kind ~= "root" or who ~= player or not first or type(element) ~= "string" then
			return
		end
		task.delay(CARD_DELAY, RootReveal.show, element, if type(grade) == "string" then grade else "Spirit")
	end)

	UserInputService.InputBegan:Connect(function(input)
		local click = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
		if click and card.Visible and os.clock() - openedAt >= CARD_MIN then
			close()
		end
	end)
end

return RootReveal
