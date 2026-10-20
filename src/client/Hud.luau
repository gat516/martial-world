--!strict
-- Qi readout, active buffs with countdowns, and toast messages.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Herbs = require(ReplicatedStorage.Shared.Herbs)
local State = require(script.Parent.State)

local TOAST_SECONDS = 3.5
local BUFF_LABELS = { QiRate = "cultivation", WalkSpeed = "speed" }

local player = Players.LocalPlayer

local Hud = {}

local gui: ScreenGui
local toastToken = 0

function Hud.toast(message: string)
	local label = gui:FindFirstChild("Toast") :: TextLabel
	toastToken += 1
	local token = toastToken
	label.Text = message
	label.Visible = true
	task.delay(TOAST_SECONDS, function()
		if token == toastToken then
			label.Visible = false
		end
	end)
end

local function formatQi(n: number): string
	if n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function buffText(b: State.Buff, now: number): string
	local herb = Herbs.Defs[b.source]
	local amount = if b.kind == "QiRate" then `+{math.floor(b.amount * 100 + 0.5)}%` else `+{b.amount}`
	return `{herb and herb.name or b.source}: {amount} {BUFF_LABELS[b.kind] or b.kind}  {formatTime(b.expires - now)}`
end

local function renderBuffs()
	local list = gui:FindFirstChild("Buffs") :: Frame
	local template = list:FindFirstChild("BuffTemplate") :: TextLabel
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") and child ~= template then
			child:Destroy()
		end
	end
	local now = workspace:GetServerTimeNow()
	for i, b in State.current.buffs do
		if b.expires > now then
			local row = template:Clone()
			row.Name = "Buff"
			row.Text = buffText(b, now)
			row.LayoutOrder = i
			row.Visible = true
			row.Parent = list
		end
	end
end

function Hud.init(screenGui: ScreenGui)
	gui = screenGui
	local panel = gui:FindFirstChild("QiPanel") :: Frame
	local qiLabel = panel:FindFirstChild("QiLabel") :: TextLabel
	local rateLabel = panel:FindFirstChild("RateLabel") :: TextLabel

	local function showQi()
		qiLabel.Text = `Qi {formatQi(player:GetAttribute("Qi") or 0)}`
	end
	player:GetAttributeChangedSignal("Qi"):Connect(showQi)
	showQi()

	State.onChanged(function(s)
		local aura = if s.aura > 0 then `  (garden aura +{math.floor(s.aura * 100 + 0.5)}%)` else ""
		rateLabel.Text = string.format("+%.1f Qi/s", s.rate) .. aura
		renderBuffs()
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			renderBuffs()
		end
	end)
end

return Hud
