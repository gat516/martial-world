--!strict
-- Skin colours the player may pick on the Clothes tab, in grid order. The first,
-- "Avatar", has no Color: it keeps the skin of the player's own Roblox avatar,
-- and it's the default. The server only accepts ids listed here.

export type SkinColor = { Id: string, DisplayName: string, Color: Color3? }

local SkinColors: { SkinColor } = {
	{ Id = "Avatar", DisplayName = "Your Avatar's Skin", Color = nil },
	{ Id = "Porcelain", DisplayName = "Porcelain", Color = Color3.fromRGB(248, 226, 208) },
	{ Id = "Ivory", DisplayName = "Ivory", Color = Color3.fromRGB(234, 206, 178) },
	{ Id = "Peach", DisplayName = "Peach", Color = Color3.fromRGB(226, 186, 150) },
	{ Id = "Honey", DisplayName = "Honey", Color = Color3.fromRGB(204, 158, 116) },
	{ Id = "Bronze", DisplayName = "Bronze", Color = Color3.fromRGB(168, 118, 82) },
	{ Id = "Umber", DisplayName = "Umber", Color = Color3.fromRGB(124, 84, 58) },
	{ Id = "Ebony", DisplayName = "Ebony", Color = Color3.fromRGB(78, 52, 38) },
	{ Id = "Jade", DisplayName = "Jade Spirit", Color = Color3.fromRGB(148, 190, 160) },
	{ Id = "Ash", DisplayName = "Ash Ghost", Color = Color3.fromRGB(178, 180, 188) },
}

return SkinColors
