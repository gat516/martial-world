--!strict
-- Draws boss projectiles (server: Projectiles.luau). One "projectile" message
-- per shot gives its path; this module flies it every frame on the same rule
-- (ProjectilePath), catching up a late message by server time, and hands each
-- frame to the drawer registered for its cue. "projectileEnd" stops it where
-- the server says it ended (hit, terrain, range...) so the impact plays there.
--
-- Drawers (EnemyFX modules register theirs):
--   ProjectileView.register("boulder", {
--       start = function(shot) end,             -- shot: Shot (see below)
--       step = function(shot, position, velocity, dt) end,
--       finish = function(shot, position, reason) end,
--   })
-- A cue with no drawer shows a plain red ball, in the testbed only, so the
-- backend can be fought before its effect exists.
--
-- Also draws a homing shot's warning ("projectileMark"): a ring under the marked
-- player that follows them until the shot leaves (Telegraphs.follow in the new
-- telegraph look, Config.NEW_TELEGRAPHS; a red pulsing ring otherwise).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ProjectilePath = require(ReplicatedStorage.Shared.ProjectilePath)
local Telegraphs = require(script.Parent.Telegraphs)

export type Shot = {
	id: number,
	cue: string,
	owner: Model?,
	radius: number,
	gravity: number,
	homing: { player: Player, turn: number }?,
	data: { [string]: any }?,
	state: ProjectilePath.State,
	startedAt: number,
	lifetime: number,
	visual: any, -- whatever the drawer keeps (the debug ball by default)
}

export type Drawer = {
	start: ((shot: Shot) -> ())?,
	step: ((shot: Shot, position: Vector3, velocity: Vector3, dt: number) -> ())?,
	finish: ((shot: Shot, position: Vector3, reason: string) -> ())?,
}

local RED = Color3.fromRGB(255, 40, 30)
local CATCH_UP_STEP = 1 / 60

local ProjectileView = {}

local drawers: { [string]: Drawer } = {}
local shots: { [number]: Shot } = {}
local ended: { [number]: boolean } = {} -- an end that beat its spawn message

function ProjectileView.register(cue: string, drawer: Drawer)
	drawers[cue] = drawer
end

local function targetOf(shot: Shot): Vector3?
	local homing = shot.homing
	local character = homing and homing.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

local function advance(shot: Shot, dt: number)
	shot.state = ProjectilePath.step(shot.state, dt, shot.gravity, targetOf(shot), if shot.homing then shot.homing.turn else nil)
end

-- testbed stand-in for a cue with no drawer
local debugDrawer: Drawer = {
	start = function(shot: Shot)
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch, ball.CastShadow = true, false, false, false, false
		ball.Material = Enum.Material.Neon
		ball.Color = RED
		ball.Size = Vector3.one * shot.radius * 2
		ball.Transparency = 0.2
		ball.Parent = workspace.CurrentCamera
		shot.visual = ball
	end,
	step = function(shot: Shot, position: Vector3)
		local ball = shot.visual :: Part
		ball.Position = position
	end,
	finish = function(shot: Shot)
		local ball = shot.visual :: Part
		TweenService:Create(ball, TweenInfo.new(0.2), { Transparency = 1, Size = ball.Size * 1.8 }):Play()
		Debris:AddItem(ball, 0.25)
	end,
}

local function drawerOf(cue: string): Drawer?
	return drawers[cue] or (if Config.TESTBED then debugDrawer else nil)
end

local function spawn(info: { [string]: any })
	local id = info.id :: number
	if ended[id] then
		ended[id] = nil
		return
	end
	local shot: Shot = {
		id = id,
		cue = info.cue,
		owner = info.owner,
		radius = info.radius,
		gravity = info.gravity or 0,
		homing = info.homing,
		data = info.data,
		state = { position = info.origin, velocity = info.velocity },
		startedAt = info.startedAt,
		lifetime = info.lifetime,
		visual = nil,
	}
	-- catch up to now: the message arrived after the shot left
	local behind = math.clamp(workspace:GetServerTimeNow() - shot.startedAt, 0, 1)
	while behind > 0 do
		local dt = math.min(CATCH_UP_STEP, behind)
		advance(shot, dt)
		behind -= dt
	end
	shots[id] = shot
	local drawer = drawerOf(shot.cue)
	if drawer and drawer.start then
		drawer.start(shot)
	end
end

local function finish(id: number, position: Vector3, reason: string)
	local shot = shots[id]
	if not shot then
		ended[id] = true
		task.delay(2, function()
			ended[id] = nil
		end)
		return
	end
	shots[id] = nil
	local drawer = drawerOf(shot.cue)
	if drawer and drawer.finish then
		drawer.finish(shot, position, reason)
	end
end

-- A red ring under the marked player, following them for `seconds`.
local function mark(player: Player, seconds: number, startedAt: number)
	local left = seconds - (workspace:GetServerTimeNow() - startedAt)
	if left <= 0 then
		return
	end
	if Telegraphs.NEW then
		Telegraphs.follow(function(): Vector3?
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			return root and root.Position - Vector3.new(0, 3, 0)
		end, left)
		return
	end
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
	ring.Material = Enum.Material.Neon
	ring.Color = RED
	ring.Transparency = 0.55
	ring.Size = Vector3.new(0.15, 7, 7)
	ring.Parent = workspace.CurrentCamera
	local until_ = os.clock() + left
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or os.clock() >= until_ then
			connection:Disconnect()
			ring:Destroy()
			return
		end
		local pulse = 1 + 0.1 * math.sin(os.clock() * 14)
		ring.Size = Vector3.new(0.15, 7 * pulse, 7 * pulse)
		ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
	end)
end

function ProjectileView.init()
	local effectRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Effect") :: RemoteEvent
	effectRemote.OnClientEvent:Connect(function(kind: string, ...)
		if kind == "projectile" then
			spawn((...))
		elseif kind == "projectileEnd" then
			local id, position, reason = ...
			finish(id, position, reason)
		elseif kind == "projectileMark" then
			local player, _owner, _name, seconds, startedAt = ...
			if typeof(player) == "Instance" and player:IsA("Player") then
				mark(player, seconds, startedAt)
			end
		end
	end)
	RunService.RenderStepped:Connect(function(dt: number)
		local now = workspace:GetServerTimeNow()
		for id, shot in shots do
			advance(shot, dt)
			local drawer = drawerOf(shot.cue)
			if drawer and drawer.step then
				drawer.step(shot, shot.state.position, shot.state.velocity, dt)
			end
			-- the server's end message normally arrives first; never fly forever
			if now - shot.startedAt > shot.lifetime + 1 then
				finish(id, shot.state.position, "lifetime")
			end
		end
	end)
end

return ProjectileView
