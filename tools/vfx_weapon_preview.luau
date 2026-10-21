--!nocheck
-- Edit-mode previews for weapon techniques (animationId + lunge defs), on top
-- of tools/vfx_preview.luau (load that first). Installs _G.vfxWeaponPreview:
--
--   W.defs[id]       stand-in defs used while src/shared/Techniques.luau lacks
--                    the technique (numbers from the weapons design spec).
--   W.cast({ id, level, rig?, freezeAt?, scene?, origin? }) -> summary
--       Like vfxPreview.castThrough, but plays the def's animationId on a
--       clone of a source weapon rig (Workspace.WeaponShowcase.<rig>, which
--       has the weapon motors) with a `Tip` attachment added at the blade's
--       far end, moves the rig forward by def.lunge from Hit to Hit Stop (the marked clips'
--       Lunge start/end markers sit there), and
--       uses ActionRules.castProfile when it understands the def, else the
--       def's own clip times (hits[1]) and castSpeed. CombatEffects.cast gets
--       the dash start as origin.
--   W.sweep({ id, level, rig?, moments?, radius?, offsets? }) -> capture list
--       One scene per moment (like vfxPreview.sweep).
--   W.tipOf(rig)     adds (or finds) the Tip attachment.
--   W.templates      set to a Folder (holding <Id>/<Id>_T<n>) to preview
--                    templates built outside ReplicatedStorage.Effects.

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local W = {}
local P = assert(_G.vfxPreview, "load tools/vfx_preview.luau first")

W.defs = {
	MoonflashDraw = {
		id = "MoonflashDraw", name = "Moonflash Draw", kind = "line", weapon = "Sword", cooldown = 7, damage = 30,
		length = 18, width = 5, lunge = 14, color = Color3.fromRGB(196, 210, 255), hand = "Right",
		animationId = "rbxassetid://103568362497302", hits = { { time = 0.07, hitStop = 0.23, damage = 30 } }, castSpeed = 1,
		cast = { windup = 0.07, recovery = 0.25, moveMultiplier = 0, recoveryMoveMultiplier = 0.6, dodgeBeforeHit = false },
		icon = "", blurb = "",
	},
	DragonPierce = {
		id = "DragonPierce", name = "Dragon-Piercing Thrust", kind = "line", weapon = "Spear", cooldown = 8, damage = 34,
		length = 22, width = 4, lunge = 8, color = Color3.fromRGB(230, 70, 70), hand = "Right",
		animationId = "rbxassetid://116456285069838", hits = { { time = 0.30, hitStop = 0.40, damage = 34 } }, castSpeed = 1,
		cast = { windup = 0.30, recovery = 0.3, moveMultiplier = 0, recoveryMoveMultiplier = 0.6, dodgeBeforeHit = true },
		icon = "", blurb = "",
	},
	CrescentSweep = {
		id = "CrescentSweep", name = "Crescent Moon Sweep", kind = "circle", weapon = "Guandao", cooldown = 9, damage = 32,
		radius = 11, color = Color3.fromRGB(120, 230, 160), hand = "Right",
		animationId = "rbxassetid://111684861050012", hits = { { time = 0.63, hitStop = 0.75, damage = 32 } }, castSpeed = 1,
		cast = { windup = 0.63, recovery = 0.3, moveMultiplier = 0, recoveryMoveMultiplier = 0.6, dodgeBeforeHit = true },
		icon = "", blurb = "",
	},
}
W.rigs = { MoonflashDraw = "katanadummy", DragonPierce = "SpearRig", CrescentSweep = "GreataxeRig" }

local BODY = { Head = 1, Head2 = 1, Torso = 1, HumanoidRootPart = 1, ["Right Arm"] = 1, ["Left Arm"] = 1, ["Right Leg"] = 1, ["Left Leg"] = 1, HiltR = 1, HiltL = 1, Hilt = 1 }

function W.tipOf(rig)
	for _, d in rig:GetDescendants() do
		if d:IsA("Attachment") and d.Name == "Tip" then
			return d
		end
	end
	local arm = rig["Right Arm"]
	local hand = (arm.CFrame * CFrame.new(0, -1, 0)).Position
	local best, bp, bl = -1, nil, nil
	for _, p in rig:GetDescendants() do
		if p:IsA("BasePart") and not BODY[p.Name] and not p:FindFirstAncestorOfClass("Accessory") then
			for sx = -1, 1, 2 do
				for sy = -1, 1, 2 do
					for sz = -1, 1, 2 do
						local l = Vector3.new(sx, sy, sz) * p.Size / 2
						local dist = ((p.CFrame * CFrame.new(l)).Position - hand).Magnitude
						if dist > best then
							best, bp, bl = dist, p, l
						end
					end
				end
			end
		end
	end
	local a = Instance.new("Attachment")
	a.Name = "Tip"
	a.Position = bl * 0.9
	a.Parent = bp
	return a
end

local function weaponRig(S, rigName)
	if S.weaponRig and S.weaponRig.Name == rigName then
		return S.weaponRig
	end
	local src = workspace.WeaponShowcase:FindFirstChild(rigName)
	local rig = src:Clone()
	rig.Name = rigName
	local at = S.rig and S.rig:GetPivot() or CFrame.lookAt(S.C + Vector3.new(0, 3, 0), S.C + Vector3.new(1, 3, 0))
	if S.rig then
		S.rig:Destroy()
	end
	local _, size = rig:GetBoundingBox()
	rig:PivotTo(CFrame.lookAt(S.C + Vector3.new(0, 3, 0), S.C + Vector3.new(1, 3, 0)))
	local PhysicsService = game:GetService("PhysicsService")
	if not PhysicsService:IsCollisionGroupRegistered("_VFXPreviewRig") then
		PhysicsService:RegisterCollisionGroup("_VFXPreviewRig")
	end
	PhysicsService:CollisionGroupSetCollidable("_VFXPreviewRig", "Default", false)
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "_VFXPreviewRig"
			d.Anchored = d.Name == "HumanoidRootPart"
		end
	end
	rig.Parent = S.folder
	W.tipOf(rig)
	S.rig, S.weaponRig = rig, rig
	return rig
end

-- castProfile for defs the shared ActionRules doesn't understand yet.
local function profileOf(Rules, def)
	local ok, p = pcall(Rules.castProfile, def)
	if ok and p and p.windup and p.windup > 0 then
		return p
	end
	local h = def.hits[1]
	local speed = def.castSpeed or 1
	return { speed = speed, windup = h.time / speed, active = ((h.stop or h.hitStop) - h.time) / speed, recovery = def.cast.recovery }
end

function W.cast(opts)
	local S = opts.scene or P.current
	assert(S, "call vfxPreview.scene first")
	S.folder._fxOut:ClearAllChildren()
	local temp = workspace.Terrain:FindFirstChild("TempVFX")
	if temp and not opts.scene then
		temp:ClearAllChildren()
	end
	local holder = P.fresh({ "CombatEffects", "Sfx", "TechniqueVFX", "CastFX" })
	local CE = require(holder.CombatEffects)
	local Techniques = require(holder.Shared.Techniques)
	local Rules = require(holder.Shared.ActionRules)
	local def = Techniques.Defs[opts.id]
	if not def then
		def = W.defs[opts.id]
		Techniques.Defs[opts.id] = def
	end
	local profile = profileOf(Rules, def)
	if W.templates then -- preview unexported templates from a scratch folder (W.templates.<Id>.<Id>_T<n>)
		local TV = require(holder.TechniqueVFX)
		TV.template = function(tid, level)
			local tier, step = Techniques.visualTier(level)
			local group = W.templates:FindFirstChild(tid)
			return group and group:FindFirstChild(`{tid}_T{tier}`), tier, step
		end
	end
	do -- the copies' castProfile, for CastFX.phases and CombatEffects.windup
		local original = Rules.castProfile
		Rules.castProfile = function(d)
			local ok, p = pcall(original, d)
			if ok and p and p.windup and p.windup > 0 then
				return p
			end
			return profileOf({ castProfile = function() error("x") end }, d)
		end
	end
	local rig = weaponRig(S, opts.rig or W.rigs[opts.id] or "katanadummy")
	local root = rig.HumanoidRootPart
	local start = CFrame.lookAt(S.C + Vector3.new(0, 3, 0), S.C + Vector3.new(1, 3, 0))
	rig:PivotTo(start)
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local anim = Instance.new("Animation")
	local marked = RS.Animations:FindFirstChild("Techniques") and RS.Animations.Techniques:FindFirstChild(opts.id)
	anim.AnimationId = if marked then marked.AnimationId else (def.animationId or W.defs[opts.id].animationId)
	local track = animator:LoadAnimation(anim)
	local t0 = os.clock()
	while track.Length == 0 and os.clock() - t0 < 5 do
		task.wait()
	end
	track:Play(0, 1, 0)
	local dir = Vector3.new(1, 0, 0)
	local origin = opts.origin or root.Position
	local lunge = def.lunge or 0
	-- the marked clips lunge from "Lunge start" to "Lunge end", which sit on
	-- Hit and Hit Stop for these skills
	local lw = def.lungeWindow or { def.hits[1].time, def.hits[#def.hits].stop or def.hits[#def.hits].hitStop }
	local lungeFrom, lungeTime = lw[1] / profile.speed, (lw[2] - lw[1]) / profile.speed
	local clock, cast, err = os.clock(), false, nil
	local ok, e = pcall(CE.windup, rig, opts.id, opts.level)
	if not ok then
		err = e
	end
	while true do
		local t = os.clock() - clock
		track.TimePosition = math.min(t * profile.speed, track.Length - 0.01)
		animator:StepAnimations(0)
		if lunge > 0 then
			local k = math.clamp((t - lungeFrom) / lungeTime, 0, 1)
			rig:PivotTo(start + dir * lunge * (1 - (1 - k) ^ 2))
		end
		if not cast and t >= profile.windup then
			cast = true
			local ok2, e2 = pcall(CE.cast, rig, opts.id, origin, dir, nil, opts.level)
			if not ok2 then
				err = e2
			end
		end
		if (opts.freezeAt and t >= opts.freezeAt) or t > 3 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if opts.freezeAt then
		for _, r in { workspace.Terrain:FindFirstChild("TempVFX"), S.folder } do
			if r then
				for _, d in r:GetDescendants() do
					if d:IsA("ParticleEmitter") then
						d.TimeScale = 0
					end
				end
			end
		end
		local TV = require(holder.TechniqueVFX)
		for tween in TV.waves or {} do
			tween:Pause()
		end
	end
	pcall(function()
		RunService:UnbindFromRenderStep("CombatShake")
	end)
	local kids = {}
	for _, d in S.folder._fxOut:GetChildren() do
		table.insert(kids, d.Name)
	end
	return string.format("t=%.2f err=%s spawned=%d (%s)", os.clock() - clock, tostring(err), #kids, table.concat(kids, ",", 1, math.min(#kids, 12)))
end

-- The def from src/shared/Techniques.luau when it has the technique, else W.defs.
function W.liveDef(id)
	local holder = P.fresh({ "TechniqueVFX" })
	return require(holder.Shared.Techniques).Defs[id] or W.defs[id]
end

function W.sweep(opts)
	local def = W.liveDef(opts.id)
	local stop = def.hits[1].stop or def.hits[1].hitStop
	local p = { windup = def.hits[1].time / (def.castSpeed or 1), active = (stop - def.hits[1].time) / (def.castSpeed or 1), recovery = def.cast.recovery }
	local lag = opts.lag or 0.03
	local w, a, r = p.windup, p.active, p.recovery
	local moments = opts.moments or {
		{ name = "windup", t = w * 0.8, cameras = { "hand" } },
		{ name = "hit", t = w + a * 0.5 + lag, cameras = { "player", "side" } },
		{ name = "hitstop", t = w + a + 0.08 + lag, cameras = { "player", "top" } },
		{ name = "aftermath", t = w + a + r + 0.3 + lag, cameras = { "player" } },
	}
	P.clear()
	local base = opts.center or Vector3.new(400, 640, 300)
	local lines, results = {}, {}
	for i, m in moments do
		local scene = P.scene({ center = base + Vector3.new(0, 0, (i - 1) * (opts.spacing or 160)), radius = opts.radius, keep = true, enemies = opts.enemies, offsets = opts.offsets })
		table.insert(results, m.name .. ": " .. W.cast({ id = opts.id, level = opts.level, freezeAt = m.t, scene = scene, rig = opts.rig }))
		for _, cam in m.cameras do
			local c = (opts.cameras and opts.cameras[cam]) or P.CAMERAS[cam]
			local from, to = scene.C + c[1], scene.C + c[2]
			table.insert(lines, string.format("%s_L%d_%s_%s | %.1f, %.1f, %.1f | %.1f, %.1f, %.1f",
				opts.id, opts.level, m.name, cam, from.X, from.Y, from.Z, to.X, to.Y, to.Z))
		end
	end
	return table.concat(results, "\n") .. "\n" .. table.concat(lines, "\n")
end

_G.vfxWeaponPreview = W
return "vfxWeaponPreview installed"
