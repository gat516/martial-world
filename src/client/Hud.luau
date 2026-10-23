--!strict
-- The vitals mount at the bottom (Stack.Vitals, art in art/ui/figma): segmented
-- health, the combat qi bar (Qi/QiMax, the mana techniques spend) and the guard
-- trough (GuardBar.luau drives that one), with the realm plaque (Crest) on top. Your
-- own name isn't on the HUD (user, 2026-10-22: a name row made the stack too tall on
-- phones and told you nothing). A refused
-- cast (QiDenied changes) flashes the qi bar and shakes the mount. Cultivation and
-- the dantian aren't here: they show while seated (SeatBars.luau). Also active
-- buffs with countdowns, and toasts. The top-left corner is left to Roblox's chat.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)
local State = require(script.Parent.State)

local TOAST_SECONDS = 3.2
local TOAST_QUEUE_MAX = 4 -- older pending toasts are dropped past this
local TOAST_GAP = 8 -- px kept from Roblox's buttons, the tiles, windows and the edges
local TOAST_MAX_TEXT = 380 -- widest a toast's text runs before it wraps
local BUFF_LABELS = { QiRate = "cultivation", WalkSpeed = "speed" }

local player = Players.LocalPlayer

local Hud = {}

local gui: ScreenGui
local queue: { string } = {}
local showing = false
local said: { [string]: number } = {} -- message -> os.clock() it was queued

-- Where the toast goes: the row of Roblox's top bar, which windows never use (they
-- start below it; user, 2026-10-23: a toast landed on the open Inventory's title).
-- Centred on the screen when it fits, else slid clear of Roblox's buttons on the
-- left and, while they show, the top-right tiles. Should an open window or the
-- build banner still reach it, it goes below that, or above it.
local function placeToast(toast: GuiObject)
	local message = toast:FindFirstChild("Message") :: TextLabel
	local pad = toast:FindFirstChild("UIPadding") :: UIPadding
	local padX = pad.PaddingLeft.Offset + pad.PaddingRight.Offset
	local origin = gui.AbsolutePosition
	local barBottom, freeLeft = Platform.topbar(gui)
	local left, right = freeLeft + TOAST_GAP, gui.AbsoluteSize.X - TOAST_GAP
	local open = Menus.current()
	local tiles = gui:FindFirstChild("Buttons") :: GuiObject?
	if not open and tiles and tiles.Visible then
		right = math.min(right, tiles.AbsolutePosition.X - origin.X - TOAST_GAP)
	end
	-- the text's own size at the lane's width (one line when it fits, else wrapped)
	local params = Instance.new("GetTextBoundsParams")
	params.Text = message.Text
	params.Font = message.FontFace
	params.Size = message.TextSize
	params.Width = math.clamp(right - left - padX, 160, TOAST_MAX_TEXT)
	local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
	if ok then
		message.Size = UDim2.fromOffset(math.ceil(bounds.X) + 1, math.ceil(bounds.Y))
	end
	local size = Vector2.new(message.Size.X.Offset + padX, message.Size.Y.Offset + pad.PaddingTop.Offset + pad.PaddingBottom.Offset)
	local x = math.clamp(gui.AbsoluteSize.X / 2, left + size.X / 2, math.max(left + size.X / 2, right - size.X / 2))
	local y = if barBottom >= size.Y then barBottom / 2 else (if barBottom > 0 then 4 else 10) + size.Y / 2
	-- an open window or the build banner in the way: go below it, or above it
	local banner = gui:FindFirstChild("BuildBanner") :: GuiObject?
	for _, obstacle in { open, if banner and banner.Visible then banner else nil } do
		if obstacle and obstacle.Visible then
			local p, s = obstacle.AbsolutePosition - origin, obstacle.AbsoluteSize
			local top, bottom = y - size.Y / 2, y + size.Y / 2
			if x + size.X / 2 > p.X and x - size.X / 2 < p.X + s.X and bottom > p.Y and top < p.Y + s.Y then
				if p.Y + s.Y + TOAST_GAP + size.Y <= gui.AbsoluteSize.Y then
					y = p.Y + s.Y + TOAST_GAP + size.Y / 2
				else
					y = math.max(size.Y / 2, p.Y - TOAST_GAP - size.Y / 2)
				end
			end
		end
	end
	toast.Position = UDim2.fromOffset(math.round(x), math.round(y))
end

-- Toasts queue up instead of overwriting each other, so simultaneous news (an
-- insight and a manual from one kill) are all readable. Repeats are skipped.
function Hud.toast(message: string)
	said[message] = os.clock()
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
		local first = true
		while #queue > 0 do
			label.Text = table.remove(queue, 1) :: string
			placeToast(toast)
			toast.Visible = true
			if first then
				Motion.fadeIn(toast) -- eases in
				first = false
			end
			-- longer messages stay up a little longer
			task.wait(TOAST_SECONDS + math.min(2, #label.Text / 60))
		end
		showing = false
		Motion.fadeOut(toast, function()
			if not showing then
				toast.Visible = false
			end
		end)
	end)
end

-- Whether a toast containing `text` was queued in the last `seconds` (so a client
-- nudge doesn't repeat what the server just said).
function Hud.saidLately(text: string, seconds: number): boolean
	local now = os.clock()
	for message, at in said do
		if now - at <= seconds and string.find(string.lower(message), string.lower(text), 1, true) then
			return true
		end
	end
	return false
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

local TRAIL = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.25)
local DENY_COLOR = Color3.fromRGB(255, 96, 80)
local shakeHome: UDim2? = nil -- where the mount sits while a shake plays

-- Fill eases to the value; a pale trail (if the bar has one) lingers where a
-- drop started, then follows, so a hit or a spend reads as a chunk.
function Hud.setBar(bar: Frame, value: number, max: number, label: TextLabel?, text: string?)
	local fill = bar:FindFirstChild("Fill") :: GuiObject
	local ratio = if max > 0 then math.clamp(value / max, 0, 1) else 0
	Motion.ease(fill, { Size = UDim2.fromScale(ratio, 1) })
	fill.Visible = value > 0
	local trail = bar:FindFirstChild("Trail") :: GuiObject?
	if trail then
		if ratio >= trail.Size.X.Scale then
			Motion.ease(trail, { Size = UDim2.fromScale(ratio, 1) })
		else
			Motion.tween(trail, { Size = UDim2.fromScale(ratio, 1) }, TRAIL)
		end
	end
	if label and text then
		label.Text = text
	end
end
local setBar = Hud.setBar

-- The bar fills, trails and flashes are 9-sliced images with pointed or rounded
-- ends (art/ui/hud_fill_*.png, 64 px tall). Keeping SliceScale at height / 64
-- keeps the ends in proportion at any stack size; the authored values fit the PC
-- stack, so Studio's edit view already matches.
local SLANT_SOURCE_HEIGHT = 64
local SLANTED = { Fill = true, Trail = true, Flash = true, Sheen = true }
local function keepSlants(root: Instance)
	for _, image in root:GetDescendants() do
		if image:IsA("ImageLabel") and SLANTED[image.Name] and image.ScaleType == Enum.ScaleType.Slice then
			local function fit()
				if image.AbsoluteSize.Y > 0 then
					image.SliceScale = image.AbsoluteSize.Y / SLANT_SOURCE_HEIGHT
				end
			end
			image:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
			fit()
		end
	end
end

-- A refused cast: the qi bar flashes red and the mount gives a short shake.
local function denyFlash(vitals: Frame, qiBar: Frame)
	local flash = qiBar:FindFirstChild("Flash") :: ImageLabel
	flash.ImageColor3 = DENY_COLOR
	flash.ImageTransparency = 0.2
	Motion.tween(flash, { ImageTransparency = 1 }, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	if shakeHome then
		return -- already shaking; the flash above is enough
	end
	local home = vitals.Position
	shakeHome = home
	task.spawn(function()
		for _, dx in { 5, -5, 4, -3, 2, 0 } do
			vitals.Position = home + UDim2.fromOffset(dx, 0)
			task.wait(0.03)
		end
		shakeHome = nil
	end)
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
	local qiBar = vitals:FindFirstChild("QiBar") :: Frame
	local qiText = vitals:FindFirstChild("QiText") :: TextLabel
	local healthText = vitals:FindFirstChild("HealthText") :: TextLabel
	keepSlants(gui:FindFirstChild("Stack") :: Frame)

	local function showRealm()
		realmLabel.Text = player:GetAttribute("Realm") or ""
	end
	player:GetAttributeChangedSignal("Realm"):Connect(showRealm)
	showRealm()

	-- combat qi (Qi/QiMax; 0 until the server publishes them)
	local function showQi()
		local qi, max = tonumber(player:GetAttribute("Qi")) or 0, tonumber(player:GetAttribute("QiMax")) or 0
		setBar(qiBar, qi, max, qiText, if max > 0 then `{math.floor(qi)} / {math.floor(max)}` else "")
	end
	for _, attr in { "Qi", "QiMax" } do
		player:GetAttributeChangedSignal(attr):Connect(showQi)
	end
	showQi()
	player:GetAttributeChangedSignal("QiDenied"):Connect(function()
		denyFlash(vitals, qiBar)
	end)

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
	-- a window opening or the top bar changing moves a toast that's up
	local function replace()
		local toast = gui:FindFirstChild("Toast") :: GuiObject
		if toast.Visible then
			placeToast(toast)
		end
	end
	Menus.onChanged(function()
		task.defer(replace)
	end)
	Platform.topbarChanged(replace)

	State.onChanged(function()
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
