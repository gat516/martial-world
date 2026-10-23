--!strict
-- Skins for the Events screen's frames (docs/ui/leaderboards.md, "Blood Sect skin").
-- `default` is the kit's gold; `blood` is the Blood Sect's (codex sheet C6:
-- blackened iron and crimson, thorned scrolls): its own corner set and studs,
-- and crimson tints for the gold pieces that have no blood version yet.
-- A component opts in by naming its parts as below and calling Themes.apply:
--   CornerTL/TR/BL/BR  window corners (image and aspect swap)
--   Body               the panel (tinted)
--   Crest              the title crest strip (tinted) with a Title label
--   Rule, Divider      cloud dividers (tinted)
--   Stud               a ruby stud (image swap)
--   Row/RowYou Art     leaderboard rows (tinted, via Themes.tintRow)
-- Only the demon path uses `blood`, and only once the player has found it
-- (never before: roadmap 9, "The demon secret").

export type Theme = {
	name: string,
	corners: { TL: string, TR: string, BL: string, BR: string },
	cornerAspect: number,
	stud: string,
	panelTint: Color3,
	frameTint: Color3, -- gold art with no blood version (crest, rows, dividers)
	title: Color3,
	text: Color3,
	dim: Color3,
	accent: Color3, -- values, selected tab
}

local c = Color3.fromRGB

local Themes = {}

Themes.default = {
	name = "default",
	corners = {
		TL = "rbxassetid://85875302473824",
		TR = "rbxassetid://88976605104747",
		BL = "rbxassetid://77144194929366",
		BR = "rbxassetid://113361229444828",
	},
	cornerAspect = 573 / 386,
	stud = "rbxassetid://73915978017269",
	panelTint = c(255, 255, 255),
	frameTint = c(255, 255, 255),
	title = c(236, 196, 104),
	text = c(250, 236, 195),
	dim = c(196, 182, 150),
	accent = c(236, 196, 104),
} :: Theme

Themes.blood = {
	name = "blood",
	corners = {
		TL = "rbxassetid://106524586692378",
		TR = "rbxassetid://127210710631437",
		BL = "rbxassetid://76377171901319",
		BR = "rbxassetid://104331680085975",
	},
	cornerAspect = 812 / 491,
	stud = "rbxassetid://88195591853280",
	panelTint = c(255, 176, 170),
	frameTint = c(214, 112, 100),
	title = c(240, 112, 96),
	text = c(255, 228, 220),
	dim = c(200, 160, 150),
	accent = c(236, 92, 76),
} :: Theme

-- Other C6 pieces, for components that want them (all uploaded, art/ui/assets.json).
Themes.bloodPieces = {
	nameScroll = "rbxassetid://137196541860109",
	goldStud = "rbxassetid://102528420780680", -- a copper-red diamond
	rubyStud = "rbxassetid://88195591853280",
}

function Themes.get(name: string?): Theme
	return if name == "blood" then Themes.blood else Themes.default
end

local function tint(inst: Instance?, color: Color3)
	if not inst then
		return
	end
	local all = inst:GetDescendants()
	table.insert(all, inst)
	for _, d in all do
		if d:IsA("ImageLabel") or d:IsA("ImageButton") then
			d.ImageColor3 = color
		end
	end
end

-- Skin a window built from the named parts above.
function Themes.apply(root: Instance, theme: Theme)
	for key, id in theme.corners do
		local corner = root:FindFirstChild("Corner" .. key) :: ImageLabel?
		if corner then
			corner.Image = id
			local ratio = corner:FindFirstChildOfClass("UIAspectRatioConstraint")
			if ratio then
				ratio.AspectRatio = theme.cornerAspect
			end
		end
	end
	local body = root:FindFirstChild("Body") :: ImageLabel?
	if body then
		body.ImageColor3 = theme.panelTint
	end
	local crest = root:FindFirstChild("Crest")
	if crest then
		tint(crest:FindFirstChild("Art"), theme.frameTint)
		local title = crest:FindFirstChild("Title") :: TextLabel?
		if title then
			title.TextColor3 = theme.title
		end
	end
	for _, name in { "Rule", "Divider" } do
		tint(root:FindFirstChild(name), theme.frameTint)
	end
	local stud = root:FindFirstChild("Stud", true) :: ImageLabel?
	if stud then
		stud.Image = theme.stud
	end
end

-- Skin a leaderboard row (its frame art; the crest and medal keep their colours).
function Themes.tintRow(row: Instance, theme: Theme)
	tint(row:FindFirstChild("Art"), theme.frameTint)
end

return Themes
