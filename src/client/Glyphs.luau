--!strict
-- The kit's white action glyphs (art/ui/codex/cut/ornament_glyph_*.png, uploaded
-- ids in art/ui/assets.json), shared by the dialogue responses and the world
-- prompts. Glyphs are white and tinted where they're shown (ImageColor3).

local Glyphs = {}

Glyphs.ids = {
	bag = "rbxassetid://79272402356640",
	bow = "rbxassetid://116766298717242",
	chest = "rbxassetid://119003802152254",
	exclaim = "rbxassetid://122224709560844",
	fight = "rbxassetid://81973780999702",
	give = "rbxassetid://73285348937035",
	harvest = "rbxassetid://129912521604806",
	heart = "rbxassetid://123509286396045",
	insight = "rbxassetid://98394523996866",
	leave = "rbxassetid://109771468541779",
	lock = "rbxassetid://113742246645347",
	plant = "rbxassetid://136552828056796",
	purse = "rbxassetid://138645714231638",
	qi = "rbxassetid://136193980275932",
	quest = "rbxassetid://127423221559639",
	question = "rbxassetid://89245673078222",
	rush = "rbxassetid://120396012908643",
	talk = "rbxassetid://110522667354738",
} :: { [string]: string }

-- A prompt's glyph from the first word of its action text. A prompt can name
-- its own with a `Glyph` attribute (one of the names above).
local BY_WORD: { [string]: string } = {
	talk = "talk",
	speak = "talk",
	ask = "talk",
	harvest = "harvest",
	pick = "harvest",
	gather = "harvest",
	plant = "plant",
	no = "plant", -- "No seeds" on a bed
	grow = "rush",
	read = "quest",
	browse = "purse",
	buy = "purse",
	trade = "purse",
	sell = "purse",
	open = "chest",
	claim = "chest",
	take = "bag",
	store = "chest", -- the haul's Store all
	study = "insight",
	touch = "qi",
	absorb = "qi",
	meditate = "qi",
	travel = "leave",
	leave = "leave",
	enter = "leave",
	give = "give",
	offer = "give",
	pray = "bow",
	bow = "bow",
	fight = "fight",
	challenge = "fight",
}

-- Whole action texts whose first word would pick the wrong glyph.
local BY_TEXT: { [string]: string } = {
	["gather qi"] = "qi",
}

-- The image id for a glyph name, or nil.
function Glyphs.get(name: string?): string?
	return if name then Glyphs.ids[name] else nil
end

-- The glyph name for a prompt (its Glyph attribute, else its action text).
function Glyphs.forPrompt(prompt: ProximityPrompt): string?
	local named = prompt:GetAttribute("Glyph")
	if type(named) == "string" and Glyphs.ids[named] then
		return named
	end
	local action = string.lower(prompt.ActionText)
	local whole = BY_TEXT[action]
	if whole then
		return whole
	end
	local word = string.match(action, "^%a+")
	return if word then BY_WORD[word] else nil
end

return Glyphs
