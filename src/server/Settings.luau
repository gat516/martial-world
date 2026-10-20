--!strict
-- Saves the Settings window's choices (SaveSettings remote). The client applies
-- them itself and sends the whole set; the server only checks and stores it, so
-- it follows the player to their next session and device.

local PlayerData = require(script.Parent.PlayerData)

local Settings = {}

local function volume(value: any, fallback: number): number
	return if type(value) == "number" and value == value then math.clamp(value, 0, 1) else fallback
end

local function flag(value: any, fallback: boolean): boolean
	return if type(value) == "boolean" then value else fallback
end

function Settings.save(player: Player, sent: any)
	local data = PlayerData.get(player)
	if not data or type(sent) ~= "table" then
		return
	end
	local s = data.settings
	s.music = volume(sent.music, s.music)
	s.sfx = volume(sent.sfx, s.sfx)
	s.autoAttack = flag(sent.autoAttack, s.autoAttack)
	s.lockHint = flag(sent.lockHint, s.lockHint)
end

return Settings
