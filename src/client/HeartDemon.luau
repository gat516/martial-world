--!strict
-- The heart-demon trial on the dialogue screen (docs/systems/heart-demon.md; the
-- server's HeartDemon.luau builds the questions and tempers the grades). Offered
-- from the meditation seat, never forced:
--   - Break Through at a major's stage 9 (QC9, QR9) with its demon unfaced asks
--     first, once a session: Face it first / Break through now / Not now. Facing
--     it ends with a Break through choice; nothing here stops a breakthrough.
--   - Sitting down with any demon unfaced (stage 9 of a major or past it, FE9 at
--     the peak) offers it once a session, unless "Not now" was said within
--     Pacing.HeartDemon.OFFER_COOLDOWN (the server's `snoozed`).
-- Closing the screen mid-trial records nothing; it can be faced again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CirculationMinigame = require(script.Parent.CirculationMinigame)
local Dialogue = require(script.Parent.Dialogue)
local Hud = require(script.Parent.Hud)
local Menus = require(script.Parent.Menus)
local State = require(script.Parent.State)

local remote = ReplicatedStorage.Remotes.CultivationAction :: RemoteFunction

local SPEAKER = "Heart Demon"
-- gray silhouette (NPC portrait rule); a heart-demon silhouette of its own is a ui-designer task
local PORTRAIT = "unnamed"
local SEAT_DELAY = 2.5 -- seconds after sitting before the seat offer

local HeartDemon = {}

local offered: { [string]: boolean } = {} -- this session: "<major>" seat offers, "bt:<major>" Break Through offers
local running = false

local function say(lines: { string }, responses: { Dialogue.Response }): number?
	return Dialogue.open({ speaker = SPEAKER, portrait = PORTRAIT, lines = lines, responses = responses })
end

local function invoke(...: any): (boolean, any)
	local ok, success, payload = pcall(remote.InvokeServer, remote, ...)
	if not ok then
		return false, "Something went wrong"
	end
	return success == true, payload
end

-- Face the demon. `breaking`: the trial came from Break Through, so it ends with
-- that choice. Returns whether it finished, and the closing choice.
local function run(breaking: boolean): (boolean, number?)
	local ok, payload = invoke("heartDemon")
	if not ok then
		if type(payload) == "string" then
			Hud.toast(payload)
		end
		return false, nil
	end
	local choices = {}
	local carry: string? = nil -- the demon's reply to the last answer opens the next question
	for i, q in payload.questions do
		local lines = table.clone(q.lines)
		if carry then
			table.insert(lines, 1, carry)
		end
		local responses: { Dialogue.Response } = {}
		for _, a in q.answers do
			table.insert(responses, { text = a.text, icon = "heart" })
		end
		local choice = say(lines, responses)
		if not choice then
			Hud.toast("The voice fades for now. Sit and face it whenever you're ready.")
			return false, nil
		end
		choices[i] = choice
		carry = q.answers[choice].reply
	end
	local done, result = invoke("heartDemonAnswer", choices)
	if not done then
		if type(result) == "string" then
			Hud.toast(result)
		end
		return false, nil
	end
	local lines = {}
	if carry then
		table.insert(lines, carry)
	end
	for _, line in result.lines do
		table.insert(lines, line)
	end
	local closing: { Dialogue.Response } = if breaking
		then {
			{ text = "Break through.", icon = "rush", highlight = true },
			{ text = "Stay seated a while.", icon = "leave", cancel = true },
		}
		else { { text = "Open my eyes.", icon = "insight", highlight = true, cancel = true } }
	return true, say(lines, closing)
end

-- Break Through was pressed: whether to go ahead now. At a major's stage 9 with its
-- demon unfaced, asks first (once a session).
function HeartDemon.beforeBreakthrough(): boolean
	local s = State.current.heartDemon
	if running then
		return false
	end
	if not (s and s.open and s.atPeak) or offered["bt:" .. s.open] then
		return true
	end
	offered["bt:" .. s.open] = true
	offered[s.open] = true
	running = true
	local choice = say({
		"Before you break through, something stirs in your heart.",
		`Your heart demon, from {s.name}. It knows how you have climbed. Face it, and your old foundations may be tempered.`,
		"Or break through now, and face it later from your seat.",
	}, {
		{ text = "Face it first.", icon = "insight", highlight = true },
		{ text = "Break through now.", icon = "rush" },
		{ text = "Not now.", icon = "leave", cancel = true },
	})
	local proceed = choice == 2
	if choice == 1 then
		local done, closing = run(true)
		proceed = done and closing == 1
	end
	running = false
	return proceed
end

-- Called by Meditation once the player is seated: the seat offer.
function HeartDemon.onSeated()
	task.delay(SEAT_DELAY, function()
		local s = State.current.heartDemon
		if running or not (s and s.open) or s.snoozed or offered[s.open] then
			return
		end
		if State.current.meditation == nil or Menus.isOpen() or Dialogue.isOpen() or CirculationMinigame.isRunning() then
			return
		end
		offered[s.open] = true
		running = true
		local choice = say({
			"As your breath slows, something stirs in your heart.",
			`Your heart demon, from {s.name}. It knows how you have climbed, and it wants to talk.`,
			"Facing it costs you nothing. Answer it truly, and your old foundations may be tempered.",
		}, {
			{ text = "Face it.", icon = "insight", highlight = true },
			{ text = "Not now.", icon = "leave", cancel = true },
		})
		if choice == 1 then
			run(false)
		elseif choice == 2 then
			invoke("heartDemonDecline")
		end
		running = false
	end)
end

return HeartDemon
