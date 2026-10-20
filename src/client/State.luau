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
