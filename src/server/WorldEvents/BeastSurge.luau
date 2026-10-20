--!strict
-- World event kind: beasts across the open wilds grow restless. Ambient
-- encounters (Spawner.luau) come more often and in bigger packs while it runs.
-- Def settings: rate, extra (see Spawner.boost).

local Spawner = require(script.Parent.Parent.Spawner)

local BeastSurge = {}

function BeastSurge.start(run: any): boolean
	local def = run.def
	local stop = Spawner.boost(def.id, { rate = def.rate, extra = def.extra })
	run.onEnd(function()
		stop()
		run.announce("The beasts of the wilds settle down again.")
	end)
	run.announce("The beasts of the wilds are restless! Packs roam the open ground. Travel carefully, or hunt them.")
	return true
end

return BeastSurge
