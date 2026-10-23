--!strict
-- Starting outfit choices: exactly two categories, Shirt and Pants. Each option:
--   DisplayName  shown on its card
--   AssetId      the Roblox catalog id of the Shirt or Pants (what you see in the
--                catalog URL). The server looks up its template image once and hands
--                it to the preview, so you only need this id.
--   Template     optional rbxassetid:// template image (the Shirt/Pants texture
--                itself, an Image asset). When set it's worn as is, with no
--                catalog lookup, and AssetId can stay 0.
--   Thumbnail    optional rbxassetid:// image for the card; "" uses the Template,
--                else Roblox's catalog thumbnail of AssetId (rbxthumb://).
-- The first entry of each list is the default, and what everyone spawns in
-- (user, 2026-10-23: the ranger shirt and pants). Order here is the order on screen.
-- The robes and trousers after the rangers are placeholders (AssetId 0).

export type Option = { Id: string, DisplayName: string, AssetId: number, Template: string?, Thumbnail: string }

local Clothing: { Shirt: { Option }, Pants: { Option } } = {
	Shirt = {
		{ Id = "RangerShirt", DisplayName = "Ranger Shirt", AssetId = 0, Template = "rbxassetid://80918776916707", Thumbnail = "" },
		{ Id = "WhiteRobe", DisplayName = "Outer Disciple Robe", AssetId = 0, Thumbnail = "" },
		{ Id = "BlackRobe", DisplayName = "Ink Robe", AssetId = 0, Thumbnail = "" },
	},
	Pants = {
		{ Id = "RangerPants", DisplayName = "Ranger Pants", AssetId = 0, Template = "rbxassetid://129286863129062", Thumbnail = "" },
		{ Id = "BlackTrousers", DisplayName = "Ink Trousers", AssetId = 0, Thumbnail = "" },
		{ Id = "WhiteTrousers", DisplayName = "Pale Trousers", AssetId = 0, Thumbnail = "" },
	},
}

return Clothing
