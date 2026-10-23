--!strict
-- NEW badges. The profile keeps what the Inventory has shown and when it first
-- did (State `seen`, PlayerData.seen: id -> os.time()): anything the player holds
-- that isn't in it is NEW. The "New" sort puts NEW first, then the most recently
-- first seen (seenAt). Seeing
-- something (hovering or choosing its cell, dragging it, or having it on the
-- hotbar) marks it here at once and tells the server in a batch a moment later
-- (InventoryAction "seen"), so it stays seen across sessions and devices. The
-- server forgets an id once none is left, so finding it again is NEW again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Weapons)
local State = require(script.Parent.State)

local FLUSH_DELAY = 0.8 -- seconds to gather sightings into one call

local Fresh = {}

local inventoryRemote = ReplicatedStorage.Remotes.InventoryAction :: RemoteFunction
local pending: { [string]: boolean } = {}
local local_: { [string]: boolean } = {} -- seen here, not yet in a snapshot
local scheduled = false
local listeners: { () -> () } = {}

local function seenSet(): { [string]: number }
	return (State.current :: any).seen or {}
end

-- Whether an id the player holds is NEW. Bare Fists never are; before the first
-- snapshot nothing is.
function Fresh.isNew(id: string): boolean
	local seen = (State.current :: any).seen
	if id == Weapons.FIST or seen == nil then
		return false
	end
	return not seen[id] and not local_[id]
end

-- When it was first seen (os.time(); huge while NEW, 0 for what was owned before
-- NEW badges existed), for the "New" sort.
function Fresh.seenAt(id: string): number
	if Fresh.isNew(id) then
		return math.huge
	end
	local at = seenSet()[id]
	return if type(at) == "number" then at elseif local_[id] then os.time() else 0
end

local function flush()
	scheduled = false
	local ids = {}
	for id in pending do
		table.insert(ids, id)
		if #ids >= 64 then
			break
		end
	end
	for _, id in ids do
		pending[id] = nil
	end
	if #ids > 0 then
		task.spawn(function()
			inventoryRemote:InvokeServer("seen", ids)
		end)
	end
	if next(pending) then
		scheduled = true
		task.delay(FLUSH_DELAY, flush)
	end
end

-- The player has seen these: clear their badges now, tell the server soon.
function Fresh.see(ids: { string })
	local any = false
	for _, id in ids do
		if Fresh.isNew(id) then
			local_[id] = true
			pending[id] = true
			any = true
		end
	end
	if not any then
		return
	end
	if not scheduled then
		scheduled = true
		task.delay(FLUSH_DELAY, flush)
	end
	for _, fn in listeners do
		task.spawn(fn)
	end
end

function Fresh.onChanged(fn: () -> ())
	table.insert(listeners, fn)
end

State.onChanged(function()
	-- the snapshot now carries what we sent; keep only sightings still in flight
	local seen = seenSet()
	for id in local_ do
		if seen[id] and not pending[id] then
			local_[id] = nil
		end
	end
end)

return Fresh
