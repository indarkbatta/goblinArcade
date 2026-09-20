local _, GA = ...

GA.EnemyGenerator = GA.EnemyGenerator or {}
local EG = GA.EnemyGenerator

EG.VERSION = 9

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
        xpMultiplier = 1.00,
    },
    veteran = {
        levelBonus = 1,
        hpMultiplier = 1.30,
        damageMultiplier = 1.12,
        scoreMultiplier = 1.30,
        xpMultiplier = 1.35,
    },
    elite = {
        levelBonus = 2,
        hpMultiplier = 1.80,
        damageMultiplier = 1.30,
        scoreMultiplier = 1.80,
        xpMultiplier = 2.00,
    },
    boss = {
        levelBonus = 3,
        hpMultiplier = 3.60,
        damageMultiplier = 1.60,
        scoreMultiplier = 3.00,
        xpMultiplier = 5.00,
    },
}

local ARCHETYPES = {
    kobold = {
        name = "Kobold",
        hpMultiplier = 0.95,
        damageMultiplier = 0.90,
        visionRadius = 6,
        movementPattern = "normal",
        baseScore = 100,
        dangerRating = 2,
    },
    spider = {
        name = "Spider",
        hpMultiplier = 0.70,
        damageMultiplier = 0.80,
        visionRadius = 7,
        movementPattern = "quick",
        baseScore = 90,
        dangerRating = 2,
    },
    skeleton = {
        name = "Skeleton",
        hpMultiplier = 1.20,
        damageMultiplier = 1.00,
        visionRadius = 5,
        movementPattern = "slow",
        baseScore = 125,
        dangerRating = 3,
    },
    brute = {
        name = "Brute",
        hpMultiplier = 1.50,
        damageMultiplier = 1.25,
        visionRadius = 5,
        baseScore = 160,
        dangerRating = 4,
    },
}

local function FindStudioRecord(collectionName, recordId)
    for _, record in ipairs(GA.StudioData and GA.StudioData[collectionName] or {}) do
        if record.id == recordId then
            return record
        end
    end
    return nil
end

local function GetRankDefinition(rankName)
    local key = rankName or "normal"
    local fallback = RANKS[key] or RANKS.normal
    local record = FindStudioRecord("ranks", key)
    if not record then
        return fallback
    end
    return {
        levelBonus = tonumber(record.levelBonus) or fallback.levelBonus,
        hpMultiplier = tonumber(record.hpMultiplier) or fallback.hpMultiplier,
        damageMultiplier = tonumber(record.damageMultiplier) or fallback.damageMultiplier,
        scoreMultiplier = tonumber(record.scoreMultiplier) or fallback.scoreMultiplier,
        xpMultiplier = tonumber(record.xpMultiplier) or fallback.xpMultiplier or 1,
    }
end

local function GetArchetypeDefinition(archetypeName)
    local key = archetypeName or "kobold"
    local fallback = ARCHETYPES[key] or ARCHETYPES.kobold
    local record = FindStudioRecord("enemies", key)
    if not record then
        return fallback
    end
    return {
        name = record.name or fallback.name,
        hpMultiplier = tonumber(record.hpMultiplier) or fallback.hpMultiplier,
        damageMultiplier = tonumber(record.damageMultiplier) or fallback.damageMultiplier,
        visionRadius = tonumber(record.visionRadius) or fallback.visionRadius,
        movementPattern = string.lower(tostring(record.movement or fallback.movementPattern or "normal")),
        baseScore = tonumber(record.baseScore) or fallback.baseScore,
        dangerRating = math.max(1, math.min(10, tonumber(record.dangerRating) or fallback.dangerRating or 1)),
        lootTableId = record.lootTableId,
    }
end

local function GetXpPerDanger()
    for _, record in ipairs(GA.StudioData and GA.StudioData.progression or {}) do
        if record.id == "run_xp" then
            return math.max(1, tonumber(record.xpPerDanger) or 8)
        end
    end
    return 8
end

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
        hpMultiplier = 1 + 0.15 * depth,
        damageMultiplier = 1 + 0.05 * depth,
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
    local rank = GetRankDefinition(rankName)

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
    local archetype = GetArchetypeDefinition(archetypeKey)
    local rank = GetRankDefinition(rankKey)
    local playerLevel = math.max(1, tonumber(options.playerLevel) or 1)
    local floor = math.max(1, tonumber(options.floor) or 1)
    local gearPressure = options.gearPressure
        or self:CalculateGearPressure(playerLevel, options.equipment or {})

    local effectiveLevel = self:GetEffectiveLevel(playerLevel, floor, rankKey)
    local levelPressure = GetLevelPressure(playerLevel)
    local floorPressure = GetFloorPressure(floor)

    -- Balance v2: HP is intentionally a little chunkier so late-floor
    -- Veterans/Elites survive long enough for Warrior control/defense tools
    -- to matter without turning early normals into damage sponges.
    local referenceDamage = 5 + effectiveLevel * 0.90
    local baseHp = referenceDamage * 3.25

    -- Damage remains deterministic before the final bounded hit roll. The
    -- steeper floor pressure makes Floors 7-9 meaningfully dangerous while
    -- keeping Floors 1-2 readable for fresh Arcade heroes.
    local referencePlayerHealth = 100 + effectiveLevel * 20
    local averageDamage = referencePlayerHealth * 0.040

    local rawMaxHp = math.max(1, Round(
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

    local rawDamageMin = math.max(1, Round(scaledAverageDamage * 0.80))
    local rawDamageMax = math.max(rawDamageMin, Round(scaledAverageDamage * 1.20))

    local maxHp = GA:ScaleCombatValue(rawMaxHp)
    local damageMin = GA:ScaleCombatValue(rawDamageMin)
    local damageMax = math.max(damageMin, GA:ScaleCombatValue(rawDamageMax))
    local scoreValue = math.max(1, Round(archetype.baseScore * rank.scoreMultiplier))
    local xpValue = math.max(1, Round((archetype.dangerRating or 1) * GetXpPerDanger() * (rank.xpMultiplier or 1)))

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
        movementPattern = archetype.movementPattern or "normal",
        scoreValue = scoreValue,
        dangerRating = archetype.dangerRating or 1,
        rankXpMultiplier = rank.xpMultiplier or 1,
        xpValue = xpValue,
        lootTableId = archetype.lootTableId,
        alive = true,
        alerted = false,
        skipTurn = false,
    }
end
