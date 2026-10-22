--!strict
-- Starting outfit choices: exactly two categories, Shirt and Pants. Each option:
--   DisplayName  shown on its card
--   AssetId      the Roblox catalog id of the Shirt or Pants (what you see in the
--                catalog URL). The server looks up its template image once and hands
--                it to the preview, so you only need this id.
--   Thumbnail    optional rbxassetid:// image for the card; "" uses Roblox's
--                catalog thumbnail of AssetId (rbxthumb://).
-- The first entry of each list is the default. Order here is the order on screen.
-- The ids below are placeholders: replace them with the sect's real outfits.

export type Option = { Id: string, DisplayName: string, AssetId: number, Thumbnail: string }

local Clothing: { Shirt: { Option }, Pants: { Option } } = {
	Shirt = {
		{ Id = "WhiteRobe", DisplayName = "Outer Disciple Robe", AssetId = 0, Thumbnail = "" },
		{ Id = "BlackRobe", DisplayName = "Ink Robe", AssetId = 0, Thumbnail = "" },
	},
	Pants = {
		{ Id = "BlackTrousers", DisplayName = "Ink Trousers", AssetId = 0, Thumbnail = "" },
		{ Id = "WhiteTrousers", DisplayName = "Pale Trousers", AssetId = 0, Thumbnail = "" },
	},
}

return Clothing
