--!strict
-- The heart-demon trial (docs/systems/heart-demon.md). At each major's stage 9
-- (QC9, QR9, and FE9 at the peak) an inner voice asks the player about how they
-- actually climbed: the path they walked (blade or garden, from kills and
-- harvests), then the few things their record says most loudly (the beasts they
-- slew, the danger they sought, their deaths, qi surges, the haul they risked or
-- banked, their peak, the Herbarium, root pills, the company they kept (or didn't), hours in stillness and seclusion,
-- the sect's board answered or walked past).
-- Each question has 2-3 answers; the one the player's own record contradicts is a
-- denial. A new system that says how someone plays adds a counter in data.stats and
-- a question here (docs/systems/heart-demon.md "Keeping it current"). Finishing tempers old foundation percents
-- (Foundation.temper): Pacing.HeartDemon TEMPER_CALM with no denials (the demon is
-- calmed), one fewer per denial, never fewer than TEMPER_ROUGH, never lowering
-- anything. Optional and choice-based: no reflexes, it never blocks or costs a
-- breakthrough, and it can be declined and taken later (once per major).
-- The client (src/client/HeartDemon.luau) offers it from the seat and runs it on
-- the dialogue screen; it reaches here through CultivationAction:
--   "heartDemon"         start: the questions (answers without their honesty)
--   "heartDemonAnswer"   the chosen answer per question -> the outcome
--   "heartDemonDecline"  "Not now" from a seat offer (OFFER_COOLDOWN before the next)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local TitleDefs = require(ReplicatedStorage.Shared.Titles)
local PlayerData = require(script.Parent.PlayerData)
local Foundation = require(script.Parent.Foundation)
local Analytics = require(script.Parent.Analytics)

local Config = Pacing.HeartDemon

local HeartDemon = {}

-- Set by Cultivation: whether the player is meditating, and the stats + state refresh.
HeartDemon.seated = nil :: ((Player) -> boolean)?
HeartDemon.onChanged = nil :: ((Player) -> ())?

-- title: the Dao-heart title (Shared.Titles id) a path answer picks; a denial picks the
-- road the record shows, so the title is never a punishment (design review rec 1)
type Answer = { text: string, reply: string, honest: boolean, heart: string?, title: string? }
type Question = { id: string, lines: { string }, answers: { Answer } }
-- A record question and how loudly the record speaks (Candidate.weight, see `weigh`);
-- `group` keeps two of one kind (stillness and seclusion) from both being asked.
type Candidate = { q: Question, weight: number, group: string? }
type Major = { id: string, name: string, peak: number }

-- Every major with a trial, in order, with its stage 9's ladder index.
local MAJORS: { Major } = {}
for _, stage in Realms.Stages do
	if stage.minor == 9 then
		local name = string.gsub(stage.name, " 9$", "")
		table.insert(MAJORS, { id = stage.major, name = name, peak = Realms.index(stage.major, 9) })
	end
end

-- What a beast's memory sounds like, by enemy id (default ECHO).
local ECHOES: { [string]: string } = {
	SpiritWolf = "Do their howls follow you?",
	ShadowManeWolf = "Do their howls follow you?",
	StoneBoar = "Do you still hear their hooves?",
	StoneTortoise = "Do you still feel their shells crack?",
	VenomSerpent = "Does their hiss find you in the dark?",
	BloodCentipede = "Do you still hear their legs on the stone?",
	FlameRaven = "Do their cries follow you?",
	BloodBat = "Do their wings beat in your sleep?",
}
local ECHO = "Do they follow you into your dreams?"

local pending: { [Player]: { major: string, questions: { Question } } } = {}
local rng = Random.new()

local function plural(name: string, n: number): string
	if n == 1 then
		return name
	elseif string.sub(name, -3) == "olf" then
		return string.sub(name, 1, -2) .. "ves"
	elseif string.match(name, "[sx]$") or string.match(name, "ch$") then
		return name .. "es"
	end
	return name .. "s"
end

local function times(n: number): string
	return if n == 1 then "once" elseif n == 2 then "twice" else `{n} times`
end

-- How loudly a counter speaks: 1 at its threshold, +1 each doubling past it, up to
-- Config.WEIGHT_CAP, so 300 kills don't drown out 3 surges.
local function weigh(value: number, min: number): number
	return math.min(Config.WEIGHT_CAP, 1 + math.log(math.max(value, min) / math.max(min, 1e-6), 2))
end

-- The lowest major whose stage 9 the player has reached without facing its demon.
function HeartDemon.open(data: PlayerData.Data): Major?
	local here = Realms.index(data.realm.major, data.realm.minor)
	for _, m in MAJORS do
		if here >= m.peak and not data.heartDemon.trials[m.id] then
			return m
		end
	end
	return nil
end

--[[ The questions, each from the player's own record ]]

-- The path: mostly hunting, mostly gardening, both, or neither (only sitting).
local function pathQuestion(data: PlayerData.Data): Question
	local kills = data.stats.kills
	local home = data.stats.harvests * Config.HARVEST_WEIGHT
	local total = kills + home
	if total < Config.LEAN_MIN then
		return {
			id = "still",
			lines = { "You have sat, and breathed, and done little else.", "Were you waiting for the world to come to you?" },
			answers = {
				{ text = "I was. It never came.", reply = "Then go to it. It won't wait forever.", honest = true, heart = "You waited for the world", title = "HeartOfStillness" },
				{ text = "Stillness is a road too.", reply = "It is. A narrow one.", honest = true, heart = "You walked the still road", title = "HeartOfStillness" },
				{ text = "I've seen it all out there.", reply = "Everything? You've hardly left your seat.", honest = false, heart = "You claimed a road you never walked", title = "HeartOfStillness" },
			},
		}
	end
	local share = kills / total
	if share >= Config.HUNTER_SHARE then
		return {
			id = "hunter",
			lines = { "The blade, the next beast, the blade again. Your garden waits untended.", "Is there nothing in you but the fight?" },
			answers = {
				{ text = "The fight is how I grow.", reply = "Then grow. But know what it feeds.", honest = true, heart = "You walked the blade's road", title = "HeartOfTheBlade" },
				{ text = "I lost my peace out there.", reply = "Yes. You did. You can find it again.", honest = true, heart = "You walked the blade's road and missed the quiet", title = "RestlessBlade" },
				{ text = "I'm a gardener at heart.", reply = "A gardener? Your hands remember every fight.", honest = false, heart = "You denied the blade's road", title = "HeartOfTheBlade" },
			},
		}
	elseif share <= Config.GARDENER_SHARE then
		return {
			id = "gardener",
			lines = { "Seeds, water, harvest, again. The wilds went on without you.", "Were you hiding from the world?" },
			answers = {
				{ text = "Yes. It frightened me.", reply = "Fear is honest. Honesty is a start.", honest = true, heart = "You hid in your garden and owned it", title = "UnhiddenHeart" },
				{ text = "My garden is enough.", reply = "A small world can still be a true one.", honest = true, heart = "You tended a quiet world", title = "HeartOfTheLotus" },
				{ text = "No, I fight every day.", reply = "Every day? Your blade has gathered dust.", honest = false, heart = "You denied the garden's road", title = "HeartOfTheLotus" },
			},
		}
	end
	return {
		id = "both",
		lines = { "The blade one day, the garden the next.", "Which road is truly yours?" },
		answers = {
			{ text = "Both. Neither alone.", reply = "Balance. Harder than it looks.", honest = true, heart = "You walked both roads", title = "TwoRoadHeart" },
			{ text = "Only the blade.", reply = "Then whose hands tended those herbs?", honest = false, heart = "You forgot the garden", title = "TwoRoadHeart" },
			{ text = "Only the garden.", reply = "Then whose blade is so worn?", honest = false, heart = "You forgot the blade", title = "TwoRoadHeart" },
		},
	}
end

-- The beasts slain: the most-slain one by name, and any boss besides.
local function slainQuestion(data: PlayerData.Data): Candidate?
	local kills = data.stats.kills
	if kills < Config.SLAIN_MIN then
		return nil
	end
	local topId, topCount = nil :: string?, 0
	local bossName: string? = nil
	local bossCount = 0
	for id, n in data.stats.slain do
		local def = Enemies.Defs[id]
		if def and def.boss then
			if n > bossCount then
				bossName, bossCount = def.name, n
			end
		elseif def and n > topCount then
			topId, topCount = id, n
		end
	end
	local lines = {}
	if topId then
		local def = Enemies.Defs[topId]
		table.insert(lines, `{topCount} {plural(def.name, topCount)}. {ECHOES[topId] or ECHO}`)
	else
		-- counted before the trial kept them by beast
		table.insert(lines, `{kills} beasts have fallen to you. {ECHO}`)
	end
	if bossName then
		table.insert(lines, `Even the {bossName} fell to you.`)
	elseif data.stats.bossKills > 0 then
		table.insert(lines, "Even great beasts fell to you.")
	end
	table.insert(lines, "What do you feel for them?")
	return { weight = weigh(kills, Config.SLAIN_MIN), q = {
		id = "slain",
		lines = lines,
		answers = {
			{ text = "Guilt. I remember them.", reply = "Good. Memory keeps a blade honest.", honest = true, heart = "remembered every beast you slew" },
			{ text = "Resolve. I carry them.", reply = "Resolve. Mind it doesn't turn to stone.", honest = true, heart = "carried the fallen with resolve" },
			{ text = "Nothing. Only beasts.", reply = "Only beasts? Then why am I here?", honest = false, heart = "would not look at the fallen" },
		},
	} }
end

-- Danger sought: elite and apex beasts (realm variants) slain.
local function dangerQuestion(data: PlayerData.Data): Candidate?
	local elites, apexes = data.stats.elites, data.stats.apexes
	local score = elites + apexes * 2
	if score < Config.DANGER_MIN then
		return nil
	end
	local parts = {}
	if elites > 0 then
		table.insert(parts, `{elites} {if elites == 1 then "elite" else "elites"}`)
	end
	if apexes > 0 then
		table.insert(parts, `{apexes} apex {if apexes == 1 then "beast" else "beasts"}`)
	end
	return { weight = weigh(score, Config.DANGER_MIN) + 0.5, q = {
		id = "danger",
		lines = { `You went looking for the strongest: {table.concat(parts, " and ")}.`, "What were you hoping to find?" },
		answers = {
			{ text = "Something stronger than me.", reply = "You found it. Again and again.", honest = true, heart = "sought out the strongest beasts" },
			{ text = "Proof that I'm ready.", reply = "Proof is a hungry thing. Feed it carefully.", honest = true, heart = "hunted danger for proof" },
			{ text = "I keep to easy prey.", reply = "Easy? The dark ones remember you.", honest = false, heart = "hid the danger you chased" },
		},
	} }
end

-- Deaths: fear. Never fallen: pride (a quieter record, so it weighs least).
local function fearQuestion(data: PlayerData.Data): Candidate
	local deaths = data.stats.deaths
	if deaths > 0 then
		return { weight = weigh(deaths, 1), q = {
			id = "fear",
			lines = { `You have fallen {times(deaths)}. Each time, you rose.`, "Are you afraid to fall again?" },
			answers = {
				{ text = "Yes, but I keep going.", reply = "Then fear hasn't won.", honest = true, heart = "feared the fall and went on" },
				{ text = "Falling made me careful.", reply = "A hard teacher. A good one.", honest = true, heart = "learned from every fall" },
				{ text = "I'm never afraid.", reply = "Never? I was there every time.", honest = false, heart = "hid your fear" },
			},
		} }
	end
	return { weight = 1, q = {
		id = "pride",
		lines = { "Not once have you fallen.", "Do you think you can't?" },
		answers = {
			{ text = "Anyone can fall.", reply = "Careful. Keep it.", honest = true, heart = "never fell, and knew you could" },
			{ text = "I've been lucky.", reply = "Luck runs out. Be ready when it does.", honest = true, heart = "thanked your luck" },
			{ text = "Nothing can touch me.", reply = "Pride is a crack you can't see.", honest = false, heart = "thought nothing could touch you" },
		},
	} }
end

-- The qi surge (QiSurge.luau): burning raw qi to fight a stage up when nearly beaten.
-- Old forced breakthroughs (the surge replaced them) count as surges.
local function surgeQuestion(data: PlayerData.Data): Candidate?
	local n = data.stats.surges + data.stats.forced
	if n < Config.SURGE_MIN then
		return nil
	end
	return { weight = weigh(n, Config.SURGE_MIN) + 0.5, q = {
		id = "surge",
		lines = { `You burned your qi to survive {times(n)}, beaten and bleeding.`, "Was it worth what it cost?" },
		answers = {
			{ text = "I'd have fallen without it.", reply = "Then it bought you this moment.", honest = true, heart = "burned your qi to stay standing" },
			{ text = "I lean on it too much.", reply = "Then learn to stand without it.", honest = true, heart = "leaned on the surge, and knew it" },
			{ text = "I've never needed it.", reply = "Never? Your dantian remembers the fire.", honest = false, heart = "forgot the fire that saved you" },
		},
	} }
end

-- The haul (Haul.luau): greed (spills, fleeing mid-fight) or caution (Store all,
-- the spirit ring). Neither when there's too little of either.
local function haulQuestion(data: PlayerData.Data): Candidate?
	local st = data.stats
	local lost = st.spills + st.fled
	if lost >= Config.HAUL_LOST_MIN and lost * Config.HAUL_LOST_WEIGHT >= st.stored then
		local lines = { `Your haul spilled on the ground {times(lost)}.` }
		if st.reclaimed > 0 then
			table.insert(lines, `You went back for it {times(st.reclaimed)}.`)
		end
		table.insert(lines, "Why carry so much, so far from home?")
		return { weight = weigh(lost, Config.HAUL_LOST_MIN) + 0.5, q = {
			id = "greed",
			lines = lines,
			answers = {
				{ text = "I wanted more. Always more.", reply = "Greed is honest. It is also heavy.", honest = true, heart = "carried more than you could keep" },
				{ text = "I'll bank sooner now.", reply = "Then the wilds will keep less of you.", honest = true, heart = "learned to bring it home" },
				{ text = "I always bring it home.", reply = "Always? The ground still glows where you fell.", honest = false, heart = "denied what the wilds kept" },
			},
		} }
	end
	if st.stored >= Config.HAUL_STORED_MIN and lost == 0 then
		local lines = { `You came home {times(st.stored)} and stored every grain. The wilds kept nothing.` }
		if st.ringed > 0 then
			table.insert(lines, "Even your ring held what you couldn't bear to lose.")
		end
		table.insert(lines, "Is caution all you have?")
		return { weight = weigh(st.stored, Config.HAUL_STORED_MIN), q = {
			id = "caution",
			lines = lines,
			answers = {
				{ text = "Nothing earned is wasted.", reply = "A careful hand. A slow one too.", honest = true, heart = "brought every grain home" },
				{ text = "I'm afraid to lose it.", reply = "Then you know what it's worth.", honest = true, heart = "guarded what you earned, and feared for it" },
				{ text = "I gamble it all.", reply = "Gamble? You never once lost a grain.", honest = false, heart = "hid your caution" },
			},
		} }
	end
	return nil
end

-- Peak building (Build, Peaks): a builder, or a wanderer whose peak stands bare.
local function peakQuestion(data: PlayerData.Data): Candidate?
	local placed = data.stats.placed
	if placed >= Config.BUILD_MIN then
		return { weight = weigh(placed, Config.BUILD_MIN), q = {
			id = "builder",
			lines = { `{placed} pieces set on your peak, one by one. Its score rose to {math.floor(data.stats.peakBest)}.`, "Are you building a home, or a wall?" },
			answers = {
				{ text = "A home to come back to.", reply = "Then return to it. Often.", honest = true, heart = "built a home to return to" },
				{ text = "A wall against the world.", reply = "Walls keep out the cold. And the warmth.", honest = true, heart = "built your walls high" },
				{ text = "I don't care for my peak.", reply = "No? Then who set every stone?", honest = false, heart = "disowned the home you built" },
			},
		} }
	end
	if placed <= Config.WANDER_MAX and data.stats.kills >= Config.SLAIN_MIN then
		return { weight = 1, q = {
			id = "wanderer",
			lines = { "Your peak stands bare. You are always somewhere else.", "Is anywhere home to you?" },
			answers = {
				{ text = "The road is my home.", reply = "A wide home. A cold one at night.", honest = true, heart = "made the road your home" },
				{ text = "I haven't had the time.", reply = "Make time. A peak remembers its keeper.", honest = true, heart = "left your peak waiting" },
				{ text = "My peak is my pride.", reply = "Your pride? It hardly knows your face.", honest = false, heart = "boasted of a peak you never tended" },
			},
		} }
	end
	return nil
end

-- The Herbarium (Herbarium.luau): herbs discovered and tier pages completed.
local function herbariumQuestion(data: PlayerData.Data): Candidate?
	local found = 0
	for _ in data.herbarium.herbs do
		found += 1
	end
	if found < Config.HERB_MIN then
		return nil
	end
	local pages = 0
	for _ in data.herbarium.tiers do
		pages += 1
	end
	local lines = { `{found} of {#Herbs.Order} herbs written in your book.` }
	if pages > 0 then
		table.insert(lines, `{if pages == 1 then "One page" else `{pages} pages`} full, every name in place.`)
	end
	table.insert(lines, "What were you looking for?")
	return { weight = weigh(found, Config.HERB_MIN) + pages * 0.5, q = {
		id = "herbarium",
		lines = lines,
		answers = {
			{ text = "Everything, all named.", reply = "Then keep looking. The world is wide.", honest = true, heart = "named every herb you found" },
			{ text = "Something that might heal.", reply = "A gentle reason. Hold on to it.", honest = true, heart = "searched the green for healing" },
			{ text = "I never stopped to look.", reply = "Never? Your book says otherwise.", honest = false, heart = "forgot the herbs you named" },
		},
	} }
end

-- Root pills (Roots.luau): marrow washing and root rebirth, chasing a better self.
local function rootQuestion(data: PlayerData.Data): Candidate?
	local washed, rerolls = data.stats.washed, data.stats.rerolls
	if washed + rerolls < Config.ROOT_MIN then
		return nil
	end
	local line = if washed > 0 and rerolls > 0
		then `You burned your marrow with {washed} {if washed == 1 then "pill" else "pills"}, and remade your root {times(rerolls)}.`
		elseif washed > 0 then `You burned your marrow with {washed} {if washed == 1 then "pill" else "pills"}.`
		else `You dissolved your root and remade it {times(rerolls)}.`
	return { weight = weigh(washed + rerolls * 2, Config.ROOT_MIN) + 0.5, q = {
		id = "root",
		lines = { line, "Were you not enough as you were?" },
		answers = {
			{ text = "I want to be more.", reply = "Want is a fire. Mind what it burns.", honest = true, heart = "chased a better self" },
			{ text = "I'm still finding myself.", reply = "Then keep looking. Gently.", honest = true, heart = "searched for who you are" },
			{ text = "I'm content as I am.", reply = "Content? Then why the pills?", honest = false, heart = "hid your hunger to change" },
		},
	} }
end

-- The sect (Sect.luau): a dutiful disciple who answers the board, or a lone wolf
-- who read it and walked past.
local function sectQuestion(data: PlayerData.Data): Candidate?
	local dailies, earned = data.stats.dailies, data.stats.contribution
	if dailies >= Config.DUTY_MIN then
		return { weight = weigh(dailies, Config.DUTY_MIN), q = {
			id = "duty",
			lines = { `You answered the sect's board {dailies} times. {earned} contribution to your name.`, "Do you serve the sect, or yourself?" },
			answers = {
				{ text = "The sect raised me.", reply = "And you repay it. Mind it repays you.", honest = true, heart = "served the sect that raised you" },
				{ text = "Its rewards serve me.", reply = "An honest trade. Few admit it.", honest = true, heart = "served the sect for what it paid" },
				{ text = "I walk alone.", reply = "Alone? The board knows your hand well.", honest = false, heart = "disowned the sect you served" },
			},
		} }
	end
	if dailies <= Config.LONE_MAX and data.lessons.BoardRead then
		return { weight = 1, q = {
			id = "lone",
			lines = { "The sect's board called for you, day after day. You walked past it.", "Do you need no one?" },
			answers = {
				{ text = "I walk my own road.", reply = "A lone wolf hunts well. And sleeps cold.", honest = true, heart = "walked your own road" },
				{ text = "I meant to, one day.", reply = "One day comes. Or it doesn't.", honest = true, heart = "left the sect's call for one day" },
				{ text = "I serve the sect well.", reply = "Serve it? You never took its work.", honest = false, heart = "claimed a duty you never took up" },
			},
		} }
	end
	return nil
end

local function stillQuestion(data: PlayerData.Data): Candidate?
	local hours = data.stats.seated / 3600
	if hours < Config.STILL_MIN_HOURS then
		return nil
	end
	local shown = if hours < 1.5 then "An hour" else `{math.floor(hours + 0.5)} hours`
	return { group = "sit", weight = weigh(hours, Config.STILL_MIN_HOURS) - 1, q = {
		id = "stillness",
		lines = { `{shown} seated in stillness.`, "Were you searching, or only waiting?" },
		answers = {
			{ text = "Searching. Quiet teaches.", reply = "It does, to those who listen.", honest = true, heart = "listened to the quiet" },
			{ text = "Waiting, and that's fine.", reply = "It is. Waiting is not nothing.", honest = true, heart = "knew how to wait" },
			{ text = "I hardly ever sit.", reply = "Hardly ever? I counted every breath.", honest = false, heart = "would not admit your stillness" },
		},
	} }
end

-- Seclusion (Seclusion.luau): long hours shut away, online and offline. Shares the
-- "sit" group with stillness: only the louder of the two is asked.
local function seclusionQuestion(data: PlayerData.Data): Candidate?
	local hours = data.stats.secluded / 3600
	if hours < Config.SECLUDED_MIN_HOURS then
		return nil
	end
	return { group = "sit", weight = weigh(hours, Config.SECLUDED_MIN_HOURS), q = {
		id = "seclusion",
		lines = { `You sat in seclusion for {math.floor(hours + 0.5)} hours.`, "Were you hiding?" },
		answers = {
			{ text = "No. I was gathering.", reply = "Then let what you gathered show.", honest = true, heart = "shut the world out to gather yourself" },
			{ text = "Yes. The world is loud.", reply = "It is. But it waits for you.", honest = true, heart = "hid from the world, and said so" },
			{ text = "I never shut myself away.", reply = "Never? The door was closed a long time.", honest = false, heart = "would not admit your seclusion" },
		},
	} }
end

-- Company (Party.luau): time in a party with someone nearby, or none at all.
local function companyQuestion(data: PlayerData.Data): Question?
	local minutes = (data.stats.partied or 0) / 60
	if minutes < Config.SOLITARY_MAX_MINUTES then
		if data.stats.kills + data.stats.harvests < Config.LEAN_MIN then
			return nil -- too early to call anyone a loner
		end
		return {
			id = "solitude",
			lines = { "You never walked with another.", "Do you trust no one?" },
			answers = {
				{ text = "No one has earned it.", reply = "Then you carry it all yourself.", honest = true, heart = "trusted no one" },
				{ text = "I like my own road.", reply = "A lonely road is still a road.", honest = true, heart = "walked alone by choice" },
				{ text = "I always walk with friends.", reply = "Always? I saw only your shadow.", honest = false, heart = "would not admit your solitude" },
			},
		}
	end
	if minutes < Config.COMPANY_MIN_MINUTES then
		return nil
	end
	local hours = minutes / 60
	local shown = if minutes < 60 then `{math.floor(minutes + 0.5)} minutes`
		elseif hours < 1.5 then "An hour"
		else `{math.floor(hours + 0.5)} hours`
	return {
		id = "company",
		lines = { `{shown} walking beside others.`, "Did you lean on them?" },
		answers = {
			{ text = "Yes, and they on me.", reply = "Then the bond holds both ways.", honest = true, heart = "climbed with others" },
			{ text = "No. We walked as equals.", reply = "Equals. Rarer than you think.", honest = true, heart = "walked beside equals" },
			{ text = "I've always walked alone.", reply = "Alone? Their footsteps say otherwise.", honest = false, heart = "would not admit your companions" },
		},
	}
end

-- The company question as a candidate: solitude weighs 1, company grows with the minutes.
local function companyCandidate(data: PlayerData.Data): Candidate?
	local q = companyQuestion(data)
	if not q then
		return nil
	end
	local minutes = (data.stats.partied or 0) / 60
	return { weight = if q.id == "solitude" then 1 else weigh(minutes, Config.COMPANY_MIN_MINUTES), q = q }
end

-- Always there: why climb at all (every answer is honest).
local function climbQuestion(): Question
	return {
		id = "climb",
		lines = { "One more wall. Then another, and another.", "Why do you climb at all?" },
		answers = {
			{ text = "To protect those I love.", reply = "Then hold on to them.", honest = true, heart = "climbed for others" },
			{ text = "To see how high I go.", reply = "Higher than this. We'll see.", honest = true, heart = "climbed to see how high" },
			{ text = "I don't know yet.", reply = "An honest answer. Rarer than you think.", honest = true, heart = "climbed without knowing why, and said so" },
		},
	}
end

-- The questions for this player: the path first, then the record questions that
-- speak loudest (highest weight; ties keep the order below), one per group, with
-- "why climb" filling in up to Config.QUESTIONS. Answers shuffled.
function HeartDemon.questions(data: PlayerData.Data): { Question }
	local list = { pathQuestion(data) }
	local built = {
		slainQuestion(data), dangerQuestion(data), fearQuestion(data), surgeQuestion(data),
		haulQuestion(data), peakQuestion(data), herbariumQuestion(data), rootQuestion(data),
		companyCandidate(data), seclusionQuestion(data), stillQuestion(data), sectQuestion(data),
	}
	local candidates: { Candidate } = {}
	local order: { [Candidate]: number } = {}
	for i = 1, 12 do -- `built` has holes where a question had nothing to ask
		local c = built[i]
		if c then
			table.insert(candidates, c)
			order[c] = i
		end
	end
	table.sort(candidates, function(a, b)
		if a.weight ~= b.weight then
			return a.weight > b.weight
		end
		return order[a] < order[b]
	end)
	local groups: { [string]: boolean } = {}
	for _, c in candidates do
		if #list >= Config.QUESTIONS then
			break
		end
		if not (c.group and groups[c.group]) then
			table.insert(list, c.q)
			if c.group then
				groups[c.group] = true
			end
		end
	end
	if #list < Config.QUESTIONS then
		table.insert(list, climbQuestion())
	end
	for _, q in list do
		for i = #q.answers, 2, -1 do
			local j = rng:NextInteger(1, i)
			q.answers[i], q.answers[j] = q.answers[j], q.answers[i]
		end
	end
	return list
end

--[[ The trial ]]

function HeartDemon.start(player: Player): (boolean, any)
	local data = PlayerData.get(player)
	if not data then
		return false, "Still loading"
	end
	local major = HeartDemon.open(data)
	if not major then
		return false, "No heart demon stirs in you now."
	end
	if HeartDemon.seated and not HeartDemon.seated(player) then
		return false, "Sit and meditate to face your heart demon."
	end
	local questions = HeartDemon.questions(data)
	pending[player] = { major = major.id, questions = questions }
	local view = {}
	for _, q in questions do
		local answers = {}
		for _, a in q.answers do
			table.insert(answers, { text = a.text, reply = a.reply })
		end
		table.insert(view, { lines = q.lines, answers = answers })
	end
	return true, { major = major.id, name = major.name, questions = view }
end

local function temperLine(tempered: { Foundation.Tempered }, data: PlayerData.Data): string
	if #tempered == 0 then
		return if next(data.foundation.grades) == nil
			then "You have no old foundations yet. There was nothing to temper."
			else `Your old foundations are all {Pacing.Foundation.TEMPER_MAX}% or more. There was nothing left to temper.`
	end
	local parts = {}
	for _, t in tempered do
		table.insert(parts, `{Realms.ByKey[t.key].name} is now {t.toPercent}%`)
	end
	return `Your old foundations temper: {table.concat(parts, ", ")}.`
end

function HeartDemon.answer(player: Player, choices: any): (boolean, any)
	local data = PlayerData.get(player)
	local trial = pending[player]
	if not (data and trial) then
		return false, "Your heart demon has gone quiet. Sit and face it again."
	end
	if data.heartDemon.trials[trial.major] then
		pending[player] = nil
		return false, "You have already faced this demon."
	end
	if type(choices) ~= "table" or #choices ~= #trial.questions then
		return false, "Answer every question."
	end
	local denials = 0
	local hearts = {}
	local title: string? = nil -- the path (always first) picks the Dao heart
	for i, q in trial.questions do
		local c = choices[i]
		local answer = type(c) == "number" and q.answers[c]
		if not answer then
			return false, "Answer every question."
		end
		if not answer.honest then
			denials += 1
		end
		if i == 1 then
			title = answer.title
		end
		if answer.heart and #hearts < 2 then
			table.insert(hearts, answer.heart)
		end
	end
	pending[player] = nil
	local calm = denials == 0
	local steps = math.max(Config.TEMPER_ROUGH, Config.TEMPER_CALM - denials)
	local tempered = Foundation.temper(data, steps)
	local note = `{table.concat(hearts, ", and ")}. {if calm then "The demon was calmed." else "The demon still whispers."}`
	data.heartDemon.trials[trial.major] = {
		calm = calm,
		denials = denials,
		tempered = #tempered,
		note = note,
		at = os.time(),
		title = title, -- Titles.check grants it on the push below (server Titles)
	}
	Analytics.event(player, "HeartDemonFaced", denials, trial.major, if calm then "calm" else "whispers")
	local lines = if calm
		then { "The voice goes quiet. It was only ever your own heart.", temperLine(tempered, data) }
		else { "The demon fades, but not all the way. You'll hear it now and then.", temperLine(tempered, data) }
	local heart = title and TitleDefs.Defs[title]
	if heart then
		table.insert(lines, `Your Dao heart: {heart.name}.`)
	end
	if HeartDemon.onChanged then
		HeartDemon.onChanged(player)
	end
	return true, { calm = calm, lines = lines, note = note, tempered = tempered }
end

-- "Not now" from a seat offer: the seat waits OFFER_COOLDOWN before asking again.
function HeartDemon.decline(player: Player): (boolean, any)
	local data = PlayerData.get(player)
	local major = data and HeartDemon.open(data)
	if not (data and major) then
		return false, nil
	end
	data.heartDemon.declined[major.id] = os.time()
	if HeartDemon.onChanged then
		HeartDemon.onChanged(player)
	end
	return true, nil
end

-- For the PlayerState push: the open trial (nil when none), whether the player is
-- at a stage 9 (the Break Through offer), whether a seat offer waits
-- out a "Not now", and every finished trial (the heart notes, for the Self card).
function HeartDemon.state(data: PlayerData.Data)
	local major = HeartDemon.open(data)
	local declined = major and data.heartDemon.declined[major.id] or 0
	return {
		open = major and major.id,
		name = major and major.name,
		atPeak = major ~= nil and data.realm.minor == 9, -- at a major's stage 9 (its own, or a later one's)
		snoozed = major ~= nil and os.time() - declined < Config.OFFER_COOLDOWN,
		trials = data.heartDemon.trials,
	}
end

function HeartDemon.forget(player: Player)
	pending[player] = nil
end

return HeartDemon
