--!strict
-- Latest PlayerState snapshot from the server, with change listeners.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Buff = { source: string, kind: string, amount: number, expires: number }
export type Technique = { level: number, xp: number }
export type Snapshot = {
	insight: number,
	techniques: { owned: { [string]: Technique } },
	hotbar: { string }, -- technique id, item id or "" per slot
	rate: number,
	aura: number,
	herbs: { [string]: number },
	items: { [string]: number },
	seeds: { [string]: number },
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
}

local State = {}

State.current = {
	insight = 0,
	techniques = { owned = {} },
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
