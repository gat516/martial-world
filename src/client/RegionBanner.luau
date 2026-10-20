--!strict
-- The region entry banner (StarterGui.Rewards.Region): crossing into a new named
-- region (Shared.Regions) brushes its name across the top of the screen, a calm
-- travel beat beside the breakthrough title card. An ink wash sweeps in, the
-- name fades up, a brush rule draws out from a seal stamp that presses down, and
-- the region's recommended realm sits under it, coloured by danger:
--   jade "Safe ground" (no realm), gold when you're at or past its realm,
--   cinnabar "Beyond your cultivation" when it's above yours.
-- It never takes input, skips the first region you spawn into (and respawns),
-- waits until you've stayed in the new region a moment, and stays quiet while a
-- menu or minigame is open. Regions sharing a name (the sect's two) count as one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Realms = require(ReplicatedStorage.Shared.Realms)
local Regions = require(ReplicatedStorage.Shared.Regions)
local Menus = require(script.Parent.Menus)
local Platform = require(script.Parent.Platform)

local POLL = 0.3 -- seconds between position checks
local SETTLE = 1.0 -- seconds you must stay in a new region before it's announced
local HOLD = 2.6 -- seconds the banner stays up (a breakthrough holds 2.6-4)
local HOLD_DANGER = 3.4

local MOODS = {
	safe = {
		kicker = Color3.fromRGB(150, 225, 190),
		ink = Color3.fromRGB(110, 200, 160),
		tag = Color3.fromRGB(190, 240, 215),
		glyph = "安",
	},
	normal = {
		kicker = Color3.fromRGB(232, 190, 92),
		ink = Color3.fromRGB(214, 172, 92),
		tag = Color3.fromRGB(240, 214, 160),
		glyph = "境",
	},
	danger = {
		kicker = Color3.fromRGB(255, 120, 100),
		ink = Color3.fromRGB(205, 55, 42),
		tag = Color3.fromRGB(255, 200, 185),
		glyph = "危",
	},
}

local player = Players.LocalPlayer

local RegionBanner = {}

local banner: Frame
local scale: UIScale
local wash: ImageLabel
local sweep: UIGradient
local kicker: TextLabel
local title: TextLabel
local rule: ImageLabel
local seal: ImageLabel
local sealScale: UIScale
local glyph: TextLabel
local tag: TextLabel
local subtitle: TextLabel

local RULE_SIZE: UDim2
local WASH_ALPHA: number
local texts: { TextLabel }
local showToken = 0

local function tween(inst: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?, delay: number?)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay or 0)
	TweenService:Create(inst, info, props):Play()
end

-- The player's own stage index on the Realms ladder, from the Realm attribute (its name).
local function myIndex(): number
	local name = player:GetAttribute("Realm")
	for i, stage in Realms.Stages do
		if stage.name == name then
			return i
		end
	end
	return 1
end

local function hide(token: number)
	if token ~= showToken then
		return
	end
	local out = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, label in texts do
		TweenService:Create(label, out, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end
	for _, image in { wash, rule, seal } do
		TweenService:Create(image, out, { ImageTransparency = 1 }):Play()
	end
	TweenService:Create(scale, out, { Scale = 1.03 }):Play()
	task.delay(0.65, function()
		if token == showToken then
			banner.Visible = false
		end
	end)
end

local function show(region: Regions.Region)
	showToken += 1
	local token = showToken

	local mood, tagText
	if region.realm == nil then
		mood, tagText = MOODS.safe, "Safe ground"
	else
		local major, minor = region.realm[1] :: string, region.realm[2] :: number
		local name = Realms.get(major, minor).name
		if Realms.index(major, minor) > myIndex() then
			mood = MOODS.danger
			tagText = `{name}  <font color="#ff7a64">·  Beyond your cultivation</font>`
		else
			mood, tagText = MOODS.normal, name
		end
	end

	kicker.Text = "YOU HAVE ENTERED"
	kicker.TextColor3 = mood.kicker
	title.Text = region.name
	tag.Text = tagText
	tag.TextColor3 = mood.tag
	subtitle.Text = region.subtitle
	-- a phone's subtitle would render too small to read; the name and realm carry it
	subtitle.Visible = not (Platform.isTouch() and Platform.isSmall())
	rule.ImageColor3 = mood.ink
	seal.ImageColor3 = mood.ink
	glyph.Text = mood.glyph

	-- start state
	for _, label in texts do
		label.TextTransparency = 1
		label.TextStrokeTransparency = 1
	end
	wash.ImageTransparency = WASH_ALPHA
	sweep.Offset = Vector2.new(-1, 0)
	rule.ImageTransparency = 0
	rule.Size = UDim2.new(0, 0, RULE_SIZE.Y.Scale, RULE_SIZE.Y.Offset)
	seal.ImageTransparency = 1
	sealScale.Scale = 1.6
	scale.Scale = 0.96
	banner.Visible = true

	-- the ink brushes across, then the words come up out of it
	tween(sweep, 0.55, { Offset = Vector2.new(0.2, 0) }, Enum.EasingStyle.Sine)
	tween(scale, 0.45, { Scale = 1 })
	local strokes = { [title] = 0.3, [glyph] = 1 } -- the seal's glyph is carved: no outline
	for _, label in texts do
		local after = if label == kicker then 0.1 elseif label == title then 0.18 else 0.5
		tween(label, 0.5, { TextTransparency = 0, TextStrokeTransparency = strokes[label] or 0 }, nil, after)
	end
	tween(rule, 0.6, { Size = RULE_SIZE }, Enum.EasingStyle.Quad, 0.3)
	tween(seal, 0.15, { ImageTransparency = 0 }, nil, 0.42)
	tween(sealScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back, 0.42)

	task.delay(if mood == MOODS.danger then HOLD_DANGER else HOLD, hide, token)
end

function RegionBanner.init()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("Rewards") :: ScreenGui
	banner = gui:FindFirstChild("Region") :: Frame
	scale = banner:FindFirstChild("Motion") :: UIScale
	wash = banner:FindFirstChild("Wash") :: ImageLabel
	sweep = wash:FindFirstChild("Sweep") :: UIGradient
	local content = banner:FindFirstChild("Content") :: Frame
	kicker = content:FindFirstChild("Kicker") :: TextLabel
	title = content:FindFirstChild("Title") :: TextLabel
	tag = content:FindFirstChild("Tag") :: TextLabel
	subtitle = content:FindFirstChild("Subtitle") :: TextLabel
	local row = content:FindFirstChild("RuleRow") :: Frame
	rule = row:FindFirstChild("Rule") :: ImageLabel
	seal = row:FindFirstChild("Seal") :: ImageLabel
	sealScale = seal:FindFirstChild("Motion") :: UIScale
	glyph = seal:FindFirstChild("Glyph") :: TextLabel
	texts = { kicker, title, tag, subtitle, glyph }
	RULE_SIZE = rule.Size
	WASH_ALPHA = wash.ImageTransparency
	banner.Visible = false

	-- a menu or minigame opening takes the screen: clear the banner out of its way
	Menus.onChanged(function()
		if Menus.isOpen() and banner.Visible then
			showToken += 1
			banner.Visible = false
		end
	end)

	local current: string? = nil -- the name announced (or spawned into) last
	local pending: string? = nil
	local pendingSince = 0
	-- for a few seconds after (re)spawning, regions are just noted: that's where the
	-- server put you, not somewhere you travelled
	local quietUntil = os.clock() + 3

	player.CharacterAdded:Connect(function()
		quietUntil = os.clock() + 3
	end)

	task.spawn(function()
		while true do
			task.wait(POLL)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local region = root and Regions.at(root.Position)
			if not region then
				pending = nil
				continue
			end
			if os.clock() < quietUntil then
				current, pending = region.name, nil
				continue
			end
			if region.name == current then
				pending = nil
				continue
			end
			local now = os.clock()
			if pending ~= region.name then
				pending, pendingSince = region.name, now
			elseif now - pendingSince >= SETTLE then
				current, pending = region.name, nil
				if not Menus.isOpen() then
					show(region)
				end
			end
		end
	end)
end

return RegionBanner
