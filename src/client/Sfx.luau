--!strict
-- One-shot sound effects. The templates are the Sounds under SoundService.SFX,
-- one per name (Swing, Hit, Dodge, a technique's id, ...; folders make paths
-- like "Enemies/SpiritWolf/Attack"); each play clones one and routes it through
-- that group, so the Settings sound slider scales it.
-- Given a position the sound plays from there in 3D, given a part it follows the
-- part, and given neither it plays flat (your own moves and the UI).

local SoundService = game:GetService("SoundService")

local group = SoundService:WaitForChild("SFX") :: SoundGroup

local PITCH_JITTER = 0.08 -- each play's speed varies by up to ±4% so repeats don't drone
local MAX_SECONDS = 8 -- a clone is cleaned up after this even if Ended never fires

local Sfx = {}

local lastPlayed: { [string]: number } = {}

-- `gap`: skip the play if this name went off less than `gap` seconds ago (for
-- sounds that can arrive in bursts, like one hit per enemy struck).
function Sfx.play(name: string, at: (Vector3 | BasePart)?, gap: number?)
	local template: Instance? = group
	for step in string.gmatch(name, "[^/]+") do
		template = template and template:FindFirstChild(step)
	end
	if not (template and template:IsA("Sound")) then
		return
	end
	local now = os.clock()
	if gap and now - (lastPlayed[name] or -math.huge) < gap then
		return
	end
	lastPlayed[name] = now

	local sound = template:Clone()
	sound.SoundGroup = group
	sound.PlaybackSpeed *= 1 + (math.random() - 0.5) * PITCH_JITTER
	local holder: Instance
	if typeof(at) == "Instance" then
		holder = sound
		sound.Parent = at
	elseif at then
		local anchor = Instance.new("Attachment")
		anchor.WorldPosition = at :: Vector3
		anchor.Parent = workspace.Terrain
		holder = anchor
		sound.Parent = anchor
	else
		holder = sound
		sound.Parent = SoundService
	end
	sound.Ended:Once(function()
		holder:Destroy()
	end)
	task.delay(MAX_SECONDS, function()
		if holder.Parent then
			holder:Destroy()
		end
	end)
	sound:Play()
end

return Sfx
