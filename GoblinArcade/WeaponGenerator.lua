local _, GA = ...

GA.WeaponGenerator = GA.WeaponGenerator or {}
local WG = GA.WeaponGenerator

WG.VERSION = 2

local ARCHETYPES = {
    Dagger = {
        multiplier = 0.78,
        spread = 0.25,
        speed = "FAST",
        range = 1,
        trait = "BACKSTAB",
        traitValues = { [2] = 35, [3] = 45, [4] = 55, [5] = 65, [6] = 75 },
        traitText = function(value)
            return string.format("+%d%% damage when attacking from behind.", value)
        end,
    },
    Sword = {
        multiplier = 0.95,
        spread = 0.30,
        speed = "NORMAL",
        range = 1,
        trait = "GUARD",
        traitValues = { [2] = 5, [3] = 8, [4] = 12, [5] = 16, [6] = 20 },
        traitText = function(value)
            return string.format("After attacking, gain +%d%% Parry until your next turn.", value)
        end,
    },
    Axe = {
        multiplier = 1.02,
        spread = 0.38,
        speed = "NORMAL",
        range = 1,
        trait = "CLEAVE",
        traitValues = { [2] = 20, [3] = 25, [4] = 30, [5] = 35, [6] = 40 },
        traitText = function(value)
            return string.format("An adjacent enemy takes %d%% of the attack's damage.", value)
        end,
    },
    Mace = {
        multiplier = 1.05,
        spread = 0.35,
        speed = "NORMAL",
        range = 1,
        trait = "STAGGER",
        traitValues = { [2] = 15, [3] = 20, [4] = 25, [5] = 30, [6] = 35 },
        traitText = function(value)
            return string.format("%d%% chance to delay the target's next action.", value)
        end,
    },
    Staff = {
        multiplier = 0.95,
        spread = 0.30,
        speed = "NORMAL",
        range = 2,
        trait = "SWEEP",
        traitValues = { [2] = 25, [3] = 35, [4] = 45, [5] = 55, [6] = 65 },
        traitText = function(value)
            return string.format("A second adjacent target takes %d%% damage.", value)
        end,
    },
    Polearm = {
        multiplier = 1.08,
        spread = 0.35,
        speed = "SLOW",
        range = 2,
        trait = "IMPALE",
        traitValues = { [2] = 20, [3] = 30, [4] = 40, [5] = 50, [6] = 60 },
        traitText = function(value)
            return string.format("Attacks at range 2 deal +%d%% damage.", value)
        end,
    },
    Bow = {
        multiplier = 0.92,
        spread = 0.28,
        speed = "NORMAL",
        range = 4,
        trait = "PRECISE",
        traitValues = { [2] = 6, [3] = 9, [4] = 12, [5] = 15, [6] = 18 },
        traitText = function(value)
            return string.format("+%d%% critical strike chance at maximum range.", value)
        end,
    },
    Gun = {
        multiplier = 1.02,
        spread = 0.38,
        speed = "SLOW",
        range = 4,
        trait = "IMPACT",
        traitValues = { [2] = 20, [3] = 30, [4] = 40, [5] = 50, [6] = 60 },
        traitText = function(value)
            return string.format("Deal +%d%% damage to enemies at full health.", value)
        end,
    },
    Crossbow = {
        multiplier = 1.05,
        spread = 0.35,
        speed = "SLOW",
        range = 4,
        trait = "PUNCTURE",
        traitValues = { [2] = 10, [3] = 15, [4] = 20, [5] = 25, [6] = 30 },
        traitText = function(value)
            return string.format("Ignore %d%% of the target's Armor.", value)
        end,
    },
    Wand = {
        multiplier = 0.72,
        spread = 0.20,
        speed = "FAST",
        range = 4,
        trait = "FOCUS",
        traitValues = { [2] = 10, [3] = 15, [4] = 20, [5] = 25, [6] = 30 },
        traitText = function(value)
            return string.format("Repeated attacks on the same target gain +%d%% damage.", value)
        end,
    },
    Fist = {
        multiplier = 0.82,
        spread = 0.25,
        speed = "FAST",
        range = 1,
        trait = "FLURRY",
        traitValues = { [2] = 15, [3] = 20, [4] = 25, [5] = 30, [6] = 35 },
        traitText = function(value)
            return string.format("%d%% chance for an immediate half-damage follow-up hit.", value)
        end,
    },
    Weapon = {
        multiplier = 0.95,
        spread = 0.30,
        speed = "NORMAL",
        range = 1,
    },
}

local function Contains(text, needle)
    return text and string.find(string.lower(text), needle, 1, true) ~= nil
end

local function ResolveArchetype(itemSubType)
    if Contains(itemSubType, "dagger") then return "Dagger" end
    if Contains(itemSubType, "sword") then return "Sword" end
    if Contains(itemSubType, "axe") then return "Axe" end
    if Contains(itemSubType, "mace") then return "Mace" end
    if Contains(itemSubType, "staff") or Contains(itemSubType, "staves") then return "Staff" end
    if Contains(itemSubType, "polearm") then return "Polearm" end
    if Contains(itemSubType, "crossbow") then return "Crossbow" end
    if Contains(itemSubType, "bow") then return "Bow" end
    if Contains(itemSubType, "gun") then return "Gun" end
    if Contains(itemSubType, "wand") then return "Wand" end
    if Contains(itemSubType, "fist") then return "Fist" end
    return "Weapon"
end

local function ResolveHandedness(archetype, itemSubType, equipLoc)
    if equipLoc == "INVTYPE_2HWEAPON" or Contains(itemSubType, "two-handed") then
        return "Two-Handed"
    end

    if archetype == "Staff" or archetype == "Polearm" then
        return "Two-Handed"
    end

    if archetype == "Bow" or archetype == "Gun" or archetype == "Crossbow" or archetype == "Wand" then
        return "Ranged"
    end

    return "One-Handed"
end

local function Rounded(value)
    return math.floor(value + 0.5)
end

function WG:Convert(metadata)
    if not metadata then
        return nil
    end

    local archetypeName = ResolveArchetype(metadata.itemSubType)
    local archetype = ARCHETYPES[archetypeName] or ARCHETYPES.Weapon
    local handedness = ResolveHandedness(archetypeName, metadata.itemSubType, metadata.equipLoc)

    local itemLevel = math.max(1, tonumber(metadata.itemLevel) or 1)
    local quality = tonumber(metadata.quality) or 1

    -- Deterministic power budget. Item level sets damage; type/handedness shapes it.
    local baseDamage = 3 + math.floor(itemLevel * 0.55)
    local multiplier = archetype.multiplier

    if handedness == "Two-Handed" then
        multiplier = multiplier * 1.22
    end

    local rawMinDamage = math.max(1, Rounded(baseDamage * multiplier))
    local rawSpread = math.max(2, Rounded(rawMinDamage * archetype.spread))
    local rawMaxDamage = rawMinDamage + rawSpread

    local minDamage = GA:ScaleCombatValue(rawMinDamage)
    local maxDamage = math.max(minDamage, GA:ScaleCombatValue(rawMaxDamage))

    local speed = archetype.speed
    if handedness == "Two-Handed" and (archetypeName == "Axe" or archetypeName == "Mace" or archetypeName == "Sword" or archetypeName == "Staff") then
        speed = "SLOW"
    end

    local traitName
    local traitDescription
    local traitValue

    -- Rarity never rolls a random affix. Uncommon+ simply strengthens the fixed
    -- signature mechanic of that weapon archetype.
    if quality >= 2 and archetype.trait and archetype.traitValues then
        local cappedQuality = math.min(quality, 6)
        traitValue = archetype.traitValues[cappedQuality] or archetype.traitValues[2]
        traitName = archetype.trait

        if archetype.traitText then
            traitDescription = archetype.traitText(traitValue)
        end
    end

    return {
        generatorVersion = self.VERSION,
        sourceItemID = metadata.itemID,
        sourceName = metadata.name,
        itemLevel = itemLevel,
        quality = quality,
        archetype = archetypeName,
        handedness = handedness,
        style = handedness .. " " .. archetypeName,
        damageMin = minDamage,
        damageMax = maxDamage,
        speed = speed,
        range = archetype.range,
        traitName = traitName,
        traitValue = traitValue,
        traitDescription = traitDescription,
    }
end
