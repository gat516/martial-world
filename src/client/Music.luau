--!strict
-- Zone music: one looped track per area, crossfaded as you move between them.
-- The tracks are the Sounds under SoundService.Music, named after their zone and
-- played through that group, so the Settings music slider scales them.
--   Boss      the boss arena at the far end of the Wilds
--   Marsh     the serpent marshes, the Wilds' far half
--   Wilds     the rest of the Wilds, below the peaks
--   MyPeak    your own spirit peak
--   MainPeak  everywhere else (the main peak and the sect)
-- The Wilds zones stream out with distance, so their layout is copied here
-- (from Workspace.Wilds.Zones) rather than read from the parts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local MyPeak = require(script.Parent.MyPeak)

local player = Players.LocalPlayer
local group = SoundService:WaitForChild("Music") :: SoundGroup

local WILDS_TOP = 420 -- the Wilds lie below this height (their flight ceiling; the peaks stand far above)...
local WILDS_SOUTH = 470 -- ...and south of this Z (the valley starts at the sect gate)
local MARSH_SOUTH = 1560 -- the Ruined Borderlands (serpent marshes) start here, past the border river
local BOSS_CENTER = Vector2.new(220, 1800) -- the BossArena zone's X, Z
local BOSS_RADIUS = 60 -- a little past the arena's edge
local CHECK_SECONDS = 0.5
local FADE_SECONDS = 2.5

local Music = {}

local volumes: { [Sound]: number } = {} -- each track's authored volume
local current: Sound? = nil

local function zoneAt(position: Vector3): string
	if position.Y < WILDS_TOP and position.Z > WILDS_SOUTH then
		if (Vector2.new(position.X, position.Z) - BOSS_CENTER).Magnitude <= BOSS_RADIUS then
			return "Boss"
		end
		return if position.Z > MARSH_SOUTH then "Marsh" else "Wilds"
	end
	local frame = MyPeak.frame()
	if frame then
		local offset = (position - frame.Position) * Vector3.new(1, 0, 1)
		if offset.Magnitude <= Config.Circulation.PEAK_RADIUS then
			return "MyPeak"
		end
	end
	return "MainPeak"
end

local function fade(sound: Sound, volume: number, done: (() -> ())?)
	local tween = TweenService:Create(sound, TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Sine), { Volume = volume })
	if done then
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				done()
			end
		end)
	end
	tween:Play()
end

local function switchTo(name: string)
	local track = group:FindFirstChild(name)
	if not (track and track:IsA("Sound")) or track == current then
		return
	end
	local old = current
	current = track
	if old then
		-- paused, not stopped: coming back picks the track up where it left off
		fade(old, 0, function()
			if current ~= old then
				old:Pause()
			end
		end)
	end
	track:Resume() -- also starts a track that never played
	fade(track, volumes[track] or 0.35)
end

function Music.init()
	for _, track in group:GetChildren() do
		if track:IsA("Sound") then
			volumes[track] = track.Volume
			track.SoundGroup = group
			track.Volume = 0
		end
	end
	task.spawn(function()
		while true do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				switchTo(zoneAt(root.Position))
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return Music
