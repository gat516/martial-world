--!strict
-- The vitals mount at the bottom (segmented health, qi and cultivation bars, the
-- realm crest above it), active buffs
-- with countdowns, and toasts. The top-left corner is left to Roblox's chat.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local Motion = require(script.Parent.Motion)
local State = require(script.Parent.State)

local TOAST_SECONDS = 3.2
local TOAST_QUEUE_MAX = 4 -- older pending toasts are dropped past this
local BUFF_LABELS = { QiRate = "cultivation", WalkSpeed = "speed" }

local player = Players.LocalPlayer

local Hud = {}

local gui: ScreenGui
local queue: { string } = {}
local showing = false

-- Toasts queue up instead of overwriting each other, so simultaneous news (an
-- insight and a manual from one kill) are all readable. Repeats are skipped.
function Hud.toast(message: string)
	if queue[#queue] == message then
		return
	end
	table.insert(queue, message)
	while #queue > TOAST_QUEUE_MAX do
		table.remove(queue, 1)
	end
	if showing then
		return
	end
	showing = true
	task.spawn(function()
		local toast = gui:FindFirstChild("Toast") :: GuiObject
		local label = toast:FindFirstChild("Message") :: TextLabel
		while #queue > 0 do
			label.Text = table.remove(queue, 1) :: string
			toast.Visible = true
			-- longer messages stay up a little longer
			task.wait(TOAST_SECONDS + math.min(2, #label.Text / 60))
		end
		toast.Visible = false
		showing = false
	end)
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function buffText(b: State.Buff, now: number): string
	local item = Items.Defs[b.source]
	local amount = if b.kind == "QiRate" then `+{math.floor(b.amount * 100 + 0.5)}%` else `+{b.amount}`
	return `{item and item.name or b.source}: {amount} {BUFF_LABELS[b.kind] or b.kind}  {formatTime(b.expires - now)}`
end

local function renderBuffs()
	local list = gui:FindFirstChild("Buffs", true) :: Frame
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

local function setBar(bar: Frame, value: number, max: number, label: TextLabel?, text: string?)
	local fill = bar:FindFirstChild("Fill") :: Frame
	Motion.ease(fill, { Size = UDim2.fromScale(if max > 0 then math.clamp(value / max, 0, 1) else 0, 1) })
	fill.Visible = value > 0
	if label and text then
		label.Text = text
	end
end

-- Mirror the character's health; the default Roblox health bar is hidden in its favor.
local function watchHealth(bar: Frame, label: TextLabel, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local function show()
		local hp, max = math.ceil(humanoid.Health), humanoid.MaxHealth
		setBar(bar, hp, max, label, `{hp} / {math.floor(max)}`)
	end
	humanoid.HealthChanged:Connect(show)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(show)
	show()
end

function Hud.init(screenGui: ScreenGui)
	gui = screenGui
	local vitals = (gui:FindFirstChild("Stack") :: Frame):FindFirstChild("Vitals") :: Frame
	local realmLabel = (vitals:FindFirstChild("Crest") :: Frame):FindFirstChild("RealmText") :: TextLabel
	local healthBar = vitals:FindFirstChild("HealthBar") :: Frame
	local dantianBar = vitals:FindFirstChild("DantianBar") :: Frame
	local cultivationBar = vitals:FindFirstChild("CultivationBar") :: Frame
	local healthText = vitals:FindFirstChild("HealthText") :: TextLabel
	local insightText = ""

	local function showCultivation()
		realmLabel.Text = (player:GetAttribute("Realm") or "") .. insightText
		local value, max = player:GetAttribute("Cultivation") or 0, player:GetAttribute("CultivationMax") or 0
		setBar(cultivationBar, value, max)
		setBar(dantianBar, player:GetAttribute("RawQi") or 0, player:GetAttribute("DantianCap") or 0)
	end
	for _, attr in { "Realm", "Cultivation", "CultivationMax", "RawQi", "DantianCap" } do
		player:GetAttributeChangedSignal(attr):Connect(showCultivation)
	end
	showCultivation()

	-- the HUD draws its own health bar and hotbar (HotbarView); no leaderboard
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	player.CharacterAdded:Connect(function(character)
		watchHealth(healthBar, healthText, character)
	end)
	if player.Character then
		task.spawn(watchHealth, healthBar, healthText, player.Character)
	end

	local notifyRemote = ReplicatedStorage.Remotes.Notify :: RemoteEvent
	notifyRemote.OnClientEvent:Connect(Hud.toast)

	State.onChanged(function(s)
		insightText = if s.insight > 0 then `  ·  Insight {s.insight}` else ""
		showCultivation()
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
