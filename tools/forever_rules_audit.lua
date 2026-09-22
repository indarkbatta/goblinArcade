local GA = {
    WEAPON_SPEED_SECONDS = { FAST = 1.8, NORMAL = 2.4, SLOW = 3.2 },
}
function GA:ScaleCombatValue(value, preservePositive)
    local scaled = math.floor(((tonumber(value) or 0) / 10) + 0.5)
    if preservePositive == false then return math.max(0, scaled) end
    return math.max(1, scaled)
end

local studioChunk = assert(loadfile("GoblinArcade/Data/StudioData.lua"))
studioChunk("GoblinArcade", GA)
local chunk = assert(loadfile("GoblinArcade/ForeverRules.lua"))
chunk("GoblinArcade", GA)
local FR = assert(GA.ForeverRules)
assert(FR.VERSION == 3)
assert(FR.ID == "FOREVER_CLASSIC_BETA_V3")
local level1 = FR:GetClassLevelStats("WARRIOR", 1)
local level20 = FR:GetClassLevelStats("WARRIOR", 20)
local level60 = FR:GetClassLevelStats("WARRIOR", 60)
assert(level1.baseHealth == 20 and level1.strength == 23 and level1.stamina == 22)
assert(level20.baseHealth == 199 and level20.strength == 47 and level20.stamina == 43)
assert(level60.baseHealth == 1689 and level60.strength == 120 and level60.stamina == 110)
assert(FR:HealthFromStamina(22) == 40)
local reference1 = FR:GetReferencePlayerCombatProfile("WARRIOR", 1)
assert(reference1.attackPower == 29 and reference1.rawMaxHealth == 60 and reference1.maxHealth == 6)

local warrior = FR:BuildDerivedStats(20, "WARRIOR", {
    strength = 10, agility = 5, stamina = 8, armor = 300,
    hit = 2, crit = 1, expertise = 1, defense = 10,
    dodge = 1, parry = 1, block = 5, blockValue = 4,
    weaponSkill = 3, hasShield = true,
})
assert(warrior.strength > 10)
assert(warrior.attackPower > 0)
assert(warrior.maxHealth == 53, "Level 20 Warrior with +8 STA should resolve to 529 raw / 53 arcade HP")
assert(warrior.rawMaxHealth == 529)
assert(warrior.maxMana == warrior.intellect * 15)
assert(warrior.armor >= 300)
assert(warrior.hit == 2)
assert(warrior.defenseSkill == 110)
assert(warrior.weaponSkill == 103)
assert(warrior.block > 0 and warrior.blockValue > 4)

local reduction = FR:CalculateArmorReduction(17265, 63)
assert(math.abs(reduction - 0.75) < 0.0001, "armor cap/reference formula mismatch")
assert(FR:CalculateArmorReduction(999999, 60) == 0.75)

local apBonus = FR:CalculateAttackPowerDamageBonus(140, { weaponSpeedSeconds = 2.5 })
assert(apBonus == 3, "scaled 140 AP / 14 * 2.5 should be 3 arcade damage")

math.randomseed(1337)
local enemy = { level = 23, id = "orc_raider", rank = "normal", dangerRating = 3, armor = 400, dodge = 0, parry = 0, block = 0 }
local player = {
    level = 20, weaponSkill = 100, defenseSkill = 100, hit = 100,
    expertise = 100, crit = 0, dodge = 0, parry = 0, block = 0,
}
local result = FR:ResolvePlayerMeleeAttack(player, enemy, { weaponSpeedSeconds = 2.4 }, { id = "heroic_strike" })
assert(result.kind == "HIT", "capped hit/expertise test should land")

local damage = FR:ApplyPhysicalMitigation(100, 0, 20, { kind = "CRIT", multiplier = 2 })
assert(damage == 200)
local blocked = FR:ApplyPhysicalMitigation(20, 0, 20, { kind = "BLOCK", multiplier = 1, blocked = true, blockValue = 7 })
assert(blocked == 13)

assert(FR:CalculateRageFromSwing({ weaponSpeedSeconds = 2.4, handedness = "One-Handed" }, { kind = "HIT" }) >= 7)
assert(FR:CalculateRageFromSwing({ weaponSpeedSeconds = 3.2, handedness = "Two-Handed" }, { kind = "HIT" }) >= 14)
assert(FR:CalculateRageFromSwing({ weaponSpeedSeconds = 3.2, handedness = "Two-Handed" }, { kind = "MISS" }) == 0)

print("Forever rules audit OK: Classic class rows, stamina HP, AP, armor, attack tables, block value and normalized Rage verified.")
