local GA = {
    COMBAT_NUMBER_DIVISOR = 10,
    WEAPON_SPEED_SECONDS = { FAST = 1.8, NORMAL = 2.4, SLOW = 3.2 },
}
function GA:ScaleCombatValue(value, preservePositive)
    local n = tonumber(value) or 0
    if n <= 0 then return 0 end
    local scaled = math.floor((n / 10) + 0.5)
    if preservePositive == false then return math.max(0, scaled) end
    return math.max(1, scaled)
end
function GA:GetDifficultyDefinition(id)
    local key = string.upper(tostring(id or "NORMAL"))
    if key == "EASY" then return { id = "EASY", hpMultiplier = 0.90, damageMultiplier = 0.85, scoreMultiplier = 0.90 } end
    if key == "HARD" then return { id = "HARD", hpMultiplier = 1.20, damageMultiplier = 1.20, scoreMultiplier = 1.20 } end
    return { id = "NORMAL", hpMultiplier = 1, damageMultiplier = 1, scoreMultiplier = 1 }
end

assert(loadfile("GoblinArcade/Data/StudioData.lua"))("GoblinArcade", GA)
assert(GA.StudioData.schemaVersion == 17)
assert(GA.StudioData.studioVersion == "1.16.0")
assert(loadfile("GoblinArcade/ForeverRules.lua"))("GoblinArcade", GA)
assert(loadfile("GoblinArcade/EnemyGenerator.lua"))("GoblinArcade", GA)

local FR = GA.ForeverRules
local EG = GA.EnemyGenerator
local warrior = FR:GetClassProfile("warrior")
assert(warrior and warrior.strAP == 2 and warrior.healthPerStaminaAfter20 == 10)

local l1 = FR:GetClassLevelStats("warrior", 1, "human")
local l5 = FR:GetClassLevelStats("warrior", 5, "human")
local l10 = FR:GetClassLevelStats("warrior", 10, "human")
assert(l1.baseHealth == 20 and l1.strength == 23 and l1.stamina == 22)
assert(l5.baseHealth == 56 and l5.strength == 28 and l5.stamina == 26)
assert(l10.baseHealth == 97 and l10.strength == 33 and l10.stamina == 31)
assert(FR:HealthFromStamina(22, "warrior") == 40)

local human1 = FR:GetReferencePlayerCombatProfile("warrior", 1, "human")
local human5 = FR:GetReferencePlayerCombatProfile("warrior", 5, "human")
local human10 = FR:GetReferencePlayerCombatProfile("warrior", 10, "human")
assert(human1.attackPower == 29 and human1.rawMaxHealth == 60 and human1.maxHealth == 6)
assert(human5.attackPower == 51 and human5.rawMaxHealth == 136)
assert(human10.attackPower == 76 and human10.rawMaxHealth == 227)

local orc1 = FR:GetReferencePlayerCombatProfile("warrior", 1, "orc")
assert(orc1.stats.strength == 26 and orc1.stats.agility == 17 and orc1.stats.stamina == 23)
assert(orc1.stats.intellect == 17 and orc1.stats.spirit == 22)
assert(orc1.attackPower == 35 and orc1.rawMaxHealth == 70)

local derived = FR:BuildDerivedStats(1, "warrior", {}, "orc")
assert(derived.attackPower == 35 and derived.rawMaxHealth == 70 and derived.raceId == "orc")
assert(derived.defenseSkill == 5 and derived.weaponSkill == 5)
assert(math.abs(derived.armor - 34) < 0.001)

local studioWarrior
for _, row in ipairs(GA.StudioData.classes) do if row.id == "warrior" then studioWarrior = row break end end
assert(studioWarrior)
local originalStrengthAp = studioWarrior.meleeApPerStrength
studioWarrior.meleeApPerStrength = originalStrengthAp + 1
local stronger = FR:GetReferencePlayerCombatProfile("warrior", 1)
assert(stronger.attackPower > human1.attackPower)
studioWarrior.meleeApPerStrength = originalStrengthAp

local originalTable = studioWarrior.levelStatTable
studioWarrior.levelStatTable = string.gsub(originalTable, "1,20,0,23,20,22,20,20", "1,20,0,24,20,22,20,20", 1)
local changedCurve = FR:GetReferencePlayerCombatProfile("warrior", 1)
assert(changedCurve.stats.strength == 24 and changedCurve.attackPower == 31)
studioWarrior.levelStatTable = originalTable

local orcRace
for _, row in ipairs(GA.StudioData.races) do if row.id == "orc" then orcRace = row break end end
assert(orcRace)
local originalOrcStrength = orcRace.strengthOffset
orcRace.strengthOffset = originalOrcStrength + 1
local changedRace = FR:GetReferencePlayerCombatProfile("warrior", 1, "orc")
assert(changedRace.stats.strength == 27 and changedRace.attackPower == 37)
orcRace.strengthOffset = originalOrcStrength

local gearPressure = { hpMultiplier = 1, damageMultiplier = 1 }
local baseEnemy = EG:CreateEnemy({ archetype = "kobold", rank = "normal", playerLevel = 1, floor = 1, classId = "warrior", gearPressure = gearPressure, difficulty = "NORMAL" })

studioWarrior.meleeApPerStrength = originalStrengthAp + 1
local offenseEnemy = EG:CreateEnemy({ archetype = "kobold", rank = "normal", playerLevel = 1, floor = 1, classId = "warrior", gearPressure = gearPressure, difficulty = "NORMAL" })
assert(offenseEnemy.maxHp > baseEnemy.maxHp)
studioWarrior.meleeApPerStrength = originalStrengthAp

local originalStaminaHp = studioWarrior.healthPerStaminaAfter20
studioWarrior.healthPerStaminaAfter20 = originalStaminaHp + 5
local durabilityEnemy = EG:CreateEnemy({ archetype = "kobold", rank = "normal", playerLevel = 1, floor = 1, classId = "warrior", gearPressure = gearPressure, difficulty = "NORMAL" })
assert(durabilityEnemy.damageMax > baseEnemy.damageMax or durabilityEnemy.damageMin > baseEnemy.damageMin)
studioWarrior.healthPerStaminaAfter20 = originalStaminaHp

local veteran = EG:CreateEnemy({ archetype = "kobold", rank = "veteran", playerLevel = 1, floor = 1, classId = "warrior", gearPressure = gearPressure, difficulty = "NORMAL" })
local hard = EG:CreateEnemy({ archetype = "kobold", rank = "normal", playerLevel = 1, floor = 1, classId = "warrior", gearPressure = gearPressure, difficulty = "HARD" })
assert(veteran.maxHp > baseEnemy.maxHp and veteran.damageMax >= baseEnemy.damageMax)
assert(hard.maxHp > baseEnemy.maxHp and hard.damageMax >= baseEnemy.damageMax)

print("Class progression runtime audit OK: L1/L5/L10 snapshots, race offsets, editable class curve, derived stats, and enemy offense/durability/rank/difficulty reactions verified.")
