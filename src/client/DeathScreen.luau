--!strict
-- The death screen (StarterGui.DeathScreen, docs/ui/death-screen.md): a calm
-- card in the middle of the screen while the body waits to reform. A soft
-- crimson vignette at the edges, an ink-wash band behind the text, the cause as
-- the title ("Slain by the Spirit Wolf"), the kit's cloud divider, one line of
-- flavour, and the respawn countdown. No flash, no blackout, no pulse.
--
-- The server's Effect "died" (Combat.died) says what killed you; the lines come
-- from DeathLines. It closes when your new character arrives.
--   DeathScreen.preview(cause?)  cause: "beast", "boss", "poison", "fall",
--     "tribulation", "unknown", or an enemy id ("ThunderApe"). From the console:
--     require(game.Players.LocalPlayer.PlayerScripts.Client.DeathScreen).preview("boss")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Enemies = require(ReplicatedStorage.Shared.Enemies)
local DeathLines = require(script.Parent.DeathLines)
local DeathSave = require(script.Parent.DeathSave)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local UiScale = require(script.Parent.UiScale)

-- The phone shows the desktop layout at this size (titles ~35 px, flavour ~20,
-- the countdown ~16 on an 844x390 screen).
local PHONE_SCALE = 0.72
local VIGNETTE = 0.3 -- the vignette's resting transparency (it's mostly clear already)
local VIGNETTE_IN = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local VIGNETTE_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local PREVIEW_SECONDS = 5

local player = Players.LocalPlayer

export type Info = {
	cause: string, -- "enemy", "fall", "tribulation" or "unknown" (from the server)
	source: string?, -- the enemy's def id, for "enemy"
	poisoned: boolean?,
	respawn: number?, -- seconds until the respawn
	hub: boolean?, -- respawning at the main peak
}

local DeathScreen = {}

local vignette: ImageLabel
local panel: Frame
local body: Frame
local title: TextLabel
local flavour: TextLabel
local countdown: TextLabel
local token = 0
local shown = false

-- The cause the lines are keyed by, and the killer's name.
local function resolve(info: Info): (string, string?)
	if info.cause == "enemy" then
		local def = Enemies.Defs[info.source or ""]
		if not def then
			return "unknown", nil
		end
		local name = def.name
		if info.poisoned then
			return "poison", name
		end
		return if def.boss then "boss" else "beast", name
	end
	return info.cause, nil
end

local function hide()
	if not shown then
		return
	end
	shown = false
	token += 1
	local mine = token
	TweenService:Create(vignette, VIGNETTE_OUT, { ImageTransparency = 1 }):Play()
	Motion.fadeOut(body, function()
		if token == mine then
			panel.Visible = false
			vignette.Visible = false
		end
	end)
	Menus.setCalm(false)
end

function DeathScreen.show(info: Info)
	token += 1
	local mine = token
	local cause, name = resolve(info)
	local titleText, flavourText = DeathLines.pick(cause, name)
	title.Text = titleText
	flavour.Text = flavourText
	local respawn = DeathLines.Respawn[if info.hub then "hub" else "here"]

	-- Nothing else stays open over a death: windows close, the HUD steps aside.
	if DeathSave.isOpen() then
		DeathSave.cancel()
	end
	local open = Menus.current()
	if open then
		Menus.close(open)
	end
	task.delay(0.2, function()
		if token == mine then
			Menus.setCalm(true)
		end
	end)

	if not shown then
		shown = true
		vignette.ImageTransparency = 1
		vignette.Visible = true
		TweenService:Create(vignette, VIGNETTE_IN, { ImageTransparency = VIGNETTE }):Play()
		panel.Visible = true
		Motion.fadeIn(body)
	end

	local deadline = os.clock() + (info.respawn or PREVIEW_SECONDS)
	task.spawn(function()
		while token == mine do
			local left = math.ceil(deadline - os.clock())
			countdown.Text = if left > 0
				then (string.gsub(respawn.count, "{n}", tostring(left)))
				else respawn.soon
			if left <= 0 then
				break
			end
			task.wait(math.max(0.05, deadline - os.clock() - (left - 1)))
		end
	end)
end

-- Sample screen; it closes by itself after a few seconds.
function DeathScreen.preview(cause: string?)
	local info: Info
	local c = cause or "beast"
	if Enemies.Defs[c] then
		info = { cause = "enemy", source = c }
	elseif c == "beast" then
		info = { cause = "enemy", source = "SpiritWolf" }
	elseif c == "boss" then
		info = { cause = "enemy", source = "ThunderApe" }
	elseif c == "poison" then
		info = { cause = "enemy", source = "JadeJiao", poisoned = true }
	else
		info = { cause = c }
	end
	info.respawn = PREVIEW_SECONDS
	info.hub = true
	DeathScreen.show(info)
	local mine = token
	task.delay(PREVIEW_SECONDS + 1, function()
		if token == mine then
			hide()
		end
	end)
end

function DeathScreen.init()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("DeathScreen") :: ScreenGui
	vignette = gui:WaitForChild("Vignette") :: ImageLabel
	local canvas = gui:WaitForChild("Canvas") :: Frame
	UiScale.fit(canvas)
	panel = canvas:WaitForChild("Panel") :: Frame
	local device = panel:FindFirstChild("Device") :: UIScale
	device.Scale = if UiScale.isPhone() then PHONE_SCALE else 1
	body = panel:FindFirstChild("Body") :: Frame
	title = body:FindFirstChild("Title", true) :: TextLabel
	flavour = body:FindFirstChild("Flavour", true) :: TextLabel
	countdown = body:FindFirstChild("Countdown", true) :: TextLabel
	vignette.Visible = false
	panel.Visible = false;

	(ReplicatedStorage.Remotes.Effect :: RemoteEvent).OnClientEvent:Connect(function(kind: string, info: any)
		if kind == "died" and typeof(info) == "table" then
			DeathScreen.show(info)
		end
	end)
	player.CharacterAdded:Connect(hide)
end

return DeathScreen
