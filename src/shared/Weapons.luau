--!strict
-- Weapon classes (Dao paths) and weapon items.
--   A class owns its M1 chain, hitbox and max targets (Config.Combat.CLASSES),
--   its idle/walk, the Motor6D joint its model hangs from and a Dao
--   comprehension level (Pacing.Weapons). "Fist" is the class with nothing equipped.
--   A weapon item is one concrete weapon of a class and grade; its model is
--   ServerStorage.WeaponModels.<model>, joined to the Right Arm by the Motor6D
--   named `joint` inside the model's PrimaryPart (see docs/systems/weapons.md).
-- Damage of M1 and the class's techniques = base * realm power
--   * grade multiplier (equipped weapon) * daoMultiplier(class level).
-- Animation ids live only in assets/Animations.rbxmx: Animations.Fists.<n>
-- for Fist, Animations.Weapons.<Class>.<n> / .Idle / .Walk for the rest.

local Combat = require(script.Parent.Config).Combat
local Pacing = require(script.Parent.Pacing).Weapons

export type Class = {
	id: string,
	name: string, -- "Sword"
	dao: string, -- "Sword Dao"
	noun: string, -- what "Requires a ..." names: "sword"; "bare hands" for Fist
	joint: string?, -- the Motor6D / PrimaryPart name in its weapon models (nil for Fist)
	steps: { any }, -- Config.Combat.CLASSES[id].steps
	hitbox: Vector3,
	maxTargets: number,
	idle: boolean, -- has Animations.Weapons.<id>.Idle
	walk: boolean, -- has Animations.Weapons.<id>.Walk
	icon: string?,
}

export type Weapon = {
	id: string,
	name: string,
	class: string,
	grade: string,
	model: string, -- ServerStorage.WeaponModels child
	blurb: string,
	icon: string?,
}

export type Grade = { name: string, multiplier: number, color: Color3, order: number, tier: number }

local Weapons = {}

Weapons.FIST = "Fist"

local function class(id: string, name: string, noun: string, joint: string?, idle: boolean, walk: boolean): Class
	local c = Combat.CLASSES[id]
	return {
		id = id, name = name, dao = `{name} Dao`, noun = noun, joint = joint,
		steps = c.steps, hitbox = c.hitbox, maxTargets = c.maxTargets, idle = idle, walk = walk,
	}
end

Weapons.Classes = {
	Fist = class("Fist", "Fist", "bare hands", nil, false, false),
	Sword = class("Sword", "Sword", "sword", "HiltR", true, false),
	Saber = class("Saber", "Saber", "saber", "Hilt", true, false),
	Greatsword = class("Greatsword", "Greatsword", "greatsword", "HiltR", true, true),
	Guandao = class("Guandao", "Guandao", "guandao", "Hilt", true, true),
	Spear = class("Spear", "Spear", "spear", "Hilt", true, true),
	Staff = class("Staff", "Staff", "staff", "Hilt", true, true),
} :: { [string]: Class }

Weapons.ClassOrder = { "Fist", "Sword", "Saber", "Greatsword", "Guandao", "Spear", "Staff" }

-- Grades of weapons and arts. tier is the inventory frame on the shared rarity
-- ladder (1 bronze, 2 silver, 3 jade, 4 violet, 5 gold; docs/ui/inventory.md) and
-- color matches that frame.
Weapons.Grades = {
	Mortal = { name = "Mortal", multiplier = 1.0, color = Color3.fromRGB(214, 168, 118), order = 1, tier = 1 },
	Spirit = { name = "Spirit", multiplier = 1.25, color = Color3.fromRGB(112, 222, 156), order = 2, tier = 3 },
	Earth = { name = "Earth", multiplier = 1.5, color = Color3.fromRGB(196, 150, 255), order = 3, tier = 4 },
	Heaven = { name = "Heaven", multiplier = 1.9, color = Color3.fromRGB(255, 208, 96), order = 4, tier = 5 },
} :: { [string]: Grade }

local function weapon(id: string, name: string, cls: string, grade: string, model: string, blurb: string): Weapon
	return { id = id, name = name, class = cls, grade = grade, model = model, blurb = blurb }
end

Weapons.Defs = {
	-- Mortal: the starting jian and the sect rack's weapons
	IronJian = weapon("IronJian", "Iron Jian", "Sword", "Mortal", "Jian", "A plain double-edged sword, the first blade of every disciple."),
	IronDadao = weapon("IronDadao", "Iron Dadao", "Saber", "Mortal", "Dadao", "A heavy single-edged saber that cleaves in wide arcs."),
	IronGreatsword = weapon("IronGreatsword", "Iron Greatsword", "Greatsword", "Mortal", "Greatsword", "A slab of iron for those who would rather not swing twice."),
	IronGuandao = weapon("IronGuandao", "Iron Guandao", "Guandao", "Mortal", "Guandao", "A crescent blade on a long haft that keeps beasts at bay."),
	IronSpear = weapon("IronSpear", "Iron Spear", "Spear", "Mortal", "Spear", "A long spear for fast, far-reaching thrusts."),
	BambooStaff = weapon("BambooStaff", "Bamboo Staff", "Staff", "Mortal", "Staff", "A spirit-bamboo staff that sweeps everything around you."),
	-- Spirit: boss drops
	AzureFrostJian = weapon("AzureFrostJian", "Azure Frost Jian", "Sword", "Spirit", "Jian", "A jian forged in a glacier spring; its edge never warms."),
	CrimsonFangDadao = weapon("CrimsonFangDadao", "Crimson Fang Dadao", "Saber", "Spirit", "Dadao", "A saber quenched in demon-beast blood."),
	MountainSplitterGreatsword = weapon("MountainSplitterGreatsword", "Mountain Splitter", "Greatsword", "Spirit", "Greatsword", "A greatsword said to have split a hill in two."),
	GreenDragonGuandao = weapon("GreenDragonGuandao", "Green Dragon Guandao", "Guandao", "Spirit", "Guandao", "A guandao whose crescent hums like a dragon's breath."),
	SilverSerpentSpear = weapon("SilverSerpentSpear", "Silver Serpent Spear", "Spear", "Spirit", "Spear", "A spear that strikes as fast as a serpent."),
	CloudSageStaff = weapon("CloudSageStaff", "Cloud Sage Staff", "Staff", "Spirit", "Staff", "A staff carried by a wandering sage of the clouds."),
} :: { [string]: Weapon }

Weapons.Order = {
	"IronJian", "IronDadao", "IronGreatsword", "IronGuandao", "IronSpear", "BambooStaff",
	"AzureFrostJian", "CrimsonFangDadao", "MountainSplitterGreatsword", "GreenDragonGuandao", "SilverSerpentSpear", "CloudSageStaff",
}

Weapons.STARTING = "IronJian" -- new profiles own and equip this

-- The class a weapon belongs to; nil, "" or an unknown id is Fist.
function Weapons.classOf(weaponId: string?): string
	local def = weaponId and Weapons.Defs[weaponId]
	return if def then def.class else Weapons.FIST
end

function Weapons.gradeMultiplier(weaponId: string?): number
	local def = weaponId and Weapons.Defs[weaponId]
	local grade = def and Weapons.Grades[def.grade]
	return if grade then grade.multiplier else 1
end

function Weapons.daoMultiplier(level: number): number
	local index = math.clamp(math.floor(level), 0, Pacing.MAX_LEVEL) + 1
	return Pacing.MULTIPLIER[index] or 1
end

-- Dao XP to go from `level` to the next.
function Weapons.xpToNext(level: number): number
	return Pacing.XP_BASE + level * Pacing.XP_PER_LEVEL
end

Weapons.MAX_LEVEL = Pacing.MAX_LEVEL

-- The message a gated technique shows without its class equipped.
function Weapons.requires(classId: string): string
	local c = Weapons.Classes[classId]
	if not c then
		return "Requires a weapon"
	elseif classId == Weapons.FIST then
		return "Requires bare hands"
	end
	return `Requires a {c.noun}`
end

-- The Animations path of a class's chain step: "Fists/3", "Weapons/Sword/2".
function Weapons.clip(classId: string, step: number): string
	if classId == Weapons.FIST or not Weapons.Classes[classId] then
		return `Fists/{step}`
	end
	return `Weapons/{classId}/{step}`
end

return Weapons
