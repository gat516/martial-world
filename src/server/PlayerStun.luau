--!strict
-- Player crowd control: the hit reaction (flinch) and the two things a boss can
-- do to take a player's control (stagger, stun). Server authority; clients read
-- the state off the player's Humanoid attributes and draw it (CrowdControl.luau),
-- gate their input on it (ActionState.crowdLocked) and play the animations.
--
--   flinch   ~0.25 s hit reaction. Every enemy hit that lands on a player fires
--            one from Combat.hurt. A pose only: it never cancels or blocks an
--            action and slows walking a little.
--   stagger  ~0.75 s (0.4-1.0): knocked off balance. Cancels the current action,
--            no attacking, dodging or casting, walking at a fifth of the speed,
--            a stumble away from `source`.
--   stun     `seconds` (default 1.2, at most 3): cancels the action, no actions,
--            no movement, dazed loop.
--
-- Protection (Config.Combat.CC):
--   * A dodge's i-frames (and a dash skill's) dodge a stagger or stun too:
--     apply returns "evaded".
--   * After a stagger or stun ends the player is immune to both for IMMUNITY
--     seconds ("immune"). A stun can replace a stagger in progress; nothing
--     replaces a stun.
--   * A stun landing within DR_WINDOW seconds of the end of the previous one
--     lasts DR_FACTOR times as long for each link in the chain (1.2 -> 0.6 -> 0.3,
--     which is under STUN_MIN and so ignored). A pause longer than DR_WINDOW
--     resets the chain.
--   * Flinches never start during a stagger or stun, and not within FLINCH_GAP
--     of the previous flinch.
--
-- Humanoid attributes (all server time via workspace:GetServerTimeNow()):
--   CCKind  "flinch" | "stagger" | "stun" (nil when free)
--   CCStart, CCEnd  when it started and ends
--   CCMove  walk speed share (Movement.apply multiplies by it)
--   CCLock  true for stagger and stun
--   CCFrom  Vector3, the source's position (stagger: which way to stumble)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config).Combat.CC
local Movement = require(script.Parent.Movement)

export type Kind = "flinch" | "stagger" | "stun"
export type Result = "applied" | "immune" | "evaded" | "ignored"

type State = {
	character: Model?,
	kind: Kind?,
	startedAt: number,
	endsAt: number,
	flinchAt: number,
	immuneUntil: number,
	lastStunEnd: number,
	chain: number,
}
local states: { [Player]: State } = {}

local PlayerStun = {}

-- Set by Combat: does a dodge or dash skill's i-frame cover this player now,
-- and a lock just began (cancel the player's action).
PlayerStun.shielded = nil :: ((player: Player) -> boolean)?
PlayerStun.onLock = nil :: ((player: Player) -> ())?

local function humanoidOf(player: Player): Humanoid?
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return if humanoid and humanoid.Health > 0 then humanoid else nil
end

local function stateOf(player: Player): State
	local s = states[player]
	if not s then
		s = {
			character = player.Character, kind = nil, startedAt = 0, endsAt = 0,
			flinchAt = -math.huge, immuneUntil = 0, lastStunEnd = -math.huge, chain = 0,
		}
		states[player] = s
	end
	if s.character ~= player.Character then
		s.character, s.kind, s.endsAt = player.Character, nil, 0
		s.flinchAt, s.immuneUntil, s.lastStunEnd, s.chain = -math.huge, 0, -math.huge, 0
	end
	return s
end

-- The kind in effect now, or nil.
function PlayerStun.kind(player: Player): Kind?
	local s = stateOf(player)
	return if s.kind and workspace:GetServerTimeNow() < s.endsAt then s.kind else nil
end

-- Stagger or stun in effect: no actions, movement taken.
function PlayerStun.isLocked(player: Player): boolean
	local kind = PlayerStun.kind(player)
	return kind == "stagger" or kind == "stun"
end

-- Seconds left on the current kind (0 when free).
function PlayerStun.remaining(player: Player): number
	local s = stateOf(player)
	return if PlayerStun.kind(player) then math.max(0, s.endsAt - workspace:GetServerTimeNow()) else 0
end

local function publish(humanoid: Humanoid, kind: Kind?, startedAt: number, endsAt: number, from: Vector3?)
	local move = 1
	if kind == "flinch" then
		move = Config.FLINCH_MOVE
	elseif kind == "stagger" then
		move = Config.STAGGER_MOVE
	elseif kind == "stun" then
		move = 0
	end
	humanoid:SetAttribute("CCMove", move)
	humanoid:SetAttribute("CCLock", kind == "stagger" or kind == "stun")
	humanoid:SetAttribute("CCFrom", from)
	humanoid:SetAttribute("CCStart", if kind then startedAt else nil)
	humanoid:SetAttribute("CCEnd", if kind then endsAt else nil)
	humanoid:SetAttribute("CCKind", kind) -- last: clients key off it
	Movement.apply(humanoid)
end

-- Free the player now (respawn-safe; also ends a stun early).
function PlayerStun.clear(player: Player)
	local s = stateOf(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if s.kind and humanoid then
		publish(humanoid, nil, 0, 0, nil)
	end
	s.kind, s.endsAt = nil, 0
end

function PlayerStun.forget(player: Player)
	states[player] = nil
end

-- Apply a reaction. `seconds` overrides the kind's default length (a flinch
-- ignores it unless given; stagger and stun are clamped). `source` is the model
-- the player should stumble away from. Returns what happened.
function PlayerStun.apply(player: Player, kind: Kind, seconds: number?, source: Model?): Result
	local humanoid = humanoidOf(player)
	if not humanoid then
		return "ignored"
	end
	local s = stateOf(player)
	local now = workspace:GetServerTimeNow()
	local active = PlayerStun.kind(player)
	local duration: number
	if kind == "flinch" then
		if active == "stagger" or active == "stun" or now - s.flinchAt < Config.FLINCH_GAP then
			return "ignored"
		end
		s.flinchAt = now
		duration = math.clamp(seconds or Config.FLINCH_SECONDS, 0.1, 0.5)
	else
		local shield = PlayerStun.shielded
		if shield and shield(player) then
			return "evaded"
		end
		if active == "stun" or (active == "stagger" and kind == "stagger") then
			return "ignored"
		end
		if active ~= "stagger" and now < s.immuneUntil then
			return "immune"
		end
		if kind == "stun" then
			s.chain = if now - s.lastStunEnd <= Config.DR_WINDOW then s.chain + 1 else 0
			duration = math.min(seconds or Config.STUN_SECONDS, Config.STUN_MAX) * Config.DR_FACTOR ^ s.chain
			if duration < Config.STUN_MIN then
				return "immune"
			end
			s.lastStunEnd = now + duration
		else
			duration = math.clamp(seconds or Config.STAGGER_SECONDS, Config.STAGGER_MIN, Config.STAGGER_MAX)
		end
		s.immuneUntil = now + duration + Config.IMMUNITY
	end
	s.kind, s.startedAt, s.endsAt = kind, now, now + duration
	local sourceRoot = source and source:GetPivot().Position
	publish(humanoid, kind, now, s.endsAt, sourceRoot)
	if kind ~= "flinch" and PlayerStun.onLock then
		PlayerStun.onLock(player)
	end
	return "applied"
end

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	for player, s in states do
		if s.kind and now >= s.endsAt then
			s.kind = nil
			local humanoid = s.character and s.character:FindFirstChildOfClass("Humanoid")
			if humanoid and player.Character == s.character then
				publish(humanoid, nil, 0, 0, nil)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(PlayerStun.forget)

return PlayerStun
