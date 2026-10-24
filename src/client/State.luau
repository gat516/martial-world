--!strict
-- Latest PlayerState snapshot from the server, with change listeners.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Buff = { source: string, kind: string, amount: number, expires: number, seconds: number? } -- seconds: its full span (the chip's timer ring)
export type Technique = { level: number, xp: number }
export type Snapshot = {
	techniques: { owned: { [string]: Technique }, manuals: { [string]: boolean }? }, -- manuals: found, waiting on weapon Dao
	hotbar: { string }, -- technique id, item id or "" per slot
	rate: number,
	aura: number,
	herbs: { [string]: number },
	items: { [string]: number },
	seeds: { [string]: number },
	ring: { string }?, -- spirit ring: herb and item ids whose stacks are banked even in the wilds (server Haul)
	ringSlots: number?, -- stacks the ring holds at this realm
	buffs: { Buff },
	decor: { [string]: number }?,
	meditation: { multiplier: number, place: string }?, -- nil when not meditating
	settings: { music: number, sfx: number, autoAttack: boolean, lockHint: boolean }?,
	weapons: { owned: { [string]: number }, equipped: string }?, -- equipped "" = Fist (Shared.Weapons)
	dao: { [string]: { level: number, xp: number } }?, -- by weapon class; missing = level 0
	caches: { [string]: boolean }?, -- world manual caches / weapon racks claimed, by Cache id
	seen: { [string]: number }?, -- ids the Inventory has shown, by os.time() first seen; held and not here = NEW (Fresh)
	inventoryView: { [string]: { sort: string, filter: string } }?, -- the Inventory's saved sort and filter per tab
	root: { element: string, grade: string, pending: string, grades: { [string]: string } }?, -- spirit root (Shared.Roots); element "" = not tested, pending = a reformed element awaiting keep/return ("" = none), grades = other elements' own grades
	methods: { owned: { [string]: boolean }, active: string }?, -- cultivation methods (Shared.Methods); active "" = Sect Breathing
	daoPracticeReady: number?, -- os.time() when the next Practice Dao drill opens (server DaoPractice)
	-- the current stage's foundation (server Foundation.state; docs/ui/cultivation.md):
	-- count/target experiences, the grade it would get now, past grades by stage key,
	-- the summed bonus share, and up to 5 open experiences { category, text }
	foundation: { count: number, target: number, grade: string, grades: { [string]: string }, bonus: number, hints: { { category: string, text: string } } }?,
	-- the heart-demon trial (server HeartDemon.state): the open major's id and name (nil
	-- when none), whether the player is at a stage 9 (the Break Through offer), whether a seat offer waits out
	-- a "Not now", and finished trials by major (`note` is the heart line for the Self card)
	heartDemon: {
		open: string?,
		name: string?,
		atPeak: boolean,
		snoozed: boolean,
		trials: { [string]: { calm: boolean, denials: number, tempered: number, note: string, at: number } },
	}?,
}

local State = {}

State.current = {
	techniques = { owned = {}, manuals = {} },
	hotbar = { "", "", "", "", "", "", "", "", "" },
	rate = 0,
	aura = 0,
	herbs = {},
	items = {},
	seeds = {},
	buffs = {},
	decor = {},
	weapons = { owned = {}, equipped = "" },
	dao = {},
} :: Snapshot

local listeners: { (Snapshot) -> () } = {}

function State.onChanged(fn: (Snapshot) -> ())
	table.insert(listeners, fn)
	fn(State.current)
end

(ReplicatedStorage.Remotes.PlayerState :: RemoteEvent).OnClientEvent:Connect(function(snapshot: Snapshot)
	State.current = snapshot
	for _, fn in listeners do
		task.spawn(fn, snapshot)
	end
end)

return State
