--!strict
-- The character screen's look in one place: colours, fonts, timings and the
-- per-tab titles. The authored GUI (assets/CharacterCreator.rbxmx) carries the
-- same palette; scripts use this table for anything they recolour at runtime
-- (selection, errors, disabled states), so restyle both together.

local Theme = {}

Theme.Color = {
	Parchment = Color3.fromRGB(238, 229, 208),
	Ink = Color3.fromRGB(40, 35, 30),
	InkSoft = Color3.fromRGB(104, 92, 78),
	Cream = Color3.fromRGB(247, 240, 224),
	Gold = Color3.fromRGB(200, 162, 88),
	GoldBright = Color3.fromRGB(236, 200, 122),
	GoldDim = Color3.fromRGB(150, 118, 66),
	Jade = Color3.fromRGB(36, 54, 49),
	JadeMid = Color3.fromRGB(46, 74, 66),
	JadeText = Color3.fromRGB(44, 116, 86), -- success lines on parchment
	Lacquer = Color3.fromRGB(168, 54, 44), -- error lines on parchment
	CardStroke = Color3.fromRGB(66, 63, 56),
	Wash = Color3.fromRGB(10, 14, 14),
	Alert = Color3.fromRGB(226, 84, 66), -- "!" on a dark nav plate
	AlertLight = Color3.fromRGB(255, 136, 112), -- a missing value on the dark name plinth
	Locked = Color3.fromRGB(196, 186, 168), -- lock on a dimmed plate
	Disabled = Color3.fromRGB(150, 146, 140), -- ImageColor3 of a locked plate or button
	Need = Color3.fromRGB(214, 160, 52), -- gold rim on a required field still empty
}

-- Kit ornaments (art/ui/creator/build.py, ids in art/ui/assets.json) the scripts swap
-- at runtime; the rest of the art is set in the GUI.
Theme.Art = {
	Plate = "rbxassetid://112445824422500", -- nav plate, Back
	PlateHi = "rbxassetid://117312282844677", -- current nav plate, Next / Enter World
	Check = "rbxassetid://104701721574504",
	Exclaim = "rbxassetid://122224709560844",
	Lock = "rbxassetid://113742246645347",
}

local SERIF = "rbxasset://fonts/families/Merriweather.json"
local SANS = "rbxasset://fonts/families/BuilderSans.json"
Theme.Font = {
	Title = Font.new(SERIF, Enum.FontWeight.Bold),
	Serif = Font.new(SERIF, Enum.FontWeight.Regular),
	Italic = Font.new(SERIF, Enum.FontWeight.Regular, Enum.FontStyle.Italic),
	Body = Font.new(SANS, Enum.FontWeight.Medium),
	BodyBold = Font.new(SANS, Enum.FontWeight.Bold),
}

Theme.Tween = {
	Hover = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Select = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Pop = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Page = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Veil = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
	Reveal = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

Theme.Selection = {
	GlowOn = 0.1, -- Glow ImageTransparency when selected
	StrokeOn = 2.5, -- card UIStroke thickness when selected
	StrokeOff = 1.5,
	NavShift = 8, -- px the current nav plate slides right
}

Theme.ROBUX = "\u{E002}" -- the Robux glyph in Roblox's fonts

-- Fit: the nav and panel are authored at a desktop design size and scaled by
-- their `Fit` UIScale to the screen height (Controller.fit).
Theme.Fit = {
	DesignHeight = 790, -- screen height at which Fit = 1
	Min = 0.66, -- floor on phones: nav buttons ~53 px tall, small text ~10 px
	Max = 1.25,
	Margin = 16, -- px from the screen edges
	MinPreview = 160, -- px the preview keeps between the nav and the panel
	NavWidth = 270, -- design size of the nav column with labels
	NavCompactWidth = 104, -- glyph rings only (narrow screens)
	NavHeight = 440,
	CompactBelow = 240, -- px of preview width under which the nav goes compact
}

-- Tabs, in nav order: the nav label and glyph, and the panel's title line.
Theme.Tabs = {
	{ Id = "Clothes", Label = "Clothes", Glyph = "衣", Title = "Clothing", Subtitle = "Choose your starting outfit." },
	{ Id = "Hair", Label = "Hair", Glyph = "发", Title = "Hair", Subtitle = "Use an asset ID and choose a color." },
	{ Id = "Identity", Label = "Identity", Glyph = "名", Title = "Identity", Subtitle = "Your race, your name, your family." },
	{
		Id = "Confirm",
		Label = "Confirm",
		Glyph = "定",
		Title = "Finalize",
		Subtitle = "Review your character before entering the world.",
	},
}

return Theme
