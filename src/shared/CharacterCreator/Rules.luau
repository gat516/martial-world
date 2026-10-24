--!strict
-- Rules both sides use: weighted rolls, name and hair-id checks, and the screen's
-- switches. The server is the authority; the client runs the same checks only to
-- give instant feedback.

local Config = require(script.Parent.Parent.Config)

local Rules = {}

-- Open the join screen (save slots, then the character creator) on join, unless
-- a slot is already being played (QuickPlay). Testbed only until the user
-- approves it for the main game (with Config.Slots.ENABLED).
Rules.SHOW_ON_JOIN = Config.TESTBED
-- On Enter World the server dresses the live character (shirt, pants, hair, colour).
Rules.APPLY_TO_CHARACTER = true
-- The paid race and clan rerolls (Config.PAID_REROLLS; off for now).
Rules.PAID_REROLLS = Config.PAID_REROLLS == true

Rules.FIRST_NAME = { MIN = 2, MAX = 14 }
-- Roblox catalog asset types the hair field accepts (41 = HairAccessory).
Rules.HAIR_ASSET_TYPES = { [41] = true }
-- Hair accessories a player can wear at once (one field each on the Hair tab).
Rules.MAX_HAIRS = 3

-- Picks a key from a { [key]: { Weight: number } } table, weighted. `random` is an
-- optional Random so the server can seed it.
function Rules.roll(defs: { [string]: any }, random: Random?): string
	local keys = {}
	local total = 0
	for key, def in defs do
		if def.Weight > 0 then
			table.insert(keys, key)
			total += def.Weight
		end
	end
	table.sort(keys) -- stable order so a seeded roll is repeatable
	assert(total > 0, "Rules.roll: nothing to roll")
	local pick = (random or Random.new()):NextNumber() * total
	for _, key in keys do
		pick -= defs[key].Weight
		if pick <= 0 then
			return key
		end
	end
	return keys[#keys]
end

-- Chance of one key in percent, for display ("5%").
function Rules.chance(defs: { [string]: any }, key: string): number
	local total = 0
	for _, def in defs do
		total += math.max(def.Weight, 0)
	end
	local def = defs[key]
	return if def and total > 0 then def.Weight / total * 100 else 0
end

-- Basic shape check for a first name (the server also runs Roblox's text filter).
-- Returns the trimmed name, or nil and a reason the player can read.
function Rules.checkFirstName(raw: string): (string?, string?)
	local name = raw:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	local length = utf8.len(name) or #name
	if length < Rules.FIRST_NAME.MIN then
		return nil, `At least {Rules.FIRST_NAME.MIN} letters`
	elseif length > Rules.FIRST_NAME.MAX then
		return nil, `At most {Rules.FIRST_NAME.MAX} letters`
	elseif not name:match("^[%a][%a%s'%-]*$") then
		return nil, "Letters only"
	end
	return name:sub(1, 1):upper() .. name:sub(2), nil
end

-- A hair asset id typed by the player: digits only, sensible length.
function Rules.parseAssetId(raw: string): (number?, string?)
	local digits = raw:gsub("%s", "")
	if digits == "" then
		return nil, "Enter an asset ID"
	elseif not digits:match("^%d+$") then
		return nil, "Numbers only"
	elseif #digits < 4 or #digits > 19 then
		return nil, "That isn't a valid asset ID"
	end
	return tonumber(digits), nil
end

-- Tints a hair accessory: strips its texture so the colour shows, on both the
-- classic SpecialMesh hair and MeshPart hair. Used by the preview and the server.
function Rules.tintHair(accessory: Accessory, color: Color3)
	local handle = accessory:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end
	handle.Color = color
	if handle:IsA("MeshPart") then
		handle.TextureID = ""
	end
	local mesh = handle:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		mesh.TextureId = ""
		mesh.VertexColor = Vector3.new(color.R, color.G, color.B)
	end
	local surface = handle:FindFirstChildOfClass("SurfaceAppearance")
	if surface then
		surface:Destroy()
	end
end

return Rules
