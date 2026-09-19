local _, GA = ...

GA.EnemyGenerator = GA.EnemyGenerator or {}
local EG = GA.EnemyGenerator

EG.VERSION = 2

local GEAR_SLOTS = {
    "head",
    "neck",
    "shoulder",
    "chest",
    "waist",
    "legs",
    "feet",
    "wrist",
    "hands",
    "finger1",
    "finger2",
    "trinket1",
    "trinket2",
    "back",
    "mainhand",
    "offhand",
}

local RANKS = {
    normal = {
        levelBonus = 0,
        hpMultiplier = 1.00,
        damageMultiplier = 1.00,
        scoreMultiplier = 1.00,
    },
    veteran = {
        levelBonus = 1,
        hpMultiplier = 1.25,
        damageMultiplier = 1.10,
        scoreMultiplier = 1.30,
    },
    elite = {
        levelBonus = 2,
        hpMultiplier = 1.60,
        damageMultiplier = 1.25,
        scoreMultiplier = 1.80,
    },
    boss = {
        levelBonus = 3,
        hpMultiplier = 2.80,
        damageMultiplier = 1.45,
        scoreMultiplier = 3.00,
    },
}

local ARCHETYPES = {
    kobold = {
        name = "Kobold",
        hpMultiplier = 0.95,
        damageMultiplier = 0.90,
        visionRadius = 6,
        baseScore = 100,
    },
    spider = {
        name = "Spider",
        hpMultiplier = 0.70,
        damageMultiplier = 0.80,
        visionRadius = 7,
        baseScore = 90,
    },
    skeleton = {
        name = "Skeleton",
        hpMultiplier = 1.20,
        damageMultiplier = 1.00,
        visionRadius = 5,
        baseScore = 125,
    },
    brute = {
        name = "Brute",
        hpMultiplier = 1.50,
        damageMultiplier = 1.25,
        visionRadius = 5,
        baseScore = 160,
    },
}

local function Clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function Round(value)
    return math.floor(value + 0.5)
end

local function GetFloorBonus(floor)
    floor = math.max(1, tonumber(floor) or 1)

    if floor >= 9 then
        return 4
    elseif floor >= 7 then
        return 3
    elseif floor >= 5 then
        return 2
    elseif floor >= 3 then
        return 1
    end

    return 0
end

local function GetLevelPressure(playerLevel)
    local level = math.max(1, tonumber(playerLevel) or 1)

    -- Level 1 = 1.00x, level 60 = 1.15x.
    -- Keep this separate from Effective Enemy Level so higher-level characters
    -- face a slightly higher relative challenge, not only larger raw numbers.
    return 1 + 0.15 * ((level - 1) / 59)
end

local function GetFloorPressure(floor)
    local floorNumber = math.max(1, tonumber(floor) or 1)
    local depth = floorNumber - 1

    return {
        hpMultiplier = 1 + 0.06 * depth,
        damageMultiplier = 1 + 0.04 * depth,
    }
end

local function GetItemLevel(item)
    if not item then
        return 0
    end

    return tonumber(item.itemLevel)
        or (item.arcadeWeapon and tonumber(item.arcadeWeapon.itemLevel))
        or (item.arcadeItem and tonumber(item.arcadeItem.itemLevel))
        or 0
end

local function UsesVirtualOffhand(mainHand)
    if not mainHand then
        return false
    end

    if mainHand.equipLoc == "INVTYPE_2HWEAPON"
        or mainHand.equipLoc == "INVTYPE_RANGED"
        or mainHand.equipLoc == "INVTYPE_RANGEDRIGHT" then
        return true
    end

    local handedness = mainHand.arcadeWeapon and mainHand.arcadeWeapon.handedness
    return handedness == "Two-Handed" or handedness == "Ranged"
end

function EG:CalculateGearPressure(playerLevel, equipment)
    local level = math.max(1, tonumber(playerLevel) or 1)
    local expectedAverageItemLevel = level + 3
    local expectedGearSum = #GEAR_SLOTS * expectedAverageItemLevel
    local actualGearSum = 0

    equipment = equipment or {}

    for _, slotKey in ipairs(GEAR_SLOTS) do
        actualGearSum = actualGearSum + GetItemLevel(equipment[slotKey])
    end

    -- A two-handed/ranged weapon consumes the off-hand budget. Count its
    -- item level a second time only when the actual off-hand is empty.
    if not equipment.offhand and UsesVirtualOffhand(equipment.mainhand) then
        actualGearSum = actualGearSum + GetItemLevel(equipment.mainhand)
    end

    local gearIndex = expectedGearSum > 0 and (actualGearSum / expectedGearSum) or 1
    local overgear = Clamp(gearIndex - 1.0, 0.0, 0.50)

    return {
        actualGearSum = actualGearSum,
        expectedGearSum = expectedGearSum,
        expectedAverageItemLevel = expectedAverageItemLevel,
        gearIndex = gearIndex,
        overgear = overgear,
        hpMultiplier = 1 + overgear * 0.70,
        damageMultiplier = 1 + overgear * 0.35,
    }
end

function EG:GetEffectiveLevel(playerLevel, floor, rankName)
    local level = math.max(1, tonumber(playerLevel) or 1)
    local rank = RANKS[rankName or "normal"] or RANKS.normal

    return level + GetFloorBonus(floor) + rank.levelBonus
end

function EG:GetLevelPressure(playerLevel)
    return GetLevelPressure(playerLevel)
end

function EG:GetFloorPressure(floor)
    local pressure = GetFloorPressure(floor)

    return {
        hpMultiplier = pressure.hpMultiplier,
        damageMultiplier = pressure.damageMultiplier,
    }
end

function EG:CreateEnemy(options)
    options = options or {}

    local archetypeKey = options.archetype or "kobold"
    local rankKey = options.rank or "normal"
    local archetype = ARCHETYPES[archetypeKey] or ARCHETYPES.kobold
    local rank = RANKS[rankKey] or RANKS.normal
    local playerLevel = math.max(1, tonumber(options.playerLevel) or 1)
    local floor = math.max(1, tonumber(options.floor) or 1)
    local gearPressure = options.gearPressure
        or self:CalculateGearPressure(playerLevel, options.equipment or {})

    local effectiveLevel = self:GetEffectiveLevel(playerLevel, floor, rankKey)
    local levelPressure = GetLevelPressure(playerLevel)
    local floorPressure = GetFloorPressure(floor)

    -- Reference attack power is calibrated so a level-13 normal enemy lands
    -- around the original prototype's ~36 HP before archetype adjustments.
    local referenceDamage = 5 + effectiveLevel * 0.90
    local baseHp = referenceDamage * 2.20

    -- Damage is based on a deterministic reference player-health curve.
    -- The individual hit still rolls inside the resulting fixed damage range.
    local referencePlayerHealth = 100 + effectiveLevel * 20
    local averageDamage = referencePlayerHealth * 0.035

    local maxHp = math.max(1, Round(
        baseHp
        * archetype.hpMultiplier
        * rank.hpMultiplier
        * levelPressure
        * floorPressure.hpMultiplier
        * gearPressure.hpMultiplier
    ))

    local scaledAverageDamage = averageDamage
        * archetype.damageMultiplier
        * rank.damageMultiplier
        * levelPressure
        * floorPressure.damageMultiplier
        * gearPressure.damageMultiplier

    local damageMin = math.max(1, Round(scaledAverageDamage * 0.80))
    local damageMax = math.max(damageMin, Round(scaledAverageDamage * 1.20))
    local scoreValue = math.max(1, Round(archetype.baseScore * rank.scoreMultiplier))

    return {
        generatorVersion = self.VERSION,
        id = archetypeKey,
        archetype = archetypeKey,
        rank = rankKey,
        name = archetype.name,
        level = effectiveLevel,
        playerLevel = playerLevel,
        floor = floor,
        levelPressure = levelPressure,
        floorHpMultiplier = floorPressure.hpMultiplier,
        floorDamageMultiplier = floorPressure.damageMultiplier,
        gearHpMultiplier = gearPressure.hpMultiplier,
        gearDamageMultiplier = gearPressure.damageMultiplier,
        hp = maxHp,
        maxHp = maxHp,
        damageMin = damageMin,
        damageMax = damageMax,
        visionRadius = archetype.visionRadius,
        scoreValue = scoreValue,
        alive = true,
        alerted = false,
        skipTurn = false,
    }
end
