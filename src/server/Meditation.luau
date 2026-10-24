--!strict
-- Meditation: the player sits still and passive cultivation is multiplied by where
-- they sit. Anywhere gives a little, their own spirit peak more, and a seat or
-- artifact on their peak (the cushion in the cave abode) adds its own bonus.
-- Bonuses are keyed by ItemId (BuildItems `meditation`), so starter pieces and
-- placed copies count alike. The peak score adds to it on your own peak
-- (Peaks.meditationBonus). World events can open sites (Meditation.addSite) that
-- beat sitting anywhere while they last. The client plays the animations and asks to start
-- or stop; the server re-checks the spot every second and stands the player up
-- if they drift away from where they sat. The same remote carries the client's
-- throttled "awake" ping (input seen), which keeps the player from counting as AFK.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Meditation
local PEAK_RADIUS = require(ReplicatedStorage.Shared.Config).Circulation.PEAK_RADIUS
local Rates = require(ReplicatedStorage.Shared.Pacing).Meditation
local Peak = require(ReplicatedStorage.Shared.Peak)
local BuildItems = require(ReplicatedStorage.Shared.BuildItems)
local Cultivation = require(script.Parent.Cultivation)
local Peaks = require(script.Parent.Peaks)

local meditateRemote = ReplicatedStorage.Remotes.Meditate :: RemoteEvent

export type Spot = { multiplier: number, place: string, own: boolean? } -- own: on your own peak (where seclusion can begin)
type Session = { anchor: Vector3, spot: Spot }

local Meditation = {}

local sessions: { [Player]: Session } = {}

type Site = { center: Vector3, radius: number, spot: Spot }
local sites: { Site } = {}

-- Open a meditation site: anyone meditating within `radius` of `center` gets
-- `multiplier`. Returns a function that closes it (seated players are re-checked
-- within a second).
function Meditation.addSite(center: Vector3, radius: number, multiplier: number, place: string): () -> ()
	local site = { center = center, radius = radius, spot = { multiplier = multiplier, place = place } }
	table.insert(sites, site)
	return function()
		local i = table.find(sites, site)
		if i then
			table.remove(sites, i)
		end
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The best seat or artifact within range on the player's own peak.
local function bestItem(peak: Model, position: Vector3): { bonus: number, name: string }?
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { peak }
	local best = nil
	for _, part in workspace:GetPartBoundsInRadius(position, Config.ITEM_RANGE, params) do
		local piece = Peak.pieceOf(part)
		local id = piece and piece:GetAttribute("ItemId")
		local def = if type(id) == "string" then BuildItems.Defs[id] else nil
		if def and def.meditation and (not best or def.meditation > best.bonus) then
			best = { bonus = def.meditation, name = string.lower(def.name) }
		end
	end
	return best
end

local function spotAt(player: Player, position: Vector3): Spot
	local peak = Peaks.ownedBy(player)
	if peak then
		local offset = Peak.frame(peak):PointToObjectSpace(position)
		if Vector2.new(offset.X, offset.Z).Magnitude <= PEAK_RADIUS and math.abs(offset.Y) <= PEAK_RADIUS then
			local item = bestItem(peak, position)
			local base = Rates.ON_PEAK + Peaks.meditationBonus(player) -- the peak score (Pacing.PeakScore)
			if item then
				return { multiplier = base + item.bonus, place = `on your {item.name}`, own = true }
			end
			return { multiplier = base, place = "on your peak", own = true }
		end
	end
	local best: Spot = { multiplier = Rates.ANYWHERE, place = "" }
	for _, site in sites do
		if (position - site.center).Magnitude <= site.radius and site.spot.multiplier > best.multiplier then
			best = site.spot
		end
	end
	return best
end

-- Passive-rate multiplier and where it comes from, or nil when not meditating.
function Meditation.spot(player: Player): Spot?
	local s = sessions[player]
	return s and s.spot
end

local function stop(player: Player, tellClient: boolean)
	if not sessions[player] then
		return
	end
	sessions[player] = nil
	player:SetAttribute("Meditating", nil)
	if tellClient then
		meditateRemote:FireClient(player, false)
	end
	Cultivation.pushState(player)
end

local function start(player: Player)
	local root = rootOf(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid:GetAttribute("ActionBusy") then
		meditateRemote:FireClient(player, false)
		return
	end
	if not root or sessions[player] then
		meditateRemote:FireClient(player, sessions[player] ~= nil)
		return
	end
	if Cultivation.deviated(player) then
		Cultivation.notify(player, "Your qi is in turmoil. Let it settle before you meditate.")
		meditateRemote:FireClient(player, false)
		return
	end
	sessions[player] = { anchor = root.Position, spot = spotAt(player, root.Position) }
	-- every client reads this to draw the player's method aura while seated
	player:SetAttribute("Meditating", true)
	Cultivation.markActive(player)
	Cultivation.pushState(player)
end

function Meditation.handle(player: Player, on: any)
	if on == true then
		start(player)
	elseif on == false then
		stop(player, false)
	elseif on == "awake" then
		Cultivation.awake(player) -- the client saw input (Pacing.Income.AFK_AFTER)
	end
end

function Meditation.forget(player: Player)
	sessions[player] = nil
	player:SetAttribute("Meditating", nil)
end

Cultivation.meditation = Meditation.spot

task.spawn(function()
	while true do
		task.wait(1)
		for player, s in sessions do
			local root = rootOf(player)
			if not root or (root.Position - s.anchor).Magnitude > Config.MAX_DRIFT then
				stop(player, true)
			else
				local spot = spotAt(player, s.anchor)
				if spot.multiplier ~= s.spot.multiplier then
					s.spot = spot
					Cultivation.pushState(player)
				end
			end
		end
	end
end)

return Meditation
