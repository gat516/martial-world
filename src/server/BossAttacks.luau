--!nonstrict
-- Attack kinds for the Jade Jiao that EnemyService doesn't know on its own, kept
-- here so the state machine only needs a few hooks (all called from EnemyService):
--   bolt     venom lanes from the mouth (`lanes` angles): the windup shows each lane
--            (Projectiles.warnLane), the release fires one real projectile down each
--            (Projectiles.fire, cue "venomBolt"), aimed down to the target's height. With
--            the target inside `minRange` at the release, nothing fires.
--   pools    circles (one on the target, two `flank` studs either side) that hurt at
--            windup end and then stay `poolSeconds` as poison pools.
--   burrow   no damage: it dives (sets Burrowed, so it can't be hit or locked) and
--            dashes underground along a lane; a `followUp` erupt surfaces it.
--   coil     a circle locked on the target; the boss runs to a point `coilRadius` from the
--            centre, stuns whoever the circle catches and closes into a ring with a door
--            gap. After `hold` seconds it squeezes everyone inside and outside the gap
--            (damage only). Enough damage during the hold breaks it.
--   cone `strikes`   follow-up cones after the first, each re-aimed and re-shown.
-- Burrowed, Phase and the Coil* attributes are what clients draw from (enemies.md).

local Players = game:GetService("Players")

local PlayerPoison = require(script.Parent.PlayerPoison)
local PlayerSlow = require(script.Parent.PlayerSlow)
local Projectiles = require(script.Parent.Projectiles)

local BossAttacks = {}

-- kinds whose area EnemyService builds through BossAttacks.shape
BossAttacks.SHAPED = { bolt = true, pools = true, coil = true }
-- kinds EnemyService resolves through BossAttacks.resolve
BossAttacks.OWNED = { bolt = true, pools = true, coil = true, burrow = true }

local BREAK_SHARE = 0.03 -- of max health, dealt during a coil's hold, breaks it
local BREAK_STAGGER = 0.9
local UNWIND = 1.4 -- the ring's attributes stay this long after the squeeze
local MOUTH_AHEAD = 24 -- default studs from the root centre to the mouth (attack.mouth)
local MOUTH_HEIGHT = 13 -- default mouth height above the ground (attack.mouthHeight)

local ctx: any = nil
local states = setmetatable({}, { __mode = "k" }) :: { [any]: any }
local pools: { { center: Vector3, radius: number, expires: number, nextTick: number, source: string, effect: string?, slow: { factor: number, seconds: number }? } } = {}
local poolLoop = false

function BossAttacks.init(context: any)
	ctx = context
end

local function state(enemy): any
	local s = states[enemy]
	if not s then
		s = { extras = {}, token = 0 }
		states[enemy] = s
	end
	return s
end

local function name(attack): string
	return attack.name or attack.kind
end

local function clearCoil(enemy)
	local s = state(enemy)
	s.token += 1
	s.coil = nil
	local model = enemy.model
	for _, attribute in { "CoilCenter", "CoilRadius", "CoilGap", "CoilHalfAngle", "CoilAt", "CoilSqueezeAt" } do
		model:SetAttribute(attribute, nil)
	end
end

--[[ Areas ]]

function BossAttacks.shape(enemy, attack, targetRoot: BasePart, ground: Vector3, dir: Vector3): any
	local s = state(enemy)
	table.clear(s.extras)
	if attack.kind == "bolt" then
		local length = attack.length
		local start = ground + dir * (attack.mouth or MOUTH_AHEAD)
		local list = {}
		for _, degrees in attack.lanes or { 0 } do
			local d = CFrame.Angles(0, math.rad(degrees), 0):VectorToWorldSpace(dir)
			table.insert(list, {
				kind = "box",
				cframe = CFrame.lookAt(start, start + d) * CFrame.new(0, 0, -length / 2),
				size = Vector2.new(attack.width, length),
			})
		end
		for i = 2, #list do
			table.insert(s.extras, list[i])
		end
		return list[1]
	elseif attack.kind == "pools" then
		local center = ctx.groundAt(targetRoot.Position)
		local side = Vector3.new(-dir.Z, 0, dir.X)
		table.insert(s.extras, { kind = "circle", center = ctx.groundAt(center + side * attack.flank), radius = attack.radius })
		table.insert(s.extras, { kind = "circle", center = ctx.groundAt(center - side * attack.flank), radius = attack.radius })
		return { kind = "circle", center = center, radius = attack.radius }
	else -- coil
		local center = ctx.groundAt(targetRoot.Position)
		local away = ctx.flat(enemy.root.Position - center)
		away = if away.Magnitude > 0.1 then away.Unit else -dir
		local point = ctx.groundAt(center + away * attack.coilRadius)
		s.coil = { center = center, point = point, away = away, active = false, damage = 0, attack = attack }
		return { kind = "circle", center = center, radius = attack.radius }
	end
end

-- after the windup's own telegraph went out: show the extra areas too, and clear
-- anything left from a ring that was cut short
function BossAttacks.begin(enemy, attack)
	local s = state(enemy)
	for _, shape in s.extras do
		if attack.kind == "bolt" then
			local look = shape.cframe.LookVector
			local start = shape.cframe.Position - look * (shape.size.Y / 2)
			Projectiles.warnLane(enemy.model, name(attack), start, look, shape.size.Y, shape.size.X, attack.windup)
		else
			ctx.telegraph(shape, attack.windup, enemy.model, name(attack))
		end
	end
end

-- every AI tick of a windup: a coil's boss runs for its ring point meanwhile
function BossAttacks.windupTick(enemy)
	local s = states[enemy]
	local coil = s and s.coil
	if coil and not coil.active and enemy.attack.kind == "coil" then
		ctx.setSpeed(enemy, enemy.def.runSpeed)
		ctx.moveTo(enemy, coil.point)
	end
end

--[[ Resolving ]]

-- One bolt down a lane: from the mouth, aimed down to the target's height over its
-- distance (kept between 12 studs and the lane's length), straight, no pierce.
local function fireBolt(enemy, attack, shape, targetRoot: BasePart?)
	local look = shape.cframe.LookVector
	local start = shape.cframe.Position - look * (shape.size.Y / 2)
	local origin = start + Vector3.new(0, attack.mouthHeight or MOUTH_HEIGHT, 0)
	local slope = 0
	if targetRoot then
		local far = math.clamp(ctx.flat(targetRoot.Position - start).Magnitude, 12, shape.size.Y)
		slope = (targetRoot.Position.Y - origin.Y) / far
	end
	local speed = attack.boltSpeed or 75
	Projectiles.fire({
		owner = enemy.model,
		cue = "venomBolt",
		origin = origin,
		velocity = (look + Vector3.yAxis * slope).Unit * speed,
		radius = attack.boltRadius or 1.8,
		range = shape.size.Y * 1.05,
		onHit = function(player: Player)
			ctx.hurtPlayer(enemy, attack, player, origin) -- guarded from the mouth it left
			return nil
		end,
		data = { size = (attack.boltRadius or 1.8) * 2 },
	})
end

local function poolTicks()
	if poolLoop then
		return
	end
	poolLoop = true
	task.spawn(function()
		while #pools > 0 do
			task.wait(0.25)
			local now = workspace:GetServerTimeNow()
			for i = #pools, 1, -1 do
				local pool = pools[i]
				if now >= pool.expires then
					table.remove(pools, i)
				elseif now >= pool.nextTick then
					local slows = pool.effect == "slow"
					pool.nextTick = now + (if slows then 0.5 else 1)
					local area = { kind = "circle", center = pool.center, radius = pool.radius }
					for _, player in Players:GetPlayers() do
						local root = ctx.playerRoot(player)
						if root and ctx.inside(area, root.Position) then
							if slows and pool.slow then
								PlayerSlow.apply(player, pool.slow.factor, pool.slow.seconds)
							else
								PlayerPoison.apply(player, 1, 5, pool.source)
							end
						end
					end
				end
			end
		end
		poolLoop = false
	end)
end

local function squeeze(enemy, attack, coil)
	local radius = attack.coilRadius + 1.7
	local area = { kind = "circle", center = coil.center, radius = radius }
	local crush = table.clone(attack)
	crush.damage, crush.stun, crush.poison = attack.squeezeDamage, nil, nil
	local gap = enemy.model:GetAttribute("CoilGap")
	local half = math.rad(enemy.model:GetAttribute("CoilHalfAngle") or 40)
	ctx.cue(enemy.model, "squeeze")
	for _, player in Players:GetPlayers() do
		local root = ctx.playerRoot(player)
		if root and ctx.caught(area, player, root) then
			local offset = ctx.flat(root.Position - coil.center)
			local inGap = false
			if gap and offset.Magnitude > 1 then
				inGap = math.acos(math.clamp(offset.Unit:Dot(gap), -1, 1)) <= half
			end
			if not inGap then
				ctx.hurtPlayer(enemy, crush, player)
			end
		end
	end
end

local function startCoil(enemy, attack, shape, now: number)
	local s = state(enemy)
	local coil = s.coil
	if not coil then
		return
	end
	local third = enemy.phase >= 3
	local hitting = attack
	if third and attack.stun and attack.stun.secondsP3 then
		hitting = table.clone(attack)
		hitting.stun = { kind = attack.stun.kind, radius = 0, seconds = attack.stun.secondsP3, onHit = true }
	end
	for _, player in Players:GetPlayers() do
		local root = ctx.playerRoot(player)
		if root and ctx.caught(shape, player, root) then
			ctx.hurtPlayer(enemy, hitting, player)
		end
	end
	-- run in to the ring point
	local position = enemy.root.Position
	local point = Vector3.new(coil.point.X, position.Y, coil.point.Z)
	local distance = ctx.flat(point - position).Magnitude
	local dashSeconds = math.max(distance / attack.dashSpeed, attack.dashMin or 0)
	enemy.dashTo = point
	enemy.dashLength = distance
	enemy.model:SetAttribute("DashSeconds", dashSeconds)
	-- the ring: closed, with a door gap that starts at the boss's point and sweeps on
	local half = if third then attack.halfAngleP3 or attack.halfAngle else attack.halfAngle
	local hold = if third then attack.holdP3 or attack.hold else attack.hold
	local gap = CFrame.Angles(0, math.rad(half), 0):VectorToWorldSpace(coil.away)
	local at = ctx.serverNow()
	local delay = dashSeconds + 0.1 + hold
	local model = enemy.model
	model:SetAttribute("CoilCenter", coil.center)
	model:SetAttribute("CoilRadius", attack.coilRadius)
	model:SetAttribute("CoilGap", gap)
	model:SetAttribute("CoilHalfAngle", half)
	model:SetAttribute("CoilAt", at)
	model:SetAttribute("CoilSqueezeAt", at + delay)
	coil.active, coil.damage, coil.landed = true, 0, false
	s.token += 1
	local token = s.token
	task.delay(delay, function()
		if s.token ~= token or not ctx.alive(enemy) then
			return
		end
		coil.active = false
		squeeze(enemy, attack, coil)
		task.delay(UNWIND, function()
			if s.token == token then
				clearCoil(enemy)
			end
		end)
	end)
end

function BossAttacks.resolve(enemy, attack, shape, now: number)
	local s = state(enemy)
	if attack.kind == "bolt" then
		local player = enemy.target
		local targetRoot = player and ctx.playerRoot(player)
		if targetRoot and attack.minRange and ctx.flat(targetRoot.Position - enemy.root.Position).Magnitude < attack.minRange then
			-- the target came inside the bolt's minRange during the windup: no point-blank shot
			return
		end
		fireBolt(enemy, attack, shape, targetRoot)
		for _, lane in s.extras do
			fireBolt(enemy, attack, lane, targetRoot)
		end
	elseif attack.kind == "pools" then
		local all = { shape, table.unpack(s.extras) }
		local seen = {}
		for _, player in Players:GetPlayers() do
			local root = ctx.playerRoot(player)
			if root then
				for _, area in all do
					if not seen[player] and ctx.caught(area, player, root) then
						seen[player] = true
						ctx.hurtPlayer(enemy, attack, player)
					end
				end
			end
		end
		local stamp = workspace:GetServerTimeNow()
		for _, area in all do
			table.insert(pools, {
				center = area.center,
				radius = area.radius,
				expires = stamp + (attack.poolSeconds or 7),
				nextTick = stamp + 0.5,
				source = enemy.def.id,
			})
		end
		poolTicks()
	elseif attack.kind == "burrow" then
		enemy.model:SetAttribute("Burrowed", true)
	elseif attack.kind == "coil" then
		startCoil(enemy, attack, shape, now)
	end
end

-- A lingering patch (a spit's `patch`): a circle on the ground for `patch.seconds` that
-- poisons (`effect` "poison") or slows (`effect` "slow", `patch.slow`) whoever stands in it.
-- Clients draw it from the Effect remote's enemyPatch (EnemyFX `patch`).
function BossAttacks.addPatch(enemy, center: Vector3, radius: number, patch)
	local stamp = workspace:GetServerTimeNow()
	table.insert(pools, {
		center = center,
		radius = patch.radius or radius,
		expires = stamp + patch.seconds,
		nextTick = stamp + 0.25,
		source = enemy.def.id,
		effect = patch.effect,
		slow = patch.slow,
	})
	ctx.patchCue(enemy.model, center, patch.radius or radius, patch.seconds, patch.effect)
	poolTicks()
end

-- after any attack resolved (attack is the one that just did)
function BossAttacks.resolved(enemy, attack, now: number)
	if attack.unburrow then
		enemy.model:SetAttribute("Burrowed", nil)
	end
	if attack.strikes then
		local id = enemy.strikeId
		task.spawn(function()
			local elapsed = 0
			for _, strike in attack.strikes do
				local player = enemy.target
				local root = player and ctx.playerRoot(player)
				if not root or not ctx.valid(enemy, id) then
					return
				end
				ctx.face(enemy, root.Position)
				local ground = ctx.groundAt(enemy.root.Position)
				local dir = ctx.flat(root.Position - enemy.root.Position)
				dir = if dir.Magnitude > 0.1 then dir.Unit else ctx.flat(enemy.root.CFrame.LookVector).Unit
				local area = {
					kind = "cone",
					center = ground,
					cframe = CFrame.lookAt(ground, ground + dir),
					radius = strike.radius,
					size = Vector2.new(strike.angle, 0),
				}
				local wait = strike.at - elapsed
				ctx.telegraph(area, wait, enemy.model, name(attack))
				task.wait(wait)
				elapsed = strike.at
				if not ctx.valid(enemy, id) then
					return
				end
				ctx.hurtIn(enemy, attack, area)
			end
		end)
	end
end

-- the dash just ended: a coil's boss settles tangent to the ring, the centre on its left
function BossAttacks.landed(enemy)
	local s = states[enemy]
	local coil = s and s.coil
	if coil and coil.active and not coil.landed then
		coil.landed = true
		local position = enemy.root.Position
		local forward = Vector3.yAxis:Cross(coil.away)
		enemy.root.CFrame = CFrame.lookAt(position, position + forward)
	end
end

-- the boss took damage: enough of it while a coil holds breaks the ring
function BossAttacks.damaged(enemy, amount: number, now: number)
	local s = states[enemy]
	local coil = s and s.coil
	if coil and coil.active then
		coil.damage += amount
		if coil.damage >= BREAK_SHARE * enemy.maxHealth then
			clearCoil(enemy)
			ctx.cue(enemy.model, "coilBreak")
			ctx.stagger(enemy, BREAK_STAGGER)
		end
	end
end

--[[ Lifecycle ]]

function BossAttacks.onSpawn(enemy)
	if enemy.def.startsBurrowed then
		enemy.model:SetAttribute("Burrowed", true)
	end
end

function BossAttacks.reset(enemy)
	clearCoil(enemy)
	BossAttacks.onSpawn(enemy)
end

-- it lost its target: it comes up (a beast walking home isn't underground)
function BossAttacks.disengaged(enemy)
	Projectiles.cancelOwner(enemy.model)
	clearCoil(enemy)
	enemy.model:SetAttribute("Burrowed", nil)
end

function BossAttacks.died(enemy)
	Projectiles.cancelOwner(enemy.model)
	clearCoil(enemy)
	enemy.model:SetAttribute("Burrowed", nil)
end

return BossAttacks
