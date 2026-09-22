local GA = {
    StudioData = {
        classes = {
            {
                id = "warrior",
                baseHealth = 20, baseMana = 0,
                baseStrength = 23, baseAgility = 20, baseStamina = 22, baseIntellect = 20, baseSpirit = 20,
                meleeApPerLevel = 3, meleeApPerStrength = 2, meleeApPerAgility = 0, meleeApOffset = -20,
                rangedApPerLevel = 1, rangedApPerAgility = 1, rangedApOffset = -10,
                critAgiPerPercent = 20, dodgeAgiPerPercent = 20,
                baseDodge = 3, baseParry = 5, baseBlock = 5,
                levelStatTable = [==[1,20,0,23,20,22,20,20
20,199,0,47,35,43,22,26
60,1689,0,120,80,110,30,45]==],
            },
        },
    },
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
assert(loadfile("GoblinArcade/ForeverRules.lua"))("GoblinArcade", GA)
local FR = GA.ForeverRules
local l1 = FR:GetClassLevelStats("warrior", 1)
local l20 = FR:GetClassLevelStats("warrior", 20)
local l60 = FR:GetClassLevelStats("warrior", 60)
assert(l1.baseHealth == 20 and l1.strength == 23 and l1.stamina == 22)
assert(l20.baseHealth == 199 and l20.strength == 47 and l20.stamina == 43)
assert(l60.baseHealth == 1689 and l60.strength == 120 and l60.stamina == 110)
assert(FR:HealthFromStamina(22) == 40)
local r1 = FR:GetReferencePlayerCombatProfile("warrior", 1)
assert(r1.attackPower == 29)
assert(r1.rawMaxHealth == 60)
assert(r1.maxHealth == 6)
local d = FR:BuildDerivedStats(1, "warrior", {})
assert(d.attackPower == 29 and d.rawMaxHealth == 60 and d.maxHealth == 6)
print("Class progression runtime audit OK: exact Warrior rows and Classic level-1 health/AP resolve correctly.")
