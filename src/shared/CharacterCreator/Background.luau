--!strict
-- How the world behind the character screen is shown.
--   Mode = "Live":  the real map, seen through the player's camera parked at a
--                   high vantage over the sect (a stone pillar overlooking it).
--   Mode = "Image": a full-screen image (FallbackImage). Used automatically when
--                   the vantage can't be found (no Workspace.Map).
-- The vantage comes from a part tagged VantageTag in Workspace.Map (place-only;
-- its CFrame is the camera: position = eye, look vector = view), else from
-- VantageCFrame below. Place the tagged part in Studio to move the view without
-- touching code.

local Background = {
	Mode = "Live" :: "Live" | "Image",
	VantageTag = "CharacterCreatorVantage",
	-- Fallback when no tagged part exists (nil = use the image; ignored in a
	-- place without Workspace.Map). High above the East Sentinels karst pillar (Map.Karst.EastSentinels,
	-- top about y 870), looking west at the sect's central peak (MainPeak) with its
	-- ring of spirit peaks, bridges and cloud sea, like reference 4.
	VantageCFrame = CFrame.lookAt(Vector3.new(400, 880, 420), Vector3.new(-170, 650, 0)) :: CFrame?,
	FieldOfView = 55,
	Drift = { Degrees = 2.5, Period = 24 }, -- slow sway of the live camera; Degrees 0 turns it off
	Blur = 6, -- BlurEffect size behind the panels (0 = none)
	DepthOfField = { Enabled = true, FocusDistance = 120, InFocusRadius = 400, FarIntensity = 0.25 },
	FallbackImage = "", -- rbxassetid:// of a scenic painting; "" = the theme's plain ink-wash gradient
}

return Background
