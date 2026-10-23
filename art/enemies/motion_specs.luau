--!nocheck
-- Shared _G.MOTION specs for art/enemies/motion_probe.luau and tools/anim_filmstrip.luau, one per
-- keyed family: the family's EnemyAnimator values (scale, keyedBlend, seamless / seamlessStrike,
-- staggerSeconds, deathSeconds: copy them from FAMILIES in src/client/EnemyAnimator.luau), its
-- setup hook, hero points and a default move list. When you probe a family that isn't here, add
-- it; when you change a family's flags in EnemyAnimator, change them here too.
--
-- Use (art/enemies is served on 8767 by tools/serve.sh):
--   local S = loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8767/motion_specs.luau?" .. os.clock()))()
--   _G.MOTION = S.with("NineTailFox", { moves = { "tailSweep" }, steps = true })
-- `with(name, overrides)` returns a fresh copy with the overrides on top.
local SPECS = {}

SPECS.ThunderApe = {
	module = "ThunderApe", template = "ThunderApeB", def = "ThunderApe",
	scale = 3.71, keyedBlend = 0.06, seamless = true, staggerSeconds = 0.45, deathSeconds = 3.2,
	heroes = { fistR = "HandFR.FistR_FX", mouth = "Skull.Mouth", chest = "Chest.Core" },
	lows = true, quiet = true,
	moves = {
		"clubSwing",
		{ attack = "bound", input = { mode = "over" } },
		{ loop = "walk", speed = 6, seconds = 2 },
	},
}

SPECS.NineTailFox = {
	module = "NineTailFox", template = "NineTailFoxB", def = "NineTailFox",
	scale = 2.13, keyedBlend = 0.06, seamlessStrike = true, deathSeconds = 3.2,
	-- the tails need the rig's real layout and the head guard (without it they use the defaults)
	setup = function(M, template)
		M.configure(template, 2.13)
	end,
	heroes = { head = "Head", tailTip = "Tail5Tip", pawFR = "PawFR" },
	lows = true, steps = true, quiet = true,
	moves = {
		"rendingPounce",
		"tailSweep",
		{ loop = "run", speed = 14, seconds = 2 },
	},
}

local function with(name, overrides)
	local base = SPECS[name] or error("no motion spec " .. tostring(name) .. " (add it to motion_specs.luau)")
	local out = table.clone(base)
	for k, v in overrides or {} do
		out[k] = v
	end
	return out
end

return { specs = SPECS, with = with }
