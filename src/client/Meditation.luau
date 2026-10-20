--!strict
-- Meditation: M or the Meditate button sits the character down; M or the button
-- (now "Rise") stands them back up. Plays Animations.Meditate: Sit once, Loop
-- while seated, GetUp to stand. Movement is locked while seated, taking damage
-- stands you up, and the server (Meditation.luau) can end it too. Where you sit
-- sets the passive multiplier; a toast says what it is whenever it changes.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controls = require(script.Parent.Controls)
local Hud = require(script.Parent.Hud)
local State = require(script.Parent.State)

local remote = ReplicatedStorage.Remotes.Meditate :: RemoteEvent
local animations = (ReplicatedStorage:WaitForChild("Animations") :: Folder):WaitForChild("Meditate") :: Folder
local player = Players.LocalPlayer

local BLEND = 0.2 -- seconds each animation fades into the next

local Meditation = {}

type Phase = "idle" | "sitting" | "seated" | "rising"
local phase: Phase = "idle"
local token = 0 -- bumped on every sit and stand, so stale callbacks do nothing
local tracks: { [string]: AnimationTrack } = {}
local button: TextButton

local function refresh()
	button.Text = if phase == "idle" then "Meditate" else "Rise"
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
	Controls.lock("Meditation")
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
function Meditation.stand(fromServer: boolean?)
	if phase == "idle" or phase == "rising" then
		return
	end
	phase = "rising"
	token += 1
	local mine = token
	if not fromServer then
		remote:FireServer(false)
	end
	tracks.Sit:Stop(BLEND)
	tracks.Loop:Stop(BLEND)
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

function Meditation.toggle()
	if phase == "idle" then
		Meditation.sit()
	else
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
	button = (gui:FindFirstChild("Buttons") :: Frame):FindFirstChild("MeditateButton") :: TextButton
	button.Activated:Connect(Meditation.toggle)
	ContextActionService:BindAction("Meditate", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Meditation.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M)

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
