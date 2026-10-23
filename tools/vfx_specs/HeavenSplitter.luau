--!nocheck
-- Heaven-Splitting Descent's templates (HeavenSplitter_T1..T4). Build with
-- HeavenSplitter.build(parent) (its own blocks first, then vfxBlocks').
-- Runtime: src/client/TechniqueFX/HeavenSplitter.luau (+ BladeSkill.luau).
--
-- The move (Greatsword, anim 90109091413405, 3.67 s, castSpeed ~1.3; clip
-- seconds below, real = clip / castSpeed). Sampled on gsrigrea2lfixed:
--   0.00-0.20  the blade swings back to the right, low.
--   0.45-0.60  the LOW SWEEP: the tip skims the ground across the whole front,
--              right to left. (The def's first hit is 0.18-0.37, by body
--              speed; the blade actually crosses the front at 0.45-0.58.)
--   0.60-1.00  crouch, blade held low-left behind, torso drives forward.
--   1.05-1.25  the RISING CUT: low front -> straight up overhead; the body
--              launches (up 3.8 by 1.7) - the "launch" hit 1.02-1.22.
--   1.25-2.10  airborne, blade raised behind the head, hands at y+6.
--   2.10-2.25  the SLAM: the blade falls from behind the head and strikes the
--              ground ahead (2.22-2.25); the body lands in a deep crouch.
--   2.25-2.65  held in the ground; recovery to 3.0.
-- Gameplay: hits { 0.18 light, 1.02 light, 2.12 slam }, lunge 6, circle r 12
-- centred 4 ahead of the landing.
--
-- INTENT (heavy pass 2026-10-23): the greatsword falls from the top of the
-- leap and the heavens follow it down. One peak, at the bite: a column of
-- heaven-azure light lands on the point, the ground bursts and a shock rolls
-- out to the radius, then the rend splits the circle. The player should feel
-- weight and finality; the job is the fight's hero hit confirm (AoE r 12).
-- Palette: heaven azure, white core (gold at mastery), ink and umber darks.
--
-- BEAT SHEET (real ms at castSpeed 1.3; clip markers drive every beat):
--   0      cast start: the Charge along the blade; Draw sound (at Hit 1)
--   280    the low sweep moves (clip 0.36): Sweep whoosh; light hits at its peak
--   770    the rising cut (clip 1.0): Rise whoosh; light hits
--   850    Leap: wind ring + dust at the feet, II+ updraft rings; Leap sound
--   960-1700 the hang (anticipation, ~40%): blade glow, III+ seal and sky
--          rift opening, III+ phantom blade; Gather sound rising, cut at the bite
--   ~1700  PEAK, the bite (Hit 3 window, WeaponFX.swing): core + star, column,
--          dust burst, shock front; Bite + Break + Rumble (+ III+ Thunder)
--   1700-2200 follow-through: ragged wind ring and dust wall roll to r 12,
--          heavy impacts as the front reaches each enemy, rend carving (+60 ms
--          Rend sound), III+ rock ring
--   2200-3700 dissipation: dust settles, the rend cools to ink, the scar fades
--
-- DIRECTIONS (spec.variant; the slam peak only, everything else is shared):
--   A "Sky cleave" (THE PICK, critic 2026-10-23): the column of light from
--     the sky onto the bite, plus B's dust burst as the explosion under it.
--   B "Earth break": the explosive dust burst is the hero, bigger, with a
--     slate shard fan heaving up; rock-coloured shock ring with an ink copy.
--   C "Heaven's judgement": a needle-thin white line from the sky for two
--     frames, then a cold mist creeping flat over the circle.
--
-- LAYER SHEET (role: cause -> asset and why; tier I / IV counts in the doc)
-- Column       HERO: the heavens splitting down onto the blade's bite -> streaked light column 12781750620 (FacingCameraWorldUp, squashed thin) on an ink copy of itself
-- Burst        secondary: the ground breaking under the blade's mass -> explosive puff flipbook 12360899465 (4x4) over an umber copy
-- Front        secondary: the shock of the bite racing out -> jagged ring 85827484380910, 0.2 s; secondary the travel: ragged wind ring mesh 99300490107593 to r 12
-- DustWall     tertiary: air shoved along the ground -> dust cloud flipbook 113990972016632 (4x4)
-- Strike       support: the contact instant -> core dot 9841273544, core star flipbook 13580358178
-- Scar         environment: the circle left broken (III+) -> crater 90713203428310, cracks 93520831389146
-- LaunchRing   secondary: air pushed off by the leap -> ragged wind ring mesh 107819007023719
-- Heave (B)    secondary: rock heaved by the mass -> shard fan mesh 114192967647602
-- Verdict (C)  HERO: the sky's single line -> needle slash 107059622686856; secondary mist 137279303567615
--
-- Earlier history (remake 2026-10-21, QA pass 2026-10-21) is in
-- docs/combat/techniques/heaven-splitter.md.
local KIT_ = function()
	return _G.vfxSpecs.BladeKit
end
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local CSK = ColorSequenceKeypoint.new
local spec -- set at the bottom; blocks read spec.variant
local V = Vector3.new
local O = CFrame.new()
local id = function(n)
	return "rbxassetid://" .. n
end

local AZURE = Color3.fromRGB(128, 156, 255) -- suggested def.color
local CORE = Color3.fromRGB(236, 242, 255)
local GOLD = Color3.fromRGB(255, 232, 170) -- mastery core
local INK = Color3.fromRGB(22, 24, 48)
local N_AZURE = Color3.fromRGB(78, 108, 240) -- Neon blooms, so parts go deeper
local N_PALE = Color3.fromRGB(150, 175, 255)
local DUST = Color3.fromRGB(214, 210, 200)
local UMBER = Color3.fromRGB(70, 58, 50) -- the dark copy under the dust burst
local SLATE = Color3.fromRGB(92, 94, 108) -- heaved rock

local RADIUS, OFFSET = 12, 4
local CENTRE = O * CFrame.new(0, 0.2, -OFFSET)
local HAND_AT = O * CFrame.new(1.1, 2.2, -0.9)

local A = {
	seal = id(83667248904000),
	ornate = id(13399941667),
	crater = id(90713203428310),
	crack = id(93520831389146),
	crackSmall = id(97725700315217),
	spindle = id(7814053668),
	mote = id(9841260273),
	glow = id(867619398),
	dust = id(11037785287),
	hitRing = id(13052235894),
	torus = id(471124075),
	swirl = id(129778117978668),
	swirl2 = id(73349240058321),
	dome = id(13567208057),
	dot = id(9841273544), -- core only
	starFlip = id(13580358178), -- core only: 4x4 star burst
	cleave = id(4543893907), -- heavy streaked crescent: the overhead cut (A)
	column = id(12781750620), -- streaked vertical light column (A)
	burst = id(12360899465), -- 4x4 explosive puff opening into a ring (B)
	heave = id(114192967647602), -- mesh: a fan of shards flaring up (B)
	spindle2 = id(107059622686856), -- needle-thin vertical slash line (C)
	mist = id(137279303567615), -- radial dust/mist disc (C)
	spikyRing = id(85827484380910), -- jagged shock ring
	raggedRing = id(99300490107593), -- mesh: ragged wind ring
	dustFlip = id(113990972016632), -- 4x4 dust cloud breaking up
	windRing = id(107819007023719), -- mesh: thin ragged wind ring (launch)
}

local function pal(core)
	return {
		color = AZURE, core = core or CORE,
		ringColor = Color3.fromRGB(120, 150, 255), swirlColor = Color3.fromRGB(110, 140, 255), groundColor = Color3.fromRGB(105, 135, 250),
	}
end
local function B_flat(props, dir)
	return _G.vfxBlocks.flat(props, dir)
end
local function coreOf(tier)
	return if tier >= 4 then GOLD else CORE
end

local blocks = {}

-- anticipation along the greatsword (Base -> Tip), played at cast start; the
-- hand gather below is only the fallback for a missing weapon rig
blocks.charge = function(root, tier)
	return _G.vfxBlocks.bladeCharge(root, tier, { color = AZURE, core = coreOf(tier), ink = INK, width = 0.6 })
end

-- the flare on the live blade tip as each Hit marker fires (1.5x at the slam)
blocks.flare = function(root, tier)
	return _G.vfxBlocks.bladeFlare(root, tier, { color = AZURE, core = coreOf(tier), ink = INK })
end


blocks.edge = function(root, tier)
	return KIT_().edge(root, tier, { color = AZURE, core = coreOf(tier), tail = N_PALE, trailLife = { 0.18, 0.22, 0.26, 0.32 }, glowWidth = { 0.35, 0.45, 0.55, 0.7 } })
end

-- the light hits (sweep and launch): a smaller impact stack
blocks.lightImpact = function(root, tier)
	local B0 = _G.vfxBlocks
	local q = pal(coreOf(tier))
	q.part = "LightImpact"
	B0.impactBurst(root, tier, q)
	q.size = ({ 2.6, 3.1, 3.6, 4.2 })[tier]
	q.groundSize = ({ 2.8, 3.3, 3.8, 4.4 })[tier]
	q.swirl, q.bubble = false, false
	q.duration = 0.24
	B0.impactShockwave(root, tier, q)
	return root:FindFirstChild("LightImpact")
end

-- the take-off at the feet (launch hit)
blocks.launch = function(root, tier)
	local B0 = _G.vfxBlocks
	local part = B0.part(root, "Launch", O * CFrame.new(0, 0.2, 0))
	B0.meshWave(part, "LaunchRing", {
		mesh = A.windRing, color = Color3.fromRGB(110, 140, 255),
		fromSize = V(1.6, 0.4, 1.6), toSize = V(7 + tier, 1 + tier * 0.15, 7 + tier),
		fromOffset = V(0, 0.15, 0), toOffset = V(0, 0.15, 0),
		fromTransparency = 0.3, toTransparency = 1, duration = 0.4, style = "Quart",
	}):SetAttribute("FadeStyle", "Quint")
	B0.emitter(part, "Dust", {
		Texture = A.dust, Color = CS(DUST), LightInfluence = 0.5,
		EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180),
		Size = NS({ KP(0, 0.8), KP(1, 2.2) }), Transparency = NS({ KP(0, 0.35), KP(0.5, 0.55), KP(1, 1) }),
		Lifetime = R(0.45, 0.7), Speed = R(16, 22), Drag = 4, Rotation = R(0, 360), RotSpeed = R(-60, 60),
	}, { EmitCount = ({ 6, 8, 10, 12 })[tier] })
	if tier >= 2 then
		-- swirl rings rising up the body: the updraft that carries the leap
		for i = 1, ({ 0, 2, 2, 3 })[tier] do
			local w = B0.meshWave(part, "Updraft" .. i, {
				mesh = A.swirl, color = N_PALE,
				fromSize = V(2.4, 0.3, 2.4), toSize = V(4.2 - i * 0.4, 0.9, 4.2 - i * 0.4),
				fromOffset = V(0, 0.6, 0), toOffset = V(0, 6 + i * 0.8, 0),
				fromTransparency = 0.25, toTransparency = 1, duration = 0.42, style = "Quad",
				delay = (i - 1) * 0.07,
			})
			w:SetAttribute("FadeStyle", "Quint")
		end
	end
	if tier >= 3 then
		B0.emitter(part, "Streaks", {
			Texture = A.spindle, Color = CS(coreOf(tier), AZURE), Orientation = Enum.ParticleOrientation.VelocityParallel,
			Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(6, 6),
			Size = NS({ KP(0, 0.3), KP(1, 0) }), Squash = NS(2.5), Transparency = NS({ KP(0, 0), KP(1, 0.6) }),
			Lifetime = R(0.25, 0.4), Speed = R(26, 34), Drag = 3, LightEmission = 0.5,
		}, { EmitCount = ({ 0, 0, 6, 9 })[tier] })
	end
	return part
end

-- III+: the rune seal over the landing circle while airborne (held long and
-- faint: it marks r 12 without hiding any ground warning)
blocks.mark = function(root, tier)
	local B0 = _G.vfxBlocks
	local part = B0.part(root, "Mark", CENTRE)
	part:SetAttribute("AuthoredAir", 0.67)
	B0.emitter(part, "Seal", B0.flat({
		Texture = A.seal, Color = CS(AZURE), LightEmission = 0.35,
		Size = NS({ KP(0, RADIUS * 1.0), KP(0.4, RADIUS * 1.45), KP(1, RADIUS * 1.5) }),
		Transparency = NS({ KP(0, 1), KP(0.15, 0.4), KP(0.85, 0.3), KP(1, 1) }),
		Lifetime = R(0.67), RotSpeed = R(28), Rotation = R(0, 360), ZOffset = 0.2,
	}), { EmitCount = 1 })
	return part
end

-- III+: a vertical rift torn in the sky above the landing (two tapered Beams,
-- widened by the runtime while airborne), shedding sparks downward
blocks.rift = function(root, tier)
	local B0 = _G.vfxBlocks
	local h = ({ 0, 0, 14, 18 })[tier]
	local part = B0.part(root, "Rift", CENTRE * CFrame.new(0, 6 + h / 2, 0))
	part:SetAttribute("Width", ({ 0, 0, 1.1, 1.5 })[tier])
	local top = B0.attach(part, "Top", V(0, h / 2, 0))
	local mid = B0.attach(part, "Mid", V(0, 0, 0))
	local bottom = B0.attach(part, "Bottom", V(0, -h / 2, 0))
	for i, pair in { { top, mid, 0, 1 }, { mid, bottom, 1, 0 } } do
		for layer, look in { Core = { coreOf(tier), 0, 0.5, 0.6 }, Glow = { AZURE, 0.35, 2.6, 0.4 } } do
			local b = Instance.new("Beam")
			b.Name = layer .. (if i == 1 then "Upper" else "Lower")
			b.Attachment0, b.Attachment1 = pair[1], pair[2]
			b.Width0, b.Width1 = 0, 0 -- the runtime opens it: Width * look[3] at Mid
			b:SetAttribute("Scale", look[3])
			b.FaceCamera = true
			b.Color = CS(look[1])
			b.Transparency = NS(look[2])
			b.LightEmission, b.LightInfluence = look[4], 0
			b.Segments = 2
			b.Enabled = false
			b.Parent = part
		end
	end
	B0.emitter(part, "Sparks", {
		Texture = A.spindle, Color = CS(coreOf(tier), AZURE), Orientation = Enum.ParticleOrientation.VelocityParallel,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(10, 10),
		Size = NS({ KP(0, 0.25), KP(1, 0) }), Squash = NS(2), Transparency = NS({ KP(0, 0.1), KP(1, 0.8) }),
		Lifetime = R(0.3, 0.5), Speed = R(10, 18), LightEmission = 0.5, Rate = ({ 0, 0, 14, 22 })[tier],
	})
	part.Size = V(0.4, h * 0.6, 0.4)
	return part
end

-- IV (III fainter): a giant phantom blade the runtime lays over the real one
-- from the top of the leap down into the ground
blocks.phantom = function(root, tier)
	local B0 = _G.vfxBlocks
	local K = KIT_()
	local holder = B0.part(root, "Phantom", O * CFrame.new(0, 6, 2))
	holder:SetAttribute("Length", ({ 0, 0, 11, 14 })[tier]) -- studs, base to tip
	holder:SetAttribute("Width", ({ 0, 0, 1.6, 2.1 })[tier])
	holder:SetAttribute("StartTransparency", ({ 0, 0, 0.55, 0.25 })[tier])
	holder:SetAttribute("Hold", 0.25)
	holder:SetAttribute("Fade", 0.5)
	-- blade body (Neon at IV, ForceField at III) plus a ForceField aura; the
	-- tip is a wedge. Sizes are per stud of Length/Width, set at runtime.
	K.heldWave(holder, "Body", { color = if tier >= 4 then N_AZURE else N_PALE, material = if tier >= 4 then Enum.Material.Neon else Enum.Material.ForceField })
	K.heldWave(holder, "Aura", { color = AZURE, material = Enum.Material.ForceField })
	local _, tip = K.heldWave(holder, "Tip", { color = if tier >= 4 then N_AZURE else N_PALE, material = if tier >= 4 then Enum.Material.Neon else Enum.Material.ForceField })
	-- swap the Tip's block for a wedge
	local wedge = Instance.new("WedgePart")
	wedge.Name = "Mesh"
	wedge.Anchored, wedge.CanCollide, wedge.CanQuery, wedge.CanTouch, wedge.CastShadow = true, false, false, false, false
	wedge.Material, wedge.Color, wedge.Transparency = tip.Material, tip.Color, 1
	wedge.Parent = tip.Parent
	tip:Destroy()
	return holder
end

-- THE PEAK: three directions for the slam, built from the same spec
-- (spec.variant, default "A"; see the header). Everything at the bite lives on
-- `Strike` (placed at the ground under the blade's point, looking along the
-- cut: local Y up, -Z ahead, so the swing plane is local YZ); everything that
-- rolls out to the radius lives on `Slam` (the circle's centre).
local function variant()
	return spec.variant or "A"
end

-- the bite: where the blade strikes the ground
blocks.strike = function(root, tier)
	local B0 = _G.vfxBlocks
	local v = variant()
	local core = coreOf(tier)
	local part = B0.part(root, "Strike", O * CFrame.new(0.4, 0.2, -3))
	-- the white-hot instant of contact (core: the hard dot and the star burst)
	B0.emitter(part, "Core", {
		Texture = A.dot, Color = CS(core), LightEmission = 1, Brightness = 3,
		Size = NS({ KP(0, ({ 2.4, 2.8, 3.2, 3.6 })[tier]), KP(1, 0.4) }), Transparency = NS({ KP(0, 0), KP(1, 1) }),
		Lifetime = R(0.09), ZOffset = 1,
	}, { EmitCount = 1 })
	B0.emitter(part, "Star", {
		Texture = A.starFlip, Color = CS(core, AZURE), LightEmission = 0.8, Brightness = 2,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Size = NS({ KP(0, ({ 4.5, 5.5, 6.5, 7.5 })[tier]), KP(1, ({ 6, 7, 8, 9.5 })[tier]) }), Transparency = NS({ KP(0, 0), KP(1, 0.2) }),
		Lifetime = R(0.2), Rotation = R(0, 360), ZOffset = 0.8,
	}, { EmitCount = 1 })
	if v == "A" then
		-- (the cut's own arc is the blade's Edge trail)
		do
			-- the heavens split down onto the bite: a column of light that lands
			-- at full height and collapses inward
			local H = ({ 20, 28, 36, 46 })[tier]
			local col = B0.attach(part, "ColumnAt", V(0, H / 2, 0))
			B0.emitter(col, "ColumnInk", {
				Texture = A.column, Color = CS(INK), Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
				LightEmission = 0, LightInfluence = 0.2,
				Size = NS({ KP(0, H / 1.45), KP(0.25, H / 2.2), KP(0.5, H / 3.2), KP(1, H / 3.6) }), Squash = NS({ KP(0, 0.45), KP(0.25, 1.2), KP(0.5, 2.2), KP(1, 2.6) }),
				Transparency = NS({ KP(0, 0.35), KP(0.4, 0.5), KP(1, 1) }), Lifetime = R(({ 0.22, 0.26, 0.28, 0.32 })[tier]), ZOffset = -1,
			}, { EmitCount = 1 })
			B0.emitter(col, "Column", {
				Texture = A.column, Color = CS(core, N_PALE), Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
				LightEmission = 0.8, Brightness = 1.3,
				-- Squash s draws a particle (1 + s)x tall and 1 / (1 + s) wide, so
				-- the size shrinks as it thins to keep the column H tall
				-- lands wide (first ~0.08 s), then thins
				Size = NS({ KP(0, H / 1.6), KP(0.25, H / 2.5), KP(0.5, H / 3.6), KP(1, H / 4) }), Squash = NS({ KP(0, 0.6), KP(0.25, 1.5), KP(0.5, 2.6), KP(1, 3) }),
				Transparency = NS({ KP(0, 0), KP(0.35, 0.2), KP(1, 1) }), Lifetime = R(({ 0.22, 0.26, 0.28, 0.32 })[tier]),
			}, { EmitCount = 1 })
		end
	end
	if v == "A" or v == "B" then
		-- the ground breaking under the blade's mass: an explosive dust burst
		-- over a dark umber copy (A: secondary under the column; B: the hero,
		-- bigger, with a fan of rock heaved up)
		local s = ({ 7, 8.5, 10, 12 })[tier]
		local at = B0.attach(part, "BurstAt", V(0, s * 0.3, 0))
		B0.emitter(at, "BurstInk", {
			Texture = A.burst, Color = CS(UMBER), LightEmission = 0, LightInfluence = 0.6,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			-- dies before the flipbook's last frames open into a ring (a floating
			-- dark ring read as a halo)
			Size = NS({ KP(0, s * 0.8), KP(1, s * 1.1) }), Transparency = NS({ KP(0, 0.05), KP(0.3, 0.6), KP(0.6, 0.9), KP(1, 1) }),
			Lifetime = R(0.22), Rotation = R(0, 360), ZOffset = -0.6,
		}, { EmitCount = 1 })
		B0.emitter(at, "Burst", {
			Texture = A.burst, Color = CS(DUST), LightEmission = 0.1, LightInfluence = 0.8,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Size = NS({ KP(0, s * 0.6), KP(1, s * 0.95) }), Transparency = NS({ KP(0, 0), KP(0.5, 0.45), KP(0.7, 0.95), KP(1, 1) }),
			Lifetime = R(0.3), Rotation = R(0, 360),
		}, { EmitCount = 1 })
		if v == "B" then
			B0.meshWave(part, "Heave", {
				mesh = A.heave, color = SLATE, material = Enum.Material.Slate,
				fromSize = V(s * 0.3, s * 0.1, s * 0.3), toSize = V(s * 0.75, s * 0.42, s * 0.75),
				fromOffset = V(0, -0.4, 0), toOffset = V(0, -0.1, 0),
				fromTransparency = 0, toTransparency = 1, duration = 0.6, style = "Quart",
			}):SetAttribute("FadeStyle", "Quint")
		end
	end
	if v == "C" then
		-- HERO: judgement, one sharp white line from the sky into the bite,
		-- two frames, then a cold mist creeping out
		local H = ({ 20, 26, 34, 44 })[tier]
		local col = B0.attach(part, "VerdictAt", V(0, H / 2, 0))
		B0.emitter(col, "Verdict", {
			Texture = A.spindle2, Color = CS(core), Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
			LightEmission = 1, Brightness = 5,
			Size = NS({ KP(0, H), KP(1, H * 1.05) }), Squash = NS(0), Transparency = NS({ KP(0, 0), KP(0.6, 0), KP(1, 1) }),
			Lifetime = R(0.07),
		}, { EmitCount = 1 })
		B0.emitter(part, "Mist", B0.flat({
			Texture = A.mist, Color = CS(Color3.fromRGB(196, 214, 255)), LightEmission = 0.2, LightInfluence = 0.5,
			Size = NS({ KP(0, 4), KP(0.3, RADIUS * 1.4), KP(1, RADIUS * 2) }), Transparency = NS({ KP(0, 0.3), KP(0.5, 0.55), KP(1, 1) }),
			Lifetime = R(1.1), Rotation = R(0, 360), RotSpeed = R(-12, 12),
		}), { EmitCount = 1, EmitDelay = 0.05 })
	end
	-- tertiary: chips and dust kicked up by the edge
	B0.emitter(part, "Chips", {
		Texture = A.dust, Color = CS(DUST), LightInfluence = 0.8,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40),
		Size = NS({ KP(0, 0.7), KP(1, 1.8) }), Transparency = NS({ KP(0, 0.3), KP(1, 1) }),
		Lifetime = R(0.4, 0.65), Speed = R(9, 15), Drag = 4, Rotation = R(0, 360), Acceleration = V(0, -12, 0),
	}, { EmitCount = 3 + tier })
	return part
end

-- what rolls out from the slam to the radius
blocks.slam = function(root, tier)
	local B0 = _G.vfxBlocks
	local v = variant()
	local ground = B0.part(root, "Slam", CENTRE)
	local k = RADIUS / 12
	-- SECONDARY: the shock front, a spiky ring over an ink copy (the 3D ragged
	-- wind ring rides it); the runtime times the heavy impacts by GroundWave
	local front = v == "A" and AZURE or (v == "B" and DUST or N_PALE)
	B0.emitter(ground, "FrontInk", B0.flat({
		Texture = A.spikyRing, Color = CS(INK), LightEmission = 0, LightInfluence = 0.3,
		Size = NS({ KP(0, 2), KP(0.35, RADIUS * 1.55), KP(1, RADIUS * 2.1) }), Transparency = NS({ KP(0, 0.2), KP(0.5, 0.45), KP(1, 1) }),
		Lifetime = R(0.5), Rotation = R(0, 360), ZOffset = -0.2,
	}), { EmitCount = v == "B" and 1 or 0 })
	B0.emitter(ground, "Front", B0.flat({
		Texture = A.spikyRing, Color = CS(coreOf(tier), front), LightEmission = v == "B" and 0.2 or 1, Brightness = 2,
		Size = NS({ KP(0, RADIUS * 0.35), KP(0.5, RADIUS * 0.8), KP(1, RADIUS) }), Transparency = NS({ KP(0, 0), KP(0.5, 1), KP(1, 1) }),
		Lifetime = R(0.2), Rotation = R(0, 360),
	}), { EmitCount = 1 })
	B0.meshWave(ground, "GroundWave", {
		mesh = A.raggedRing, color = v == "B" and SLATE or N_PALE, material = v == "B" and Enum.Material.Slate or Enum.Material.Neon,
		fromSize = V(2, 0.6, 2), toSize = V(RADIUS * 2.4, (1.6 + tier * 0.3) * k, RADIUS * 2.4),
		fromOffset = V(0, 0.3, 0), toOffset = V(0, 0.3, 0),
		fromTransparency = v == "B" and 0.1 or 0.25, toTransparency = 1, duration = 0.5, style = "Quint",
	}):SetAttribute("FadeStyle", "Quint")
	-- the dust wall shoved out along the ground (dust flipbook, lit like dust)
	B0.emitter(ground, "DustWall", {
		Texture = A.dustFlip, Color = CS(DUST), LightEmission = 0, LightInfluence = 1,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(4, 180),
		Size = NS({ KP(0, 2), KP(1, (v == "B" and 6.5 or 4.5) + tier * 0.4) }), Transparency = NS({ KP(0, 0.15), KP(0.6, 0.4), KP(1, 1) }),
		Lifetime = R(0.7, 1.0), Speed = R(30 * k, 38 * k), Drag = 3, Rotation = R(0, 360), RotSpeed = R(-40, 40),
	}, { EmitCount = (v == "B" and 14 or (v == "C" and 6 or 10)) + tier * 2 })
	if tier >= 3 then
		B0.craterRing(root, tier, { parent = "Slam", attrs = {
			Radius = RADIUS * 0.75, Count = ({ 0, 0, 10, 14 })[tier] + (v == "B" and 4 or 0), Duration = 0.36,
			Size = V(1.5, 1.1, 1.3), Lifetime = R(1.4, 1.8),
		} })
		-- environment: the scar left under the bite's circle
		B0.emitter(ground, "Crater", B0.flat({
			Texture = A.crater, Color = CS(Color3.fromRGB(56, 52, 70)), LightInfluence = 0.4,
			Size = NS(({ 0, 0, 5.5, 7 })[tier]), Transparency = NS({ KP(0, 1), KP(0.03, 0.1), KP(0.75, 0.25), KP(1, 1) }),
			Lifetime = R(2.2), Rotation = R(0, 360), ZOffset = -0.3,
		}), { EmitCount = 1 })
		B0.emitter(ground, "Cracks", B0.flat({
			Texture = A.crack, Color = CS(INK), LightInfluence = 0.3,
			Size = NS(({ 0, 0, 10, 13 })[tier]), Transparency = NS({ KP(0, 1), KP(0.03, 0.05), KP(0.7, 0.2), KP(1, 1) }),
			Lifetime = R(2.3), Rotation = R(0, 360), ZOffset = -0.4,
		}), { EmitCount = 1 })
	end
	if tier >= 4 then
		local light = Instance.new("PointLight")
		light.Name = "Light"
		light.Color = AZURE
		light.Range = 26
		light.Brightness = 0 -- the runtime flashes it
		light.Shadows = false
		light.Parent = ground
	end
	B0.screenShake(root, tier, { parent = "Slam", magnitude = ({ 1.4, 2.2, 3.4, 4.6 })[tier], falloff = "30~110", frames = tier >= 3 })
	return ground
end
-- the rend the blade splits into the ground, from the bite on through the
-- circle (BladeSkill.rend): a black branching crack carved under a jagged
-- slit tinted azure, a seam of azure qi streaks burning in it and cooling to
-- ink, dust puffs and falling rock chips as it opens, a crack-web flash at the
-- bite; II+ glowing star cracks along it and motes rising; III+ a wider web of
-- cracks and Craters rock kicks
blocks.rend = function(root, tier)
	return _G.vfxBlocks.groundRend(root, tier, {
		color = AZURE, core = coreOf(tier), ink = INK,
		width = { 3, 3.5, 4.1, 4.8 }, seam = { 0.32, 0.4, 0.48, 0.58 }, stations = { 3, 3, 4, 5 },
	})
end

-- the slam's heavy impact on each enemy
blocks.impact = function(root, tier)
	local q = pal(coreOf(tier))
	local wave = pal(coreOf(tier))
	wave.size = ({ 4.2, 5.2, 6.4, 7.8 })[tier]
	wave.groundSize = ({ 4.4, 5.4, 6.8, 8.4 })[tier]
	return _G.vfxBlocks.impactStack(root, tier, { burst = q, wave = wave })
end

spec = {
	variant = "A",
	id = "HeavenSplitter",
	root = { attrs = { AuthoredRadius = RADIUS, AuthoredOffset = OFFSET, RendOpen = 0.18 } },
	blocks = blocks,
	beats = {
		{ block = "charge" },
		{ block = "edge" },
		{ block = "flare" },
		{ block = "lightImpact" },
		{ block = "launch" },
		{ block = "mark", from = 3 },
		{ block = "rift", from = 3 },
		{ block = "phantom", from = 3 },
		{ block = "strike" },
		{ block = "slam" },
		{ block = "rend" },
		{ block = "impact" },
	},
}

function spec.build(parent)
	local B0 = _G.vfxBlocks
	local built = {}
	for tier = 1, 4 do
		local name = spec.id .. "_T" .. tier
		local old = parent:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local root = Instance.new("Model")
		root.Name = name
		for k, v in spec.root.attrs do
			root:SetAttribute(k, v)
		end
		-- how tall it stands: the sky column (and III+ rift) over the bite
		root:SetAttribute("AuthoredHeight", ({ 20, 28, 36, 46 })[tier])
		for _, beat in spec.beats do
			if tier >= (beat.from or 1) and tier <= (beat.to or 4) then
				local fn = blocks[beat.block] or B0.BLOCKS[beat.block]
				assert(fn, "unknown block " .. tostring(beat.block))
				fn(root, tier, beat.params or {})
			end
		end
		root.WorldPivot = O
		root.Parent = parent
		table.insert(built, root)
	end
	return built
end

return spec
