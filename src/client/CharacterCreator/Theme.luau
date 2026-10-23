--!strict
-- The join screen's look in one place: colours, fonts, timings, the step tabs
-- and the fit. The authored GUI (assets/CharacterCreator.rbxmx, built by
-- art/ui/creator/build_gui.luau) carries the same palette; scripts use this
-- table for anything they recolour at runtime, so restyle both together.
-- Calm and readable (user, 2026-10-23): cream on the kit's navy, gold for
-- labels, lacquer only for what needs fixing. No flashes, shakes or pulses.
-- Styled like the Inventory (house window frame, gold and lacquer pills, plain
-- wells with a cream ring for the chosen one), no ornament on repeated things.

local Theme = {}

Theme.Color = {
	Cream = Color3.fromRGB(250, 236, 195),
	Muted = Color3.fromRGB(196, 186, 164),
	Gold = Color3.fromRGB(226, 188, 108),
	Lacquer = Color3.fromRGB(240, 110, 92), -- what needs fixing, on navy
	Jade = Color3.fromRGB(140, 210, 166), -- done / ok lines, on navy
	Disabled = Color3.fromRGB(150, 146, 140), -- ImageColor3 of a button that can't be pressed yet
}

-- House pieces the scripts swap at runtime (ids in art/ui/assets.json): the
-- Inventory's pills (the current tab is gold, the others lacquer).
Theme.Art = {
	Gold = "rbxassetid://124847805310931", -- button_gold.png
	Lacquer = "rbxassetid://88447362782150", -- button_lacquer.png
}

-- A plain well's thin edge (slot_edge.png): dim neutral at rest (SlotArt's
-- NO_GRADE), gold while a required field still needs filling.
Theme.Edge = {
	Rest = Color3.fromRGB(150, 140, 120),
	RestTransparency = 0.35,
	Need = Color3.fromRGB(226, 188, 108),
}

Theme.Tween = {
	Select = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Page = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Veil = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
	Hold = 1.5, -- seconds to hold Delete
}

Theme.ROBUX = "\u{E002}" -- the Robux glyph in Roblox's fonts

-- Fit: the panel (and the nameplate and modal cards) are authored at a design
-- size and scaled by their `Fit` UIScale: Scale = clamp(H / DesignHeight, Min,
-- Max). The phone floor (0.8) keeps body text at ~14 px and buttons ~45 px; the
-- panel then fills the height and its page scrolls. The preview takes the rest.
Theme.Fit = {
	DesignHeight = 900,
	Min = 0.8,
	Max = 1.4,
	PanelWidth = 480,
	PanelHeight = 760, -- tallest the panel gets (design px)
	Margin = 16, -- px from the screen edges (and between the preview and the panel)
	CompactBelow = 600, -- a panel shorter than this (design px; phones) drops the footer divider
}

-- The creator's steps. New: Appearance, Hair, Name (Enter World on Name).
-- Edit: the same three, the name locked, Save look on every step.
Theme.Steps = {
	{ Id = "Appearance", Label = "Appearance" },
	{ Id = "Hair", Label = "Hair" },
	{ Id = "Name", Label = "Name", EditLabel = "Identity" },
}

return Theme
