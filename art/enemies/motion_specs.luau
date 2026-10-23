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

-- The rest of the roster (added by the 2026-10-23 audit, docs/enemies/audit-2026-10-23.md). `map` is
-- the family's attack -> move table from FAMILIES; `moves` defaults to the headline attack.
SPECS.SpiritWolf = {
	module = "Wolf", template = "SpiritWolfB", def = "SpiritWolf", scale = 1,
	heroes = { mouth = "Skull.Mouth", chest = "Chest.Core", pawFR = "PawFR", tailTip = "TailTip" },
	map = { bite = "FangSnap", pounce = "MoonPounce", leap = "MoonfallLeap", howl = "Howl", hop = "Hop", pounceSkid = "PounceSkid", leapSkid = "LeapSkid" },
	lows = true, quiet = true,
	moves = { "pounce", { loop = "run", speed = 18, seconds = 2 } },
}

SPECS.StoneBoar = {
	module = "Boar", template = "StoneBoarB", def = "StoneBoar", scale = 1,
	heroes = { tusk = "Head.TuskTip", chest = "Chest.Core", hoofFR = "HoofFR.HoofFR_FX" },
	map = { charge = "Charge", gore = "Gore" },
	lows = true, quiet = true,
	moves = { { chain = { "charge", "gore" } }, { loop = "run", speed = 12, seconds = 2 } },
}

SPECS.ShadowManeWolf = {
	module = "ShadowMane", template = "ShadowManeWolfB", def = "ShadowManeWolf",
	scale = 1.63, keyedBlend = 0.06, deathSeconds = 0.7,
	heroes = { mouth = "Skull.Mouth", pawFR = "PawFR.PawFR_FX", mane = "Mane.ManeTop_FX", chest = "Chest.Core" },
	map = { shadowStep = "ShadowStep", shadowRake = "ShadowRake", shadowStepSkid = "ShadowStepSkid", maneRend = "ManeRend", maneLash = "ManeLash", hop = "Hop" },
	lows = true, quiet = true,
	moves = { { attack = "shadowStep", next = "shadowRake" }, { loop = "run", speed = 20, seconds = 2 } },
}

SPECS.VenomSerpent = {
	module = "VenomSerpent", template = "VenomSerpentB", def = "VenomSerpent",
	scale = 1, keyedBlend = 0.15, staggerSeconds = 0.28, deathSeconds = 0.9,
	heroes = { mouth = "Skull.Mouth", tailTip = "Tail5.TailTip_FX", body = "Body" },
	map = { venomSpit = "VenomSpit", hoodStrike = "HoodStrike", hoodStrikeSkid = "HoodStrikeSkid", hop = "Hop" },
	lows = true, quiet = true,
	moves = { "hoodStrike", { loop = "walk", speed = 5, seconds = 2 } },
}

SPECS.StoneTortoise = {
	module = "StoneTortoise", template = "StoneTortoiseB", def = "StoneTortoise", scale = 1.76,
	heroes = { mouth = "Head.Mouth", footFR = "FootFR.FootFR_FX", shell = "Shell.Core" },
	map = { neckSnap = "NeckSnap", quakeStomp = "QuakeStomp", shellGuard = "ShellGuard", shellSnap = "ShellSnap" },
	lows = true, quiet = true,
	moves = { "quakeStomp", { loop = "walk", speed = 3.5, seconds = 2 } },
}

SPECS.BloodCentipede = {
	module = "BloodCentipede", template = "BloodCentipede", def = "BloodCentipede",
	scale = 1, keyedBlend = 0.1, staggerSeconds = 0.4, deathSeconds = 2.0,
	heroes = { mouth = "Skull.Mouth", mid = "Seg6.Seg6_FX", tailTip = "Tail.TailTip_FX" },
	chains = { body = { "Collar", "Skull" }, segs = { "Collar", "Seg3", "Seg6", "Seg9", "Seg12", "Tail" } },
	map = { pincerSnap = "PincerSnap", coilSweep = "CoilSweep", burrowDive = "BurrowDive", erupt = "Erupt" },
	lows = true, quiet = true,
	moves = { "coilSweep", { loop = "run", speed = 18, seconds = 2 } },
}

SPECS.FlameRaven = {
	module = "FlameRaven", template = "FlameRavenB", def = "FlameRaven",
	scale = 1, keyedBlend = 0.08, deathSeconds = 1.5, staggerSeconds = 0.3,
	heroes = { mouth = "Skull.Mouth", talons = "Body.Talons_FX", wingTipR = "WingTipR.WingTipR_FX" },
	chains = { body = { "Body", "Neck", "Skull" }, wingR = { "Body", "UpperWingR", "ForeWingR", "WingTipR" } },
	map = { talonDive = "TalonDive", talonRake = "TalonRake", emberFan = "EmberFan", windGust = "WindGust", hop = "Hop", talonDiveSkid = "TalonDiveSkid" },
	lows = true, quiet = true,
	moves = { { attack = "talonDive", next = "talonRake" }, { loop = "walk", speed = 8, seconds = 2 } },
}

SPECS.BloodBat = {
	module = "BloodBat", template = "BloodBat", def = "BloodBat",
	scale = 1, keyedBlend = 0.06, deathSeconds = 1.2, staggerSeconds = 0.25,
	heroes = { mouth = "Skull.Mouth", wingTipR = "WingR3.WingTipR_FX", core = "Body.Core" },
	chains = { body = { "Body", "Skull" }, wingR = { "Body", "WingR", "WingR2", "WingR3" } },
	map = { bloodDive = "BloodDive", sonicShriek = "SonicShriek", hop = "Hop", bloodDiveSkid = "BloodDiveSkid" },
	lows = true, quiet = true,
	moves = { "bloodDive", { loop = "walk", speed = 10, seconds = 2 } },
}

SPECS.ElderWolfKing = {
	module = "WolfKing", template = "ElderWolfKingB", def = "ElderWolfKing",
	scale = 2.4, keyedBlend = 0.06, seamlessStrike = true, deathSeconds = 2.6,
	heroes = { mouth = "Skull.Mouth", pawFR = "PawFR.PawFR_FX", chest = "Chest.Core", seal = "Seal.SealFX" },
	map = {
		royalBite = "RoyalBite", kingsRush = "KingsRush", crownfall = "Crownfall", pawSwipe = "PawSwipe", clawDown = "ClawDown",
		packCall = "PackCall", roar = "Roar", kingLeap = "KingLeap", kingRake = "KingRake", kingLeapSkid = "KingLeapSkid", kingsRushSkid = "KingsRushSkid",
	},
	lows = true, quiet = true,
	moves = { "royalBite", { loop = "run", speed = 16, seconds = 2 } },
}

SPECS.JadeJiao = {
	module = "JadeJiao", template = "JadeJiao", def = "JadeJiao",
	scale = 1, keyedBlend = 0.2, seamless = true, deathSeconds = 3.6, staggerSeconds = 0.4,
	heroes = { mouth = "Skull.Mouth", tailTip = "Tail18.TailTip_FX", core = "Body.Core" },
	map = {
		emerge = "Emerge", venomFang = "VenomFang", tailSweep = "TailSweep", pillarSlam = "PillarSlam", fangFlurry = "FangFlurry",
		mireDive = "MireDive", erupt = "Erupt", venomLance = "VenomLance", venomSpray = "VenomSpray", venomPools = "VenomPools",
		jiaoCoil = "JiaoCoil", dreadHiss = "DreadHiss", molt = "Molt", ascension = "Ascension", venomRain = "VenomRain", tailShove = "TailShove",
	},
	lows = true, quiet = true,
	moves = { "tailSweep", { loop = "walk", speed = 8, seconds = 2 } },
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
