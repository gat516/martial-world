--!strict
-- Cultivation seat: M or the Cultivate tile (top right) sits the character down
-- to meditate (idle, safe to leave running).
-- Seated is a calm screen with only what you can do there: a slim row above the
-- vitals with Circulate (an active minigame, played seated) and Rise; when the
-- realm bar is full, Circulate gives way to Break Through (BreakthroughView).
-- The touch combat cluster hides while seated; the tile reads "Rise".
-- Getting up: Rise, the tile, M, or simply moving or jumping (you just stand
-- and go, no get-up animation). Taking damage stands you up, and the server
-- (Meditation.luau) can end it too. Plays Animations.Meditate: Sit once, Loop
-- while seated, GetUp to stand. Where you sit sets the passive multiplier; a
-- toast says what it is whenever it changes.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CirculationMinigame = require(script.Parent.CirculationMinigame)
local Controls = require(script.Parent.Controls)
local Hud = require(script.Parent.Hud)
local Layout = require(script.Parent.Layout)
local Menus = require(script.Parent.Menus)
local State = require(script.Parent.State)

local remote = ReplicatedStorage.Remotes.Meditate :: RemoteEvent
local animations = (ReplicatedStorage:WaitForChild("Animations") :: Folder):WaitForChild("Meditate") :: Folder
local player = Players.LocalPlayer

local BLEND = 0.2 -- seconds each animation fades into the next
local MOVE_TO_RISE = 0.1 -- move input past this stands you up

local Meditation = {}

type Phase = "idle" | "sitting" | "seated" | "rising"
local phase: Phase = "idle"
local token = 0 -- bumped on every sit and stand, so stale callbacks do nothing
local tracks: { [string]: AnimationTrack } = {}
local button: TextButton
local row: Frame -- Stack.CultivatePrompt: the Circulate and Rise pills

local function barFull(): boolean
	local value, max = player:GetAttribute("Cultivation") or 0, player:GetAttribute("CultivationMax") or 0
	return max > 0 and value >= max
end

local function refresh()
	local active = phase ~= "idle"
	local seated = phase == "sitting" or phase == "seated"
	local caption = button:FindFirstChild("Caption") :: TextLabel
	caption.Text = if active then "Rise" else "Cultivate"
	local trim = button:FindFirstChild("Trim") :: UIStroke
	trim.Thickness = if active then 2.5 else 1.2
	trim.Transparency = if active then 0 else 0.45
	row.Visible = seated and not Menus.isOpen();
	-- a full bar has nothing to circulate into; Break Through shows instead
	(row:FindFirstChild("Circulate") :: GuiObject).Visible = not barFull()
	Layout.showCluster(not active)
end

-- Call fn BLEND seconds before a non-looped track ends, so the next pose fades in
-- under it instead of snapping back to idle for a frame.
local function nearEnd(track: AnimationTrack, fn: () -> ())
	task.spawn(function()
		local waited = 0
		while track.Length == 0 and waited < 2 do
			waited += task.wait()
		end
		task.wait(math.max(0, track.Length - BLEND))
		fn()
	end)
end

function Meditation.isActive(): boolean
	return phase ~= "idle"
end

function Meditation.sit()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if phase ~= "idle" or not humanoid or humanoid.Health <= 0 or not tracks.Sit then
		return
	end
	if humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	phase = "sitting"
	token += 1
	local mine = token
	remote:FireServer(true)
	tracks.Sit:Play(BLEND)
	nearEnd(tracks.Sit, function()
		if token == mine then
			phase = "seated"
			tracks.Loop:Play(BLEND)
		end
	end)
	refresh()
end

-- `fromServer`: the server already ended the session, so don't tell it again.
-- `moving`: the player is already walking off; skip the get-up animation.
function Meditation.stand(fromServer: boolean?, moving: boolean?)
	if phase == "idle" or (phase == "rising" and not moving) then
		return
	end
	token += 1
	local mine = token
	if not fromServer and phase ~= "rising" then
		remote:FireServer(false)
	end
	tracks.Sit:Stop(BLEND)
	tracks.Loop:Stop(BLEND)
	if moving then
		tracks.GetUp:Stop(BLEND)
		phase = "idle"
		Controls.unlock("Meditation")
		refresh()
		return
	end
	phase = "rising"
	Controls.lock("Meditation") -- hold still for the get-up only
	tracks.GetUp:Play(BLEND)
	nearEnd(tracks.GetUp, function()
		if token == mine then
			phase = "idle"
			Controls.unlock("Meditation")
			refresh()
		end
	end)
	refresh()
end

-- Circulate from the seat; the pills come back when the run ends.
local function circulate()
	row.Visible = false
	CirculationMinigame.start()
	refresh()
end

-- M and the tile: sit down to meditate, or stand straight back up.
function Meditation.toggle()
	if phase == "idle" then
		Meditation.sit()
	elseif not CirculationMinigame.isRunning() then
		Meditation.stand()
	end
end

local function onCharacter(character: Model)
	table.clear(tracks)
	token += 1
	phase = "idle"
	Controls.unlock("Meditation")
	refresh()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator
	for _, name in { "Sit", "Loop", "GetUp" } do
		local track = animator:LoadAnimation(animations:FindFirstChild(name) :: Animation)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = name == "Loop"
		tracks[name] = track
	end
	local last = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < last then
			Meditation.stand()
		end
		last = health
	end)
end

function Meditation.init(gui: ScreenGui)
	button = (gui:FindFirstChild("Buttons") :: Frame):FindFirstChild("CultivateButton") :: TextButton
	button.Activated:Connect(Meditation.toggle)
	row = (gui:FindFirstChild("Stack") :: Frame):FindFirstChild("CultivatePrompt") :: Frame;
	(row:FindFirstChild("Circulate") :: ImageButton).Activated:Connect(function()
		task.spawn(circulate)
	end);
	(row:FindFirstChild("Rise") :: ImageButton).Activated:Connect(function()
		Meditation.stand()
	end)
	ContextActionService:BindAction("Meditate", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Meditation.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M)

	Menus.onChanged(refresh)
	player:GetAttributeChangedSignal("Cultivation"):Connect(refresh)
	player:GetAttributeChangedSignal("CultivationMax"):Connect(refresh)
	-- moving or jumping while seated stands you up
	RunService.Heartbeat:Connect(function()
		if phase ~= "sitting" and phase ~= "seated" or CirculationMinigame.isRunning() then
			return
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and (humanoid.MoveDirection.Magnitude > MOVE_TO_RISE or humanoid.Jump) then
			Meditation.stand(false, true)
		end
	end)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	remote.OnClientEvent:Connect(function(on: boolean)
		if not on then
			Meditation.stand(true)
		end
	end)

	local shown: number? = nil
	State.onChanged(function(s)
		local spot = s.meditation
		local multiplier = spot and spot.multiplier
		if spot and multiplier ~= shown then
			local where = if spot.place ~= "" then ` {spot.place}` else ""
			Hud.toast(`Meditating{where}: passive cultivation ×{spot.multiplier}`)
		end
		shown = multiplier
	end)
end

return Meditation
