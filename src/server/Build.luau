--!strict
-- Owner-only building on their peak. Placing takes one of the item from the
-- player's owned count (data.decor); storing anything (placed items or the starter
-- pieces every peak comes with) puts it back. Starter pieces are stashed so they
-- return for the next owner of the peak. Items are bought with Spirit Stones at the
-- Spirit Market on the main peak (BuildItems.luau has every item's definition).
--
-- The server is the authority on where things go: every place and move is
-- re-checked with Placement.check (bounds, support, overlap, reserved zones,
-- restricted geometry) against a fresh index of the peak. Requests carry the
-- pivot in peak-local space, a yaw in degrees and a placement mode.
--
-- Support: storing a piece also stores everything resting on it (stacked,
-- socketed or hung from it), and moving a piece carries those along unchanged.
-- Moving a starter piece turns it into a placed copy (the original is stashed).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Build
local BuildItems = require(ReplicatedStorage.Shared.BuildItems)
local Peak = require(ReplicatedStorage.Shared.Peak)
local Placement = require(ReplicatedStorage.Shared.Placement)
local PlayerData = require(script.Parent.PlayerData)
local Peaks = require(script.Parent.Peaks)
local Garden = require(script.Parent.Garden)
local Cultivation = require(script.Parent.Cultivation)

local catalog = ReplicatedStorage.BuildCatalog
local probe = (ReplicatedStorage.BuildKit.Probe :: BasePart):Clone() -- queries only; never parented

local MODES = { floor = true, wall = true, ceiling = true, socket = true }
local POS_STEP = 0.05 -- saved positions are quantised to this

local lastAction: { [Player]: number } = {}

local Build = {}

local function give(data: PlayerData.Data, itemId: any)
	if type(itemId) == "string" and BuildItems.Defs[itemId] then
		data.decor[itemId] = (data.decor[itemId] or 0) + 1
	end
end

local function take(data: PlayerData.Data, itemId: string)
	data.decor[itemId] -= 1
	if data.decor[itemId] <= 0 then
		data.decor[itemId] = nil
	end
end

-- How many of an item stand on the peak: placed copies plus starter pieces still out.
local function countOnPeak(peak: Model, itemId: string): number
	local n = 0
	for _, d in peak:GetDescendants() do
		if d:GetAttribute("ItemId") == itemId and (d:GetAttribute("PlacedId") or d:GetAttribute("StarterId")) then
			n += 1
		end
	end
	return n
end

local function context(peak: Model, ignore: { [Instance]: boolean }?): Placement.Context
	return { peak = peak, frame = Peak.frame(peak), index = Placement.newIndex(peak), ignore = ignore, probe = probe }
end

local function recordOf(data: PlayerData.Data, piece: Instance): (PlayerData.Placed?, number?)
	local id = piece:GetAttribute("PlacedId")
	for i, rec in data.peak.placed do
		if rec.u == id then
			return rec, i
		end
	end
	return nil, nil
end

-- Saved placement mode of a piece (starters stand on the floor).
local function modeOf(data: PlayerData.Data): (Instance) -> Placement.Mode
	return function(piece)
		local rec = recordOf(data, piece)
		return (rec and rec.m or "floor") :: Placement.Mode
	end
end

-- Quantise a request's pivot the way it's saved, so the check sees what gets built.
local function requestedPivot(frame: CFrame, pos: Vector3, yaw: number): (Vector3, number, CFrame)
	local p = Vector3.new(Peak.snap(pos.X, POS_STEP), Peak.snap(pos.Y, POS_STEP), Peak.snap(pos.Z, POS_STEP))
	local r = Peak.snap(yaw, 1) % 360
	return p, r, frame * CFrame.new(p) * CFrame.Angles(0, math.rad(r), 0)
end

local function validRequest(args: any): boolean
	return typeof(args.pos) == "Vector3" and type(args.yaw) == "number" and args.yaw == args.yaw
		and args.pos == args.pos and type(args.mode) == "string" and MODES[args.mode] == true
end

local function planted(data: PlayerData.Data, piece: Instance): boolean
	local plotId = piece:GetAttribute("PlotId")
	return type(plotId) == "string" and Garden.isPlanted(data, plotId)
end

local function place(player: Player, data: PlayerData.Data, peak: Model, args: any): (boolean, string?)
	local itemId = args.item
	if type(itemId) ~= "string" or not validRequest(args) then
		return false, "Bad request"
	end
	local def = BuildItems.Defs[itemId]
	local template = catalog:FindFirstChild(itemId)
	if not (def and template) then
		return false, "Unknown item"
	end
	if (data.decor[itemId] or 0) < 1 then
		return false, `You have no {def.name} left. Buy more at the Spirit Market`
	end
	if #data.peak.placed >= Config.MAX_ITEMS then
		return false, `Your peak holds at most {Config.MAX_ITEMS} items`
	end
	if def.limit and countOnPeak(peak, itemId) >= def.limit then
		return false, `Your peak holds at most {def.limit} {def.name}`
	end
	local ctx = context(peak)
	local pos, yaw, pivot = requestedPivot(ctx.frame, args.pos, args.yaw)
	local result = Placement.check(ctx, def, Placement.boxes(template, def), pivot, args.mode)
	if not result.ok then
		return false, result.reason
	end
	local rec: PlayerData.Placed = {
		u = HttpService:GenerateGUID(false):sub(1, 8),
		i = itemId,
		x = pos.X,
		y = pos.Y,
		z = pos.Z,
		r = yaw,
		m = if args.mode == "floor" then nil else args.mode,
	}
	if not Peaks.spawnPlaced(peak, rec) then
		return false, "Couldn't place that"
	end
	table.insert(data.peak.placed, rec)
	take(data, itemId)
	return true, nil
end

-- Take a piece off the peak: drop its record, or stash it if it's a starter.
local function removePiece(data: PlayerData.Data, peak: Model, piece: Instance)
	local _, i = recordOf(data, piece)
	if i then
		table.remove(data.peak.placed, i)
		piece:Destroy()
	else
		local starterId = piece:GetAttribute("StarterId") :: string
		data.peak.removed[starterId] = true
		Peaks.stashStarter(peak, starterId)
	end
end

local function ownPiece(peak: Model, target: any): Instance?
	if typeof(target) ~= "Instance" then
		return nil
	end
	local piece = Peak.pieceOf(target)
	return if piece and Peak.of(piece) == peak and Placement.isPiece(piece) then piece else nil
end

local function store(player: Player, data: PlayerData.Data, peak: Model, args: any): (boolean, string?)
	local piece = ownPiece(peak, args.target)
	if not piece then
		return false, "That isn't part of your peak"
	end
	local ctx = context(peak)
	local pieces = Placement.dependents(ctx, piece, modeOf(data))
	table.insert(pieces, 1, piece)
	for _, p in pieces do
		if planted(data, p) then
			return false, if p == piece then "Harvest this bed before storing it" else "Harvest the bed resting on it first"
		end
	end
	for _, p in pieces do
		local itemId = p:GetAttribute("ItemId")
		removePiece(data, peak, p)
		give(data, itemId)
	end
	return true, if #pieces > 1 then `Stored it and {#pieces - 1} item(s) resting on it` else nil
end

-- Put a piece at a new pivot, keeping its id when it's a placed item.
local function setPivot(data: PlayerData.Data, peak: Model, frame: CFrame, piece: Instance, pivot: CFrame, mode: string?)
	local l = frame:ToObjectSpace(pivot)
	local look = l.LookVector
	local yaw = math.deg(math.atan2(-look.X, -look.Z)) % 360
	local rec = recordOf(data, piece)
	if rec then
		rec.x, rec.y, rec.z, rec.r = l.X, l.Y, l.Z, yaw
		if mode then
			rec.m = if mode == "floor" then nil else mode
		end
		(piece :: Model):PivotTo(pivot)
		return
	end
	-- a starter: stash it and place a copy that saves like any placed item
	local newRec: PlayerData.Placed = {
		u = HttpService:GenerateGUID(false):sub(1, 8),
		i = piece:GetAttribute("ItemId") :: string,
		x = l.X,
		y = l.Y,
		z = l.Z,
		r = yaw,
		m = if mode and mode ~= "floor" then mode else nil,
	}
	removePiece(data, peak, piece)
	if Peaks.spawnPlaced(peak, newRec) then
		table.insert(data.peak.placed, newRec)
	end
end

local function move(player: Player, data: PlayerData.Data, peak: Model, args: any): (boolean, string?)
	local piece = ownPiece(peak, args.target)
	if not piece then
		return false, "That isn't part of your peak"
	end
	if not validRequest(args) then
		return false, "Bad request"
	end
	local def = Placement.defOf(piece) :: BuildItems.Def
	local probeCtx = context(peak)
	local riders = Placement.dependents(probeCtx, piece, modeOf(data))
	local ignore: { [Instance]: boolean } = { [piece] = true }
	for _, p in riders do
		ignore[p] = true
	end
	for _, p in { piece, table.unpack(riders) } do
		if p:GetAttribute("StarterId") and planted(data, p) then
			return false, "Harvest this bed before moving it"
		end
	end
	local ctx = probeCtx
	ctx.ignore = ignore
	local _, _, pivot = requestedPivot(ctx.frame, args.pos, args.yaw)
	local result = Placement.check(ctx, def, Placement.boxes(piece, def), pivot, args.mode, piece)
	if not result.ok then
		return false, result.reason
	end
	local entry = ctx.index.entries[piece]
	local delta = pivot * entry.pivot:Inverse()
	local moved: { { piece: Instance, pivot: CFrame } } = {}
	for _, p in riders do
		local e = ctx.index.entries[p]
		if e then
			local to = delta * e.pivot
			local world = Placement.worldBoxes(to, Placement.boxes(p, e.def))
			for _, b in world do
				if not Peak.inBounds(ctx.frame:PointToObjectSpace(b.cf.Position)) then
					return false, "Something resting on it would end up off your peak"
				end
			end
			if Placement.reservedHit(peak, world) then
				return false, "Something resting on it would block a path"
			end
			table.insert(moved, { piece = p, pivot = to })
		end
	end
	setPivot(data, peak, ctx.frame, piece, pivot, args.mode)
	for _, m in moved do
		setPivot(data, peak, ctx.frame, m.piece, m.pivot, nil)
	end
	return true, nil
end

-- The Spirit Market stall on the main peak, where items are bought.
local function marketNear(player: Player): boolean
	local hub = workspace:FindFirstChild("Hub")
	local market = hub and hub:FindFirstChild("SpiritMarket") :: Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return market ~= nil and root ~= nil and (root.Position - market:GetPivot().Position).Magnitude <= Config.MARKET_RANGE
end

local function buy(player: Player, data: PlayerData.Data, args: any): (boolean, string?)
	local itemId, count = args.item, args.count
	local def = type(itemId) == "string" and BuildItems.Defs[itemId]
	if not def or type(count) ~= "number" or count ~= count // 1 or count < 1 or count > Config.MAX_BUY then
		return false, "Bad request"
	end
	if not marketNear(player) then
		return false, "Buy build items at the Spirit Market on the main peak"
	end
	local ok, need = BuildItems.unlocked(def, data.realm)
	if not ok then
		return false, `{def.name} unlocks at {need}`
	end
	local price = def.cost * count
	if data.stones < price then
		return false, `You need {price - data.stones} more Spirit Stones`
	end
	data.stones -= price
	data.decor[def.id] = (data.decor[def.id] or 0) + count
	return true, `Bought {count} {def.name} for {price} Spirit Stones`
end

function Build.handle(player: Player, action: any, args: any): (boolean, string?)
	local now = os.clock()
	if now - (lastAction[player] or 0) < Config.MIN_INTERVAL then
		return false, "Slow down"
	end
	lastAction[player] = now
	local data = PlayerData.get(player)
	if not data or type(args) ~= "table" then
		return false, "Bad request"
	end
	args.mode = args.mode or "floor"
	local ok, message
	if action == "buy" then
		ok, message = buy(player, data, args)
		if ok then
			Cultivation.pushState(player)
		end
		return ok, message
	end
	local peak = Peaks.ownedBy(player)
	if not peak then
		return false, "You don't have a peak to build on"
	end
	if action == "place" then
		ok, message = place(player, data, peak, args)
	elseif action == "store" then
		ok, message = store(player, data, peak, args)
	elseif action == "move" then
		ok, message = move(player, data, peak, args)
	else
		return false, "Unknown action"
	end
	if ok then
		Cultivation.pushState(player) -- inventory counts changed
	end
	return ok, message
end

function Build.forget(player: Player)
	lastAction[player] = nil
end

return Build
