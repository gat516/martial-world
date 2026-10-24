--!strict
-- Titles (docs/systems/titles.md): earned once, kept forever, one worn at a time.
-- The worn one shows over the player's head on their namecard (Player attributes
-- Title and TitleColor, docs/systems/nameplates.md). The server (src/server/Titles.luau)
-- grants them from the profile's record; the client's picker reads these defs.
-- Only titles up to Foundation Establishment exist (user, 2026-10-24): nothing for
-- Core Formation or later. Names stay at 18 characters or fewer where they can, so
-- they fit a phone's namecard (one exception: the user's "Foundation Perfected").
--
-- A def:
--   id        the key in data.titles.owned
--   name      the text on the namecard
--   how       one short line for the picker: how it's earned (shown on locked ones too)
--   rarity    Items.Rarities key; picks the colour (the inventory's ladder)
--   category  Titles.Categories key; the picker groups by it
--   rule      what grants it (server Titles.met reads it):
--     { kind = "realm", key = "QR1" }             reached that stage
--     { kind = "stat", stat = "elites", min = n } data.stats[stat] >= min
--     { kind = "slain", ids = { ... } }           killed every one of these enemy ids
--     { kind = "rank", id = "Inner" }             sect rank at least this
--     { kind = "pages", min = n }                 Herbarium pages complete
--     { kind = "herbs" }                          every herb in the Herbarium
--     { kind = "foundation", min = pct }          any stage's foundation percent >= pct
--     { kind = "root", grade = "Earth" }          a spirit root at this grade or higher
--     { kind = "dao", class = "Sword", min = n }  weapon Dao level of a class
--     { kind = "heart" }                          a heart-demon trial picked it (its
--                                                 path answer's `title`, HeartDemon.luau)
--     { kind = "calm" }                           a heart-demon trial calmed (no denials)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

export type Rule = {
	kind: string,
	key: string?,
	stat: string?,
	min: number?,
	ids: { string }?,
	id: string?,
	grade: string?,
	class: string?,
}
export type Def = { id: string, name: string, how: string, rarity: string, category: string, rule: Rule }

local Titles = {}

-- Picker groups, in order.
Titles.Categories = {
	{ id = "Realm", name = "Realm" },
	{ id = "Heart", name = "Dao Heart" },
	{ id = "Sect", name = "Sect" },
	{ id = "Hunt", name = "Hunt" },
	{ id = "Home", name = "Home" },
	{ id = "Path", name = "Path" },
	{ id = "Dao", name = "Weapon Dao" },
}

local function def(id: string, name: string, how: string, rarity: string, category: string, rule: Rule): Def
	return { id = id, name = name, how = how, rarity = rarity, category = category, rule = rule }
end

Titles.Order = {} :: { string }
Titles.Defs = {} :: { [string]: Def }

local function add(d: Def)
	table.insert(Titles.Order, d.id)
	Titles.Defs[d.id] = d
end

-- Realm milestones
add(def("QiRefiner", "Qi Refiner", "Reach Qi Refining 1.", "Uncommon", "Realm", { kind = "realm", key = "QR1" }))
add(def("PeakOfRefining", "Peak of Refining", "Reach Qi Refining 9.", "Rare", "Realm", { kind = "realm", key = "QR9" }))
add(def("FoundationBuilder", "Foundation Builder", "Reach Foundation Establishment 1.", "Epic", "Realm", { kind = "realm", key = "FE1" }))
add(def("FoundationPerfected", "Foundation Perfected", "Reach Foundation Establishment 9.", "Legendary", "Realm", { kind = "realm", key = "FE9" }))

-- Dao hearts: a heart-demon trial's path answer picks one (HeartDemon.luau `title`)
add(def("HeartOfTheBlade", "Heart of the Blade", "Face your heart demon: own the blade's road.", "Rare", "Heart", { kind = "heart" }))
add(def("RestlessBlade", "Restless Blade", "Face your heart demon: miss the quiet.", "Rare", "Heart", { kind = "heart" }))
add(def("HeartOfTheLotus", "Heart of the Lotus", "Face your heart demon: your garden is enough.", "Rare", "Heart", { kind = "heart" }))
add(def("UnhiddenHeart", "Unhidden Heart", "Face your heart demon: own the fear you hid from.", "Rare", "Heart", { kind = "heart" }))
add(def("TwoRoadHeart", "Two-Road Heart", "Face your heart demon: walk both roads.", "Rare", "Heart", { kind = "heart" }))
add(def("HeartOfStillness", "Heart of Stillness", "Face your heart demon: walk the still road.", "Rare", "Heart", { kind = "heart" }))
add(def("CalmHeart", "Calm Heart", "Calm a heart demon: deny nothing it asks.", "Epic", "Heart", { kind = "calm" }))

-- Sect ranks
add(def("OuterDisciple", "Outer Disciple", "Answer the sect's board once.", "Common", "Sect", { kind = "stat", stat = "dailies", min = 1 }))
add(def("InnerDisciple", "Inner Disciple", "Rise to Inner Disciple.", "Rare", "Sect", { kind = "rank", id = "Inner" }))
add(def("CoreDisciple", "Core Disciple", "Rise to Core Disciple.", "Epic", "Sect", { kind = "rank", id = "Core" }))

-- The hunt: bosses, then elite and apex beasts (realm variants)
add(def("WolfKingsBane", "Wolf King's Bane", "Defeat the Elder Wolf King.", "Rare", "Hunt", { kind = "slain", ids = { "ElderWolfKing" } }))
add(def("JiaoSlayer", "Jiao Slayer", "Defeat the Jade Jiao.", "Rare", "Hunt", { kind = "slain", ids = { "JadeJiao" } }))
add(def("ThunderApeSlayer", "Thunder Ape Slayer", "Defeat the Thunder Ape.", "Epic", "Hunt", { kind = "slain", ids = { "ThunderApe" } }))
add(def("NineTailHunter", "Nine-Tail Hunter", "Defeat the Nine-Tailed Fox.", "Epic", "Hunt", { kind = "slain", ids = { "NineTailFox" } }))
add(def("BaneOfKings", "Bane of Kings", "Defeat all four beast kings.", "Legendary", "Hunt",
	{ kind = "slain", ids = { "ElderWolfKing", "JadeJiao", "ThunderApe", "NineTailFox" } }))
add(def("EliteHunter", "Elite Hunter", "Slay 10 elite beasts.", "Uncommon", "Hunt", { kind = "stat", stat = "elites", min = 10 }))
add(def("ApexHunter", "Apex Hunter", "Slay an apex beast.", "Rare", "Hunt", { kind = "stat", stat = "apexes", min = 1 }))

-- Home: the Herbarium, the peak, seclusion, the haul
add(def("PageKeeper", "Page Keeper", "Fill a Herbarium page.", "Uncommon", "Home", { kind = "pages", min = 1 }))
add(def("MasterHerbalist", "Master Herbalist", "Write every herb in your Herbarium.", "Legendary", "Home", { kind = "herbs" }))
add(def("AbodeBuilder", "Abode Builder", "Raise your peak's score to 60.", "Uncommon", "Home", { kind = "stat", stat = "peakBest", min = 60 }))
add(def("LordOfThePeak", "Lord of the Peak", "Raise your peak's score to 250.", "Epic", "Home", { kind = "stat", stat = "peakBest", min = 250 }))
add(def("SecludedOne", "Secluded One", "Spend 10 hours in seclusion.", "Uncommon", "Home", { kind = "stat", stat = "secluded", min = 10 * 3600 }))
add(def("HermitOfClouds", "Hermit of Clouds", "Spend 100 hours in seclusion.", "Epic", "Home", { kind = "stat", stat = "secluded", min = 100 * 3600 }))
add(def("PrudentHauler", "Prudent Hauler", "Store your haul 50 times.", "Uncommon", "Home", { kind = "stat", stat = "stored", min = 50 }))

-- The path: foundation, root, surges, company
add(def("DeepFoundation", "Deep Foundation", "Settle a stage at 150% foundation.", "Rare", "Path", { kind = "foundation", min = 150 }))
add(def("EarthRoot", "Earth Root", "Raise your spirit root to Earth grade.", "Rare", "Path", { kind = "root", grade = "Earth" }))
add(def("HeavenlyRoot", "Heavenly Root", "Raise your spirit root to Heaven grade.", "Legendary", "Path", { kind = "root", grade = "Heaven" }))
add(def("BurningMeridians", "Burning Meridians", "Fire 3 qi surges.", "Rare", "Path", { kind = "stat", stat = "surges", min = 3 }))
add(def("FellowTraveler", "Fellow Traveler", "Walk an hour beside a party.", "Uncommon", "Path", { kind = "stat", stat = "partied", min = 3600 }))

-- Weapon Dao: the top level of each class
for _, class in Weapons.ClassOrder do
	local c = Weapons.Classes[class]
	add(def(`{class}Master`, `{c.name} Master`, `Reach {c.name} Dao 10.`, "Epic", "Dao", { kind = "dao", class = class, min = 10 }))
end

-- The colour a title shows in (its rarity's, the inventory's ladder).
function Titles.color(id: string): Color3
	local d = Titles.Defs[id]
	local r = d and Items.Rarities[d.rarity]
	return if r then r.color else Color3.fromRGB(236, 200, 122)
end

return Titles
