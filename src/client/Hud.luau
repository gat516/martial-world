--!strict
-- Status panel (realm, cultivation bar, dantian, health), active buffs with
-- countdowns, and toast messages.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
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

local function formatNumber(n: number): string
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

local function setBar(bar: Frame, value: number, max: number, text: string)
	local fill = bar:FindFirstChild("Fill") :: Frame
	fill.Size = UDim2.fromScale(if max > 0 then math.clamp(value / max, 0, 1) else 0, 1)
	fill.Visible = value > 0
	(bar:FindFirstChild("Label") :: TextLabel).Text = text
end

-- Mirror the character's health; the default Roblox health bar is hidden in its favor.
local function watchHealth(bar: Frame, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local function show()
		local hp, max = math.ceil(humanoid.Health), humanoid.MaxHealth
		setBar(bar, hp, max, `{hp} / {math.floor(max)}`)
	end
	humanoid.HealthChanged:Connect(show)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(show)
	show()
end

function Hud.init(screenGui: ScreenGui)
	gui = screenGui
	local panel = gui:FindFirstChild("StatusPanel") :: Frame
	local realmLabel = panel:FindFirstChild("RealmLabel") :: TextLabel
	local cultivationBar = panel:FindFirstChild("CultivationBar") :: Frame
	local rateLabel = panel:FindFirstChild("RateLabel") :: TextLabel
	local dantianBar = panel:FindFirstChild("DantianBar") :: Frame
	local healthBar = panel:FindFirstChild("HealthBar") :: Frame

	local function showCultivation()
		realmLabel.Text = player:GetAttribute("Realm") or ""
		local value, max = player:GetAttribute("Cultivation") or 0, player:GetAttribute("CultivationMax") or 0
		setBar(cultivationBar, value, max, `{formatNumber(value)} / {formatNumber(max)}`)
		local qi, cap = player:GetAttribute("RawQi") or 0, player:GetAttribute("DantianCap") or 0
		setBar(dantianBar, qi, cap, `Dantian {formatNumber(qi)} / {formatNumber(cap)}`)
	end
	for _, attr in { "Realm", "Cultivation", "CultivationMax", "RawQi", "DantianCap" } do
		player:GetAttributeChangedSignal(attr):Connect(showCultivation)
	end
	showCultivation()

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	player.CharacterAdded:Connect(function(character)
		watchHealth(healthBar, character)
	end)
	if player.Character then
		task.spawn(watchHealth, healthBar, player.Character)
	end

	(ReplicatedStorage.Remotes.Notify :: RemoteEvent).OnClientEvent:Connect(Hud.toast)

	State.onChanged(function(s)
		local aura = if s.aura > 0 then `  (garden +{math.floor(s.aura * 100 + 0.5)}%)` else ""
		rateLabel.Text = string.format("+%.2f/s passive", s.rate) .. aura
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
