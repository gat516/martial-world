--!strict
-- The heart-demon trial (docs/systems/heart-demon.md). At each major's stage 9
-- (QC9, QR9, and FE9 at the peak) an inner voice asks the player about how they
-- actually climbed: the path they walked (blade or garden, from kills and
-- harvests), the beasts they slew, their deaths, forced breakthroughs, hours in
-- stillness and in seclusion. Each question has 2-3 answers; the one the player's own record
-- contradicts is a denial. Finishing tempers old foundation grades
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
local PlayerData = require(script.Parent.PlayerData)
local Foundation = require(script.Parent.Foundation)

local Config = Pacing.HeartDemon

local HeartDemon = {}

-- Set by Cultivation: whether the player is meditating, and the stats + state refresh.
HeartDemon.seated = nil :: ((Player) -> boolean)?
HeartDemon.onChanged = nil :: ((Player) -> ())?

type Answer = { text: string, reply: string, honest: boolean, heart: string? }
type Question = { id: string, lines: { string }, answers: { Answer } }
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
				{ text = "I was. It never came.", reply = "Then go to it. It won't wait forever.", honest = true, heart = "You waited for the world" },
				{ text = "Stillness is a road too.", reply = "It is. A narrow one.", honest = true, heart = "You walked the still road" },
				{ text = "I've seen it all out there.", reply = "Everything? You've hardly left your seat.", honest = false, heart = "You claimed a road you never walked" },
			},
		}
	end
	local share = kills / total
	if share >= Config.HUNTER_SHARE then
		return {
			id = "hunter",
			lines = { "The blade, the next beast, the blade again. Your garden waits untended.", "Is there nothing in you but the fight?" },
			answers = {
				{ text = "The fight is how I grow.", reply = "Then grow. But know what it feeds.", honest = true, heart = "You walked the blade's road" },
				{ text = "I lost my peace out there.", reply = "Yes. You did. You can find it again.", honest = true, heart = "You walked the blade's road and missed the quiet" },
				{ text = "I'm a gardener at heart.", reply = "A gardener? Your hands remember every fight.", honest = false, heart = "You denied the blade's road" },
			},
		}
	elseif share <= Config.GARDENER_SHARE then
		return {
			id = "gardener",
			lines = { "Seeds, water, harvest, again. The wilds went on without you.", "Were you hiding from the world?" },
			answers = {
				{ text = "Yes. It frightened me.", reply = "Fear is honest. Honesty is a start.", honest = true, heart = "You hid in your garden and owned it" },
				{ text = "My garden is enough.", reply = "A small world can still be a true one.", honest = true, heart = "You tended a quiet world" },
				{ text = "No, I fight every day.", reply = "Every day? Your blade has gathered dust.", honest = false, heart = "You denied the garden's road" },
			},
		}
	end
	return {
		id = "both",
		lines = { "The blade one day, the garden the next.", "Which road is truly yours?" },
		answers = {
			{ text = "Both. Neither alone.", reply = "Balance. Harder than it looks.", honest = true, heart = "You walked both roads" },
			{ text = "Only the blade.", reply = "Then whose hands tended those herbs?", honest = false, heart = "You forgot the garden" },
			{ text = "Only the garden.", reply = "Then whose blade is so worn?", honest = false, heart = "You forgot the blade" },
		},
	}
end

-- The beasts slain: the most-slain one by name, and any boss besides.
local function slainQuestion(data: PlayerData.Data): Question?
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
	return {
		id = "slain",
		lines = lines,
		answers = {
			{ text = "Guilt. I remember them.", reply = "Good. Memory keeps a blade honest.", honest = true, heart = "remembered every beast you slew" },
			{ text = "Resolve. I carry them.", reply = "Resolve. Mind it doesn't turn to stone.", honest = true, heart = "carried the fallen with resolve" },
			{ text = "Nothing. Only beasts.", reply = "Only beasts? Then why am I here?", honest = false, heart = "would not look at the fallen" },
		},
	}
end

-- Deaths: fear. Never fallen: pride.
local function fearQuestion(data: PlayerData.Data): Question
	local deaths = data.stats.deaths
	if deaths > 0 then
		return {
			id = "fear",
			lines = { `You have fallen {times(deaths)}. Each time, you rose.`, "Are you afraid to fall again?" },
			answers = {
				{ text = "Yes, but I keep going.", reply = "Then fear hasn't won.", honest = true, heart = "feared the fall and went on" },
				{ text = "Falling made me careful.", reply = "A hard teacher. A good one.", honest = true, heart = "learned from every fall" },
				{ text = "I'm never afraid.", reply = "Never? I was there every time.", honest = false, heart = "hid your fear" },
			},
		}
	end
	return {
		id = "pride",
		lines = { "Not once have you fallen.", "Do you think you can't?" },
		answers = {
			{ text = "Anyone can fall.", reply = "Careful. Keep it.", honest = true, heart = "never fell, and knew you could" },
			{ text = "I've been lucky.", reply = "Luck runs out. Be ready when it does.", honest = true, heart = "thanked your luck" },
			{ text = "Nothing can touch me.", reply = "Pride is a crack you can't see.", honest = false, heart = "thought nothing could touch you" },
		},
	}
end

local function forcedQuestion(data: PlayerData.Data): Question?
	local n = data.stats.forced
	if n < 1 then
		return nil
	end
	return {
		id = "forced",
		lines = { `You tore through a wall mid-fight, hurt and hurried, {times(n)}.`, "Was it worth the debt?" },
		answers = {
			{ text = "I had to. I'd do it again.", reply = "Desperation is honest, at least.", honest = true, heart = "broke walls when you had to" },
			{ text = "I rushed, and I paid.", reply = "Then you learned something.", honest = true, heart = "learned not to rush" },
			{ text = "I've never rushed.", reply = "Never? Your meridians remember.", honest = false, heart = "forgot your haste" },
		},
	}
end

local function stillQuestion(data: PlayerData.Data): Question?
	local hours = data.stats.seated / 3600
	if hours < Config.STILL_MIN_HOURS then
		return nil
	end
	local shown = if hours < 1.5 then "An hour" else `{math.floor(hours + 0.5)} hours`
	return {
		id = "stillness",
		lines = { `{shown} seated in stillness.`, "Were you searching, or only waiting?" },
		answers = {
			{ text = "Searching. Quiet teaches.", reply = "It does, to those who listen.", honest = true, heart = "listened to the quiet" },
			{ text = "Waiting, and that's fine.", reply = "It is. Waiting is not nothing.", honest = true, heart = "knew how to wait" },
			{ text = "I hardly ever sit.", reply = "Hardly ever? I counted every breath.", honest = false, heart = "would not admit your stillness" },
		},
	}
end

-- Seclusion (Seclusion.luau): long hours shut away, online and offline.
local function seclusionQuestion(data: PlayerData.Data): Question?
	local hours = data.stats.secluded / 3600
	if hours < Config.SECLUDED_MIN_HOURS then
		return nil
	end
	return {
		id = "seclusion",
		lines = { `You sat in seclusion for {math.floor(hours + 0.5)} hours.`, "Were you hiding?" },
		answers = {
			{ text = "No. I was gathering.", reply = "Then let what you gathered show.", honest = true, heart = "shut the world out to gather yourself" },
			{ text = "Yes. The world is loud.", reply = "It is. But it waits for you.", honest = true, heart = "hid from the world, and said so" },
			{ text = "I never shut myself away.", reply = "Never? The door was closed a long time.", honest = false, heart = "would not admit your seclusion" },
		},
	}
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

-- The questions for this player: the path first, then what the record holds most,
-- with "why climb" filling in; up to Config.QUESTIONS, answers shuffled.
function HeartDemon.questions(data: PlayerData.Data): { Question }
	local list = { pathQuestion(data) }
	for _, q in { slainQuestion(data), fearQuestion(data), forcedQuestion(data), seclusionQuestion(data), stillQuestion(data), climbQuestion() } do
		if q and #list < Config.QUESTIONS then
			table.insert(list, q)
		end
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
			then "Your foundation holds no old grades yet. There was nothing to temper."
			else "Your old foundations are already deep. There was nothing left to temper."
	end
	local parts = {}
	for _, t in tempered do
		table.insert(parts, `{Realms.ByKey[t.key].name} is now {t.to}`)
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
	for i, q in trial.questions do
		local c = choices[i]
		local answer = type(c) == "number" and q.answers[c]
		if not answer then
			return false, "Answer every question."
		end
		if not answer.honest then
			denials += 1
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
	}
	local lines = if calm
		then { "The voice goes quiet. It was only ever your own heart.", temperLine(tempered, data) }
		else { "The demon fades, but not all the way. You'll hear it now and then.", temperLine(tempered, data) }
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
