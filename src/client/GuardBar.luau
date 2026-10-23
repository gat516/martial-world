--!strict
-- The guard (posture) trough: the third bar in the vitals mount (Stack.Vitals.GuardBar,
-- in the plate's tab under health and qi, behind the lacquer seal). It is always there, so the
-- guard is readable at a glance: dim while full and idle, bright while held or
-- recovering. The pale-gold fill drains toward the centre seal and warms toward red
-- below LOW.
--   GuardBar.init(gui)             find the trough in the Hud, start the per-frame view
--   GuardBar.set(ratio, active)    guard 0..1 and whether it is held (call every frame)
--   GuardBar.flash(kind)           "parry" pale-gold flash, "blocked" jolt and tick,
--                                  "break" red cracks over the trough, the fill empty
-- Everything that changes per frame goes through UIGradient.Transparency/Color, Size
-- and Position, never the instances' own transparency, so the calm view's fade
-- (Motion.setShown) can snapshot and restore the mount without fighting this.
-- Input is not handled here; GuardController binds Hud.Play.BlockButton itself.

local RunService = game:GetService("RunService")

local BREAK_HIDE = 1.1 -- seconds the fill stays empty after a break, so it reads as shattered
local LOW = 0.3 -- below this the fill warms toward red
local IDLE_DIM = 0.12 -- fill transparency while full and not held (still clearly lit)
local WHITE = Color3.new(1, 1, 1)
local WARN = Color3.fromRGB(255, 120, 100)
local PARRY = Color3.fromRGB(255, 246, 200)
local TICK = Color3.fromRGB(255, 255, 255)

local GuardBar = {}

local trough: Frame? = nil
local fill: ImageLabel
local fillTheme: UIGradient
local flashFade: UIGradient
local flashFrame: ImageLabel
local cracksFade: UIGradient

local target = 1
local held = false
local ratioShown = 1
local dimShown = IDLE_DIM
local hiddenUntil = 0 -- fill held empty (after a break)
local parryA, tickA, breakA = 0, 0, 0
local shakeT = 0
local lastFlash, lastCracks, lastDim = -1, -1, -1

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function fade(gradient: UIGradient, transparency: number)
	gradient.Transparency = NumberSequence.new(clamp01(transparency))
end

local function step(dt: number)
	if not trough then
		return
	end
	local now = os.clock()
	parryA = math.max(0, parryA - dt / 0.35)
	tickA = math.max(0, tickA - dt / 0.18)
	breakA = math.max(0, breakA - dt / 0.9)
	shakeT += dt

	local want = if now < hiddenUntil then 0 else target
	-- drains fast, refills gently
	local rate = if want < ratioShown then 20 else 7
	ratioShown += (want - ratioShown) * clamp01(dt * rate)
	if math.abs(want - ratioShown) < 0.002 then
		ratioShown = want
	end
	fill.Size = UDim2.fromScale(clamp01(ratioShown), 1)
	fill.Visible = ratioShown > 0.015
	fill.ImageColor3 = WHITE:Lerp(WARN, clamp01(1 - ratioShown / LOW))
	-- the jolt on a blocked hit
	fill.Position = UDim2.new(0.5, math.round(math.sin(shakeT * 70) * 3 * tickA), 0, 0)

	local active = held or ratioShown < 0.999 or parryA > 0
	local dimWant = if active then 0 else IDLE_DIM
	dimShown += (dimWant - dimShown) * clamp01(dt * 8)
	if math.abs(dimShown - lastDim) > 0.005 then
		lastDim = dimShown
		fade(fillTheme, dimShown)
	end

	local flashA = math.max(parryA, tickA * 0.6)
	if flashA > 0 or lastFlash ~= 0 then
		lastFlash = flashA
		flashFrame.ImageColor3 = if parryA >= tickA then PARRY else TICK
		fade(flashFade, 1 - flashA)
	end
	local crackA = clamp01(breakA * 2.2)
	if crackA > 0 or lastCracks ~= 0 then
		lastCracks = crackA
		fade(cracksFade, 1 - crackA)
	end
end

function GuardBar.init(gui: ScreenGui)
	local vitals = gui:FindFirstChild("Vitals", true) :: Frame
	local bar = vitals:FindFirstChild("GuardBar") :: Frame
	trough = bar
	fill = bar:FindFirstChild("Fill") :: ImageLabel
	fillTheme = fill:FindFirstChild("Theme") :: UIGradient
	flashFrame = bar:FindFirstChild("Flash") :: ImageLabel
	flashFade = flashFrame:FindFirstChild("Fade") :: UIGradient
	cracksFade = (vitals:FindFirstChild("GuardCracks") :: Instance):FindFirstChild("Fade") :: UIGradient
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
		hiddenUntil = 0
	elseif kind == "blocked" then
		tickA = 1
		shakeT = 0
	elseif kind == "break" then
		breakA = 1
		hiddenUntil = now + BREAK_HIDE
	end
end

return GuardBar
