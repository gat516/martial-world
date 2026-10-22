--!strict
-- Hair colours the player may pick, in grid order (six per row reads best). The
-- first is the default. The server only accepts ids listed here.

export type HairColor = { Id: string, DisplayName: string, Color: Color3 }

local HairColors: { HairColor } = {
	{ Id = "Ink", DisplayName = "Ink Black", Color = Color3.fromRGB(24, 22, 22) },
	{ Id = "Umber", DisplayName = "Umber", Color = Color3.fromRGB(58, 42, 34) },
	{ Id = "Chestnut", DisplayName = "Chestnut", Color = Color3.fromRGB(104, 76, 56) },
	{ Id = "Sand", DisplayName = "Sand", Color = Color3.fromRGB(170, 136, 104) },
	{ Id = "Wheat", DisplayName = "Wheat", Color = Color3.fromRGB(214, 190, 150) },
	{ Id = "Frost", DisplayName = "Frost White", Color = Color3.fromRGB(232, 232, 228) },
	{ Id = "Midnight", DisplayName = "Midnight", Color = Color3.fromRGB(34, 40, 58) },
	{ Id = "Azure", DisplayName = "Dusk Azure", Color = Color3.fromRGB(70, 96, 136) },
	{ Id = "Wisteria", DisplayName = "Wisteria", Color = Color3.fromRGB(96, 70, 110) },
	{ Id = "Cinnabar", DisplayName = "Cinnabar", Color = Color3.fromRGB(122, 40, 40) },
	{ Id = "Peony", DisplayName = "Peony", Color = Color3.fromRGB(186, 82, 82) },
	{ Id = "Silver", DisplayName = "Silver", Color = Color3.fromRGB(176, 176, 178) },
}

return HairColors
