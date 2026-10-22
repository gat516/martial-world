--!strict
-- The guard (posture) bar: a bronze-rimmed trough low on the screen, just above the
-- vitals and hotbar (Hud.Play.GuardBar mirrors Hud.Stack's box; Layout copies its size).
-- The pale-gold fill drains toward the centre seal as guard is spent. It is shown
-- only while guard is held or not full, and fades out when full and idle.
--   GuardBar.init(gui)             find the bar in the Hud, start the per-frame view
--   GuardBar.set(ratio, active)    guard 0..1 and whether it is held (call every frame)
--   GuardBar.flash(kind)           "parry" pale-gold flash and pop, "blocked" tick and
--                                  shake, "break" red cracks, then hidden for a moment
-- Input is not handled here; CombatController binds Hud.Play.BlockButton itself.

local RunService = game:GetService("RunService")

local FADE_IN = 0.12
local FADE_OUT = 0.45
local BREAK_HIDE = 1.1 -- seconds the bar stays away after a break, so it reads as shattered
local LOW = 0.3 -- below this the fill warms toward red
local WHITE = Color3.new(1, 1, 1)
local WARN = Color3.fromRGB(255, 120, 100)
local RIM_RED = Color3.fromRGB(255, 100, 90)

local GuardBar = {}

local bar: Frame? = nil
local box: Frame? = nil
local rim: ImageLabel, fill: ImageLabel, flashImg: ImageLabel, cracks: ImageLabel, seal: ImageLabel
local pop: UIScale
local basePosition = UDim2.new()

local target = 1
local held = false
local shown = 0 -- fade, 0..1
local ratioShown = 1
local holdUntil = 0 -- forced visible (a flash is playing)
local hiddenUntil = 0 -- forced hidden (after a break)
local parryA, tickA, breakA = 0, 0, 0
local shakeT = 0

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function step(dt: number)
	local b = bar
	if not b or not box then
		return
	end
	local now = os.clock()
	local want
	if now < holdUntil then
		want = true
	elseif now < hiddenUntil then
		want = false
	else
		want = held or target < 0.999
	end
	if want then
		shown = clamp01(shown + dt / FADE_IN)
	else
		shown = clamp01(shown - dt / FADE_OUT)
	end
	parryA = math.max(0, parryA - dt / 0.35)
	tickA = math.max(0, tickA - dt / 0.18)
	breakA = math.max(0, breakA - dt / 0.8)
	shakeT += dt

	box.Visible = shown > 0.01 or parryA > 0 or breakA > 0
	if not box.Visible then
		return
	end

	-- drains fast, refills gently
	local rate = if target < ratioShown then 20 else 7
	ratioShown += (target - ratioShown) * clamp01(dt * rate)
	if math.abs(target - ratioShown) < 0.002 then
		ratioShown = target
	end
	fill.Size = UDim2.fromScale(clamp01(ratioShown), 1)
	fill.Visible = ratioShown > 0.015
	local warm = clamp01(1 - ratioShown / LOW)
	fill.ImageColor3 = WHITE:Lerp(WARN, warm)

	local a = shown
	local dim = if held then 0 else 0.2 -- slightly dimmer while it just regenerates
	rim.ImageTransparency = 1 - a
	seal.ImageTransparency = 1 - a
	fill.ImageTransparency = 1 - a * (1 - dim)
	flashImg.ImageTransparency = 1 - parryA * a
	cracks.ImageTransparency = 1 - clamp01(breakA * 2.2) * a
	rim.ImageColor3 = WHITE:Lerp(RIM_RED, clamp01(breakA * 1.5))

	pop.Scale = 1 + 0.12 * parryA * parryA + 0.05 * tickA
	local shake = math.sin(shakeT * 70) * 5 * tickA
	b.Position = basePosition + UDim2.fromOffset(shake, 0)
end

function GuardBar.init(gui: ScreenGui)
	local container = gui:FindFirstChild("GuardBar", true) :: Frame
	box = container
	local b = container:FindFirstChild("Bar") :: Frame
	bar = b
	basePosition = b.Position
	rim = b:FindFirstChild("Rim") :: ImageLabel
	seal = b:FindFirstChild("Seal") :: ImageLabel
	cracks = b:FindFirstChild("Cracks") :: ImageLabel
	local track = b:FindFirstChild("Track") :: Frame
	fill = track:FindFirstChild("Fill") :: ImageLabel
	flashImg = track:FindFirstChild("Flash") :: ImageLabel
	pop = b:FindFirstChild("Pop") :: UIScale
	container.Visible = false
	RunService.RenderStepped:Connect(step)
end

function GuardBar.set(ratio: number, active: boolean)
	target = clamp01(ratio)
	held = active
end

function GuardBar.flash(kind: string)
	local now = os.clock()
	if kind == "parry" then
		parryA = 1
		holdUntil = math.max(holdUntil, now + 0.6)
		hiddenUntil = 0
	elseif kind == "blocked" then
		tickA = 1
		shakeT = 0
		holdUntil = math.max(holdUntil, now + 0.5)
	elseif kind == "break" then
		breakA = 1
		holdUntil = now + 0.4
		hiddenUntil = now + BREAK_HIDE
	end
end

return GuardBar
