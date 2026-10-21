--!strict
-- The travel veil (StarterGui.Veil): an ink-dark screen that fades in over
-- everything while a teleport array carries you, with the destination's name.
-- cover() yields until the screen is dark and returns a token; reveal(token)
-- fades it away. A cover always lifts on its own after MAX_COVER seconds, so a
-- lost reveal can never leave the screen black.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Veil = {}

local FADE_OUT = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_IN = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local QUICK = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local MAX_COVER = 12

-- each piece and the transparency props it fades (to 0 when covered, 1 when clear)
local PROPS = {
	Frame = { "BackgroundTransparency" },
	TextLabel = { "TextTransparency", "TextStrokeTransparency" },
	ImageLabel = { "ImageTransparency" },
}

local shade: Frame? = nil
local title: TextLabel? = nil
local token = 0

local function find(): boolean
	if shade then
		return true
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = playerGui and playerGui:FindFirstChild("Veil")
	local found = gui and gui:FindFirstChild("Shade") :: Frame?
	if not found then
		return false
	end
	shade = found
	title = found:FindFirstChild("Title", true) :: TextLabel?
	return true
end

local function fade(to: number, info: TweenInfo)
	local root = shade :: Frame
	local all = root:GetDescendants()
	table.insert(all, root)
	for _, inst in all do
		local props = PROPS[inst.ClassName]
		if props then
			local goal = {}
			for _, prop in props do
				goal[prop] = to
			end
			TweenService:Create(inst, info, goal):Play()
		end
	end
end

local function setAll(value: number)
	local root = shade :: Frame
	local all = root:GetDescendants()
	table.insert(all, root)
	for _, inst in all do
		for _, prop in PROPS[inst.ClassName] or {} do
			(inst :: any)[prop] = value
		end
	end
end

-- Darken the screen over the destination's name; returns once it's dark.
function Veil.cover(destination: string): number
	token += 1
	local mine = token
	if not find() then
		return mine
	end
	(title :: TextLabel).Text = destination
	local root = shade :: Frame
	if not root.Visible then
		setAll(1)
		root.Visible = true
	end
	fade(0, FADE_OUT)
	task.delay(MAX_COVER, function()
		Veil.reveal(mine)
	end)
	task.wait(FADE_OUT.Time)
	return mine
end

-- Lift the cover started with this token (quick: on a refusal, no lingering).
function Veil.reveal(mine: number, quick: boolean?)
	if mine ~= token or not shade then
		return
	end
	token += 1
	local lifting = token
	local info = if quick then QUICK else FADE_IN
	fade(1, info)
	task.delay(info.Time, function()
		if token == lifting and shade then
			shade.Visible = false
		end
	end)
end

return Veil
