--!strict
-- The foundation solidity meter (roadmap 1, "Foundation solidity";
-- docs/ui/cultivation.md). Ready to wire: nothing feeds it yet. A small round
-- meter on the HUD plate's bottom-right corner, mirroring the Dash/Strike
-- cooldown chips on the left, so the HUD's footprint doesn't grow (the phone HUD
-- is already tight). It fills from the bottom with solidity, shows the
-- foundation's cracks over the fill (crack_hairline, crack_split,
-- crack_shattered) and a jade ring glow for a deep foundation (full solidity).
--
--   FoundationMeter.set({ solidity = 0.6, cracks = 1, deep = false })
--   FoundationMeter.preview() -- cycles through the states (client console)
--
-- Shown while seated (the cultivation bars are up) and, standing, only while the
-- foundation is cracked. A tap toasts what it means.

local Players = game:GetService("Players")

local CultivationGui = require(script.Parent.CultivationGui)
local Hud = require(script.Parent.Hud)
local Motion = require(script.Parent.Motion)

export type State = {
	solidity: number, -- 0..1 of the current stage
	cracks: number, -- 0 none, 1 hairline, 2 split, 3 shattered
	deep: boolean?, -- full solidity: the deep-foundation bonus
}

local CRACKS = {
	"rbxassetid://107322079054926", -- crack_hairline
	"rbxassetid://139598561995314", -- crack_split
	"rbxassetid://116569550244371", -- crack_shattered
}
local CRACK_NAMES = { "hairline cracks", "a split foundation", "a shattered foundation" }
local FILL = Color3.fromRGB(226, 178, 84)
local FILL_DEEP = Color3.fromRGB(110, 230, 170)
-- Stack-relative spot and size: the mirror of Stack.Cooldowns' Dash chip (19 px at the
-- 560 px stack, centred 3.4 px clear of the plate above and the hotbar below)
local SPOT = UDim2.fromScale(1 - 35.5 / 560, 84.113 / 149)
local SIZE = UDim2.fromScale(19 / 560, 19 / 149)
local FILL_SIZE = 0.76 -- the fill disc's share of the meter

local FoundationMeter = {}

local meter: Frame? = nil
local state: State = { solidity = 0, cracks = 0, deep = false }
local wired = false
local previewing = false

local function seated(): boolean
	local hud = Players.LocalPlayer:FindFirstChild("PlayerGui") and Players.LocalPlayer.PlayerGui:FindFirstChild("Hud")
	local bars = hud and hud:FindFirstChild("SeatBars", true)
	return bars ~= nil and (bars :: GuiObject).Visible
end

local function describe(): string
	local pct = math.round(state.solidity * 100)
	if state.deep then
		return `Foundation {pct}% solid: a deep foundation.`
	elseif state.cracks > 0 then
		return `Foundation {pct}% solid, with {CRACK_NAMES[state.cracks]}. Meditate to mend it.`
	end
	return `Foundation {pct}% solid.`
end

local function refresh()
	local m = meter
	if not m then
		return
	end
	local fill = m:FindFirstChild("Fill") :: Frame
	Motion.ease(fill, { Size = UDim2.fromScale(FILL_SIZE, FILL_SIZE * math.clamp(state.solidity, 0, 1)) });
	(fill:FindFirstChild("Disc") :: ImageLabel).ImageColor3 = if state.deep then FILL_DEEP else FILL
	local crack = m:FindFirstChild("Crack") :: ImageLabel
	crack.Visible = state.cracks > 0 and not state.deep
	crack.Image = CRACKS[math.clamp(state.cracks, 1, 3)];
	(m:FindFirstChild("Deep") :: GuiObject).Visible = state.deep == true
	m.Visible = previewing or seated() or state.cracks > 0
end

-- The meter on the HUD, made on first use.
local function attach(): Frame
	local m = meter
	if m then
		return m
	end
	local made = CultivationGui.template("FoundationMeter") :: Frame
	made.AnchorPoint = Vector2.new(0.5, 0.5)
	made.Position = SPOT
	made.Size = SIZE
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = made
	local hud = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Hud") :: ScreenGui
	local stack = hud:FindFirstChild("Stack") :: Frame
	made.Parent = stack
	meter = made;
	(made:FindFirstChild("Hit") :: TextButton).Activated:Connect(function()
		Hud.toast(describe())
	end)
	if not wired then
		wired = true
		local bars = stack:FindFirstChild("SeatBars") :: GuiObject
		bars:GetPropertyChangedSignal("Visible"):Connect(refresh)
	end
	return made
end

function FoundationMeter.set(next: State)
	state = { solidity = next.solidity, cracks = next.cracks or 0, deep = next.deep == true }
	attach()
	refresh()
end

function FoundationMeter.preview()
	local steps: { State } = {
		{ solidity = 0.8, cracks = 0 },
		{ solidity = 0.55, cracks = 1 },
		{ solidity = 0.35, cracks = 2 },
		{ solidity = 0.15, cracks = 3 },
		{ solidity = 1, cracks = 0, deep = true },
	}
	task.spawn(function()
		previewing = true
		for _, s in steps do
			FoundationMeter.set(s)
			print("FoundationMeter preview:", describe())
			task.wait(1.5)
		end
		previewing = false
		refresh()
	end)
end

return FoundationMeter
